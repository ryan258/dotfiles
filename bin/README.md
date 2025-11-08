# Dispatcher Orchestration System

This directory contains the "Dispatcher" scripts, which act as the orchestration layer for the AI-Staff-HQ. They serve as high-speed firing mechanisms to execute complex creative and technical workflows directly from the command line.

---

## Scripts

### 1. Creative Workflow: `dhp-creative.sh`

This script orchestrates a team of creative agents to generate a "First-Pass Story Package" for a new horror story concept.

-   **Purpose:** Quickly develop a beat sheet, character profile, and sensory details from a simple logline.
-   **Usage:** `dhp-creative.sh "Your story idea or logline"`
-   **Example:** `dhp-creative.sh "A lighthouse keeper who finds a mysterious deep-sea artifact that whispers forgotten sea shanties."`
-   **Output:** A new markdown file is saved to `~/projects/horror/`.

### 2. Content Workflow: `dhp-content.sh`

This script orchestrates a team of strategy and content agents to generate a "First-Draft Skeleton" for a new evergreen guide for your website.

-   **Purpose:** Research a topic for SEO/key questions and generate a Hugo-ready markdown outline.
-   **Usage:** `dhp-content.sh "Topic for your new guide"`
-   **Example:** `dhp-content.sh "A guide on using AI to overcome aphantasia in creative writing."`
-   **Output:** A new markdown file is saved to `~/projects/ryanleej.com/content/guides/`.

### 3. Technical Workflow: `dhp-tech.sh`

This script calls on the "Automation Specialist" to debug code provided via `stdin`.

-   **Purpose:** Analyze a script, identify bugs, explain the fix, and provide the corrected code.
-   **Usage:** `cat <your_script.sh> | dhp-tech.sh`
-   **Example:** `cat ./my-broken-script.sh | dhp-tech.sh`
-   **Output:** The analysis and corrected code are printed directly to the terminal.
