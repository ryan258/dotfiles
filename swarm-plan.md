# Plan: AI Staff HQ Swarm Orchestration System

## Overview

Transform the static squad-based dispatcher system into a dynamic swarm orchestration system that:

- **Analyzes user briefs** and selects specialists from all 66 available agents
- **Executes independent tasks in parallel** for performance
- **Uses Chief of Staff** as central coordinator
- **Maintains CLI interface** via dispatcher scripts

## User's Vision (Confirmed)

1. **Scope**: Replace dispatcher scripts (`dhp-content.sh`, `dhp-creative.sh`)
2. **Selection**: Fully dynamic - choose from all 66 specialists based on task analysis
3. **Execution**: Parallel where possible (independent tasks run concurrently)
4. **Coordination**: Centralized manager (Chief of Staff plans, assigns, synthesizes)

## Architecture Design

### High-Level Flow

```
User Brief → Dispatcher → SwarmRunner → Chief of Staff (Planning)
                                              ↓
                                    Task Breakdown (JSON)
                                              ↓
                               Capability Matching → Specialist Selection
                                              ↓
                          Dependency Analysis → Execution Waves
                                              ↓
                    ┌──────────────────────────────────────┐
                    │  Wave 1: Parallel Execution          │
                    │  - Task A (Specialist 1) ──┐         │
                    │  - Task B (Specialist 2) ──┼─────→   │
                    │  - Task C (Specialist 3) ──┘         │
                    └──────────────────────────────────────┘
                                              ↓
                    ┌──────────────────────────────────────┐
                    │  Wave 2: Sequential (depends on Wave 1)│
                    │  - Task D (Specialist 4)             │
                    └──────────────────────────────────────┘
                                              ↓
                      Chief of Staff (Synthesis) → Final Output
```

### Core Components

**1. SwarmRunner** (`ai-staff-hq/orchestrator/swarm_runner.py` - NEW)

- Extends `GraphRunner` for compatibility
- Orchestrates: task analysis → capability matching → execution → synthesis
- Manages parallel execution via ThreadPoolExecutor
- Handles errors and fallbacks

**2. CapabilityIndex** (`ai-staff-hq/orchestrator/capability_index.py` - NEW)

- Indexes all 66 specialist YAML files
- Extracts capabilities from `core_capabilities` and `expertise` fields
- Builds reverse index: `capability_name → [specialist_slugs]`
- Scoring algorithm: exact match (1.0), fuzzy (0.5), expertise (0.3), department boost (0.2)

**3. TaskAnalyzer** (`ai-staff-hq/orchestrator/task_analyzer.py` - NEW)

- Uses Chief of Staff to break down user brief into structured tasks
- Returns JSON: `[{id, description, required_capabilities, depends_on, priority}]`
- Reuses JSON parsing pattern from `cos_orchestration.py` (lines 42-52)
- Fallback: if parse fails, treat entire brief as single task

**4. ExecutionPlanner** (`ai-staff-hq/orchestrator/execution_planner.py` - NEW)

- Builds dependency graph from tasks
- Topological sort to determine execution order
- Groups tasks into waves: parallel (>1 task, no dependencies) or sequential (1 task or dependent)
- Respects `max_parallel` limit by batching large waves

**5. Parallel Execution**

- Uses `ThreadPoolExecutor` for I/O-bound LLM calls
- Thread safety: unique `session_id` per task (`{run_id}_{task_id}`)
- GraphRunner cache uses `(slug, session_id)` as key
- Each parallel task has isolated ConversationState

**6. Context Sharing**

- Dependent tasks receive results from `depends_on` tasks in prompt
- Truncation strategy: limit each result to 500 tokens
- Fallback: CoS summarizes prior results if context too large

**7. Error Handling**

- Primary execution fails → try alternative specialist (2nd match)
- Alternative fails → fallback to Chief of Staff
- Chief of Staff fails → return error message in result
- All errors logged to stderr

## Dispatcher Integration

### Python Wrapper Called from Bash

**New File**: `bin/dhp-swarm-content.py` (Python CLI wrapper)

```python
#!/usr/bin/env python3
from orchestrator.swarm_runner import SwarmRunner

runner = SwarmRunner(STAFF_DIR, model_override=args.model, auto_approve=True)
result = runner.run_swarm(
    brief=args.brief,
    max_parallel=args.max_parallel,
    enable_parallel=args.parallel,
)
print(result["final_output"])
```

**Modified**: `bin/dhp-content.sh` (replace lines 166-229)

```bash
# Replace mega-prompt assembly with:
python3 "$DOTFILES_DIR/bin/dhp-swarm-content.py" \
    "$USER_BRIEF" \
    --parallel \
    --max-parallel 5 \
    --auto-approve \
    ${MODEL:+--model "$MODEL"} \
    | tee "$OUTPUT_FILE"
```

**Backward Compatibility**: `--squad content` flag passes to Python, loads predefined squad from `squads.json`

## Implementation Phases

### Phase 1: Foundation (Core Components)

1. Create `CapabilityIndex` - parse YAMLs, build reverse index, implement matching
2. Create `TaskAnalyzer` - integrate with Chief of Staff, parse JSON tasks
3. Create `ExecutionPlanner` - dependency graph, topological sort, wave creation
4. Unit tests for all components

