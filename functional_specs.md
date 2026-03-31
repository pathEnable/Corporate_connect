# Spécifications Fonctionnelles : Corporate Connect

**Date** : 2026-03-23  
**Statut** : Brouillon pour revue  
**Rôle** : Clone de WhatsApp interne (Entreprise)

---

## 1. Objectifs du Projet
L'objectif est de fournir un outil de communication instantanée sécurisé, fluide et professionnel, permettant aux employés de collaborer sans utiliser leurs outils personnels.

## 2. Rôles Utilisateurs
- **Collaborateur** : Peut discuter (1:1 et Groupes), partager des documents, et gérer son profil.
- **Administrateur** : Peut gérer les utilisateurs, créer des groupes officiels, et consulter les logs de sécurité (via interface dédiée).

## 3. Parcours Utilisateur & User Stories

### B. Messagerie (Temps Réel) - V1 (2 Semaines)
- **US 3** : Messages texte instantanés.
- **US 4** : Groupes de discussion et salons.
- **US 5** : Indicateurs de lecture ("Vu").

### C. Multimédia & Appels - V1 (2 Semaines)
- **US 6** : Partage de documents, PDF, Images.
- **US 7** : Appels Audio et Vidéo simples.
- **US 8** : Statuts / Stories pour les employés.

## 4. Règles Métiers & Contraintes
- **Confidentialité** : Les messages et fichiers sont stockés sur les serveurs de l'entreprise (ou cloud privé).
- **RGPD** : Le numéro de téléphone personnel est optionnel et protégé.
- **Disponibilité** : L'application doit être fonctionnelle sur Android et iOS.

## 5. Flux de Navigation (Workflow)
1. **Écran de Bienvenue** -> Choix de la méthode de connexion.
2. **Écran Principal** -> Liste des chats (Bulle flottante pour nouveau chat).
3. **Fenêtre de Chat** -> Historique des messages, barre d'action (Jointe, Micro, Texte).
4. **Profil** -> Nom, Bio pro, Photo, Paramètres.
