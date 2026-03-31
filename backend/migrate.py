from database import engine
from sqlalchemy import text

def run_migration():
    columns_to_add = [
        ('bio', 'TEXT'),
        ('job_title', 'VARCHAR'),
        ('fcm_token', 'VARCHAR')
    ]
    
    for col_name, col_type in columns_to_add:
        # On utilise une transaction séparée par colonne
        with engine.connect() as conn:
            try:
                # SQLAlchemy text(...) nécessite l'exécution via execute()
                conn.execute(text(f'ALTER TABLE profiles ADD COLUMN {col_name} {col_type};'))
                conn.commit()
                print(f"Colonne {col_name} ajoutée avec succès.")
            except Exception as e:
                # Si la colonne existe déjà, on ignore l'erreur
                if "already exists" in str(e).lower():
                    print(f"La colonne {col_name} existe déjà. Passage à la suivante.")
                else:
                    print(f"Erreur lors de l'ajout de {col_name}: {e}")

if __name__ == "__main__":
    run_migration()
