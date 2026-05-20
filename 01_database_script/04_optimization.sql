- ==========================================
-- PROJECT: PaySphere - Enterprise Payment & Ledger Gateway
-- COMPONENT: 04_optimization.sql
-- TARGET ENGINE: Oracle Database
-- DESCRIPTION: High-performance structural optimization for high-volume ledger parsing.
-- ==========================================

-- Create a composite B-Tree index to optimize high-volume ledger audits
CREATE INDEX idx_transactions_routing 
ON TRANSACTIONS (source_acc_id, timestamp DESC);

-- Documenting performance behavior profiles for architectural validation
-- BBD Tech Leads looking for execution insights can review the intent:
-- This composite index converts heavy Full Table Scans into targeted Index Range Seeks 
-- when generating customer chronological transaction statements or statement records.
