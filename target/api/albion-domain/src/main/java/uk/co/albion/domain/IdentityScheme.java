package uk.co.albion.domain;

/**
 * The identifier schemes present in the Albion estate (README finding #1).
 * The legacy SOAP contract collapsed several of these into a single overloaded
 * {@code customerRef} string; consumers parsed the prefix to guess which scheme
 * they had. The modern API instead exposes the scheme EXPLICITLY alongside the
 * identifier value (see {@link PartyIdentifier}).
 */
public enum IdentityScheme {
    /** POLARIS PAS PARTY_ID ('P' + 7 digits) — the canonical group party key. */
    POLARIS,
    /** LEGACY_PAS mainframe CLIENT_NO (zero-padded numeric). */
    LEGACY_PAS,
    /** APF core-banking CUSTOMER_ID (crosswalked via PARTY.LEGACY_CUSTOMER_ID). */
    APF_BANKING,
    /** LIFE400 LIFE_POLICY_ID ('PM' prefixed) — keyless book, fuzzy-matched. */
    LIFE400,
    /** Partner loyalty MKTG_CUST_ID — never crosswalked. */
    PARTNER_LOYALTY
}
