package com.devops;

import org.junit.Before;
import org.junit.Test;
import static org.junit.Assert.*;

public class GreetingServiceTest {

    private GreetingService service;

    @Before
    public void setUp() {
        service = new GreetingService();
    }

    @Test
    public void testGreetContainsSuccessMessage() {
        String result = service.greet("DevOps");
        assertTrue("Le message doit confirmer le succès du déploiement", result.contains("Bravo"));
    }

    @Test
    public void testGreetNotNull() {
        assertNotNull("Le message ne doit pas être null", service.greet("test"));
    }

    @Test
    public void testGetVersionNotEmpty() {
        String version = service.getVersion();
        assertNotNull(version);
        assertFalse("La version ne doit pas être vide", version.isEmpty());
    }

    @Test
    public void testGetPipelineSteps() {
        String steps = service.getPipelineSteps();
        assertTrue("Le pipeline doit inclure Jenkins", steps.contains("Jenkins"));
        assertTrue("Le pipeline doit inclure Docker", steps.contains("Docker"));
    }
}
