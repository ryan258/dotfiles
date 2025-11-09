# Project Blindspots & Future Enhancements

**Last Updated:** November 8, 2025

This document outlines remaining blindspots and proposed future enhancements for the "Dispatcher" Orchestration System. For completed improvements, see [CHANGELOG.md](CHANGELOG.md#dispatcher-robustness--streaming-improvements-november-8-2025).

---

## Recently Resolved (November 8, 2025)

- ✅ **API Error Handling** - No more silent failures ([see CHANGELOG](CHANGELOG.md))
- ✅ **Real-Time Streaming** - All dispatchers support `--stream` flag ([see CHANGELOG](CHANGELOG.md))
- ✅ **Code Duplication (Partial)** - API logic centralized in shared library ([see CHANGELOG](CHANGELOG.md))

---

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

## 4. Code Maintenance & Scalability

*   **Remaining Issue:** Some Code Duplication
    *   **Current State:** API logic centralized (✅), but validation and flag parsing still duplicated
    *   **Observation:** While `call_openrouter()` eliminates major duplication, these patterns remain duplicated across scripts:
        - Validation logic (curl/jq checks, API key checks)
        - Flag parsing patterns
        - Model fallback logic
    *   **Suggested Enhancement:**
        - Create validation library functions (e.g., `validate_dependencies()`, `validate_api_key()`)
        - Create shared flag parsing helper
        - Further consolidation of common patterns
    *   **Priority:** Low (major improvements already complete)
