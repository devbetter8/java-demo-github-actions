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

## Deploy avec Docker

```bash
docker build -t webapp-java .
docker run -p 8081:8080 webapp-java
```
