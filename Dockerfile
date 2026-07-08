# --- Stage 1 : build Maven (multi-module : server + webapp) ---
FROM maven:3.9-eclipse-temurin-11 AS build

WORKDIR /build

# Cache des dépendances : copier uniquement les pom.xml d'abord
COPY pom.xml .
COPY server/pom.xml server/pom.xml
COPY webapp/pom.xml webapp/pom.xml
RUN mvn -B -q -pl server,webapp -am dependency:go-offline

# Copier le code source puis construire le WAR (tests déjà exécutés en amont dans le pipeline CI)
COPY server/src server/src
COPY webapp/src webapp/src
RUN mvn -B -q clean package -DskipTests

# --- Stage 2 : runtime Tomcat ---
FROM tomcat:9-jdk11-temurin

LABEL maintainer="usine-logicielle"
LABEL description="Webapp Java"

RUN rm -rf /usr/local/tomcat/webapps/*
COPY --from=build /build/webapp/target/webapp.war /usr/local/tomcat/webapps/ROOT.war

EXPOSE 8080

CMD ["catalina.sh", "run"]
