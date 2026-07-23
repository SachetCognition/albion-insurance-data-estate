package uk.co.albion.domain;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;

import org.junit.jupiter.api.Test;

class PolicyNumberNormalizerTest {

    private final PolicyNumberNormalizer normalizer = new PolicyNumberNormalizer();

    @Test
    void canonicalFormIsUnchanged() {
        assertEquals("ALB-PET-0000001", normalizer.normalise("ALB-PET-0000001"));
    }

    @Test
    void bordereauxFormIsReKeyed() {
        // AL/PET-0001559 (broker bordereaux) -> canonical, mirroring pkg_policy_inquiry.sql
        assertEquals("ALB-PET-0001559", normalizer.normalise("AL/PET-0001559"));
    }

    @Test
    void mainframeHyphenStrippedFormIsReKeyed() {
        // ALBPET0003278 (PLCYMSTR feed) -> canonical
        assertEquals("ALB-PET-0003278", normalizer.normalise("albpet0003278"));
    }

    @Test
    void trimsAndUppercases() {
        assertEquals("ALB-MOT-0004014", normalizer.normalise("  alb-mot-0004014 "));
    }

    @Test
    void nullSafe() {
        assertNull(normalizer.normalise(null));
    }
}
