#!/bin/bash
# mkproject_py.sh - Sets up a complete Python project with virtual environment
set -euo pipefail

# Ask for the project name
IFS= read -r -p "Enter your Python project name: " project_name

# Check if a directory with that name already exists
if [ -d "$project_name" ]; then
    echo "Error: Directory '$project_name' already exists."
    exit 1
fi

echo "Creating project directory: $project_name"
mkdir "$project_name"
cd "$project_name" || exit 1

echo "Setting up Python virtual environment in 'venv'..."
python3 -m venv venv

echo "Creating .gitignore file..."
# A heredoc is used to write multiple lines to a file at once
cat << EOF > .gitignore
# Python virtual environment
venv/

# Python cache files
__pycache__/
*.pyc

# Environment variables
.env

# macOS specific
.DS_Store
EOF

echo "Creating requirements.txt..."
touch requirements.txt

echo "Creating main.py with a starter template..."
cat << EOF > main.py
def main():
    """Main function for the project."""
    print("Hello, Python Project!")


if __name__ == "__main__":
    main()
EOF

echo "Initializing Git repository..."
git init > /dev/null

echo ""
echo "✅ Project '$project_name' created successfully!"
echo ""
echo "--- Next Steps ---"
echo "1. Navigate into your project: cd $project_name"
echo "2. Activate the virtual environment: source venv/bin/activate"
echo "3. Install packages: pip install <package_name>"
echo "4. Start coding in main.py!"
