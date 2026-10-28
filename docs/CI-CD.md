# CI/CD avec GitHub Actions, SonarQube, Nexus, Argo CD et k3s

## Vue d'ensemble

```text
git push (main)
  |
  v
GitHub -- déclenche --► Runner auto-hébergé (machine locale)
                          |
                          |- Job build
                          |    Maven : build + tests
                          |    SonarQube : analyse + Quality Gate
                          |
                          |- Job deliver
                               Docker : build de l'image
                               Trivy : scan (bloquant si CRITICAL)
                               Nexus : push de l'image
                               Repo manifests : mise à jour du tag
                                         |
                                         v
                          Argo CD (dans k3s) détecte le commit
                                         |
                                         v
                          k3s tire l'image depuis Nexus et redéploie
```

Deux repos GitHub :

- `devbetter8/java-demo-github-actions` : le code et le pipeline (CI).
- `devbetter8/java-demo-github-actions-manifests` : les manifests Kubernetes (CD, GitOps).

### Pourquoi un runner auto-hébergé ?

Les runners fournis par GitHub tournent dans le cloud.
Ils ne peuvent pas joindre SonarQube ou Nexus, qui tournent sur votre machine locale.
Le runner auto-hébergé tourne sur votre machine. Il contacte GitHub pour récupérer les jobs.
Aucun port n'est ouvert vers l'extérieur et ngrok n'est pas nécessaire.

Les étapes du workflow sont écrites en Bash.
Le runner doit donc tourner sous macOS ou Linux. Sous Windows, utilisez WSL2.

## 1. Prérequis sur votre machine

Le runner exécute les commandes du workflow directement sur votre machine.
Chaque outil utilisé par le pipeline doit donc y être installé.

