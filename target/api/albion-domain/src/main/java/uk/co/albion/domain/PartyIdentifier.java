package uk.co.albion.domain;

/**
 * A structured, typed party identifier — the fix for the {@code customer_ref}
 * defect in {@code api_legacy/plsql/pkg_policy_inquiry.sql}:
 *
 * <pre>NVL(TO_CHAR(p.legacy_customer_id), p.party_id) AS customer_ref</pre>
 *
 * which leaked two identifier schemes into ONE overloaded string. Here the
 * canonical {@code partyId} and its {@code sourceScheme} are always explicit,
 * and the cross-referenced legacy identifiers are separate typed fields rather
 * than being packed into the same value.
 *
 * @param partyId       canonical party identifier value
 * @param sourceScheme  which scheme {@code partyId} belongs to (never ambiguous)
 * @param legacyClientNo LEGACY_PAS CLIENT_NO if cross-referenced, else null
 * @param apfCustomerId  APF banking CUSTOMER_ID if cross-referenced, else null
 */
public record PartyIdentifier(
        String partyId,
        IdentityScheme sourceScheme,
        Long legacyClientNo,
        Long apfCustomerId) {

    public static PartyIdentifier polaris(String partyId, Long legacyClientNo, Long apfCustomerId) {
        return new PartyIdentifier(partyId, IdentityScheme.POLARIS, legacyClientNo, apfCustomerId);
    }
}
