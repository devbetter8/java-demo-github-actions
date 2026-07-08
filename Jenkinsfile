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

    parameters {
        // SonarCloud configuré (2026-07-07) : serveur "sonarqube" + credential
        // "sonarqube-token" en place dans Jenkins. Activé par défaut.
        booleanParam(name: 'RUN_SONAR', defaultValue: true,
                     description: 'Exécuter l\'analyse SonarCloud + Quality Gate')
    }

    environment {
        REGISTRY        = 'registry.gitlab.com'
        IMAGE_NAME      = 'visualbd1/java-demo-appweb'
        MANIFESTS_REPO  = 'https://gitlab.com/visualbd1/usine_full.git'
        // Pas de VM dédiée à SonarQube dans cette usine (3 VM : Jenkins, k3s master,
        // k3s agent) ; le dépôt étant public, on utilise SonarCloud (alternative
        // explicitement permise par le §4 du prompt projet). Le serveur "sonarqube"
        // configuré dans Jenkins (Manage Jenkins > System) pointe vers
        // https://sonarcloud.io. Organisation SonarCloud liée au compte personnel
        // Darkbd11 (le groupe GitLab visualbd1 n'a pas pu être importé : réservé aux
        // organisations SonarCloud payantes).
        SONAR_PROJECT_KEY  = 'java-demo-appweb'
        SONAR_ORGANIZATION = 'darkbd11'
    }

    stages {

        stage('Préparation') {
            agent any
            steps {
                script {
                    env.GIT_SHORT_SHA = sh(script: 'git rev-parse --short=7 HEAD', returnStdout: true).trim()
                    // Version sémantique dérivée du dernier tag Git accessible (§9 du prompt :
                    // tags vMAJOR.MINOR.PATCH posés sur main). On force un fetch des tags car
                    // le checkout multibranch peut ne pas les ramener. Priorité : TAG_NAME
                    // (build d'un tag en multibranch) > dernier tag Git atteignable depuis
                    // HEAD > fallback v0.1.0-dev (aucun tag encore posé). L'image sort donc
                    // en vX.Y.Z-<sha> dès qu'un tag sémantique existe, au lieu de rester figée.
                    sh 'git fetch --tags --quiet || true'
                    def lastTag = sh(script: 'git describe --tags --abbrev=0 2>/dev/null || true', returnStdout: true).trim()
                    def semver = (env.TAG_NAME ?: (lastTag ?: 'v0.1.0-dev'))
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

        stage('Lint / analyse statique (SpotBugs)') {
            // §4 du prompt : "tests unitaires + lint". SpotBugs analyse le bytecode à la
            // recherche de bug patterns (NPE potentiels, ressources non fermées, etc.).
            // Seuil High + effort Max : on ne casse le build que sur les défauts à forte
            // confiance, pour éviter le bruit d'un premier branchement. `spotbugs:check`
            // échoue (donc fait échouer le pipeline) dès qu'un bug de ce niveau est trouvé.
            agent {
                docker {
                    image 'maven:3.9-eclipse-temurin-11'
                    args '-v $HOME/.m2:/root/.m2'
                }
            }
            steps {
                sh 'mvn -B compile spotbugs:check'
            }
        }

        stage('Qualité de code (SonarQube)') {
            when { expression { params.RUN_SONAR } }
            // Le scanner sonar-maven-plugin nécessite un JRE récent pour s'exécuter
            // (peu importe la version cible de compilation du projet, ici 11) :
            // Java 11 -> UnsupportedClassVersionError (constaté), puis Java 17 ->
            // rejeté explicitement par SonarQube Cloud ("deprecated, no longer
            // supported... upgrade to Java 21 or later", constaté aussi — exigence
            // relevée par SonarCloud après le premier passage). L'analyse ne recompile
            // pas le code, elle lit juste les .class déjà produits par le stage
            // précédent : aucun conflit avec le bytecode Java 11 de l'appli.
            agent {
                docker {
                    image 'maven:3.9-eclipse-temurin-21'
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
            when { expression { params.RUN_SONAR } }
            agent any
            steps {
                // On n'utilise PAS waitForQualityGate : il attend un webhook ENTRANT de
                // SonarCloud vers Jenkins (http://<IP_VM1>:8080/sonarqube-webhook/), or le
                // security group n'ouvre le 8080 qu'à l'IP autorisée en SSH — l'ouvrir au
                // monde pour ce seul callback serait une régression de sécurité. À la place,
                // on INTERROGE l'API SonarCloud en sortant (polling), ce qui ne nécessite
                // aucun port entrant. Le report-task.txt écrit par le stage précédent
                // (workspace partagé, mono-nœud) donne l'URL de la tâche d'analyse.
                withCredentials([string(credentialsId: 'sonarqube-token', variable: 'SONAR_TOKEN')]) {
                    sh '''
                        set -e
                        REPORT=$(find . -name report-task.txt -path '*sonar*' | head -1)
                        if [ -z "$REPORT" ]; then echo "report-task.txt introuvable (analyse Sonar absente)"; exit 1; fi
                        CE_URL=$(sed -n 's/^ceTaskUrl=//p' "$REPORT")
                        echo "Tâche d'analyse SonarCloud : $CE_URL"

                        # 1) Attendre la fin du traitement de l'analyse côté SonarCloud (max ~3 min).
                        ANALYSIS_ID=""
                        for i in $(seq 1 36); do
                            CE_JSON=$(curl -s -u "$SONAR_TOKEN:" "$CE_URL")
                            CE_STATUS=$(echo "$CE_JSON" | sed -n 's/.*"status":"\\([A-Z]*\\)".*/\\1/p')
                            echo "  statut analyse : ${CE_STATUS:-?}"
                            case "$CE_STATUS" in
                                SUCCESS) ANALYSIS_ID=$(echo "$CE_JSON" | sed -n 's/.*"analysisId":"\\([^"]*\\)".*/\\1/p'); break ;;
                                FAILED|CANCELED) echo "Analyse SonarCloud en échec"; exit 1 ;;
                            esac
                            sleep 5
                        done
                        if [ -z "$ANALYSIS_ID" ]; then echo "Timeout : analyse SonarCloud non terminée"; exit 1; fi

                        # 2) Récupérer le verdict du Quality Gate pour cette analyse.
                        QG_JSON=$(curl -s -u "$SONAR_TOKEN:" "https://sonarcloud.io/api/qualitygates/project_status?analysisId=$ANALYSIS_ID")
                        GATE=$(echo "$QG_JSON" | sed -n 's/.*"projectStatus":{"status":"\\([A-Z]*\\)".*/\\1/p')
                        echo "Quality Gate = ${GATE:-inconnu}"
                        case "$GATE" in
                            OK)    echo "Quality Gate PASSÉ." ;;
                            ERROR) echo "Quality Gate en ERREUR -> échec du pipeline"; exit 1 ;;
                            *)     echo "Quality Gate ni OK ni ERROR (=$GATE) : on ne bloque pas (ex: aucune période de référence sur un projet neuf)." ;;
                        esac
                    '''
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
