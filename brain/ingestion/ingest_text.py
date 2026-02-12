import argparse
import sys
import os
import datetime

# Add brain root path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "../..")))

from brain.lib import memory

def ingest_text(content, title, tags, project, memory_type):
    client = memory.get_client()
    if not client:
        print("Error: Could not connect to Hive Mind. Is start_brain.sh running?", file=sys.stderr)
        sys.exit(1)

    metadata = {
        "source": "cli_ingest",
        "project_context": project,
        "type": memory_type,
        "tags": tags,
        "conversation_title": title,
        "timestamp": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    }
    
    try:
        memory.add_memory(client, content, metadata)
        print(f"✓ Saved to Brain: '{title}' ({project})")
    except Exception as e:
        print(f"Error saving to brain: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Ingest text into the Brain.")
    parser.add_argument("content", nargs="?", help="Content to ingest (or stdin)")
    parser.add_argument("--title", required=True, help="Title of the memory")
    parser.add_argument("--tags", default="", help="Comma separated tags")
    parser.add_argument("--project", default="generic", help="Project context")
    parser.add_argument("--type", default="artifact", dest="memory_type", help="Type of memory")

    args = parser.parse_args()

    content = args.content
    if not content:
        # Read from stdin
        if not sys.stdin.isatty():
            content = sys.stdin.read()
    
    if not content or not content.strip():
        print("Error: No content provided", file=sys.stderr)
        sys.exit(1)

    ingest_text(content, args.title, args.tags, args.project, args.memory_type)
