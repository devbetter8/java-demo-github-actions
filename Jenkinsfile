// Pipeline CI/CD : récupère le code depuis GitLab, compile, teste, package le WAR,
// construit l'image Docker puis redéploie le conteneur de l'application.
pipeline {
    agent any

    triggers {
        // Jenkins local n'est pas joignable par GitLab.com : il vérifie lui-même
        // la présence de nouveaux commits toutes les 2 minutes.
        pollSCM('H/2 * * * *')
    }

    tools {
        // Nom de l'installation Maven déclarée dans "Administrer Jenkins > Tools".
        maven 'Maven-3.9'
    }

    environment {
        IMAGE_NAME = 'webapp-java'
        CONTAINER_NAME = 'webapp-java'
        // Port de la machine sur lequel l'application est accessible (8080 est pris par Jenkins).
        APP_PORT = '8081'
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        disableConcurrentBuilds()
    }

    stages {
        stage('Build') {
            steps {
                sh 'mvn -B clean compile'
            }
        }

        stage('Test') {
            steps {
                sh 'mvn -B test'
            }
            post {
                always {
                    // Publie les résultats JUnit, même si un test échoue.
                    junit '**/target/surefire-reports/*.xml'
                }
            }
        }

        stage('Package') {
            steps {
                // Les tests ont déjà été exécutés à l'étape précédente.
                sh 'mvn -B package -DskipTests'
            }
            post {
                success {
                    archiveArtifacts artifacts: 'webapp/target/webapp.war', fingerprint: true
                }
            }
        }

        stage('Docker Build') {
            steps {
                // Le Dockerfile à la racine copie webapp/target/webapp.war dans Tomcat.
                sh 'docker build -t $IMAGE_NAME:$BUILD_NUMBER .'
            }
        }

        stage('Deploy') {
            steps {
                // Remplace l'ancien conteneur par la nouvelle version.
                // "|| true" évite l'échec au tout premier déploiement, quand aucun conteneur n'existe.
                sh '''
                    docker rm -f $CONTAINER_NAME || true
                    docker run -d --name $CONTAINER_NAME \
                        -p $APP_PORT:8080 \
                        -e IMAGE_TAG=$BUILD_NUMBER \
                        -e BUILD_NUMBER=$BUILD_NUMBER \
                        $IMAGE_NAME:$BUILD_NUMBER
                '''
            }
        }
    }

    post {
        success {
            echo "Build #${env.BUILD_NUMBER} déployé : http://localhost:${env.APP_PORT}"
        }
        failure {
            echo "Build #${env.BUILD_NUMBER} en échec : consulter les logs de l'étape concernée."
        }
    }
}
