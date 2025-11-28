-- =====================================================
-- DATA QUALITY VALIDATION FRAMEWORK
-- =====================================================
-- PostgreSQL Version
-- Comprehensive data quality checks for Basel III reporting
-- Critical for regulatory compliance and capital accuracy
-- Author: Matías López Sosa
-- =====================================================

-- Can be run on either:
-- - public schema (clean data)
-- - test_data_quality schema (problematic data)
-- Change schema name below to test

DO $$
DECLARE
    target_schema TEXT := 'test_data_quality';  -- Change to 'public' for clean data
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'STARTING DATA QUALITY VALIDATION';
    RAISE NOTICE 'Target Schema: %', target_schema;
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
END $$;


-- =====================================================
-- CHECK 1: NULL VALUE DETECTION
-- =====================================================
-- WHY: Missing critical data can invalidate regulatory calculations
-- IMPACT: Cannot calculate EL/RWA if PD, LGD, or EAD are NULL
-- =====================================================

DO $$ BEGIN RAISE NOTICE '--- CHECK 1: Null Values in Critical Fields ---'; END $$;

-- Check for nulls in clients table
SELECT 
    'clients' AS table_name,
    'client_name' AS column_name,
    COUNT(*) AS null_count
FROM test_data_quality.clients
WHERE client_name IS NULL

UNION ALL

SELECT 'clients', 'client_type', COUNT(*) 
FROM test_data_quality.clients WHERE client_type IS NULL

UNION ALL

SELECT 'clients', 'sector', COUNT(*) 
FROM test_data_quality.clients WHERE sector IS NULL

UNION ALL

SELECT 'clients', 'internal_rating', COUNT(*) 
FROM test_data_quality.clients WHERE internal_rating IS NULL

UNION ALL

SELECT 'clients', 'onboarding_date', COUNT(*) 
FROM test_data_quality.clients WHERE onboarding_date IS NULL;

-- Check for nulls in facilities table
SELECT 
    'facilities' AS table_name,
    'pd' AS column_name,
    COUNT(*) AS null_count
FROM test_data_quality.facilities
WHERE pd IS NULL

UNION ALL

SELECT 'facilities', 'lgd', COUNT(*) 
FROM test_data_quality.facilities WHERE lgd IS NULL

UNION ALL

SELECT 'facilities', 'ead', COUNT(*) 
FROM test_data_quality.facilities WHERE ead IS NULL

UNION ALL

SELECT 'facilities', 'outstanding_balance', COUNT(*) 
FROM test_data_quality.facilities WHERE outstanding_balance IS NULL;

DO $$ BEGIN RAISE NOTICE 'Null check completed'; RAISE NOTICE ''; END $$;

-- =====================================================
-- CHECK 2: DUPLICATE DETECTION
-- =====================================================
-- WHY: Duplicates can inflate exposure and capital requirements
-- IMPACT: Same facility counted twice = incorrect RWA
-- =====================================================

DO $$ BEGIN RAISE NOTICE '--- CHECK 2: Duplicate Records ---'; END $$;

-- Check for duplicate client IDs
SELECT 
    'clients' AS table_name,
    client_id,
    COUNT(*) AS duplicate_count
FROM test_data_quality.clients
GROUP BY client_id
HAVING COUNT(*) > 1;

-- Check for duplicate facility IDs
SELECT 
    'facilities' AS table_name,
    facility_id,
    COUNT(*) AS duplicate_count
FROM test_data_quality.facilities
GROUP BY facility_id
HAVING COUNT(*) > 1;

DO $$ BEGIN RAISE NOTICE 'Duplicate check completed'; RAISE NOTICE ''; END $$;

-- =====================================================
-- CHECK 3: REFERENTIAL INTEGRITY
-- =====================================================
-- WHY: Ensures all foreign keys point to valid records
-- IMPACT: Orphaned facilities = cannot link to client data
-- =====================================================

DO $$ BEGIN RAISE NOTICE '--- CHECK 3: Referential Integrity Violations ---'; END $$;

