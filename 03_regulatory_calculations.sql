-- =====================================================
-- BASEL III REGULATORY CAPITAL CALCULATIONS
-- =====================================================
-- PostgreSQL Version
-- Calculates Expected Loss (EL), Risk-Weighted Assets (RWA),
-- and Capital Requirements according to Basel III framework
-- Author: Matías López Sosa
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'BASEL III REGULATORY CALCULATIONS';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
END $$;

-- =====================================================
-- CALCULATION 1: EXPECTED LOSS (EL)
-- =====================================================
-- WHAT: Calculates expected credit loss per facility
-- FORMULA: EL = PD × LGD × EAD
-- PURPOSE: Estimates average loss over 1 year
-- USE CASE: Provisioning, pricing, risk appetite
-- EXAMPLE: If PD=2%, LGD=45%, EAD=$100k → EL=$900
-- =====================================================

DO $$ BEGIN RAISE NOTICE '--- Expected Loss by Facility ---'; END $$;

SELECT 
    f.facility_id,
    c.client_name,
    c.client_type,
    f.outstanding_balance,
    f.pd AS probability_of_default,
    f.lgd AS loss_given_default,
    f.ead AS exposure_at_default,
    
    -- Calculate Expected Loss
    ROUND((f.pd * f.lgd * f.ead)::NUMERIC, 2) AS expected_loss_usd,
    
    -- Express as percentage of EAD
    ROUND((f.pd * f.lgd * 100)::NUMERIC, 4) AS expected_loss_rate_pct,
    
    f.facility_status
FROM facilities f
INNER JOIN clients c ON f.client_id = c.client_id
WHERE f.facility_status = 'Active'
ORDER BY expected_loss_usd DESC;

-- =====================================================
-- CALCULATION 2: RISK-WEIGHTED ASSETS (RWA)
-- =====================================================
-- WHAT: Calculates regulatory capital requirement per facility
-- FORMULA: RWA = EAD × Risk Weight
-- PURPOSE: Determines how much capital bank must hold
-- USE CASE: Basel III compliance, capital planning
-- EXAMPLE: Mortgage $100k, RW=35% → RWA=$35k → Capital=$2.8k (8%)
-- =====================================================

DO $$ BEGIN RAISE NOTICE ''; RAISE NOTICE '--- Risk-Weighted Assets by Facility ---'; END $$;

SELECT 
    f.facility_id,
    c.client_name,
    c.client_type,
    p.product_type,
    f.ead,
    p.base_risk_weight,
    
    -- Calculate RWA
    ROUND((f.ead * p.base_risk_weight)::NUMERIC, 2) AS risk_weighted_assets,
    
    -- Capital requirement (8% of RWA per Basel III minimum)
    ROUND((f.ead * p.base_risk_weight * 0.08)::NUMERIC, 2) AS minimum_capital_requirement
    
FROM facilities f
INNER JOIN clients c ON f.client_id = c.client_id
INNER JOIN products p ON f.product_id = p.product_id
WHERE f.facility_status = 'Active'
ORDER BY risk_weighted_assets DESC;

-- =====================================================
-- CALCULATION 3: PORTFOLIO AGGREGATIONS BY SECTOR
-- =====================================================
-- WHAT: Aggregates all metrics by industry sector
-- PURPOSE: Identify concentration risk by industry
-- USE CASE: Regulatory reporting, portfolio diversification
-- EXAMPLE: "We have 40% exposure in Manufacturing" → High concentration risk
-- =====================================================

DO $$ BEGIN RAISE NOTICE ''; RAISE NOTICE '--- Portfolio Summary by Sector ---'; END $$;

SELECT 
    c.sector,
    COUNT(DISTINCT c.client_id) AS num_clients,
    COUNT(f.facility_id) AS num_facilities,
    ROUND(SUM(f.ead)::NUMERIC, 2) AS total_exposure,
    ROUND(AVG(f.pd)::NUMERIC, 6) AS avg_pd,
    ROUND(AVG(f.lgd)::NUMERIC, 4) AS avg_lgd,
    ROUND(SUM(f.pd * f.lgd * f.ead)::NUMERIC, 2) AS total_expected_loss,
    ROUND(SUM(f.ead * p.base_risk_weight)::NUMERIC, 2) AS total_rwa,
    ROUND(SUM(f.ead * p.base_risk_weight * 0.08)::NUMERIC, 2) AS total_capital_requirement
