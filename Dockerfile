# La CI construit le WAR via Maven (mvn clean verify),
# puis Docker empaquète uniquement le runtime Tomcat + WAR.
# Une image JRE suffit pour exécuter le WAR : plus légère qu'une image JDK.
FROM tomcat:11-jre25-temurin

LABEL maintainer="ftutorials"
LABEL description="Webapp Java"

# Suppression des webapps par défaut de Tomcat
RUN rm -rf /usr/local/tomcat/webapps/*

# Copie du WAR buildé par la CI (webapp/target/webapp.war)
COPY webapp/target/webapp.war /usr/local/tomcat/webapps/ROOT.war

EXPOSE 8080

CMD ["catalina.sh", "run"]