| Outil          | Utilisé par         | Installation                                                                      |
|----------------|---------------------|-----------------------------------------------------------------------------------|
| Docker         | le pipeline et vous | [Docker Desktop](https://docs.docker.com/get-docker/) ou Docker Engine sous Linux |
| Maven 3.9+     | le pipeline         | [Binaire officiel](https://maven.apache.org/download.cgi)                         |
| Trivy          | le pipeline         | [Installation](https://trivy.dev/latest/getting-started/installation/)            |
| yq (mikefarah) | le pipeline         | [Releases](https://github.com/mikefarah/yq/releases)                              |
| k3d            | vous, une fois      | [Installation](https://k3d.io/stable/#installation)                               |
| kubectl        | vous                | [Installation](https://kubernetes.io/docs/tasks/tools/)                           |

Le JDK 25 est installé par le workflow avec `actions/setup-java`. Pas besoin de l'installer.

Avec Homebrew (macOS Apple Silicon ou Linux), une seule commande suffit :

```bash
brew install maven trivy yq k3d kubectl
```

Homebrew ne prend plus en charge les Mac Intel.
Sur ces machines, installez Maven depuis le binaire officiel :

```bash
curl -LO https://archive.apache.org/dist/maven/maven-3/3.9.11/binaries/apache-maven-3.9.11-bin.tar.gz
mkdir -p ~/tools
tar xzf apache-maven-3.9.11-bin.tar.gz -C ~/tools
rm apache-maven-3.9.11-bin.tar.gz
echo 'export PATH="$HOME/tools/apache-maven-3.9.11/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
mvn -v
```

Remplacez `~/.zshrc` par `~/.bashrc` si votre shell est Bash.

## 2. Lancer SonarQube et Nexus

```bash
docker compose -f infra/docker-compose.yml up -d
```

Vérifiez que les ports 9000, 8081 et 8082 sont libres.
Arrêtez par exemple un autre SonarQube déjà lancé sur le port 9000.

Nexus met 1 à 2 minutes à démarrer. Pour vérifier que SonarQube est prêt :

```bash
curl http://localhost:9000/api/system/status
```

La réponse doit contenir `"status":"UP"`.

## 3. Configurer SonarQube

1. Ouvrir http://localhost:9000 (admin / admin la première fois).
2. My Account > Security > Generate Tokens.
3. Type `Global Analysis Token`. Copier le token.

Le projet `java-demo-github-actions` est créé automatiquement à la première analyse.

## 4. Configurer Nexus comme registre Docker

1. Récupérer le mot de passe admin initial :

   ```bash
   docker exec nexus cat /nexus-data/admin.password
   ```

2. Ouvrir http://localhost:8081 et se connecter avec `admin`.
3. Créer le dépôt Docker :
   - Settings (roue crantée) > Repositories > Create repository > `docker (hosted)`.
   - Name : `docker-hosted`.
   - Repository Connectors : cocher HTTP, port `8082`.
4. Activer l'authentification Docker :
   - Security > Realms.
   - Passer `Docker Bearer Token Realm` dans la colonne Active. Save.
5. Créer un utilisateur dédié à la CI :
   - Security > Roles > Create role. ID `github-ci-role`.
     Privilège : `nx-repository-view-docker-docker-hosted-*`.
   - Security > Users > Create local user. ID `github-ci`, rôle `github-ci-role`.
6. Tester depuis votre machine :

   ```bash
   docker login localhost:8082 -u github-ci
   ```

Docker accepte le HTTP sans configuration pour les registres en `localhost`.

## 5. Créer le repo des manifests

1. Sur GitHub, créer le repo public `java-demo-github-actions-manifests` (sans README).
2. Pousser le contenu fourni :

   ```bash
   cd java-demo-github-actions-manifests
   git init -b main
   git add .
   git commit -m "feat: add webapp kubernetes manifests"
   git remote add origin https://github.com/devbetter8/java-demo-github-actions-manifests.git
   git push -u origin main
   ```

## 6. Créer le token pour le repo des manifests

Le `GITHUB_TOKEN` automatique ne peut écrire que dans le repo du workflow.
Pour pousser dans le repo des manifests, il faut un Personal Access Token.

1. GitHub > Settings > Developer settings > Fine-grained tokens > Generate new token.
2. Repository access : cocher `Only select repositories`, puis choisir `java-demo-github-actions-manifests`.
   La liste des permissions n'apparaît qu'après ce choix.
3. Permissions : ajouter `Contents` et choisir `Read and write`.
   `Metadata: Read-only` s'ajoute automatiquement.

Un token classic avec le scope `public_repo` fonctionne aussi.
Il donne cependant accès en écriture à tous vos repos. Le fine-grained token limite l'accès au seul repo de manifests.

## 7. Déclarer les secrets et variables

Dans le repo applicatif : Settings > Secrets and variables > Actions.

Onglet **Secrets** :

| Nom               | Valeur                      |
|-------------------|-----------------------------|
| `SONAR_TOKEN`     | Token SonarQube (étape 3)   |
| `NEXUS_USERNAME`  | `github-ci`                 |
| `NEXUS_PASSWORD`  | Mot de passe de `github-ci` |
| `MANIFESTS_TOKEN` | Token GitHub (étape 6)      |

Onglet **Variables**, section **Repository variables** :

| Nom              | Valeur                                          |
|------------------|-------------------------------------------------|
| `SONAR_HOST_URL` | `http://localhost:9000`                         |
| `MANIFESTS_REPO` | `devbetter8/java-demo-github-actions-manifests` |

Un secret est masqué dans les logs. Une variable est visible. L'URL n'est pas sensible, d'où la variable.

Attention : une variable absente ou mal placée (dans Secrets ou dans un Environment) est remplacée par une chaîne vide, sans erreur.

## 8. Installer le runner auto-hébergé

1. Repo applicatif > Settings > Actions > Runners > New self-hosted runner.
2. Choisir le système et l'architecture de votre machine.
3. Créer le dossier du runner **en dehors** du repo, par exemple `~/actions-runner`.
   Il contient les identifiants du runner et ne doit jamais être commité.
4. Exécuter les commandes affichées (téléchargement puis `./config.sh ...`).
   Garder les labels par défaut.
5. Démarrer le runner dans un terminal et le laisser ouvert :

   ```bash
   ./run.sh
   ```

Le runner enregistre le PATH au moment de `./config.sh`, dans le fichier `.path`.
Si vous installez un outil après coup, mettez ce fichier à jour puis relancez le runner :

```bash
echo "$PATH" > ~/actions-runner/.path
```

Sous macOS, lancez le runner avec `./run.sh` plutôt qu'en service.
En service, `docker login` échoue souvent car il n'a pas accès au trousseau macOS.

**Sécurité.** Le repo est public. Le workflow ne se déclenche pas sur les pull requests.
Un fork ne peut donc pas exécuter de code sur votre machine.
Par précaution : Settings > Actions > General > Fork pull request workflows > `Require approval for all external contributors`.

## 9. Premier lancement du pipeline

Pousser sur `main` ou lancer le workflow à la main (onglet Actions > CI/CD > Run workflow).

Vérifier :

- Le job est vert dans l'onglet Actions.
- L'image apparaît dans Nexus : Browse > `docker-hosted`.
- Un commit `chore(webapp): deploy image ...` apparaît dans le repo des manifests.

En cas d'échec, **Re-run failed jobs** suffit si vous avez corrigé un outil, une variable ou un secret.
Si vous avez modifié le workflow, il faut un nouveau push : une relance réutilise le workflow du commit d'origine.

## 10. Créer le cluster k3s avec k3d

```bash
cp infra/k3d/registries.yaml.example infra/k3d/registries.yaml
# Remplacer CHANGE_ME par le mot de passe de github-ci.

k3d cluster create tp-gha \
  -p "8090:80@loadbalancer" \
  --registry-config infra/k3d/registries.yaml
```

- `-p "8090:80@loadbalancer"` expose l'Ingress Traefik sur http://localhost:8090.
- `--registry-config` indique à k3s comment joindre Nexus.

Dans le cluster, `localhost` désigne le nœud lui-même et pas votre machine.
Le fichier redirige donc `localhost:8082` vers `host.k3d.internal:8082`, qui pointe vers votre machine.
L'image garde le même nom partout : `localhost:8082/webapp-java:<tag>`.

## 11. Installer Argo CD

```bash
kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

kubectl -n argocd rollout status deploy/argocd-server
```

Mot de passe admin :

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d; echo
```

Interface web (laisser tourner dans un terminal) :

```bash
kubectl port-forward svc/argocd-server -n argocd 8443:443
```

Puis https://localhost:8443 avec `admin`.

Déclarer l'application (depuis le repo des manifests) :

```bash
kubectl apply -n argocd -f argocd/application.yaml
```

## 12. Vérifier la boucle complète

1. Ouvrir http://localhost:8090. La carte « Build GitHub Actions » affiche le numéro du run.
2. Modifier le message de `GreetingService.greet()` (et le test si besoin).
3. Pousser sur `main`.
4. Argo CD vérifie le repo toutes les 3 minutes environ. Le bouton Refresh force la vérification.
5. La page affiche le nouveau message, le nouveau tag et le nouveau numéro de build.

## Dépannage

| Problème                                    | Piste                                                                                                                                   |
|---------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------|
| Le job reste en `Queued`                    | Le runner n'est pas lancé (`./run.sh`).                                                                                                 |
| `command not found` (mvn, trivy, yq)        | L'outil n'est pas installé, ou le fichier `.path` du runner est à mettre à jour (étape 8).                                              |
| `SonarQube server [] can not be reached`    | La variable `SONAR_HOST_URL` est absente ou mal placée (étape 7).                                                                       |
| Quality Gate en échec                       | Lire le détail dans SonarQube. Le job échoue volontairement.                                                                            |
| Trivy bloque le pipeline                    | Lire le rapport dans les logs. Mettre à jour l'image de base du Dockerfile.                                                             |
| `error storing credentials` au login Docker | Sous macOS, lancer le runner avec `./run.sh` dans une session ouverte.                                                                  |
| Pod en `ImagePullBackOff`                   | Vérifier le mot de passe dans `registries.yaml`. Contrôler avec `docker exec k3d-tp-gha-server-0 cat /etc/rancher/k3s/registries.yaml`. |
| Le pod ne démarre pas avant le premier run  | Normal : l'image `initial` n'existe pas. Lancer le pipeline une fois.                                                                   |
