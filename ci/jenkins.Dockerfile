# Image Jenkins avec la commande docker.
# Jenkins en a besoin pour construire l'image de l'application et lancer son conteneur.
FROM jenkins/jenkins:lts-jdk17

# On récupère uniquement le binaire du client Docker depuis l'image officielle.
# Le moteur Docker utilisé reste celui de la machine hôte (via le socket monté dans docker-compose.yml).
COPY --from=docker:27-cli /usr/local/bin/docker /usr/local/bin/docker
