-- =====================================================
-- DATABASE SCHEMA FOR BASEL III REGULATORY REPORTING
-- =====================================================
-- Based on real-world experience managing credit risk databases
-- at a major international bank for economic and regulatory capital calculations
-- Author: Matías López Sosa
-- =====================================================

-- Drop existing tables if they exist (for clean recreation)
DROP TABLE IF EXISTS facilities CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS clients CASCADE;

-- =====================================================
-- TABLE: clients
-- Stores customer information for both Retail and Corporate clients
-- =====================================================
CREATE TABLE clients (
    client_id INT PRIMARY KEY,
    client_name VARCHAR(100) NOT NULL,
    client_type VARCHAR(20) NOT NULL,
    sector VARCHAR(50) NOT NULL,
    country VARCHAR(50) NOT NULL,
    internal_rating VARCHAR(10) NOT NULL,
    external_rating VARCHAR(10),
    relationship_manager VARCHAR(100),
    onboarding_date DATE NOT NULL,
    last_review_date DATE,
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Constraints
    CONSTRAINT chk_client_type CHECK (client_type IN ('Retail', 'Corporate', 'SME')),
    CONSTRAINT chk_rating CHECK (internal_rating IN ('AAA', 'AA', 'A', 'BBB', 'BB', 'B', 'CCC', 'D')),
    CONSTRAINT chk_dates CHECK (last_review_date >= onboarding_date)
);

-- =====================================================
-- TABLE: products
-- Catalog of credit products for both Retail and Corporate clients
-- =====================================================
CREATE TABLE products (
    product_id INT PRIMARY KEY,
    product_type VARCHAR(50) NOT NULL,
    product_category VARCHAR(50) NOT NULL,
    base_risk_weight NUMERIC(5,4) NOT NULL,
    maturity_years INT,
    collateral_type VARCHAR(50),
    is_secured BOOLEAN DEFAULT FALSE,
    
    -- Constraints
    CONSTRAINT chk_risk_weight CHECK (base_risk_weight >= 0 AND base_risk_weight <= 1.5),
    CONSTRAINT chk_maturity CHECK (maturity_years > 0 OR maturity_years IS NULL),
    CONSTRAINT chk_product_type CHECK (product_type IN ('Term Loan', 'Revolving Credit', 'Trade Finance', 'Overdraft', 'Credit Card', 'Mortgage', 'Personal Loan'))
);

-- =====================================================
-- TABLE: facilities
-- Credit facilities/exposures with Basel III risk parameters
-- =====================================================
CREATE TABLE facilities (
    facility_id INT PRIMARY KEY,
    client_id INT NOT NULL,
    product_id INT NOT NULL,
    facility_amount NUMERIC(18,2) NOT NULL,
    outstanding_balance NUMERIC(18,2) NOT NULL,
    currency VARCHAR(3) NOT NULL,
    
    -- Basel III Risk Parameters
    pd NUMERIC(8,6) NOT NULL,
    lgd NUMERIC(5,4) NOT NULL,
    ead NUMERIC(18,2) NOT NULL,
    ccf NUMERIC(5,4) DEFAULT 1.0,
    
    -- Calculated Regulatory Metrics
    expected_loss NUMERIC(18,2),
    risk_weighted_assets NUMERIC(18,2),
    capital_requirement NUMERIC(18,2),
    calculation_date DATE,
    
    -- Facility Details
    origination_date DATE NOT NULL,
    maturity_date DATE,
    facility_status VARCHAR(20) DEFAULT 'Active',
    
    -- Foreign Keys
    CONSTRAINT fk_client FOREIGN KEY (client_id) REFERENCES clients(client_id),
    CONSTRAINT fk_product FOREIGN KEY (product_id) REFERENCES products(product_id),
    
    -- Business Logic Constraints
    CONSTRAINT chk_outstanding CHECK (outstanding_balance <= facility_amount),
    CONSTRAINT chk_outstanding_positive CHECK (outstanding_balance >= 0),
    CONSTRAINT chk_pd_range CHECK (pd >= 0 AND pd <= 1),
    CONSTRAINT chk_lgd_range CHECK (lgd >= 0 AND lgd <= 1),
    CONSTRAINT chk_ead_positive CHECK (ead > 0),
    CONSTRAINT chk_ccf_range CHECK (ccf >= 0 AND ccf <= 1),
    CONSTRAINT chk_maturity_logic CHECK (maturity_date IS NULL OR maturity_date > origination_date),
    CONSTRAINT chk_status CHECK (facility_status IN ('Active', 'Closed', 'Default', 'Restructured'))
);

