# LamentersHelper

## Vue d'ensemble

LamentersHelper est un addon privé World of Warcraft orienté raid pour le roster Lamenters. Il est structuré en modules autour d'une table partagée `M`, avec une configuration persistante via `LamentersHelperDB`, un panneau d'options et plusieurs systèmes d'affichage en combat.

## Architecture

- Chargement via `LamentersHelper.toc`
- Table partagée `local addonName, M = ...`
- Sauvegarde des réglages dans `LamentersHelperDB`
- Initialisation de la configuration au `PLAYER_LOGIN`
- Sauvegarde complète au `PLAYER_LOGOUT`
- Commande slash `/lh` pour ouvrir ou fermer le panneau principal
- Commande slash `/lhcheck` pour vérifier quels joueurs ont l'addon
- Organisation par boss via le dossier `boss/`

## Interface et configuration

- Fenêtre principale draggable avec menu latéral
- Deux sections d'interface :
  - `Options`
  - `Imperator`
- Section `Options` pour les réglages globaux
- Section `Imperator` pour les réglages liés au boss Imperator Averzian
- Gestion d'anchors pour déplacer les éléments visuels
- Sauvegarde des positions après déplacement

## Systèmes de texte

### Global Text

- Texte principal pour les calls de raid importants
- Position configurable
- Taille configurable
- Affichage temporaire avec auto-hide
- Utilisé notamment par la grille tactique

### Private Text

- Deuxième zone de texte pour messages secondaires ciblés
- Position configurable
- Taille configurable
- Affichage temporaire avec auto-hide
- Utilisé pour des consignes spécifiques comme les dispels

### RL Note

- Zone de texte persistante réservée au personnage RL défini dans le code
- Position configurable pour le RL uniquement
- Taille configurable pour le RL uniquement
- Affichage persistant sans timer
- Prévu pour les notes vocales, listes de joueurs et plans d'exécution

## Module Grid

- Grille 3x3 visuelle et draggable
- Icônes de raid affichées dans chaque case
- Interaction limitée au RL
- Sélection de 3 cases
- Calcul automatique d'un carré rouge et de deux carrés verts
- Priorité stratégique du skip :
  - bords d'abord
  - coins ensuite
  - centre en dernier
- Évite de créer une ligne de 3 tant que possible
- Sélection déterministe
- Mémorisation des cases rouges déjà utilisées
- Reset manuel via bouton
- Reset automatique après délai
- Synchronisation du visuel via messages addon `LH_GRID`
- Texte automatique de type `SOAK icon AND icon`

## Visibilité de la grille

- Grille cachée par défaut
- Affichage automatique pendant l'encounter ciblé
- Encounter suivi par `encounterID`
- Override via option `Toujours afficher la grille (test)`
- Affichage possible en mode anchors pour déplacer la grille hors combat

## Débogage encounter

- Option globale pour afficher l'`encounterID` dans le chat
- Affichage sur `ENCOUNTER_START`
- Affichage sur `ENCOUNTER_END`

## Module Void Marked

- Détection des auras :
  - `Void Marked`
  - `Marque du Vide`
- Scan automatique du raid
- Création de 3 groupes de 2 joueurs marqués
- Détection automatique des soigneurs du raid via les rôles assignés
- Assignation initiale des dispels en round-robin
- Construction d'une note RL structurée par `SOAK 1`, `SOAK 2`, `SOAK 3`
- Envoi d'un message ciblé aux heals via le `private text`
- Suppression automatique du message privé quand plus aucun joueur n'est assigné
- Couleur de classe appliquée au joueur à dispel dans le `private text`
- Synchronisation des assignations via messages addon `LH_VM`
- Commande de test `/lhvoidtest`

## Alertes

- Fonction `TriggerAlert`
- Affichage d'un message via le Global Text
- Lecture d'un son si l'option son est activée

## État actuel

Fonctionnalités déjà présentes et utilisables :

- UI principale et navigation interne
- Configuration persistante
- Global Text
- Private Text
- RL Note
- Grille tactique Imperator Averzian
- Détection et test encounter
- Système Void Marked avec note RL et messages privés
- Synchronisation addon entre joueurs

## Structure actuelle des boss

- `boss/imperator/`
- `boss/vorasius/`
- `boss/salhadaar/`
- `boss/drakes/`
- `boss/vanguard/`
- `boss/crown/`
- `boss/chimaerus/`
- `boss/beloren/`
- `boss/ura/`

## Pistes déjà préparées pour la suite

- Ajout de nouveaux boutons dans la section Imperator
- Nouvelles mécaniques boss-spécifiques
- Raffinement de l'algorithme d'assignation des heals
- Extension du système de private texts pour d'autres rôles
