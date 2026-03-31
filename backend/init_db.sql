-- ==============================================================
-- Corporate Connect — Script d'Initialisation de la Base de Données
-- SGBD : PostgreSQL 15+
-- ==============================================================

-- 1. Créer la base de données (à exécuter en tant que superuser)
-- CREATE DATABASE connect_db;
-- \c connect_db;

-- 2. Activer l'extension UUID
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ==============================================================
-- TABLE : profiles
-- Description : Utilisateurs de l'application
-- ==============================================================
CREATE TABLE IF NOT EXISTS profiles (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email           VARCHAR(255) UNIQUE,
    phone_number    VARCHAR(20) UNIQUE,
    hashed_password VARCHAR(255),
    full_name       VARCHAR(150) NOT NULL,
    username        VARCHAR(50) UNIQUE NOT NULL,
    avatar_url      VARCHAR(500),
    is_online       BOOLEAN DEFAULT FALSE,
    is_active       BOOLEAN DEFAULT TRUE,
    is_admin        BOOLEAN DEFAULT FALSE,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ
);

-- Index pour recherche rapide
CREATE INDEX IF NOT EXISTS idx_profiles_email ON profiles(email);
CREATE INDEX IF NOT EXISTS idx_profiles_phone ON profiles(phone_number);
CREATE INDEX IF NOT EXISTS idx_profiles_username ON profiles(username);
CREATE INDEX IF NOT EXISTS idx_profiles_fullname ON profiles(full_name);

-- ==============================================================
-- TABLE : rooms
-- Description : Salons de discussion (privé ou groupe)
-- ==============================================================
CREATE TABLE IF NOT EXISTS rooms (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name        VARCHAR(255),
    is_group    BOOLEAN DEFAULT FALSE,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ==============================================================
-- TABLE : room_members
-- Description : Association N:N entre profiles et rooms
-- ==============================================================
CREATE TABLE IF NOT EXISTS room_members (
    room_id     UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
    profile_id  UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    joined_at   TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (room_id, profile_id)
);

CREATE INDEX IF NOT EXISTS idx_room_members_room ON room_members(room_id);
CREATE INDEX IF NOT EXISTS idx_room_members_profile ON room_members(profile_id);

-- ==============================================================
-- TABLE : messages
-- Description : Messages envoyés dans les salons
-- Note : Le contenu texte est chiffré (AES/Fernet) côté applicatif
-- ==============================================================
CREATE TABLE IF NOT EXISTS messages (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    room_id         UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
    sender_id       UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    content         TEXT,
    message_type    VARCHAR(20) DEFAULT 'text',
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_messages_room ON messages(room_id);
CREATE INDEX IF NOT EXISTS idx_messages_sender ON messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_created ON messages(created_at);

-- ==============================================================
-- TABLE : statuses
-- Description : Stories éphémères (expiration automatique 24h)
-- ==============================================================
CREATE TABLE IF NOT EXISTS statuses (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    media_url   VARCHAR(500),
    text        VARCHAR(500),
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    expires_at  TIMESTAMPTZ NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_statuses_user ON statuses(user_id);
CREATE INDEX IF NOT EXISTS idx_statuses_expires ON statuses(expires_at);

-- ==============================================================
-- DONNÉES DE SEED : Administrateur par défaut
-- Mot de passe : "Admin@123" (hashé avec bcrypt)
-- ==============================================================
INSERT INTO profiles (id, email, full_name, username, hashed_password, is_admin, is_active)
VALUES (
    uuid_generate_v4(),
    'admin@corporate-connect.com',
    'Administrateur Système',
    'admin',
    '$2b$12$LJ3m4ys3Lk0vF6QKZ8xZxO5iGJGJ5vF6QrKZ8xZxO5iGJGJ5vF6Q', -- À remplacer par un vrai hash bcrypt
    TRUE,
    TRUE
) ON CONFLICT (email) DO NOTHING;

-- ==============================================================
-- VUE : Statuts actifs (non expirés)
-- ==============================================================
CREATE OR REPLACE VIEW active_statuses AS
SELECT s.*, p.full_name AS user_name, p.avatar_url AS user_avatar
FROM statuses s
JOIN profiles p ON s.user_id = p.id
WHERE s.expires_at > NOW()
ORDER BY s.created_at DESC;

-- ==============================================================
-- FONCTION : Nettoyage automatique des statuts expirés
-- ==============================================================
CREATE OR REPLACE FUNCTION cleanup_expired_statuses()
RETURNS void AS $$
BEGIN
    DELETE FROM statuses WHERE expires_at < NOW();
END;
$$ LANGUAGE plpgsql;

-- Optionnel: Planifier avec pg_cron (si extension installée)
-- SELECT cron.schedule('cleanup-statuses', '0 * * * *', 'SELECT cleanup_expired_statuses()');

COMMENT ON TABLE profiles IS 'Utilisateurs de l''application Corporate Connect';
COMMENT ON TABLE rooms IS 'Salons de discussion (privé 1-1 ou groupe)';
COMMENT ON TABLE room_members IS 'Table d''association N:N entre utilisateurs et salons';
COMMENT ON TABLE messages IS 'Messages échangés (le contenu texte est chiffré AES côté applicatif)';
COMMENT ON TABLE statuses IS 'Stories éphémères avec expiration automatique à 24h';
