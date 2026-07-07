// Pipeline CI/CD de l'usine logicielle.
//
// Déclenchement : webhook GitLab configuré sur ce dépôt (Settings > Webhooks),
// pointant vers l'URL générique du plugin GitLab de Jenkins. Aucune configuration
// de trigger n'est nécessaire ici : le job Jenkins (multibranch) est configuré
// pour builder sur push.
//
// Flux GitOps : ce pipeline ne se connecte JAMAIS au cluster k3s. Il pousse
// l'image sur le registry puis met à jour le tag d'image dans le dépôt
// usine_full (dossier k8s-manifests/). Argo CD, sur le cluster, détecte ce
// changement et synchronise seul (mode pull).
//
// Credentials Jenkins attendues (Jenkins Credentials Store, jamais en clair ici) :
//   - gitlab-registry-creds : identifiants (user/token) pour registry.gitlab.com
//   - gitlab-manifests-creds : token GitLab (scope write_repository) pour committer
//                              sur le dépôt usine_full (k8s-manifests/)
//   - sonarqube-token : token d'authentification SonarQube/SonarCloud
//
// Serveur SonarQube nommé "sonarqube" dans la configuration globale Jenkins
// (Manage Jenkins > System > SonarQube servers).

pipeline {
    agent none

    options {
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '20'))
    }

    environment {
        REGISTRY        = 'registry.gitlab.com'
        IMAGE_NAME      = 'visualbd1/java-demo-appweb'
        MANIFESTS_REPO  = 'https://gitlab.com/visualbd1/usine_full.git'
        // Pas de VM dédiée à SonarQube dans cette usine (3 VM : Jenkins, k3s master,
        // k3s agent) ; le dépôt étant public, on utilise SonarCloud (alternative
        // explicitement permise par le §4 du prompt projet). Le serveur "sonarqube"
        // configuré dans Jenkins (Manage Jenkins > System) pointe alors vers
        // https://sonarcloud.io. Adapter SONAR_ORGANIZATION à votre organisation SonarCloud.
        SONAR_PROJECT_KEY  = 'visualbd1_java-demo-appweb'
        SONAR_ORGANIZATION = 'visualbd1'
    }

    stages {

        stage('Préparation') {
            agent any
            steps {
                script {
                    env.GIT_SHORT_SHA = sh(script: 'git rev-parse --short=7 HEAD', returnStdout: true).trim()
                    def semver = (env.TAG_NAME ?: 'v0.1.0-dev')
                    env.IMAGE_TAG = "${semver}-${env.GIT_SHORT_SHA}"
                    echo "Tag d'image calculé : ${env.IMAGE_TAG}"
                }
            }
        }

        stage('Build & Tests unitaires') {
            agent {
                docker {
                    image 'maven:3.9-eclipse-temurin-11'
                    args '-v $HOME/.m2:/root/.m2'
                }
            }
            steps {
                sh 'mvn -B clean verify'
            }
            post {
                always {
                    junit '**/target/surefire-reports/*.xml'
                }
            }
        }

        stage('Qualité de code (SonarQube)') {
            agent {
                docker {
                    image 'maven:3.9-eclipse-temurin-11'
                    args '-v $HOME/.m2:/root/.m2'
                }
            }
            steps {
                withSonarQubeEnv('sonarqube') {
                    sh """
                        mvn -B sonar:sonar \
                          -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
                          -Dsonar.organization=${SONAR_ORGANIZATION} \
                          -Dsonar.token=\$SONAR_AUTH_TOKEN
                    """
                }
            }
        }

        stage('Quality Gate') {
            agent any
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Scan secrets (Gitleaks)') {
            agent any
            steps {
                sh '''
                    docker run --rm -v "$WORKSPACE:/repo" zricethezav/gitleaks:latest \
                      detect --source=/repo --no-git -v --exit-code 1
                '''
            }
        }

        stage('Package (Docker build)') {
            agent any
            steps {
                sh "docker build -t ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG} ."
            }
        }

        stage('Scan vulnérabilités (Trivy)') {
            agent any
            steps {
                sh """
                    docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
                      aquasec/trivy:latest image \
                      --exit-code 1 --severity CRITICAL,HIGH --ignore-unfixed \
                      ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}
                """
            }
        }

        stage('Push registry') {
            agent any
            steps {
                withCredentials([usernamePassword(credentialsId: 'gitlab-registry-creds',
                                                   usernameVariable: 'REG_USER',
                                                   passwordVariable: 'REG_TOKEN')]) {
                    sh """
                        echo "\$REG_TOKEN" | docker login ${REGISTRY} -u "\$REG_USER" --password-stdin
                        docker push ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}
                        docker logout ${REGISTRY}
                    """
                }
            }
        }

        stage('Déploiement GitOps (mise à jour manifeste)') {
            agent any
            steps {
                withCredentials([usernamePassword(credentialsId: 'gitlab-manifests-creds',
                                                   usernameVariable: 'GIT_USER',
                                                   passwordVariable: 'GIT_TOKEN')]) {
                    sh """
                        rm -rf usine_full
                        git clone https://\$GIT_USER:\$GIT_TOKEN@gitlab.com/visualbd1/usine_full.git
                        cd usine_full/k8s-manifests/base
                        curl -sL https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv5.4.3/kustomize_v5.4.3_linux_amd64.tar.gz | tar xz
                        ./kustomize edit set image app=${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}
                        rm -f kustomize
                        git config user.email 'jenkins-ci@usine-logicielle.local'
                        git config user.name 'jenkins-ci'
                        git commit -am "deploy: ${IMAGE_NAME}:${IMAGE_TAG}" || echo 'Rien à committer'
                        git push origin HEAD:main
                    """
                }
                echo 'Argo CD détecte et synchronise automatiquement le cluster (mode pull).'
            }
        }
    }

    post {
        always {
            node('') {
                sh "docker rmi ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG} || true"
            }
        }
    }
}
