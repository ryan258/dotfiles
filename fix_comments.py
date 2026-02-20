import os
import subprocess

# Revert cheatsheet and weather
subprocess.run(["git", "restore", "--staged", "scripts/cheatsheet.sh", "scripts/weather.sh"])
subprocess.run(["git", "restore", "scripts/cheatsheet.sh", "scripts/weather.sh"])

# Look at remaining staged files
result = subprocess.run(["git", "diff", "--cached", "--name-only"], capture_output=True, text=True)
files = [f for f in result.stdout.split('\n') if f.endswith('.sh') and f.startswith('scripts/')]

for f in files:
    with open(f, "r") as r:
        lines = r.readlines()
    
    # Find the description line
    desc_idx = -1
    for i, line in enumerate(lines):
        if line.startswith("# ") and " - " in line and line.strip().endswith(os.path.basename(f) + " -") is False:
             # Just a heuristic for "script.sh - description"
             if os.path.basename(f) in line:
                 desc_idx = i
                 break
    
    if desc_idx > 0 and desc_idx != 1:
        # Move it to right after shebang
        desc_line = lines.pop(desc_idx)
        lines.insert(1, desc_line)
        
        with open(f, "w") as w:
            w.writelines(lines)
