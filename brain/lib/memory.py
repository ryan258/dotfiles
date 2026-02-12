import chromadb
import os
import uuid

# Configuration - derive path relative to this module
BRAIN_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_COLLECTION = "hive_mind"
HOST = "localhost"
PORT = 8000

def get_client():
    """Returns a HttpClient connected to the Hive Mind server."""
    try:
        client = chromadb.HttpClient(host=HOST, port=PORT)
        # Fast heartbeat check
        client.heartbeat()
        return client
    except Exception as e:
        # ChromaDB HTTP client can raise various exceptions (httpx, requests, etc.)
        # so we catch broadly but check for connection-related keywords if not obvious
        err_str = str(e).lower()
        if isinstance(e, (ConnectionError, OSError)) or "connection" in err_str or "refused" in err_str:
            print(f"Error connecting to Hive Mind at {HOST}:{PORT}. Is start_brain.sh running?")
            print(f"Details: {e}")
            return None
        # If it's something else, re-raise
        raise

def add_memory(client, content, metadata=None, collection_name=DEFAULT_COLLECTION):
    """
    Adds a memory to the brain.

    Args:
        client: The ChromaDB client
        content: String or list of strings
        metadata: Dict or list of dicts. If a single dict is provided with a list
                  of content, it will be replicated for each document.
        collection_name: Target collection
    """
    if metadata is None:
        metadata = {}

    collection = client.get_or_create_collection(name=collection_name)

    # Normalize to lists
    if isinstance(content, str):
        content = [content]
        metadata = [metadata]
    elif isinstance(metadata, dict):
        # Replicate single metadata dict for each document
        metadata = [metadata.copy() for _ in content]

    # Generate UUIDs
    ids = [str(uuid.uuid4()) for _ in content]

    collection.add(
        documents=content,
        metadatas=metadata,
        ids=ids
    )
    return ids

def recall(client, query, n_results=5, where=None, where_document=None, collection_name=DEFAULT_COLLECTION):
    """
    Retrieves memories from the brain.
    
    Args:
        client: The ChromaDB client
        query: Search string
        n_results: Max results
        where: Metadata filter (e.g. {"source": "project_alpha"})
        
    Returns:
        Query results dictionary
    """
    collection = client.get_or_create_collection(name=collection_name)
    results = collection.query(
        query_texts=[query],
        n_results=n_results,
        where=where,
        where_document=where_document
    )
    return results

if __name__ == "__main__":
    # Simple test
    print("Testing connection...")
    c = get_client()
    if c:
        print(f"Connected! Heartbeat: {c.heartbeat()}")
        print("Collections:", c.list_collections())
    else:
        print("Connection failed.")