**Validation**: Can index specialists, break down brief, create execution plan

### Phase 2: Sequential Orchestration

1. Create `SwarmRunner` extending `GraphRunner`
2. Implement `run_swarm()` with sequential-only execution
3. Build LangGraph with sequential nodes
4. Test with simple briefs (2-3 tasks)

**Validation**: Can execute multi-task brief sequentially with dynamic selection

### Phase 3: Parallel Execution

1. Implement `_execute_parallel_wave()` with ThreadPoolExecutor
2. Add unique session IDs for thread safety
3. Test with 5+ parallel tasks
4. Implement context sharing and error handling

**Validation**: Can execute tasks in parallel, properly share context

### Phase 4: Dispatcher Integration

1. Create `dhp-swarm-content.py` and `dhp-swarm-creative.py` wrappers
2. Modify `dhp-content.sh` and `dhp-creative.sh` to call Python
3. Add backward compatibility with `--squad` flag
4. End-to-end testing

**Validation**: Can call from bash, produces quality output

### Phase 5: Optimization

1. Improve capability matching (fuzzy matching, scoring weights)
2. Add swarm metrics and cost tracking
3. Implement context truncation strategies
4. Documentation and examples

## Critical Files

### New Files to Create

```
ai-staff-hq/orchestrator/
  ├── swarm_runner.py          # SwarmRunner class (extends GraphRunner)
  ├── capability_index.py      # Capability indexing and matching
  ├── task_analyzer.py         # Task breakdown via Chief of Staff
  └── execution_planner.py     # Wave planning and dependency resolution

bin/
  ├── dhp-swarm-content.py     # Python wrapper for content swarm
  └── dhp-swarm-creative.py    # Python wrapper for creative swarm

ai-staff-hq/workflows/schemas/
  └── swarm.py                 # Pydantic models for swarm state

ai-staff-hq/tests/
  ├── test_swarm_runner.py
  ├── test_capability_index.py
  ├── test_task_analyzer.py
  └── test_execution_planner.py
```

### Files to Modify

```
bin/dhp-content.sh           # Replace lines 166-229 with Python call
bin/dhp-creative.sh          # Replace lines 166-229 with Python call
```

### Reference Files (No Changes)

```
ai-staff-hq/orchestrator/graph_runner.py         # Base class pattern
ai-staff-hq/workflows/graphs/cos_orchestration.py  # Manager-worker pattern reference
ai-staff-hq/tools/engine/core.py                 # SpecialistAgent usage
```

## Key Design Decisions

1. **Extend GraphRunner**: Reuses logging, caching, approval gates from proven base
2. **Chief of Staff for Task Analysis**: Leverages existing expertise in project coordination
3. **Capability-Based Matching**: More granular than role-based (e.g., "SEO" vs "Copywriter")
4. **ThreadPoolExecutor**: Simpler than asyncio for sync LangChain API
5. **Execution Waves**: Simpler than full DAG executor, easier to visualize
6. **Python Wrapper**: Complex logic in Python, maintains bash CLI for users
7. **Session Isolation**: Unique session_id per task prevents race conditions
8. **Fallback to CoS**: Better than halting execution on specialist failures

## Potential Challenges & Solutions

| Challenge                 | Solution                                                  |
| ------------------------- | --------------------------------------------------------- |
| Thread safety             | Unique session*id per task: `{run_id}*{task_id}`          |
| Poor task breakdown       | Few-shot examples in prompt, validation, manual override  |
| Capability match failures | Fuzzy matching, low min_score (0.3), fallback to CoS      |
| Over-parallelization      | max_parallel limit (default 5), wave batching             |
| Context window limits     | Dependencies-only strategy, truncation to 500 tokens      |
| Cost control              | Token tracking, budget parameter, cost estimation         |
| Dependency cycles         | Topological sort raises error, ask CoS to revise          |
| Specialist unavailability | Index validation, fallback matching, graceful degradation |

## Success Metrics

```python
@dataclass
class SwarmMetrics:
    total_tasks: int
    parallel_tasks: int
    total_duration_seconds: float
    specialists_used: Dict[str, int]  # slug → count
    avg_match_score: float
    speedup_factor: float  # vs pure sequential
    total_tokens: int
    estimated_cost_usd: float
    failed_tasks: int
```

Logged to: `logs/swarm_metrics/{run_id}.json`

## Usage Examples

```bash
# Basic swarm orchestration
dhp-content.sh "Create a guide on Bash scripting best practices"

# Python wrapper with control
dhp-swarm-content.py "Complex brief" --max-parallel 10 --budget 100000

# Backward compatibility (old squad system)
dhp-swarm-content.py "Brief" --squad content

# Disable parallelism
dhp-swarm-content.py "Brief" --no-parallel
```

## Implementation Status

**Phase 1**: ✅ Complete
**Phase 2**: ✅ Complete
**Phase 3**: ✅ Complete
**Phase 4**: 🔄 In Progress (CLI wrappers created, bash integration pending)
**Phase 5**: ⏳ Not Started

## Next Steps

1. Modify bash dispatcher scripts to call Python wrappers
2. Test end-to-end swarm orchestration
3. Write unit tests for all components
4. Add optimization and metrics tracking
