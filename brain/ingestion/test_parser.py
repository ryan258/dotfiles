import unittest
import sys
import os


# Add brain root path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "../..")))

from brain.ingestion.parser import ChatParser

class TestParser(unittest.TestCase):
    def test_chatgpt_linearization(self):
        """Ensure we only get the active branch, avoiding interleaving."""
        parser = ChatParser()
        test_file = os.path.join(os.path.dirname(__file__), "../test_data/branching_chatgpt.json")
        conversations = parser.parse_file(test_file, "chatgpt")
        conv = conversations[0]
        
        # We expect: Root -> Branch B -> Follow up on B
        # "Branch A" (timestamp 101) should NOT be present if we validly follow the tree,
        # OR if we just fix the flattening issue, we at least expect coherent ordering.
        # But flattening produces [Root, Branch A, Branch B, Follow up] sorted by time.
        # Ideally we want the linear path.
        
        msgs = conv["messages"]
        content = [m["content"] for m in msgs]
        print("ChatGPT Content:", content)
        
        self.assertIn("Root Question", content)
        self.assertIn("Branch B Answer (Selected)", content)
        self.assertIn("Follow up on B", content)
        
        # Verify Branch A is excluded (strict linear path)
        self.assertNotIn("Branch A Answer", content)

    def test_claude_filtering(self):
        """Ensure tool messages are not marked as assistant."""
        parser = ChatParser()
        test_file = os.path.join(os.path.dirname(__file__), "../test_data/claude_tools.json")
        conversations = parser.parse_file(test_file, "claude")
        conv = conversations[0]
        
        msgs = conv["messages"]
        roles = [m["role"] for m in msgs]
        print("Claude Roles:", roles)
        
        self.assertEqual(len(msgs), 2) # Should filter out 'tool'
        self.assertEqual(msgs[0]["role"], "user")
        self.assertEqual(msgs[1]["role"], "assistant")

if __name__ == "__main__":
    unittest.main()
