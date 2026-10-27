# Pipeline CI/CD : GitLab + Jenkins (Docker) + Maven + Docker

Ce guide met en place le flux suivant :

```text
git push --> GitLab.com <--polling── Jenkins --> Maven (build, test, package) --> docker build --> conteneur webapp-java
```

Jenkins vérifie GitLab toutes les 2 minutes.
S'il trouve un nouveau commit sur `main`, il compile et teste le code, construit l'image Docker
et remplace le conteneur de l'application. Le site http://localhost:8081 affiche alors la nouvelle version.

## Comment Jenkins utilise Docker

Jenkins tourne lui-même dans un conteneur. Pour construire et lancer l'application, il pilote le Docker de votre machine :

- `ci/jenkins.Dockerfile` ajoute la commande `docker` à l'image Jenkins.
- `docker-compose.yml` partage le socket `/var/run/docker.sock` avec Jenkins.

Le conteneur `webapp-java` est donc créé **à côté** de Jenkins sur votre machine et non à l'intérieur de Jenkins.

## Pourquoi du polling ?

GitLab.com est sur Internet. Il ne peut pas appeler `localhost` pour prévenir Jenkins.
À l'inverse, Jenkins peut joindre GitLab.com. C'est donc lui qui vérifie régulièrement s'il y a du nouveau.
On appelle cela le **polling** (ou scrutation). Il est déclaré dans le `Jenkinsfile` :

```groovy
triggers {
    pollSCM('H/2 * * * *')
}
```

La syntaxe est celle de cron. `H/2 * * * *` signifie « toutes les 2 minutes ».
Le `H` laisse Jenkins choisir la minute exacte pour éviter que tous les jobs partent en même temps.

---

## 0. Prérequis

