import argparse
import sys
import os

# Add brain root to path to allow imports
current_dir = os.path.dirname(os.path.abspath(__file__))
brain_root = os.path.abspath(os.path.join(current_dir, "../.."))
if brain_root not in sys.path:
    sys.path.insert(0, brain_root)

from brain.ingestion.parser import ChatParser
from brain.lib import memory

def ingest_file(file_path, project="generic", dry_run=False):
    print(f"Reading {file_path}...")
    parser = ChatParser()
    try:
        conversations = parser.parse_file(file_path)
    except Exception as e:
        print(f"Failed to parse file: {e}")
        return

    print(f"Found {len(conversations)} conversations. Connecting to Brain...")
    
    client = None
    if not dry_run:
        client = memory.get_client()
        if not client:
            print("Could not connect to Hive Mind. Aborting.")
            return

    total_memories = 0
    for conv in conversations:
        title = conv['title']
        conv_id = conv['id']
        source = conv['source']
        
        msgs = conv['messages']
        # Simple pairing strategy: User -> Assistant
        for i in range(len(msgs) - 1):
            if msgs[i]['role'] == 'user' and msgs[i+1]['role'] == 'assistant':
                q = msgs[i]['content']
                a = msgs[i+1]['content']
                
                if len(q.strip()) < 5 or len(a.strip()) < 5:
                    continue
                
                # Content format: The "Memory" is the Q&A pair.
                content = f"Context: {title}\nUser: {q}\nAssistant: {a}"
                
                metadata = {
                    "source": f"chat_export_{source}",
                    "project_context": project,
                    "conversation_id": conv_id,
                    "conversation_title": title,
                    "timestamp": msgs[i]['timestamp'],
                    "type": "chat_pair"
                }
                
                if not dry_run:
                    memory.add_memory(client, content, metadata)
                total_memories += 1
                
    print(f"Successfully ingested {total_memories} memory pairs from {len(conversations)} conversations.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Ingest chat logs into the Hive Mind.")
    parser.add_argument("file", help="Path to JSON chat export")
    parser.add_argument("--project", default="generic", help="Project context tag")
    parser.add_argument("--dry-run", action="store_true", help="Parse but do not insert")
    
    args = parser.parse_args()
    ingest_file(args.file, args.project, args.dry_run)
