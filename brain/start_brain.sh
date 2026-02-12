#!/usr/bin/env bash
# dotfiles/brain/start_brain.sh
# Starts the ChromaDB server in the background
set -euo pipefail

BRAIN_DIR="$(cd "$(dirname "$0")" && pwd)"
DATA_DIR="$BRAIN_DIR/data"
VENV_DIR="$BRAIN_DIR/.venv"
PORT=8000
LOG_FILE="$BRAIN_DIR/brain.log"

# Ensure directories exist
mkdir -p "$DATA_DIR"

# Check/Create Virtualenv
if [ ! -d "$VENV_DIR" ]; then
    echo "Creating virtualenv for Brain..."
    
    # Try to find python3.12 (brew install python@3.12)
    if command -v python3.12 &> /dev/null; then
        PYTHON_EXEC="python3.12"
    else
        echo "WARNING: python3.12 not found, falling back to python3"
        PYTHON_EXEC="python3"
    fi
    
    $PYTHON_EXEC -m venv "$VENV_DIR"
fi

# Always ensure dependencies are installed
source "$VENV_DIR/bin/activate"
pip install -q -r "$BRAIN_DIR/requirements.txt"

# Check if port is in use (handle missing lsof gracefully)
if command -v lsof &> /dev/null; then
    if lsof -i :"$PORT" &> /dev/null; then
        echo "Port $PORT is already in use. Chroma or another service might be running."
        exit 0
    fi
elif command -v nc &> /dev/null; then
    if nc -z localhost "$PORT" 2>/dev/null; then
        echo "Port $PORT is already in use. Chroma or another service might be running."
        exit 0
    fi
fi

echo "Starting ChromaDB on port $PORT..."
# Run in background with nohup, logging to brain.log
nohup chroma run --path "$DATA_DIR" --port "$PORT" > "$LOG_FILE" 2>&1 &
PID=$!
echo "Brain started with PID $PID. Logs at $LOG_FILE"
