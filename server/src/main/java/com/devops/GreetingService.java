package com.devops;

public class GreetingService {

    public String greet(String name) {
        return "Bravo ! Application déployée avec succès.";
    }

    public String getVersion() {
        return "1.0.0";
    }

    public String getPipelineSteps() {
        return "Git → Jenkins → Maven → Docker Build → Docker Deploy";
    }
}
