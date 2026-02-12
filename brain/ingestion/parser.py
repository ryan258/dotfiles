import json
import datetime
from typing import List, Dict, Any, Optional

class ChatParser:
    def __init__(self):
        pass

    def detect_format(self, data: Any) -> str:
        """Attempts to guess the format of the chat export."""
        if isinstance(data, list):
            if len(data) > 0 and 'mapping' in data[0] and 'create_time' in data[0]:
                return 'chatgpt'
            if len(data) > 0 and 'uuid' in data[0] and 'chat_messages' in data[0]:
                return 'claude'
        # Add more heuristics as needed
        return 'unknown'

    def parse_file(self, file_path: str, format_type: str = None) -> List[Dict]:
        """
        Parses a file and returns a list of standardized conversation objects.
        Standard format:
        {
            "id": "conv_id",
            "title": "Conversation Title",
            "created_at": "ISO8601",
            "messages": [
                {"role": "user|assistant", "content": "text", "timestamp": "ISO8601"}
            ],
            "source": "format_type"
        }
        """
        with open(file_path, 'r', encoding='utf-8') as f:
            data = json.load(f)

        if not format_type:
            format_type = self.detect_format(data)
            print(f"Detected format: {format_type}")

        if format_type == 'chatgpt':
            return self._parse_chatgpt(data)
        elif format_type == 'claude':
            return self._parse_claude(data)
        else:
            raise ValueError(f"Unsupported or unknown format: {format_type}")

    def _parse_chatgpt(self, data: List[Dict]) -> List[Dict]:
        conversations = []
        for conv in data:
            standard_conv = {
                "id": conv.get("id"),
                "title": conv.get("title", "Untitled"),
                "created_at": self._ts_to_iso(conv.get("create_time")),
                "messages": [],
                "source": "chatgpt"
            }

            mapping = conv.get("mapping", {})
            current_node_id = conv.get("current_node")
            
            if not current_node_id:
                print(f"Warning: Conversation {conv.get('id')} has no 'current_node'. Skipping.")
                conversations.append(standard_conv)
                continue
            
            # Standard export always has current_node.
            
            # Traverse backwards from current_node to root
            messages = []
            while current_node_id:
                node = mapping.get(current_node_id)
                if not node:
                    break
                
                message = node.get("message")
                if message:
                    role = message.get("author", {}).get("role")
                    if role in ("user", "assistant"):
                        content_obj = message.get("content", {})
                        if content_obj.get("content_type") == "text":
                            parts = content_obj.get("parts", [])
                            text = "".join([str(p) for p in parts])
                            ts = message.get("create_time")
                            if ts and text.strip():
                                messages.append({
                                    "role": role,
                                    "content": text,
                                    "timestamp": self._ts_to_iso(ts)
                                })
                
                current_node_id = node.get("parent")
            
            # Reverse to get chronological order
            standard_conv["messages"] = messages[::-1]
            conversations.append(standard_conv)
        return conversations

    def _parse_claude(self, data: List[Dict]) -> List[Dict]:
        conversations = []
        for conv in data:
            standard_conv = {
                "id": conv.get("uuid"),
                "title": conv.get("name", "Untitled"),
                "created_at": conv.get("created_at"),
                "messages": [],
                "source": "claude"
            }

            for msg in conv.get("chat_messages", []):
                sender = msg.get("sender")
                if sender == "human":
                    role = "user"
                elif sender == "assistant":
                    role = "assistant"
                else:
                    # Skip tools, system, etc.
                    continue
                
                ts = msg.get("created_at")
                content = msg.get("text", "")
                
                if not ts or not content.strip():
                    continue
                    
                standard_conv["messages"].append({
                    "role": role,
                    "content": content,
                    "timestamp": ts
                })
            
            # Sort by timestamp (ISO 8601 strings sort correctly lexicographically)
            standard_conv["messages"].sort(key=lambda x: x["timestamp"])
            conversations.append(standard_conv)
        return conversations

    def _ts_to_iso(self, ts: Optional[float]) -> str:
        if not ts:
            return ""
        # Ensure UTC
        return datetime.datetime.fromtimestamp(ts, tz=datetime.timezone.utc).isoformat()