-- Find facilities with invalid client references (if constraints were disabled)
SELECT 
    f.facility_id,
    f.client_id,
    'Orphaned facility - client does not exist' AS issue
FROM test_data_quality.facilities f
LEFT JOIN test_data_quality.clients c ON f.client_id = c.client_id
WHERE c.client_id IS NULL;

-- Find facilities with invalid product references
SELECT 
    f.facility_id,
    f.product_id,
    'Orphaned facility - product does not exist' AS issue
FROM test_data_quality.facilities f
LEFT JOIN test_data_quality.products p ON f.product_id = p.product_id
WHERE p.product_id IS NULL;

DO $$ BEGIN RAISE NOTICE 'Referential integrity check completed'; RAISE NOTICE ''; END $$;


-- =====================================================
-- CHECK 4: DATA RANGE VALIDATION
-- =====================================================
-- WHY: Basel III parameters must be within valid ranges
-- IMPACT: PD > 1 or negative values = calculation errors
-- =====================================================

DO $$ BEGIN RAISE NOTICE '--- CHECK 4: Data Range Validation ---'; END $$;

-- Check PD out of range
SELECT 
    facility_id,
    pd,
    'PD out of valid range [0,1]' AS issue
FROM test_data_quality.facilities
WHERE pd < 0 OR pd > 1;

-- Check LGD out of range
SELECT 
    facility_id,
    lgd,
    'LGD out of valid range [0,1]' AS issue
FROM test_data_quality.facilities
WHERE lgd < 0 OR lgd > 1;

-- Check EAD is positive
SELECT 
    facility_id,
    ead,
    'EAD must be positive' AS issue
FROM test_data_quality.facilities
WHERE ead <= 0;

-- Check outstanding balance doesn't exceed facility amount
SELECT 
    facility_id,
    facility_amount,
    outstanding_balance,
    'Outstanding exceeds facility limit' AS issue
FROM test_data_quality.facilities
WHERE outstanding_balance > facility_amount;

-- Check maturity date logic
SELECT 
    facility_id,
    origination_date,
    maturity_date,
    'Invalid maturity date (before origination)' AS issue
FROM test_data_quality.facilities
WHERE maturity_date IS NOT NULL 
  AND maturity_date <= origination_date;

DO $$ BEGIN RAISE NOTICE 'Range validation completed'; RAISE NOTICE ''; END $$;

-- =====================================================
-- CHECK 5: CROSS-COLUMN VALIDATION
-- =====================================================
-- WHY: Validates calculated fields match formulas
-- IMPACT: Wrong EAD calculation = wrong capital requirement
-- =====================================================

DO $$ BEGIN RAISE NOTICE '--- CHECK 5: Cross-Column Logic Validation ---'; END $$;

-- Verify EAD calculation
SELECT 
    facility_id,
    ead AS reported_ead,
    outstanding_balance + (facility_amount - outstanding_balance) * ccf AS calculated_ead,
    ABS(ead - (outstanding_balance + (facility_amount - outstanding_balance) * ccf)) AS difference
FROM test_data_quality.facilities
WHERE ABS(ead - (outstanding_balance + (facility_amount - outstanding_balance) * ccf)) > 0.01;

select * from test_data_quality.facilities;

-- Verify Expected Loss calculation
SELECT 
    facility_id,
    expected_loss AS reported_el,
    ROUND((pd * lgd * ead)::NUMERIC, 2) AS calculated_el,
    ABS(expected_loss - ROUND((pd * lgd * ead)::NUMERIC, 2)) AS difference
FROM test_data_quality.facilities
WHERE expected_loss IS NOT NULL
  AND pd IS NOT NULL
  AND lgd IS NOT NULL
  AND ead IS NOT NULL
  AND ABS(expected_loss - ROUND((pd * lgd * ead)::NUMERIC, 2)) > 0.01;

-- Check inactive clients with active facilities
SELECT 
    c.client_id,
    c.client_name,
    c.is_active AS client_active,
    COUNT(f.facility_id) AS active_facilities_count
