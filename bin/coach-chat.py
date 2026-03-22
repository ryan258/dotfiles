#!/usr/bin/env python3
"""Coach chat - multi-turn conversation with persistent history file.

Single-turn invocations sharing a JSON history file, designed for
integration with the bash interactive coach loop.

Commands:
  init <history_file> <system_prompt_file> [<briefing_file>]
      Create a new conversation. Reads system prompt from file.
      Optionally seeds the first assistant message from briefing file.

  turn <history_file> <user_message>
      Append user message, call OpenRouter API, append and print
      the assistant response.

Environment:
  OPENROUTER_API_KEY          Required.
  AI_COACH_MODEL              Model ID (falls back to DHP_AI_COACH_MODEL).
  AI_COACH_CHAT_TEMPERATURE   Chat temperature (default: 0.4).
"""

import json
import os
import sys
import tempfile
import urllib.error
import urllib.request


def read_file(path):
    with open(path) as f:
        return f.read()


def init_history(history_file, system_prompt_file, briefing_file=None):
    system_prompt = read_file(system_prompt_file)
    messages = [{"role": "system", "content": system_prompt}]
    if briefing_file:
        briefing = read_file(briefing_file)
        if briefing.strip():
            messages.append({"role": "assistant", "content": briefing})
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(history_file))
    with os.fdopen(fd, "w") as f:
        json.dump(messages, f)
    os.replace(tmp, history_file)


def do_turn(history_file, user_message):
    api_key = os.environ.get("OPENROUTER_API_KEY", "")
    if not api_key:
        print("Error: OPENROUTER_API_KEY not set", file=sys.stderr)
        return 1

    model = (
        os.environ.get("AI_COACH_MODEL")
        or os.environ.get("DHP_AI_COACH_MODEL")
        or "nvidia/nemotron-3-nano-30b-a3b:free"
    )
    try:
        temperature = float(
            os.environ.get(
                "AI_COACH_CHAT_TEMPERATURE",
                os.environ.get("AI_BRIEFING_TEMPERATURE", "0.4"),
            )
        )
    except ValueError:
        temperature = 0.4

    with open(history_file) as f:
        messages = json.load(f)

    messages.append({"role": "user", "content": user_message})

    payload = json.dumps(
        {
            "model": model,
            "messages": messages,
            "temperature": temperature,
            "max_tokens": 500,
        }
    ).encode()

    req = urllib.request.Request(
        "https://openrouter.ai/api/v1/chat/completions",
        data=payload,
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
    )

    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            body = json.loads(resp.read())
    except (urllib.error.URLError, urllib.error.HTTPError) as exc:
        print(f"API request failed: {exc}", file=sys.stderr)
        return 1

    if "error" in body:
        err = body["error"]
        msg = err.get("message", str(err)) if isinstance(err, dict) else str(err)
        print(f"API error: {msg}", file=sys.stderr)
        return 1

    if not body.get("choices"):
        print("Error: empty response from API", file=sys.stderr)
        return 1

    content = body["choices"][0]["message"]["content"]
    messages.append({"role": "assistant", "content": content})

    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(history_file))
    with os.fdopen(fd, "w") as f:
        json.dump(messages, f)
    os.replace(tmp, history_file)

    print(content)
    return 0


def main():
    if len(sys.argv) < 3:
        print("Usage: coach-chat.py init|turn <args...>", file=sys.stderr)
        return 2

    cmd = sys.argv[1]

    if cmd == "init":
        if len(sys.argv) < 4:
            print(
                "Usage: coach-chat.py init <history> <system_prompt_file> [<briefing_file>]",
                file=sys.stderr,
            )
            return 2
        briefing = sys.argv[4] if len(sys.argv) > 4 else None
        init_history(sys.argv[2], sys.argv[3], briefing)
        return 0

    if cmd == "turn":
        if len(sys.argv) < 4:
            print(
                "Usage: coach-chat.py turn <history> <message>",
                file=sys.stderr,
            )
            return 2
        return do_turn(sys.argv[2], sys.argv[3])

    print(f"Unknown command: {cmd}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
