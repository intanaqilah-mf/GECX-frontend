from google.cloud import firestore
import google.api_core.exceptions

# Config from your screenshot
PROJECT_ID = "emvnzir-canada-song"
DATABASE_ID = "acn-bank-fs-db"

try:
    # Try connecting to the specific database your colleague setup
    db = firestore.Client(project=PROJECT_ID, database=DATABASE_ID)
    # Ping to check if it exists
    # list(db.collections(timeout=2)) # Remove the ping, it might be hanging if the DB is unreachable
except Exception:
    # Fallback to the default database if the named one doesn't exist
    print(f"Database {DATABASE_ID} not found, falling back to (default)")
    db = firestore.Client(project=PROJECT_ID)
