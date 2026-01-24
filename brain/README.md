# Brain

A centralized vector database for cross-project memory and AI agent collaboration.

## What is this?

The Brain is a ChromaDB-based vector store that runs as a local service. It provides:

- **Shared memory** across all your projects and AI agents
- **Chat log ingestion** from ChatGPT, Claude, and other exports
- **Semantic search** for finding relevant context from past work

## Quick Start

```bash
# 1. Start the Brain service
./start_brain.sh

# 2. Test the connection
python3 test_query.py

# 3. (Optional) Ingest chat history
python3 ingestion/ingest.py ~/Downloads/chatgpt_export.json --project myproject
```

## Project Structure

```
brain/
├── start_brain.sh      # Service launcher (ChromaDB on port 8000)
├── requirements.txt    # Python dependencies (chromadb)
├── lib/
│   └── memory.py       # Client library for agents
├── ingestion/
│   ├── ingest.py       # Chat log ingestion CLI
│   └── parser.py       # Format detection (ChatGPT, Claude)
├── test_data/          # Test fixtures
├── data/               # Vector storage (gitignored)
└── .venv/              # Python virtualenv (gitignored)
```

## Documentation

| Document | Purpose |
|----------|---------|
| [HANDBOOK.md](HANDBOOK.md) | Detailed usage guide, API reference, metadata taxonomy |
| [DEMOS.md](DEMOS.md) | Demo commands for ai-staff-hq workflows and Brain integration |

## Basic Usage

### From Python

```python
from brain.lib import memory

# Connect
client = memory.get_client()

# Store a memory
memory.add_memory(
    client,
    "Always use UTC timestamps in API responses",
    metadata={"source": "code_review", "type": "best_practice"}
)

# Recall memories
results = memory.recall(client, "timestamp best practices", n_results=5)
```

### From Shell

```bash
# Ingest ChatGPT export
python3 ingestion/ingest.py chatgpt_export.json

# Ingest Claude export with project tag
python3 ingestion/ingest.py conversations.json --project my-project

# Dry run (parse only, don't insert)
python3 ingestion/ingest.py export.json --dry-run
```

## Service Management

```bash
# Start (creates venv and installs deps on first run)
./start_brain.sh

# Check if running
lsof -i :8000

# View logs
tail -f brain.log

# Stop
pkill -f "chroma run"
```

## Requirements

- Python 3.10+ (3.12 preferred)
- ~100MB disk for the virtualenv
- Port 8000 available

## Configuration

| Item | Location | Notes |
|------|----------|-------|
| Vector data | `data/` | Persistent, gitignored |
| Logs | `brain.log` | Gitignored |
| Virtual env | `.venv/` | Auto-created, gitignored |
| Port | 8000 | Hardcoded in start_brain.sh |

## Supported Chat Formats

| Platform | Format | Auto-detected |
|----------|--------|---------------|
| ChatGPT | Data Export JSON | Yes |
| Claude | conversations.json | Yes |
| Gemini | (planned) | - |

## License

Part of the dotfiles repository. Personal use.
