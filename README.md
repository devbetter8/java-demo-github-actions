# Webapp Java

Application de démo Java (JSP + Servlet).

## Structure du projet

- `server` — logique métier (module `jar`), ex. `GreetingService`.
- `webapp` — interface web JSP (module `war`), dépend de `server`.

## Prérequis

- JDK 11
- Maven 3.9+
- Docker

## Build

```bash
mvn clean package
```

Génère le fichier `webapp/target/webapp.war`.

## Tests

```bash
mvn test
```

## Intégration et déploiement continus (Jenkins)

Le `Jenkinsfile` décrit le pipeline : build, tests, packaging du WAR, image Docker et déploiement.
Jenkins vérifie GitLab toutes les 2 minutes. À chaque nouveau commit sur `main`, l'application
est reconstruite et redéployée sur http://localhost:8081.

La mise en place de Jenkins en local est détaillée dans [ci/README.md](ci/README.md).

## Deploy avec Docker

```bash
docker build -t webapp-java .
docker run -p 8081:8080 webapp-java
```
