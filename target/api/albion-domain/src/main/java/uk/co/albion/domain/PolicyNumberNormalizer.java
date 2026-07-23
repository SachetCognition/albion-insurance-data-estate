package uk.co.albion.domain;

import java.util.regex.Pattern;

/**
 * Shared, single-source policy-number normalisation.
 *
 * The bordereaux/mainframe re-keying was duplicated inline in
 * {@code api_legacy/plsql/pkg_policy_inquiry.sql} (the "4th place"):
 * <pre>REPLACE(REPLACE(UPPER(TRIM(p_policy_no)),'AL/','ALB-'),'/','-')</pre>
 * and again in the Teradata/Informatica pipelines. This component does it ONCE,
 * mirroring the dbt macro {@code normalise_policy_no} so the API and the
 * warehouse agree on the canonical form {@code ALB-XXX-9999999}.
 */
public final class PolicyNumberNormalizer {

    private static final Pattern BORDEREAUX = Pattern.compile("^AL/([A-Z]{3})-([0-9]+)$");
    private static final Pattern MAINFRAME = Pattern.compile("^ALB([A-Z]{3})([0-9]+)$");
    private static final Pattern CANONICAL = Pattern.compile("^ALB-([A-Z]{3})-([0-9]+)$");

    /**
     * @return the canonical {@code ALB-XXX-9999999} form, or the trimmed/upper
     *         input if it is not a recognised Albion policy number.
     */
    public String normalise(String raw) {
        if (raw == null) {
            return null;
        }
        String s = raw.trim().toUpperCase();
        if (CANONICAL.matcher(s).matches()) {
            return s;
        }
        var bdx = BORDEREAUX.matcher(s);
        if (bdx.matches()) {
            return "ALB-" + bdx.group(1) + "-" + bdx.group(2);
        }
        var mf = MAINFRAME.matcher(s);
        if (mf.matches()) {
            return "ALB-" + mf.group(1) + "-" + mf.group(2);
        }
        return s;
    }
}
