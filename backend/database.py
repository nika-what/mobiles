import os
from pathlib import Path
from sqlalchemy import create_engine, inspect, text
from sqlalchemy.orm import sessionmaker, DeclarativeBase

# SQLite file - check root project directory first, then backend folder
if os.environ.get("RECIPES_DB_PATH"):
    DB_FILE = os.environ.get("RECIPES_DB_PATH")
else:
    # Try root project directory first
    root_db = Path(__file__).parent.parent / "recipes.db"
    backend_db = Path(__file__).parent / "recipes.db"
    if root_db.exists():
        DB_FILE = str(root_db)
    elif backend_db.exists():
        DB_FILE = str(backend_db)
    else:
        # Default to root project directory
        DB_FILE = str(root_db)

DATABASE_URL = f"sqlite:///{DB_FILE}"

# check_same_thread=False is required for SQLite with multiple threads in FastAPI
engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False})
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


class Base(DeclarativeBase):
    pass


def migrate_database():
    """Add missing columns to existing tables if they don't exist"""
    try:
        inspector = inspect(engine)
        print(f"Database file: {DB_FILE}")
        
        # Check if recipes table exists
        if 'recipes' in inspector.get_table_names():
            existing_columns = [col['name'] for col in inspector.get_columns('recipes')]
            print(f"Existing columns in recipes table: {existing_columns}")
            
            # Add cook_time_minutes if missing
            if 'cook_time_minutes' not in existing_columns:
                with engine.begin() as conn:
                    conn.execute(text("ALTER TABLE recipes ADD COLUMN cook_time_minutes INTEGER"))
                    print("✓ Added column: cook_time_minutes")
            else:
                print("✓ Column cook_time_minutes already exists")
            
            # Add servings if missing
            if 'servings' not in existing_columns:
                with engine.begin() as conn:
                    conn.execute(text("ALTER TABLE recipes ADD COLUMN servings INTEGER"))
                    print("✓ Added column: servings")
            else:
                print("✓ Column servings already exists")
        else:
            print("Recipes table does not exist yet, will be created by create_all()")
        
        # Check if users table exists
        if 'users' in inspector.get_table_names():
            existing_columns = [col['name'] for col in inspector.get_columns('users')]
            print(f"Existing columns in users table: {existing_columns}")
            
            # Add email if missing
            if 'email' not in existing_columns:
                try:
                    with engine.begin() as conn:
                        conn.execute(text("ALTER TABLE users ADD COLUMN email VARCHAR(100)"))
                        print("✓ Added column: email")
                    # Refresh inspector to get updated column list
                    inspector = inspect(engine)
                except Exception as e:
                    print(f"Warning: Could not add email column: {e}")
                    import traceback
                    traceback.print_exc()
            else:
                print("✓ Column email already exists")
            
            # Re-check columns after potential email addition
            existing_columns = [col['name'] for col in inspector.get_columns('users')]
            
            # Add password_hash if missing
            if 'password_hash' not in existing_columns:
                try:
                    with engine.begin() as conn:
                        conn.execute(text("ALTER TABLE users ADD COLUMN password_hash VARCHAR(255)"))
                        print("✓ Added column: password_hash")
                except Exception as e:
                    print(f"Warning: Could not add password_hash column: {e}")
                    import traceback
                    traceback.print_exc()
            else:
                print("✓ Column password_hash already exists")
        else:
            print("Users table does not exist yet, will be created by create_all()")
    except Exception as e:
        print(f"Migration error: {e}")
        import traceback
        traceback.print_exc()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


