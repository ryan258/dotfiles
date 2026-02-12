import sys
import os

# Add brain root to path to allow imports
current_dir = os.path.dirname(os.path.abspath(__file__))
# Note: We go up one level ("..") because test_query.py is in brain/ root.
# Other scripts like ingest.py in brain/ingestion/ go up two levels ("../..").
brain_root = os.path.abspath(os.path.join(current_dir, ".."))
if brain_root not in sys.path:
    sys.path.insert(0, brain_root)

from brain.lib import memory

def test_query():
    print("Connecting to Hive Mind...")
    client = memory.get_client()
    if not client:
        return

    print("Querying for 'python script'...")
    results = memory.recall(client, "how to run python", n_results=3)
    
    if results and results['documents']:
        print("\n--- Search Results ---")
        for i, doc in enumerate(results['documents'][0]):
            meta = results['metadatas'][0][i]
            print(f"\n[Source: {meta.get('source')}]")
            print(doc)
    else:
        print("No results found.")

if __name__ == "__main__":
    test_query()
