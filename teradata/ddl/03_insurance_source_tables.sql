-- =============================================================================
-- Source Table DDL - Insurance Operational Systems (POLARIS PAS / Guidewire CC)
-- =============================================================================
-- Owned by the Policy Admin platform team. LEGACY_PAS (mainframe) equivalents
-- arrive as flat files (see mainframe/feed_specs) and are NOT covered here.
-- NB: PARTY.LEGACY_CUSTOMER_ID is a sparsely-populated crosswalk to
--     CORE_BANKING_DB.CUSTOMERS.CUSTOMER_ID (Albion Premium Finance).
--     Coverage was ~55% at last audit (2024). No referential integrity.
-- =============================================================================

CREATE MULTISET TABLE POLICY_ADMIN_DB.PARTY (
    PARTY_ID            CHAR(8)      NOT NULL,     -- 'P' + 7 digits
    PARTY_TYPE          VARCHAR(6),
    FIRST_NAME          VARCHAR(50),
    LAST_NAME           VARCHAR(50),
    BIRTH_DT            VARCHAR(10),               -- DD/MM/YYYY as text (!)
    NINO                CHAR(9),                   -- unmasked; masking applied
                                                   -- only in Informatica path
    EMAIL_ADDR          VARCHAR(120),              -- mixed case, no constraint
    PHONE               VARCHAR(20),
    ADDR_LINE1          VARCHAR(120),
    CITY                VARCHAR(60),
    POSTCODE            VARCHAR(10),
    LEGACY_CUSTOMER_ID  INTEGER,                   -- APF crosswalk (sparse)
    MDM_GOLDEN_FLAG     CHAR(1),
    CREATE_DT           DATE
) PRIMARY INDEX (PARTY_ID);

CREATE MULTISET TABLE POLICY_ADMIN_DB.POLICY (
    POLICY_NO           VARCHAR(18)  NOT NULL,
    PARTY_ID            CHAR(8),
    PRODUCT_CD          CHAR(3),
    PRODUCT_NAME        VARCHAR(40),
    BROKER_ID           CHAR(7),
    CHANNEL             VARCHAR(12),
    INCEPTION_DT        DATE,
    EXPIRY_DT           DATE,
    POLICY_STATUS       CHAR(2),        -- IF/RN/LP/CN/EX
    ANNUAL_PREMIUM_GBP  DECIMAL(12,2),
    IPT_RATE            DECIMAL(5,4),
    PAYMENT_PLAN        VARCHAR(16),
    UW_YEAR             SMALLINT,
    SOURCE_SYSTEM       VARCHAR(12)     -- POLARIS | LEGACY_PAS
) PRIMARY INDEX (POLICY_NO);

CREATE MULTISET TABLE CLAIMS_DB.CLAIM (
    CLAIM_NO            CHAR(11)     NOT NULL,
    POLICY_NO           VARCHAR(18),
    CLAIMANT_PARTY_ID   CHAR(8),
    LOSS_DT             VARCHAR(10),    -- DD/MM/YYYY text, see INC0067812
    NOTIFICATION_DT     DATE,
    CAUSE_CD            VARCHAR(20),
    CLAIM_STATUS        VARCHAR(8),     -- OPEN/CLOSED/REOPENED/DECLINED
    INCURRED_AMT        DECIMAL(12,2),
    PAID_AMT            DECIMAL(12,2),
    OUTSTANDING_RESERVE DECIMAL(12,2),
    FRAUD_FLAG          CHAR(1),        -- Y/N/blank; LEGACY_CLM also sends 'S'
    HANDLER_ID          CHAR(4),
    SOURCE_SYSTEM       VARCHAR(12)
) PRIMARY INDEX (CLAIM_NO);

CREATE MULTISET TABLE BILLING_DB.PREMIUM_TRANSACTIONS (
    PREMIUM_TXN_ID      INTEGER      NOT NULL,
    POLICY_NO           VARCHAR(18),
    TXN_TYPE            VARCHAR(10),    -- NB/RN/MTA/CN_REFUND
    TXN_DT              DATE,
    GROSS_AMT_GBP       DECIMAL(12,2),
    IPT_AMT_GBP         DECIMAL(12,2),
    COMMISSION_AMT_GBP  DECIMAL(12,2),
    COLLECTION_METHOD   VARCHAR(10),    -- DD/CARD/APF_LOAN
    APF_ACCOUNT_ID      INTEGER         -- FK-by-convention to
                                        -- CORE_BANKING_DB.ACCOUNTS.ACCOUNT_ID
) PRIMARY INDEX (PREMIUM_TXN_ID);

CREATE MULTISET TABLE POLICY_ADMIN_DB.BROKER (
    BROKER_ID           CHAR(7)      NOT NULL,
    BROKER_NAME         VARCHAR(80),
    FCA_REF             CHAR(6),
    CITY                VARCHAR(60),
    POSTCODE            VARCHAR(10),
    COMMISSION_PCT      DECIMAL(5,2),
    STATUS              VARCHAR(10)
) PRIMARY INDEX (BROKER_ID);

CREATE MULTISET TABLE REINSURANCE_DB.TREATY (
    TREATY_ID           CHAR(5)      NOT NULL,
    TREATY_TYPE         VARCHAR(12),
    LINE_OF_BUSINESS    CHAR(3),
    REINSURER           VARCHAR(40),
    CESSION_PCT         DECIMAL(5,1),
    RETENTION_GBP       DECIMAL(12,0),
    LIMIT_GBP           DECIMAL(14,0),
    UW_YEAR             SMALLINT
) PRIMARY INDEX (TREATY_ID);

-- Manually maintained crosswalk (Excel-upload heritage). Neither side enforced.
CREATE MULTISET TABLE REF_DB.XREF_CLIENT_PARTY (
    CLIENT_NO           DECIMAL(10,0),  -- LEGACY_PAS
    PARTY_ID            CHAR(8),        -- POLARIS
    MATCH_METHOD        VARCHAR(20),    -- 'NINO' | 'NAME_DOB' | 'MANUAL'
    MATCH_CONFIDENCE    DECIMAL(3,2),
    LOADED_BY           VARCHAR(30),
    LOAD_DT             DATE
) PRIMARY INDEX (CLIENT_NO);