FROM test_data_quality.clients c
INNER JOIN test_data_quality.facilities f ON c.client_id = f.client_id
WHERE c.is_active = FALSE
  AND f.facility_status = 'Active'
GROUP BY c.client_id, c.client_name, c.is_active;

DO $$ BEGIN RAISE NOTICE 'Cross-column validation completed'; RAISE NOTICE ''; END $$;

-- =====================================================
-- CHECK 6: BUSINESS RULE VALIDATION
-- =====================================================
-- WHY: Flags unusual data patterns that may indicate errors
-- IMPACT: High PD + low LGD is uncommon, needs review
-- =====================================================

DO $$ BEGIN RAISE NOTICE '--- CHECK 6: Business Rule Validation ---'; END $$;

-- High PD with low LGD
SELECT 
    facility_id,
    client_id,
    pd,
    lgd,
    'High PD with low LGD - review required' AS warning
FROM test_data_quality.facilities
WHERE pd > 0.05 AND lgd < 0.3;

-- Overdue review dates
SELECT 
    client_id,
    client_name,
    last_review_date,
    CURRENT_DATE - last_review_date AS days_since_review,
    'Review overdue (>365 days)' AS issue
FROM test_data_quality.clients
WHERE last_review_date IS NOT NULL
  AND CURRENT_DATE - last_review_date > 365
  AND is_active = TRUE;

-- Large exposures (concentration risk)
WITH portfolio_total AS (
    SELECT SUM(ead) AS total_ead
    FROM test_data_quality.facilities
    WHERE facility_status = 'Active'
)
SELECT 
    f.client_id,
    c.client_name,
    SUM(f.ead) AS client_total_ead,
    pt.total_ead AS total_ead,
    (SUM(f.ead) / pt.total_ead) * 100 AS percentage_of_portfolio,
    'Large exposure - concentration risk' AS warning
FROM test_data_quality.facilities f
INNER JOIN test_data_quality.clients c ON f.client_id = c.client_id
CROSS JOIN portfolio_total pt
WHERE f.facility_status = 'Active'
GROUP BY f.client_id, c.client_name, pt.total_ead
HAVING (SUM(f.ead) / pt.total_ead) > 0.10;

DO $$ BEGIN RAISE NOTICE 'Business rule validation completed'; RAISE NOTICE ''; END $$;


-- =====================================================
-- CHECK 7: SUMMARY STATISTICS
-- =====================================================
-- WHY: High-level overview of portfolio health
-- IMPACT: Quick snapshot for management reporting
-- =====================================================

DO $$ BEGIN RAISE NOTICE '--- CHECK 7: Data Quality Summary ---'; END $$;

SELECT 
    'Total Clients' AS metric,
    COUNT(*)::TEXT AS value
FROM test_data_quality.clients

UNION ALL

SELECT 'Active Clients', COUNT(*)::TEXT
FROM test_data_quality.clients WHERE is_active = TRUE

UNION ALL

SELECT 'Retail Clients', COUNT(*)::TEXT
FROM test_data_quality.clients WHERE client_type = 'Retail'

UNION ALL

SELECT 'SME Clients', COUNT(*)::TEXT
FROM test_data_quality.clients WHERE client_type = 'SME'

UNION ALL

SELECT 'Corporate Clients', COUNT(*)::TEXT
FROM test_data_quality.clients WHERE client_type = 'Corporate'

UNION ALL

SELECT 'Total Facilities', COUNT(*)::TEXT
FROM test_data_quality.facilities

UNION ALL

SELECT 'Active Facilities', COUNT(*)::TEXT
FROM test_data_quality.facilities WHERE facility_status = 'Active'

UNION ALL

SELECT 'Total Portfolio EAD', ROUND(SUM(ead))::TEXT
FROM test_data_quality.facilities WHERE facility_status = 'Active';

-- =====================================================
-- FINAL VALIDATION REPORT
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'DATA QUALITY VALIDATION COMPLETED';
    RAISE NOTICE 'Review results above for any issues';
    RAISE NOTICE '========================================';
END $$;
