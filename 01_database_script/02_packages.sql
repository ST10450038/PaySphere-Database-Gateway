-- ==========================================
-- PROJECT: PaySphere - Enterprise Payment & Ledger Gateway
-- COMPONENT: 02_packages.sql
-- TARGET ENGINE: Oracle Database
-- DESCRIPTION: Implements encapsulated transactional business logic for ledger funds allocation.
-- ==========================================

-- ==========================================
-- 1. PACKAGE SPECIFICATION
-- Defines the public contract interface visible to application tiers.
-- ==========================================
CREATE OR REPLACE PACKAGE PKG_PAYMENT_PROCESSOR AS

    -- Custom exceptions for strict enterprise error classification
    EXC_INSUFFICIENT_FUNDS EXCEPTION;
    EXC_INVALID_ACCOUNT    EXCEPTION;
    EXC_SAME_ACCOUNT       EXCEPTION;
    
    PRAGMA EXCEPTION_INIT(EXC_INSUFFICIENT_FUNDS, -20001);
    PRAGMA EXCEPTION_INIT(EXC_INVALID_ACCOUNT, -20002);
    PRAGMA EXCEPTION_INIT(EXC_SAME_ACCOUNT, -20003);

    /**
    * Executes a secure electronic funds transfer between accounts.
    * Enforces ACID compliance directly at the database tier.
    */
    PROCEDURE PRC_TRANSFER_FUNDS (
        p_source_acc_id  IN NUMBER,
        p_dest_acc_id    IN NUMBER,
        p_amount         IN NUMBER,
        p_reference      IN VARCHAR2,
        p_tx_id          OUT NUMBER
    );

END PKG_PAYMENT_PROCESSOR;
/

-- ==========================================
-- 2. PACKAGE BODY
-- Implements structural logic and transaction boundaries.
-- ==========================================
CREATE OR REPLACE PACKAGE BODY PKG_PAYMENT_PROCESSOR AS

    PROCEDURE PRC_TRANSFER_FUNDS (
        p_source_acc_id  IN NUMBER,
        p_dest_acc_id    IN NUMBER,
        p_amount         IN NUMBER,
        p_reference      IN VARCHAR2,
        p_tx_id          OUT NUMBER
    ) AS
        v_source_balance  NUMBER(15,2);
        v_source_exists   NUMBER;
        v_dest_exists     NUMBER;
    BEGIN
        -- Rule 1: Prevent self-transactions
        IF p_source_acc_id = p_dest_acc_id THEN
            RAISE_APPLICATION_ERROR(-20003, 'Transaction Aborted: Source and destination accounts must be distinct.');
        END IF;

        -- Rule 2: Validate existence of both accounts
        SELECT COUNT(*) INTO v_source_exists FROM ACCOUNTS WHERE account_id = p_source_acc_id AND status = 'ACTIVE';
        SELECT COUNT(*) INTO v_dest_exists FROM ACCOUNTS WHERE account_id = p_dest_acc_id AND status = 'ACTIVE';
        
        IF v_source_exists = 0 OR v_dest_exists = 0 THEN
            RAISE_APPLICATION_ERROR(-20002, 'Transaction Aborted: One or both accounts are invalid, suspended, or frozen.');
        END IF;

        -- Rule 3: Validate available balance (Acquire Row-Level Lock via FOR UPDATE)
        SELECT balance INTO v_source_balance 
        FROM ACCOUNTS 
        WHERE account_id = p_source_acc_id 
        FOR UPDATE;

        IF v_source_balance < p_amount THEN
            RAISE_APPLICATION_ERROR(-20001, 'Transaction Aborted: Insufficient cleared funds for requested transfer.');
        END IF;

        -- Execution Stage 1: Debit Source
        UPDATE ACCOUNTS 
        SET balance = balance - p_amount, updated_at = CURRENT_TIMESTAMP 
        WHERE account_id = p_source_acc_id;

        -- Execution Stage 2: Credit Destination
        UPDATE ACCOUNTS 
        SET balance = balance + p_amount, updated_at = CURRENT_TIMESTAMP 
        WHERE account_id = p_dest_acc_id;

        -- Execution Stage 3: Write to Immutable Ledger
        INSERT INTO TRANSACTIONS (
            source_acc_id, dest_acc_id, amount, transaction_type, status, reference_desc, timestamp
        ) VALUES (
            p_source_acc_id, p_dest_acc_id, p_amount, 'TRANSFER', 'SUCCESSFUL', p_reference, CURRENT_TIMESTAMP
        ) RETURNING transaction_id INTO p_tx_id;

        -- Persist the entire atomic unit of work safely
        COMMIT;

    EXCEPTION
        WHEN OTHERS THEN
            -- In case of any engine exception, completely rollback states to secure balance safety
            ROLLBACK;
            RAISE;
    END PRC_TRANSFER_FUNDS;

END PKG_PAYMENT_PROCESSOR;
/
