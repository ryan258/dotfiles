import argparse
import sys
import os

# Add brain root path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "../..")))

from brain.lib import memory

def recall_text(query, n_results, where):
    client = memory.get_client()
    if not client:
        print("Error: Could not connect to Hive Mind. Is start_brain.sh running?", file=sys.stderr)
        sys.exit(1)

    results = memory.recall(client, query, n_results=n_results, where=where or None)
    documents = results.get("documents", [[]])[0]
    metadatas = results.get("metadatas", [[]])[0]

    if not documents:
        print("No results found.")
        return

    for i, doc in enumerate(documents):
        meta = metadatas[i] if i < len(metadatas) else {}
        print(f"Result {i + 1}")
        print(f"Title: {meta.get('conversation_title', '(untitled)')}")
        print(f"Project: {meta.get('project_context', '')}")
        print(f"Type: {meta.get('type', '')}")
        print(f"Tags: {meta.get('tags', '')}")
        print(f"Source: {meta.get('source', '')}")
        print(f"Timestamp: {meta.get('timestamp', '')}")
        print("-" * 60)
        print(doc)
        print("\n" + "=" * 60 + "\n")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Query the Brain.")
    parser.add_argument("query", nargs="?", help="Search query (or stdin)")
    parser.add_argument("--n", type=int, default=5, help="Number of results")
    parser.add_argument("--project", help="Filter by project_context")
    parser.add_argument("--type", dest="memory_type", help="Filter by type")
    parser.add_argument("--source", help="Filter by source")

    args = parser.parse_args()

    query = args.query
    if not query and not sys.stdin.isatty():
        query = sys.stdin.read().strip()

    if not query:
        print("Error: No query provided", file=sys.stderr)
        sys.exit(1)

    where = {}
    if args.project:
        where["project_context"] = args.project
    if args.memory_type:
        where["type"] = args.memory_type
    if args.source:
        where["source"] = args.source

    recall_text(query, args.n, where)