FROM facilities f
INNER JOIN clients c ON f.client_id = c.client_id
INNER JOIN products p ON f.product_id = p.product_id
WHERE f.facility_status = 'Active'
GROUP BY c.sector
ORDER BY total_exposure DESC;

-- =====================================================
-- CALCULATION 4: EXPOSURE BY CLIENT TYPE
-- =====================================================
-- WHAT: Aggregates metrics by Retail vs Corporate vs SME
-- PURPOSE: Understand portfolio composition
-- USE CASE: Strategic planning, pricing strategy
-- EXAMPLE: "Retail has lower avg PD (1%) vs Corporate (2.5%)"
-- =====================================================

DO $$ BEGIN RAISE NOTICE ''; RAISE NOTICE '--- Portfolio Summary by Client Type ---'; END $$;

SELECT 
    c.client_type,
    COUNT(DISTINCT c.client_id) AS num_clients,
    COUNT(f.facility_id) AS num_facilities,
    ROUND(SUM(f.ead)::NUMERIC, 2) AS total_exposure,
    ROUND(AVG(f.pd)::NUMERIC, 6) AS avg_pd,
    ROUND(SUM(f.pd * f.lgd * f.ead)::NUMERIC, 2) AS total_expected_loss,
    ROUND((SUM(f.ead) / (SELECT SUM(ead) FROM facilities WHERE facility_status = 'Active'))::NUMERIC * 100, 2) AS pct_of_portfolio
FROM facilities f
INNER JOIN clients c ON f.client_id = c.client_id
WHERE f.facility_status = 'Active'
GROUP BY c.client_type
ORDER BY total_exposure DESC;

-- =====================================================
-- CALCULATION 5: RATING DISTRIBUTION
-- =====================================================
-- WHAT: Shows exposure across credit rating buckets
-- PURPOSE: Monitor portfolio credit quality migration.
-- USE CASE: Risk appetite monitoring, early warning
-- EXAMPLE: "15% of portfolio is BB or below" → High risk concentration
-- =====================================================

DO $$ BEGIN RAISE NOTICE ''; RAISE NOTICE '--- Exposure by Credit Rating ---'; END $$;

SELECT 
    c.internal_rating,
    COUNT(DISTINCT c.client_id) AS num_clients,
    COUNT(f.facility_id) AS num_facilities,
    ROUND(SUM(f.ead)::NUMERIC, 2) AS total_exposure,
    ROUND(AVG(f.pd)::NUMERIC * 100, 4) AS avg_pd_pct,
    ROUND(SUM(f.pd * f.lgd * f.ead)::NUMERIC, 2) AS total_expected_loss,
    ROUND((SUM(f.ead) / (SELECT SUM(ead) FROM facilities WHERE facility_status = 'Active'))::NUMERIC * 100, 2) AS pct_of_portfolio
FROM facilities f
INNER JOIN clients c ON f.client_id = c.client_id
WHERE f.facility_status = 'Active'
GROUP BY c.internal_rating
ORDER BY 
    CASE c.internal_rating
        WHEN 'AAA' THEN 1
        WHEN 'AA' THEN 2
        WHEN 'A' THEN 3
        WHEN 'BBB' THEN 4
        WHEN 'BB' THEN 5
        WHEN 'B' THEN 6
        WHEN 'CCC' THEN 7
        WHEN 'D' THEN 8
    END;

-- =====================================================
-- CALCULATION 6: PRODUCT TYPE ANALYSIS
-- =====================================================
-- WHAT: Metrics by product (mortgage, credit card, etc.)
-- PURPOSE: Product profitability and risk analysis
-- USE CASE: Product pricing, portfolio optimization
-- EXAMPLE: "Credit cards have 3% EL rate vs 0.5% for mortgages"
-- =====================================================

DO $$ BEGIN RAISE NOTICE ''; RAISE NOTICE '--- Analysis by Product Type ---'; END $$;

