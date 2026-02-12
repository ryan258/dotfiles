# 🧠 The Brain Handbook (Hive Mind)

> "A central intelligence for a distributed agent workforce."

## Overview

**The Brain** is a centralized Vector Database (ChromaDB) hosted within your generic `dotfiles` hub. It serves as a shared long-term memory for all your disparate projects and AI agents.

Instead of each project having a siloed `.chroma` folder that no one else can see, agents connect to The Brain to:

1.  **Store** discoveries (code patterns, successful prompts).
2.  **Recall** solutions from other projects (cross-pollination).
3.  **Search** your historical chat logs (ChatGPT, Claude, Gemini exports).

---

## 🚀 Quick Start

### 1. Start the Service

The Brain runs as a lightweight background process (no Docker required). It uses its own Python 3.12 virtual environment.

```bash
~/dotfiles/brain/start_brain.sh
```

- **Port**: 8000
- **Logs**: `~/dotfiles/brain/brain.log`
- **Data**: `~/dotfiles/brain/data/` (Gitignored)

### 2. Check Layout

```text
~/dotfiles/brain/
├── data/                 # Persistent vector storage
├── ingestion/            # Tools to import Chat logs
├── lib/                  # Python client library
├── start_brain.sh        # Service launcher
└── requirements.txt      # Dependencies
```

---

## 👩‍💻 Usage for Agents

To give an agent access to The Brain, import the `memory` library.

### Connection

```python
# Ensure root is in PYTHONPATH or install as package
from brain.lib import memory

client = memory.get_client()
if not client:
    print("Brain is offline. Run start_brain.sh")
```

### Remembering (Write)

Agents should tag memories so they can be retrieved contextually.

```python
memory.add_memory(
    client=client,
    content="Use 'logger.exception' inside except blocks to capture stack traces automatically.",
    metadata={
        "source": "project_alpha",
        "type": "coding_standard",
        "language": "python",
        "project_context": "backend_api"
    }
)
```

### Recalling (Read)

Agents can search globally or filter by specific projects.

```python
# Search EVERYTHING (Cross-pollination)
# Use the brain's virtualenv to ensure dependencies are found:
# ~/dotfiles/brain/.venv/bin/python3 path/to/script.py

results = memory.recall(client, "how to log errors in python")

# Search ONLY this project (Private memory)
results = memory.recall(
    client,
    "deploy config",
    where={"source": "project_alpha"}
)
```

---

## 📥 Ingesting Chat Logs

You can feed The Brain your entire history of conversations with ChatGPT, Claude, and Gemini.

### Usage

```bash
# General ingestion
python3 ingestion/ingest.py path/to/chat_export.json

# Tagging with specific implementation context
python3 ingestion/ingest.py path/to/export.json --project "ai-staff-hq"
```

### Supported Formats

The `parser.py` automatically detects:

- **ChatGPT**: Standard Data Export JSON
- **Claude**: `conversations.json` from User Data Export
- **Gemini**: (In Progress)

---

## 🏷 Metadata Taxonomy

To keep the Hive Mind organized, use these standard metadata keys:

| Key               | Description            | Examples                                        |
| :---------------- | :--------------------- | :---------------------------------------------- |
| `source`          | Origin of the memory   | `project_alpha`, `chat_export_claude`           |
| `type`            | Nature of the info     | `concept`, `solution`, `error_log`, `chat_pair` |
| `project_context` | Broad category         | `dotfiles`, `work`, `personal`                  |
| `timestamp`       | ISO8601 time           | `2023-10-27T10:00:00`                           |
| `tags`            | Comma-separated topics | `python, logging, debugging`                    |

---

## 🛠 Troubleshooting

**"Connection Refused"**

- Is the service running? Check `ps aux | grep chroma`
- Check logs: `tail -f ~/dotfiles/brain/brain.log`
- Did the port 8000 conflict? Change `PORT` in `start_brain.sh`.

**"Python Version Error"**

- The Brain requires Python 3.10-3.13.
- `start_brain.sh` attempts to find `python3.12` (via Homebrew) automatically.
