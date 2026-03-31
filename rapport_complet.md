# Rapport Exécutif d'Avancement - Projet Corporate Connect

*Dernière mise à jour : Mars 2026*

Ce document constitue le rapport détaillé sur l'état actuel de l'application **Corporate Connect**, résumant l'architecture logicielle, les stacks technologiques utilisés, la gestion d'état centralisée et les fonctionnalités critiques déployées lors des dernières phases de modernisation.

---

## 1. Architecture Globale et Technologies

L'application **Corporate Connect** est pensée comme une plateforme de communication d'entreprise robuste, sécurisée par E2EE (Chiffrement de Bout en Bout) et performante même en zone de faible connectivité.

### Frontend (Flutter)
- **Framework** : Flutter (Dart) respectant les standards Material Design 3.
- **State Management** : Migration complète vers **Riverpod 3.x** (`NotifierProvider`, `AsyncNotifierProvider`) pour une isolation parfaite de la logique métier et de l'interface utilisateur.
- **Base de données Hors-ligne** : Intégration de **SQLite** (`sqflite`) pour mettre en cache l'historique complet, permettant un affichage "zéro latence".
- **Communication & Appels** : 
  - `web_socket_channel` pour le chat en temps réel.
  - `agora_rtc_engine` pour maintenir des sessions WebRTC voix et vidéo.
- **Média et Partage** : Upload de fichiers et manipulation grâce à `image_picker`, `file_picker` et l'ouverture native via `url_launcher`.
- **Sécurité** : Module `cryptography` avec le standard X25519 asymétrique pour garantir la stricte confidentialité des échanges textuels (1:1).

### Backend Connecté
L'API en Python (via Ngrok) gère la persistance cloud, le routage temps réel via WebSocket, l'authentification JWT, et l'enregistrement des jetons de notification Push Firebase (FCM).

---

## 2. Fonctionnalités Déployées

Les récentes implémentations propulsent Corporate Connect au rang de véritable outil professionnel :

### A. Communication et Confidentialité (E2EE)
- **Chiffrement de Bout en Bout** : Maintien et refonte de l'interface Profil affichant visuellement le statut de la clé privée locale et l'option de régénération de la clé E2EE.
- **Stockage Indépendant** : Les messages chiffrés sont stockés dans SQLite (`chat_cache.db`), garantissant la rémanence des conversations hors-ligne et la vitesse de navigation (No-Lag).

### B. Outils de Partage (Médias et Fichiers)
- **Interface Premium de Pièces Jointes** : Menu modernisé pour l'upload depuis la Galerie, l'appareil photo, l'envoi de PDF/Documents avec indicateur de progression fluide.
- **Lecteur Audio Sophistiqué** : Les notes vocales ont une interface dédiée avec chronomètre et suivi de position en temps réel de lecture.
- **Ouverture native** : Les clics sur les URL ou les documents ouvrent l'application système idéale (ex. lecteur PDF natif) pour préserver l'ergonomie mobile.

### C. Profil du Salon et Exploration (Data Listing)
- Un tout nouvel écran de **Détails de Conversation** a vu le jour, abandonnant les simples menus déroulants pour une vue structurée par onglets :
  - **Membres** : Visualisation claire des participants et des rôles d'administration.
  - **Médias** : Galerie de photos complète de la conversation.
  - **Documents** : Liste chronologique des fichiers échangés, parés de leurs icônes de formats et tailles, prêts à être ouverts.
  - **Vocaux** : L'historique des notes vocales archivées.
- *Force Numérique* : Cet écran est propulsé par des requêtes filtrées SQLite. Son chargement est instinctif et ne requiert pas de connexion.

### D. Appels WebRTC Fiabilisés
- Toutes les opérations logiques liées au SDK Agora (Instanciation de l'Engine, Demande de permissions Caméra/Micro, Rejoindre le canal) ont été externalisées dans le composant `CallNotifier` de Riverpod. Ceci a corrigé les potentielles déconnexions dues aux cycles de vie rudimentaires de `StatefulWidget`.

### E. Paramètres et Personnalisation
Un centre de contrôle permet aux utilisateurs d'adapter Corporate Connect :
- **Thème Visuel** : Capacité à forcer le Mode Clair ou Sombre. L'interface réagit en temps réel à ce basculement.
- **Gestion du Cache** : Un moniteur surveille le poids exact de la base de données SQL et offre l'opportunité de *vider le cache* en cas de besoin d'espace disque.
- **Bascules Push** : Un commutateur conserve l'opt-in de réception des alertes notifications.

---

## 3. Qualité et Pistes d'Améliorations (Roadmap)

La base du code (Clean Architecture) est maintenant résolument saine et testable.
Néanmoins, pour passer de la phase Beta à la "Release", quelques jalons de sécurité restent recommandés :

1. **Sécurisation des Clés (Keystore System)** : Remplacer l'actuel package `shared_preferences` par `flutter_secure_storage` afin de placer la clé d'encryption `E2EE` (`X25519`) dans le coffre-fort cryptographique matériel d'Android/iOS.
2. **E2EE Étendu aux Pièces Jointes** : Implémenter le chiffrement symétrique (AES) à la volée avant upload des médias, et partager cette clé AES protégée via le canal X25519 existant pour assurer la totale non-ingérence du serveur.
3. **Appels en Background** : S'appuyer sur la centralisation permise par Riverpod pour basculer Agora en Floating/Picture-in-picture.

---
*Fin du rapport.* 
`Généré automatiquement suite au cycle d'intégration en Phase 3.`
