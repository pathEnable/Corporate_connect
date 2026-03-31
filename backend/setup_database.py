"""
Script de mise en place de la base de données Corporate Connect.
Exécutez ce script pour créer toutes les tables et l'admin par défaut.

Usage:
    python setup_database.py
"""
from database import engine, Base, SessionLocal
from models import Profile, Room, RoomMember, Message, Status
from passlib.context import CryptContext

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def create_tables():
    """Créer toutes les tables définies dans les modèles."""
    print("🔧 Création des tables...")
    Base.metadata.create_all(bind=engine)
    print("✅ Tables créées avec succès !")
    
    # Lister les tables créées
    from sqlalchemy import inspect
    inspector = inspect(engine)
    tables = inspector.get_table_names()
    print(f"\n📋 Tables dans la base de données :")
    for table in tables:
        columns = inspector.get_columns(table)
        print(f"  📁 {table} ({len(columns)} colonnes)")
        for col in columns:
            nullable = "NULL" if col['nullable'] else "NOT NULL"
            print(f"      ├─ {col['name']} : {col['type']} {nullable}")


def create_admin():
    """Créer l'administrateur par défaut s'il n'existe pas."""
    db = SessionLocal()
    try:
        existing = db.query(Profile).filter(Profile.email == "admin@corporate-connect.com").first()
        if existing:
            print("\n⚠️  L'administrateur existe déjà.")
            return
        
        admin = Profile(
            email="admin@corporate-connect.com",
            full_name="Administrateur Système",
            username="admin",
            hashed_password=pwd_context.hash("Admin@123"),
            is_admin=True,
            is_active=True,
        )
        db.add(admin)
        db.commit()
        print("\n✅ Administrateur créé !")
        print("   📧 Email : admin@corporate-connect.com")
        print("   🔑 Mot de passe : Admin@123")
        print("   ⚠️  CHANGEZ CE MOT DE PASSE EN PRODUCTION !")
    finally:
        db.close()


def verify_connection():
    """Vérifier la connexion à la base de données."""
    from config import DATABASE_URL
    print(f"🔌 Connexion à : {DATABASE_URL.split('@')[-1] if '@' in DATABASE_URL else DATABASE_URL}")
    try:
        with engine.connect() as conn:
            conn.execute("SELECT 1" if hasattr(conn, 'execute') else None)
        print("✅ Connexion réussie !")
        return True
    except Exception as e:
        print(f"❌ Erreur de connexion : {e}")
        print("\n💡 Assurez-vous que :")
        print("   1. PostgreSQL est installé et démarré")
        print("   2. La base 'connect_db' existe")
        print("   3. Les identifiants dans config.py sont corrects")
        print("\n   Commandes pour créer la base :")
        print("   $ psql -U postgres")
        print("   postgres=# CREATE DATABASE connect_db;")
        print("   postgres=# CREATE USER user WITH PASSWORD 'password';")
        print("   postgres=# GRANT ALL PRIVILEGES ON DATABASE connect_db TO user;")
        return False


if __name__ == "__main__":
    print("=" * 55)
    print("  Corporate Connect — Setup Base de Données")
    print("=" * 55)
    print()
    
    if verify_connection():
        create_tables()
        create_admin()
        print("\n" + "=" * 55)
        print("  ✅ Base de données prête !")
        print("=" * 55)
    else:
        print("\n❌ Impossible de continuer sans connexion à la base.")
