# SQL Data Quality Framework for Basel III Regulatory Reporting

## Overview
SQL-based data quality and validation framework based on real-world experience managing credit risk databases for Basel III capital adequacy calculations at a major international bank.

## Business Context
In banking regulatory reporting, data accuracy is critical. This project demonstrates:
- Systematic data quality validation
- Referential integrity checks
- Regulatory capital calculations (Expected Loss, RWA)
- Cross-table validation logic

## Tech Stack
- PostgreSQL
- Basel III regulatory framework

## Files
1. `01_schema_design.sql` - Database schema for clients, facilities, products
2. `02_data_quality_checks.sql` - Comprehensive DQ validation queries
3. `03_regulatory_calculations.sql` - Basel III calculations with validation

## Based On
Real experience as Risk Data Analyst at a major international bank (2015-2016), managing databases for economic and regulatory capital calculations under Basel III framework. Originally worked with SQL Server, this project has been adapted to PostgreSQL for broader compatibility.

---
**Author**: Matías López Sosa | [LinkedIn](https://www.linkedin.com/in/mat%C3%ADas-l%C3%B3pez-sosa-6753b292/)
