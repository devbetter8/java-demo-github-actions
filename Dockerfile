# Jenkins construit le WAR via Maven (mvn clean package),
# puis Docker empaquète uniquement le runtime Tomcat + WAR.
FROM tomcat:9-jdk11-temurin

LABEL maintainer="ftutorials"
LABEL description="Webapp Java"

# Suppression des webapps par défaut de Tomcat
RUN rm -rf /usr/local/tomcat/webapps/*

# Copie du WAR buildé par Jenkins (webapp/target/webapp.war)
COPY webapp/target/webapp.war /usr/local/tomcat/webapps/ROOT.war

EXPOSE 8080

CMD ["catalina.sh", "run"]
