# Project Blindspots & Future Enhancements

This document outlines a strategic review of the "Dispatcher" Orchestration System in its current state. The goal is to identify blindspots and propose future enhancements that would significantly benefit the project's promise of being a rapid, configurable, and robust "one-man factory."

---

## 1. Robustness & Error Handling

The current scripts are functional for the happy path, but they are brittle if the API returns an error that isn't a network failure.

*   **Blindspot:** API Error Handling
    *   **Observation:** If the `curl` command completes but the OpenRouter API returns a valid JSON object containing an error (e.g., invalid API key, model not found), the script will fail silently. The `jq` command will simply find no content at `.choices[0].message.content` and produce an empty output, which `tee` will write to the file. The user will see a "SUCCESS" message for a failed job.
    *   **Suggested Enhancement:** Before parsing the content, check if the JSON response contains an `.error` field. If it does, print the error message to `stderr` and exit with a non-zero status code. This would provide immediate, accurate feedback on API-level failures.

## 2. Configuration & Flexibility

The system's core promise is configurability, which can be greatly expanded.

*   **Blindspot:** Hardcoded Agent "Squads"
    *   **Observation:** The list of agents to load (`STAFF_TO_LOAD`) is hardcoded in each script. To create a new workflow or modify a team, the user must directly edit the script's code. This creates friction and goes against the principle of keeping configuration separate from logic.
    *   **Suggested Enhancement:** Create a central configuration file (e.g., `ai-staff-hq/squads.yaml`). This file would define different agent teams. A dispatcher script could then be simplified to just reference a squad name, loading the corresponding agents dynamically.

*   **Blindspot:** Lack of Model Parameter Control
    *   **Observation:** The scripts only configure the model name. Key API parameters like `temperature`, `max_tokens`, and `top_p` are left to the API's default values. The user has no way to tune a model's output for a specific task (e.g., higher temperature for more creative tasks, lower for more deterministic ones).
    *   **Suggested Enhancement:** Allow these parameters to be passed as optional command-line flags (e.g., `--temperature 0.8`) or defined alongside the model name in the `.env` file.

## 3. Workflow & User Experience (UX)

The current workflow is effective but could be streamlined and made more interactive.

*   **Blindspot:** Friction in Creating New Workflows
    *   **Observation:** To create a new workflow (e.g., `dhp-legal.sh`), the user must copy, paste, and modify an existing script. This leads to significant code duplication and is a manual, error-prone process.
    *   **Suggested Enhancement:** This is the most significant opportunity. Refactor the system to use a single, master `dispatch.sh` script. This script could take the "squad" name (from the proposed `squads.yaml`) as an argument, e.g., `dispatch creative "brief..."`. This would eliminate the need for separate script files for each workflow.

*   **Blindspot:** No Real-Time (Streaming) Output
    *   **Observation:** The scripts wait for the entire API response to be completed before printing any output. For complex tasks that take time to generate, this leaves the user waiting with no feedback.
    *   **Suggested Enhancement:** Modify the `curl` command to support streaming and process the response chunk-by-chunk as it arrives from the API. This would print the text to the screen in real-time, dramatically improving the interactive feel and aligning with the "high-speed" philosophy.

## 4. Code Maintenance & Scalability

As the system grows, duplicated code will become a significant liability.

*   **Blindspot:** High Degree of Code Duplication
    *   **Observation:** The three dispatcher scripts share a large amount of boilerplate code for validation, prompt assembly, and the core `curl`/`jq` logic. A bug in this core logic would require fixing it in three separate places, a number that would grow with each new workflow script.
    *   **Suggested Enhancement:** Adhere to the DRY (Don't Repeat Yourself) principle. Refactor the common code into a single, shared shell function or a helper script. This "core" function could be sourced and called by the individual dispatcher scripts (or the proposed master `dispatch.sh` script), ensuring that the main logic exists in only one place. This would make the entire system much easier to maintain, debug, and extend.
