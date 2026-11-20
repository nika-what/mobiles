#!/usr/bin/env python
"""Standalone script to migrate the database"""
import sys
import os
from pathlib import Path

# Add parent directory to path to allow imports  
backend_dir = Path(__file__).parent
project_root = backend_dir.parent
sys.path.insert(0, str(project_root))

# Change to backend directory
os.chdir(backend_dir)

from backend.database import migrate_database, DB_FILE

if __name__ == "__main__":
    print(f"Migrating database at: {DB_FILE}")
    migrate_database()
    print("Migration completed!")