SELECT 
    p.product_type,
    p.product_category,
    COUNT(f.facility_id) AS num_facilities,
    ROUND(SUM(f.facility_amount)::NUMERIC, 2) AS total_committed,
    ROUND(SUM(f.outstanding_balance)::NUMERIC, 2) AS total_outstanding,
    ROUND(AVG(f.pd)::NUMERIC * 100, 4) AS avg_pd_pct,
    ROUND(AVG(f.lgd)::NUMERIC * 100, 2) AS avg_lgd_pct,
    ROUND(SUM(f.pd * f.lgd * f.ead)::NUMERIC, 2) AS total_expected_loss,
    ROUND((SUM(f.pd * f.lgd * f.ead) / NULLIF(SUM(f.ead), 0))::NUMERIC * 100, 2) AS el_rate_pct,
    p.base_risk_weight,
    ROUND(SUM(f.ead * p.base_risk_weight)::NUMERIC, 2) AS total_rwa
FROM facilities f
INNER JOIN products p ON f.product_id = p.product_id
WHERE f.facility_status = 'Active'
GROUP BY p.product_type, p.product_category, p.base_risk_weight
ORDER BY total_outstanding DESC;

-- =====================================================
-- CALCULATION 7: TOP EXPOSURES (CONCENTRATION RISK)
-- =====================================================
-- WHAT: Top 10 clients by total exposure
-- PURPOSE: Identify single-name concentration risk
-- USE CASE: Limit monitoring, diversification strategy
-- EXAMPLE: "Client A = 15% of portfolio" → Exceeds 10% limit
-- =====================================================

DO $$ BEGIN RAISE NOTICE ''; RAISE NOTICE '--- Top 10 Client Exposures ---'; END $$;

SELECT 
    c.client_id,
    c.client_name,
    c.client_type,
    c.sector,
    c.internal_rating,
    COUNT(f.facility_id) AS num_facilities,
    ROUND(SUM(f.ead)::NUMERIC, 2) AS total_exposure,
    ROUND(SUM(f.pd * f.lgd * f.ead)::NUMERIC, 2) AS total_expected_loss,
    ROUND((SUM(f.ead) / (SELECT SUM(ead) FROM facilities WHERE facility_status = 'Active'))::NUMERIC * 100, 2) AS pct_of_portfolio
FROM facilities f
INNER JOIN clients c ON f.client_id = c.client_id
WHERE f.facility_status = 'Active'
GROUP BY c.client_id, c.client_name, c.client_type, c.sector, c.internal_rating
ORDER BY total_exposure DESC
LIMIT 10;

-- =====================================================
-- CALCULATION 8: CAPITAL ADEQUACY SUMMARY
-- =====================================================
-- WHAT: Overall portfolio-level regulatory capital summary
-- PURPOSE: Basel III compliance reporting to regulators
-- USE CASE: Board reporting, capital planning, stress testing
-- EXAMPLE: "Total RWA = $10M → Min capital = $800k (8%)"
-- KEY OUTPUT: This goes directly to CEO/CFO/Regulators
-- =====================================================

DO $$ BEGIN RAISE NOTICE ''; RAISE NOTICE '--- Overall Capital Adequacy Summary ---'; END $$;

WITH portfolio_metrics AS (
    SELECT 
        SUM(f.ead) AS total_exposure,
        SUM(f.pd * f.lgd * f.ead) AS total_expected_loss,
        SUM(f.ead * p.base_risk_weight) AS total_rwa
    FROM facilities f
    INNER JOIN products p ON f.product_id = p.product_id
    WHERE f.facility_status = 'Active'
)
SELECT 
    'Total Portfolio Exposure' AS metric,
    ROUND(total_exposure::NUMERIC, 2)::TEXT AS value
FROM portfolio_metrics

UNION ALL

SELECT 
    'Total Expected Loss',
    ROUND(total_expected_loss::NUMERIC, 2)::TEXT
FROM portfolio_metrics

UNION ALL

SELECT 
    'Portfolio EL Rate (%)',
    ROUND((total_expected_loss / total_exposure * 100)::NUMERIC, 4)::TEXT
