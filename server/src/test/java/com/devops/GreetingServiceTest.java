package com.devops;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

class GreetingServiceTest {

    private GreetingService service;

    @BeforeEach
    void setUp() {
        service = new GreetingService();
    }

    @Test
    void testGreetContainsSuccessMessage() {
        String result = service.greet("DevOps");
        assertTrue(result.contains("Bravo"), "Le message doit confirmer le succès du déploiement");
    }

    @Test
    void testGreetNotNull() {
        assertNotNull(service.greet("test"), "Le message ne doit pas être null");
    }

    @Test
    void testGetVersionNotEmpty() {
        String version = service.getVersion();
        assertNotNull(version);
        assertFalse(version.isEmpty(), "La version ne doit pas être vide");
    }

    @Test
    void testGetPipelineSteps() {
        String steps = service.getPipelineSteps();
        assertTrue(steps.contains("Jenkins"), "Le pipeline doit inclure Jenkins");
        assertTrue(steps.contains("Docker"), "Le pipeline doit inclure Docker");
    }
}
