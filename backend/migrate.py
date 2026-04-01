from database import engine
from sqlalchemy import text

def run_migration():
    """
    Migration complete : ajoute TOUTES les colonnes manquantes
    entre les modeles SQLAlchemy et la base de donnees PostgreSQL.
    """

    migrations = [
        # Table: profiles
        ('profiles', 'bio', 'TEXT'),
        ('profiles', 'job_title', 'VARCHAR'),
        ('profiles', 'fcm_token', 'VARCHAR'),
        ('profiles', 'public_key', 'VARCHAR'),
        ('profiles', 'is_active', 'BOOLEAN DEFAULT TRUE'),
        ('profiles', 'is_admin', 'BOOLEAN DEFAULT FALSE'),

        # Table: room_members
        ('room_members', 'is_admin_member', 'BOOLEAN DEFAULT FALSE'),

        # Table: messages
        ('messages', 'message_type', "VARCHAR DEFAULT 'text'"),
        ('messages', 'reply_to_id', 'UUID'),
        ('messages', 'is_read', 'BOOLEAN DEFAULT FALSE'),
        ('messages', 'read_at', 'TIMESTAMPTZ'),
    ]

    for table, col_name, col_type in migrations:
        with engine.connect() as conn:
            try:
                conn.execute(text(
                    f'ALTER TABLE {table} ADD COLUMN {col_name} {col_type};'
                ))
                conn.commit()
                print(f"  [OK] {table}.{col_name} ajoutee.")
            except Exception as e:
                conn.rollback()
                if "already exists" in str(e).lower():
                    print(f"  [SKIP] {table}.{col_name} existe deja.")
                else:
                    print(f"  [ERR] {table}.{col_name}: {e}")

    print("\nMigration terminee !")

if __name__ == "__main__":
    run_migration()
