-- ==========================================
-- PROJECT: PaySphere - Enterprise Payment & Ledger Gateway
-- COMPONENT: 03_triggers.sql
-- TARGET ENGINE: Oracle Database
-- DESCRIPTION: Implements automated, engine-level security auditing for account mutations.
-- ==========================================

CREATE OR REPLACE TRIGGER TRG_ACCOUNT_AUDIT
AFTER UPDATE OF balance ON ACCOUNTS
FOR EACH ROW
DECLARE
    v_log_payload_old CLOB;
    v_log_payload_new CLOB;
BEGIN
    -- Construct structured diagnostic states for the audit pipeline
    v_log_payload_old := '{"account_id": ' || :OLD.account_id || ', "balance": ' || :OLD.balance || ', "status": "' || :OLD.status || '"}';
    v_log_payload_new := '{"account_id": ' || :NEW.account_id || ', "balance": ' || :NEW.balance || ', "status": "' || :NEW.status || '"}';

    -- Write directly to the persistent immutable audit log
    INSERT INTO AUDIT_LOGS (
        table_name,
        operation_type,
        record_id,
        old_value,
        new_value,
        changed_by,
        timestamp
    ) VALUES (
        'ACCOUNTS',
        'UPDATE',
        :NEW.account_id,
        v_log_payload_old,
        v_log_payload_new,
        USER, -- Captures the active database session user context
        CURRENT_TIMESTAMP
    );
EXCEPTION
    WHEN OTHERS THEN
        -- Defensive design: Ensure audit failures do not silently break critical transaction state paths
        RAISE_APPLICATION_ERROR(-20009, 'Audit Logging Framework Failure: Transaction processing suspended.');
END;
/