FROM portfolio_metrics

UNION ALL

SELECT 
    'Total Risk-Weighted Assets',
    ROUND(total_rwa::NUMERIC, 2)::TEXT
FROM portfolio_metrics

UNION ALL

SELECT 
    'Minimum Capital (Tier 1, 8%)',
    ROUND((total_rwa * 0.08)::NUMERIC, 2)::TEXT
FROM portfolio_metrics

UNION ALL

SELECT 
    'Target Capital (Tier 1, 10.5%)',
    ROUND((total_rwa * 0.105)::NUMERIC, 2)::TEXT
FROM portfolio_metrics

UNION ALL

SELECT 
    'Total Capital Requirement (13%)',
    ROUND((total_rwa * 0.13)::NUMERIC, 2)::TEXT
FROM portfolio_metrics;

-- =====================================================
-- CALCULATION 9: UPDATE FACILITIES WITH CALCULATED VALUES
-- =====================================================
-- WHAT: Updates calculated fields (EAD, EL, RWA, Capital) in facilities table
-- PURPOSE: Store point-in-time snapshot for audit trail
-- USE CASE: Monthly close, regulatory submissions, historical analysis
-- EXAMPLE: "As of Dec 31, facility 1001 had EL=$900, RWA=$35k"
-- =====================================================

DO $$ BEGIN RAISE NOTICE ''; RAISE NOTICE '--- Updating Calculated Fields in Facilities Table ---'; END $$;

-- Update Exposure at Default (EAD)
UPDATE facilities f
SET 
    ead = outstanding_balance + ((facility_amount - outstanding_balance) * ccf),
    calculation_date = CURRENT_DATE
WHERE facility_status = 'Active'
  AND (ead IS NULL 
       OR ABS(ead - (outstanding_balance + ((facility_amount - outstanding_balance) * ccf))) > 0.01);

-- Update Expected Loss
UPDATE facilities f
SET 
    expected_loss = ROUND((pd * lgd * ead)::NUMERIC, 2),
    calculation_date = CURRENT_DATE
WHERE facility_status = 'Active'
  AND (expected_loss IS NULL OR expected_loss != ROUND((pd * lgd * ead)::NUMERIC, 2));

-- Update RWA and Capital Requirements
UPDATE facilities f
SET 
    risk_weighted_assets = ROUND((ead * p.base_risk_weight)::NUMERIC, 2),
    capital_requirement = ROUND((ead * p.base_risk_weight * 0.08)::NUMERIC, 2),
    calculation_date = CURRENT_DATE
FROM products p
WHERE f.product_id = p.product_id
  AND f.facility_status = 'Active'
  AND (risk_weighted_assets IS NULL OR capital_requirement IS NULL);

DO $$ 
DECLARE
    updated_count INTEGER;
BEGIN
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    RAISE NOTICE '% facilities updated with calculated metrics', updated_count;
END $$;

-- =====================================================
-- CALCULATION 10: VALIDATION
-- =====================================================
-- WHAT: Cross-checks that stored values match recalculated values
-- PURPOSE: Ensure calculation integrity and catch errors
-- USE CASE: Monthly reconciliation, audit support
-- EXAMPLE: Detects if someone manually changed EL without recalculating
-- =====================================================

DO $$ BEGIN RAISE NOTICE ''; RAISE NOTICE '--- Validation: Cross-Check Calculations ---'; END $$;

-- Verify EL calculation
SELECT 
    facility_id,
    ROUND((pd * lgd * ead)::NUMERIC, 2) AS calculated_el,
    expected_loss AS stored_el,
    ABS(ROUND((pd * lgd * ead)::NUMERIC, 2) - expected_loss) AS difference
FROM facilities
WHERE expected_loss IS NOT NULL
  AND ABS(ROUND((pd * lgd * ead)::NUMERIC, 2) - expected_loss) > 0.01;


-- =====================================================
-- FINAL SUMMARY
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'REGULATORY CALCULATIONS COMPLETED';
    RAISE NOTICE 'All metrics calculated and stored';
    RAISE NOTICE '========================================';
END $$;
