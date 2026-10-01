package uk.co.albion.api.seed;

import java.time.LocalDate;
import java.time.format.DateTimeFormatter;

/**
 * The same canonical normalisations the dbt staging layer applies, re-expressed
 * for the API's in-memory store loader so that seeded data matches the warehouse.
 * (In production the API reads the already-transformed dbt marts and none of
 * this runs; it exists to make the H2 test store faithful to the canonical model.)
 */
public final class CanonicalTransforms {

    private static final DateTimeFormatter DDMMYYYY = DateTimeFormatter.ofPattern("dd/MM/yyyy");
    private static final DateTimeFormatter ISO = DateTimeFormatter.ISO_LOCAL_DATE;

    private CanonicalTransforms() {
    }

    /** DD/MM/YYYY text -> LocalDate (single UK interpretation; replaces DQR-052 divergence). */
    public static LocalDate parseDdMmYyyy(String s) {
        if (s == null || s.isBlank()) {
            return null;
        }
        return LocalDate.parse(s.trim(), DDMMYYYY);
    }

    /** ISO yyyy-MM-dd text -> LocalDate. */
    public static LocalDate parseIso(String s) {
        if (s == null || s.isBlank()) {
            return null;
        }
        return LocalDate.parse(s.trim(), ISO);
    }

    /** Lowercase + trim once (DQR-007). */
    public static String email(String s) {
        return (s == null || s.isBlank()) ? null : s.trim().toLowerCase();
    }

    /** Standardise UK postcode once: upper, collapse spaces, single space before inward code (DQR-014). */
    public static String postcode(String s) {
        if (s == null || s.isBlank()) {
            return null;
        }
        String compact = s.replaceAll("\\s+", "").toUpperCase();
        if (compact.length() < 5) {
            return compact;
        }
        int split = compact.length() - 3;
        return compact.substring(0, split) + " " + compact.substring(split);
    }

    /** Mask NINO: first 2 + '*****' + last 2 (DQR-021). Raw NINO never stored. */
    public static String maskNino(String s) {
        if (s == null || s.isBlank()) {
            return null;
        }
        String t = s.trim();
        if (t.length() < 4) {
            return "*****";
        }
        return t.substring(0, 2) + "*****" + t.substring(t.length() - 2);
    }

    /** Canonical fraud flag: 'S' (suspected) and 'Y' -> 'Y', else 'N' (one mapping). */
    public static String fraudFlag(String s) {
        if (s == null) {
            return "N";
        }
        String t = s.trim().toUpperCase();
        return (t.equals("Y") || t.equals("S")) ? "Y" : "N";
    }
}