-- =====================================================
-- INDEXES FOR PERFORMANCE
-- =====================================================
CREATE INDEX idx_client_sector ON clients(sector);
CREATE INDEX idx_client_rating ON clients(internal_rating);
CREATE INDEX idx_client_type ON clients(client_type);
CREATE INDEX idx_facility_client ON facilities(client_id);
CREATE INDEX idx_facility_product ON facilities(product_id);
CREATE INDEX idx_facility_status ON facilities(facility_status);


-- =====================================================
-- SAMPLE DATA: CLEAN DATA (for testing calculations)
-- =====================================================

-- Insert sample clients
INSERT INTO clients VALUES
(1, 'Acme Corporation', 'Corporate', 'Manufacturing', 'USA', 'A', 'A+', 'John Smith', '2020-01-15', '2024-06-30', TRUE),
(2, 'Global Trade Ltd', 'SME', 'Retail', 'UK', 'BBB', 'BBB', 'Jane Doe', '2019-03-20', '2024-05-15', TRUE),
(3, 'Tech Innovations Inc', 'Corporate', 'Technology', 'Germany', 'AA', 'AA-', 'Mike Johnson', '2021-06-10', '2024-07-20', TRUE),
(4, 'Energy Solutions SA', 'SME', 'Energy', 'Spain', 'BB', 'BB+', 'Sarah Williams', '2018-11-05', '2024-04-10', TRUE),
(5, 'John Doe', 'Retail', 'Individual', 'Spain', 'A', NULL, 'Maria Garcia', '2022-03-15', '2024-08-20', TRUE),
(6, 'Maria Rodriguez', 'Retail', 'Individual', 'UK', 'BBB', NULL, 'Peter Brown', '2021-09-10', '2024-07-15', TRUE);

-- Insert sample products
INSERT INTO products VALUES
(101, 'Term Loan', 'Corporate Lending', 0.5000, 5, 'Real Estate', TRUE),
(102, 'Revolving Credit', 'Working Capital', 0.7500, 3, 'Inventory', TRUE),
(103, 'Trade Finance', 'Trade', 0.2000, 1, 'Goods', TRUE),
(104, 'Overdraft', 'Working Capital', 1.0000, 1, NULL, FALSE),
(201, 'Credit Card', 'Retail Banking', 1.0000, NULL, NULL, FALSE),
(202, 'Mortgage', 'Retail Banking', 0.3500, 30, 'Property', TRUE),
(203, 'Personal Loan', 'Retail Banking', 0.7500, 5, NULL, FALSE);

-- Insert clean facilities (all valid data)
INSERT INTO facilities VALUES
(1001, 1, 101, 5000000.00, 4500000.00, 'USD', 0.015000, 0.4500, 4500000.00, 1.0, 30375.00, 2250000.00, 180000.00, '2024-01-15', '2023-01-15', '2028-01-15', 'Active'),
(1002, 2, 102, 2000000.00, 1800000.00, 'GBP', 0.025000, 0.5000, 1800000.00, 0.75, 22500.00, 1350000.00, 108000.00, '2024-01-15', '2023-03-20', '2026-03-20', 'Active'),
(1003, 3, 103, 1000000.00, 950000.00, 'EUR', 0.008000, 0.3000, 950000.00, 0.50, 2280.00, 190000.00, 15200.00, '2024-01-15', '2024-01-10', '2025-01-10', 'Active'),
(1004, 4, 104, 500000.00, 450000.00, 'EUR', 0.035000, 0.6000, 450000.00, 1.0, 9450.00, 450000.00, 36000.00, '2024-01-15', '2024-02-01', '2025-02-01', 'Active'),
(2001, 5, 201, 15000.00, 12000.00, 'EUR', 0.030000, 0.8000, 12000.00, 1.0, 288.00, 12000.00, 960.00, '2024-01-15', '2022-03-15', NULL, 'Active'),
(2002, 5, 202, 250000.00, 240000.00, 'EUR', 0.010000, 0.3500, 240000.00, 1.0, 840.00, 84000.00, 6720.00, '2024-01-15', '2022-03-15', '2052-03-15', 'Active'),
(2003, 6, 203, 25000.00, 22000.00, 'GBP', 0.020000, 0.7000, 22000.00, 1.0, 308.00, 16500.00, 1320.00, '2024-01-15', '2023-09-10', '2028-09-10', 'Active');