- Docker Desktop installé et lancé (https://www.docker.com/products/docker-desktop/)
  Vérification : `docker --version` et `docker compose version`
- Le projet sur GitLab (ici `gitlab.com/sup-learn/java-demo-appweb`)
- Les ports `8080` (Jenkins) et `8081` (application) libres sur la machine

## 1. Pousser le Jenkinsfile

Le fichier `Jenkinsfile` à la racine décrit le pipeline. Jenkins le lit directement dans le dépôt.
Il doit donc être sur la branche `main` de GitLab avant de créer le job.

## 2. Démarrer Jenkins

```bash
cd ci
docker compose up -d --build
```

`--build` construit l'image Jenkins personnalisée la première fois (et après chaque modification de `jenkins.Dockerfile`).
Jenkins est disponible sur http://localhost:8080 après environ une minute.

Vérifier que Jenkins voit bien Docker :

```bash
docker exec jenkins docker ps
```

La commande doit afficher la liste des conteneurs (au moins `jenkins`).

## 3. Initialiser Jenkins

1. Récupérer le mot de passe initial :
   ```bash
   docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
   ```
2. Le coller sur http://localhost:8080.
3. Choisir **Install suggested plugins**.
4. Créer le compte administrateur.

## 4. Installer les plugins du TP

**Manage Jenkins** > **Plugins** > **Available plugins**. Rechercher et cocher :

| Plugin                | Rôle                                                                                       |
|-----------------------|--------------------------------------------------------------------------------------------|
| **GitLab**            | Intégration GitLab dans les jobs (déclencheur par webhook, statut des builds)              |
| **GitLab API**        | Bibliothèque utilisée par le plugin GitLab pour dialoguer avec GitLab (installée avec lui) |
| **Maven Integration** | Ajoute le type de job « Maven project » et une meilleure prise en charge de Maven          |
| **SonarQube Scanner** | Servira à l'étape d'analyse de qualité du code (séance SonarQube)                          |

Cliquer sur **Install**, puis cocher **Restart Jenkins when installation is complete**.

Le pipeline actuel n'utilise pas encore ces plugins : le polling et Maven fonctionnent avec les plugins suggérés.
Ils sont installés maintenant pour la suite du TP.

## 5. Déclarer Maven dans Jenkins

L'image Jenkins contient Java mais pas Maven. Jenkins peut l'installer automatiquement.

**Manage Jenkins** > **Tools** > section **Maven installations** > **Add Maven** :

- Name : `Maven-3.9` (ce nom exact est utilisé dans le `Jenkinsfile`)
- Cocher **Install automatically**
- Version : la dernière `3.9.x`

Enregistrer.

## 6. Créer le job Pipeline

**New Item** > nom `java-demo-appweb` > type **Pipeline** > OK.

Dans la section **Pipeline** :

- Definition : **Pipeline script from SCM**
- SCM : **Git**
- Repository URL : `https://gitlab.com/sup-learn/java-demo-appweb.git`
- Credentials :
  - Dépôt **public** : aucun.
  - Dépôt **privé** : créer un jeton GitLab (**Preferences** > **Access tokens**, portée `read_repository`).
    Dans Jenkins, ajouter un credential **Username with password** : utilisateur GitLab + jeton comme mot de passe.
- Branch Specifier : `*/main`
- Script Path : `Jenkinsfile`

Ne rien cocher dans la section **Triggers**. Le polling est déjà déclaré dans le `Jenkinsfile`.

Enregistrer.

## 7. Lancer le premier build à la main

Cliquer sur **Build Now**.

Ce premier build est obligatoire. Jenkins ne connaît le bloc `triggers` qu'après avoir lu le `Jenkinsfile` une première fois.
Après ce build, la case **Poll SCM** apparaît cochée dans la configuration du job.

Le pipeline enchaîne `Build`, `Test`, `Package`, `Docker Build` et `Deploy`.
Ouvrir ensuite http://localhost:8081 : la carte **Build Jenkins** affiche `#1`.

## 8. Tester la mise à jour automatique

Modifier un texte visible, par exemple le message de `greet()` dans
`server/src/main/java/com/devops/GreetingService.java`, puis :

```bash
git commit -am "feat: update greeting message"
git push origin main
```

Dans les 2 minutes, un build démarre tout seul.
À la fin, recharger http://localhost:8081 : le nouveau message s'affiche et le numéro de build a augmenté.

Le menu **Polling Log** du job montre quand Jenkins a vérifié GitLab et ce qu'il a trouvé.

Attention : le test `testGreetContainsSuccessMessage` vérifie que le message contient `Bravo`.
Si le mot disparaît, l'étape `Test` échoue et l'ancienne version reste en ligne. C'est le rôle de la CI.

---

## Dépannage

| Symptôme                                                    | Cause probable                                                                          |
|-------------------------------------------------------------|-----------------------------------------------------------------------------------------|
| Aucun build après un push                                   | Le premier build manuel n'a pas été lancé (étape 7) ou le push n'est pas sur `main`.    |
| `Tool type "maven" does not have an install of "Maven-3.9"` | Le nom saisi à l'étape 5 ne correspond pas exactement.                                  |
| `Couldn't find any revision to build`                       | La branche indiquée n'existe pas (vérifier `*/main`).                                   |
| `Authentication failed` au checkout                         | Dépôt privé sans credential, ou jeton GitLab expiré.                                    |
| `docker: not found`                                         | L'image personnalisée n'a pas été construite : relancer `docker compose up -d --build`. |
| `permission denied ... docker.sock`                         | La ligne `user: root` manque dans `docker-compose.yml`.                                 |
| `port is already allocated` au Deploy                       | Le port 8081 est déjà utilisé par un autre programme ou conteneur.                      |

## Pour aller plus loin

- **Webhook.** Le polling interroge GitLab même quand rien n'a changé, et le build peut attendre 2 minutes.
  En entreprise, GitLab appelle Jenkins à chaque push (webhook, avec le plugin GitLab).
  Cela demande que Jenkins soit joignable depuis Internet.
- **Docker Hub.** Jenkins pourra aussi pousser l'image sur Docker Hub après l'étape `Docker Build`.
  Le déploiement récupérera alors l'image depuis Docker Hub.

## Arrêter et relancer

```bash
docker compose stop        # arrête Jenkins sans rien perdre
docker compose start       # relance Jenkins
docker rm -f webapp-java   # supprime le conteneur de l'application (créé par Jenkins, hors Compose)
docker compose down -v     # supprime Jenkins et toute sa configuration
```
