# 🗓️ Plan de Projet "Commando" : Corporate Connect (14 Jours)

Ce document est votre feuille de route quotidienne. Chaque tâche doit être cochée pour passer à la suivante.

---

## 🏗️ SEMAINE 1 : LE CŒUR DU SYSTÈME

### Jour 1 : Fondation & Infrastructure
- [ ] Initialiser le projet **Flutter** (`flutter create`).
- [ ] Setup du serveur **FastAPI** (Structure de base).
- [ ] Créer la base de données **PostgreSQL**.
- [ ] Configurer Docker pour le déploiement local.

### Jour 2 : Authentification Hybride (Backend & Mobile)
- [ ] Backend : Endpoints `/auth/login` (Email/Pass) et `/auth/otp` (Phone).
- [ ] Backend : Génération et validation des tokens **JWT**.
- [ ] Mobile : Écran de connexion (Email + Téléphone).
- [ ] Mobile : Gestion de la session utilisateur (Stockage sécurisé).

### Jour 3 : Real-time Backend (WebSockets)
- [ ] Backend : Implémenter le `WebSocketManager` (FastAPI).
- [ ] Backend : Logique de routage des messages (Expéditeur -> Serveur -> Destinataire).
- [ ] Database : Migrations pour les tables `Messages` et `Rooms`.

### Jour 4 : Real-time Frontend (Flutter Integration)
- [ ] Mobile : Service WebSocket (Connexion/Déconnexion automatique).
- [ ] Mobile : Provider de messagerie (Gestion des messages reçus).
- [ ] UI : Écran de chat basique (Bulles de texte).

### Jour 5 : Gestion des Profils & Annuaire
- [ ] Backend : Endpoints pour mettre à jour le profil (Photo, Nom).
- [ ] Backend : Recherche d'utilisateurs par nom ou service.
- [ ] UI : Écran de profil utilisateur.
- [ ] UI : Liste des contacts de l'entreprise.

### Jour 6 : Groupes de Discussion & Salons
- [ ] Backend : Logique de création de groupes (Rooms multi-utilisateurs).
- [ ] Backend : Ajouter/Supprimer des membres à une Room.
- [ ] UI : Création de nouveaux groupes et gestion des participants.

### Jour 7 : Revue & Optimisation
- [ ] Test de montée en charge des WebSockets.
- [ ] Correction des bugs critiques de la semaine 1.
- [ ] Nettoyage du code (Clean Code Refactoring).

---

## 🎨 SEMAINE 2 : MÉDIAS, APPELS & POLISSAGE

### Jour 8 : Médias & Partage (Photos/Vidéos)
- [ ] Backend : Intégration du stockage Cloud (S3/Supabase Storage).
- [ ] Backend : Redimensionnement automatique des images (Thumbnails).
- [ ] UI : Support des images dans la fenêtre de chat.

### Jour 9 : Documents & Fichiers Professionnels
- [ ] Backend : Sécurisation du téléchargement des fichiers (Vérification JWT).
- [ ] UI : Partage de PDF, Excel, Word (Icônes spécifiques).
- [ ] UI : Visualiseur intégré de documents simples.

### Jour 10 : Appels Audio & Vidéo (WebRTC)
- [ ] Backend : Serveur de signalisation WebRTC (FastAPI).
- [ ] UI : Écran d'appel entrant et sortant.
- [ ] UI : Gestion des permissions Micro/Caméra.

### Jour 11 : Statuts & Stories Interne
- [ ] Backend : API pour publier et expirer les "Stories" (24h).
- [ ] UI : Cercle des statuts en haut de la liste des chats.
- [ ] UI : Lecteur de stories interactif.

### Jour 12 : Recherche Globale & Chiffrement
- [ ] Backend : Moteur de recherche plein texte (Postgres).
- [ ] Sécurité : Chiffrement des données sensibles en base de données.
- [ ] Cryptage des fichiers stockés.

### Jour 13 : Panneau Admin & QA Final
- [ ] Web Admin (Simple) : Statistiques d'usage, bannissement, gestion des groupes.
- [ ] QA : Tests complets de régression (Tous les modules).

### Jour 14 : Livraison & Déploiement
- [ ] Génération des fichiers APK/IPA finaux.
- [ ] Déploiement du Backend en production (VPS/AWS).
- [ ] Formation express et remise des accès.

---

**Monsieur le Chef de Projet, nous sommes prêts.**