-- =====================================================
-- SAMPLE DATA: PROBLEMATIC DATA (for testing DQ checks)
-- Create a separate schema for testing
-- =====================================================

-- Create test schema
CREATE SCHEMA IF NOT EXISTS test_data_quality;

-- Drop existing tables if they exist (for clean recreation)
DROP TABLE IF EXISTS test_data_quality.facilities CASCADE;
DROP TABLE IF EXISTS test_data_quality.products CASCADE;
DROP TABLE IF EXISTS test_data_quality.clients CASCADE;

-- Copy tables to test schema
CREATE TABLE test_data_quality.clients AS TABLE clients WITH NO DATA;
CREATE TABLE test_data_quality.products AS TABLE products WITH NO DATA;
CREATE TABLE test_data_quality.facilities AS TABLE facilities WITH NO DATA;

-- Add same constraints to test tables
ALTER TABLE test_data_quality.clients ADD PRIMARY KEY (client_id);
ALTER TABLE test_data_quality.products ADD PRIMARY KEY (product_id);
-- ALTER TABLE test_data_quality.facilities ADD PRIMARY KEY (facility_id);
-- ALTER TABLE test_data_quality.facilities 
--     ADD CONSTRAINT fk_client FOREIGN KEY (client_id) REFERENCES test_data_quality.clients(client_id);
-- ALTER TABLE test_data_quality.facilities 
--     ADD CONSTRAINT fk_product FOREIGN KEY (product_id) REFERENCES test_data_quality.products(product_id);

-- Insert problematic test data
INSERT INTO test_data_quality.clients VALUES
(1, 'Test Corp', 'Corporate', 'Manufacturing', 'USA', 'A', NULL, 'Manager1', '2020-01-15', '2022-06-30', TRUE),  -- Old review date
(2, NULL, 'Retail', 'Individual', 'UK', 'BBB', NULL, 'Manager2', '2019-03-20', NULL, TRUE),  -- NULL name
(3, 'Duplicate Test', 'SME', NULL, 'Spain', 'BB', NULL, 'Manager3', '2021-06-10', '2024-07-20', FALSE);  -- Inactive client

INSERT INTO test_data_quality.products VALUES
(101, 'Term Loan', 'Corporate Lending', 0.5000, 5, 'Real Estate', TRUE),
(102, 'Credit Card', 'Retail Banking', 1.0000, NULL, NULL, FALSE);

INSERT INTO test_data_quality.facilities VALUES
(1001, 1, 101, 1000000.00, 900000.00, 'USD', 0.020000, 0.4500, 900000.00, 1.0, 8100.00, 450000.00, 36000.00, '2024-01-15', '2023-01-15', '2028-01-15', 'Active'),
(1002, 2, 102, 50000.00, 45000.00, 'GBP', NULL, 0.8000, 45000.00, 1.0, NULL, NULL, NULL, NULL, '2022-03-20', '2027-03-20', 'Active'),  -- NULL pd
(1003, 3, 101, 200000.00, 180000.00, 'EUR', -0.030000, 0.6000, 180000.00, 1.0, 3240.00, 90000.00, 7200.00, '2024-01-15', '2023-06-10', '2021-06-10', 'Active'),  -- Inactive client
(1004, 1, 506, 100000.00, 120000.00, 'USD', 0.025000, 0.7000, 120000.00, 1.0, NULL, NULL, NULL, NULL, '2024-02-01', '2029-02-01', 'Active'),  -- Outstanding > facility
(1004, 1, 506, 100000.00, 120000.00, 'USD', 0.025000, -0.7000, 120000.00, 1.0, NULL, NULL, NULL, NULL, '2024-02-01', '2029-02-01', 'Active'),  -- Duplicate facility_id
(1005, 99, 721, 500000.00, 450000.00, 'EUR', 0.015000, 0.4000, -450000.00, 1.0, 2700.00, 225000.00, 18000.00, '2024-01-15', '2024-03-01', '2029-03-01', 'Active');  -- Orphaned (client 99 doesn't exist)

-- Summary
SELECT 
    'Clean data loaded into public schema' AS status,
    'Problematic data loaded into test_data_quality schema' AS note,
    'Run data quality checks on test_data_quality schema to see validations in action' AS instructions;
