#!/usr/bin/env -S uv run --project /Users/ryanjohnson/dotfiles/ai-staff-hq python
"""Swarm orchestrator for content workflows - Python CLI wrapper."""

import argparse
import sys
from pathlib import Path

# Add project root to path
DOTFILES_DIR = Path(__file__).resolve().parent.parent
AI_STAFF_HQ = DOTFILES_DIR / "ai-staff-hq"
sys.path.insert(0, str(AI_STAFF_HQ))

from orchestrator.swarm_runner import SwarmRunner
from workflows.schemas.swarm import SwarmConfig


def main():
    """Main entry point for content swarm orchestration."""
    parser = argparse.ArgumentParser(
        description="Swarm orchestrator for content creation workflows"
    )

    # Required arguments
    parser.add_argument(
        "brief",
        help="Content brief or request"
    )

    # Parallel execution
    parser.add_argument(
        "--parallel",
        action="store_true",
        default=True,
        help="Enable parallel execution (default: True)"
    )
    parser.add_argument(
        "--no-parallel",
        action="store_false",
        dest="parallel",
        help="Disable parallel execution"
    )
    parser.add_argument(
        "--max-parallel",
        type=int,
        default=5,
        help="Maximum number of parallel tasks (default: 5)"
    )

    # Model configuration
    parser.add_argument(
        "--model",
        help="Model override for all agents"
    )
    parser.add_argument(
        "--temperature",
        type=float,
        help="Temperature for generation (0.0-1.0)"
    )

    # Approval and debugging
    parser.add_argument(
        "--auto-approve",
        action="store_true",
        default=True,
        help="Auto-approve all steps (default: True)"
    )
    parser.add_argument(
        "--require-approval",
        action="store_false",
        dest="auto_approve",
        help="Require manual approval for steps"
    )
    parser.add_argument(
        "--debug",
        action="store_true",
        help="Enable verbose debugging output"
    )

    # Backward compatibility
    parser.add_argument(
        "--squad",
        help="Use predefined squad (backward compatibility mode)"
    )

    # Cost control
    parser.add_argument(
        "--budget",
        type=int,
        help="Maximum token budget (experimental)"
    )

    args = parser.parse_args()

    try:
        # Paths
        staff_dir = AI_STAFF_HQ / "staff"

        # Build configuration
        config = SwarmConfig(
            max_parallel=args.max_parallel,
            enable_parallel=args.parallel,
            max_budget_tokens=args.budget,
        )

        # Initialize SwarmRunner
        runner = SwarmRunner(
            staff_dir,
            config=config,
            model_override=args.model,
            temperature=args.temperature,
            auto_approve=args.auto_approve,
        )

        # Execute swarm
        result = runner.run_swarm(
            args.brief,
            use_squad=args.squad,
        )

        # Output final result
        print(result.get('final_output', '[No output generated]'))

        # Debug output
        if args.debug:
            print("\n" + "="*60, file=sys.stderr)
            print("SWARM EXECUTION METRICS", file=sys.stderr)
            print("="*60, file=sys.stderr)

            metrics = result.get('metrics', {})
            exec_stats = metrics.get('execution_stats', {})
            print(f"\nTotal Tasks: {exec_stats.get('total_tasks', 0)}", file=sys.stderr)
            print(f"Parallel Tasks: {exec_stats.get('parallel_tasks', 0)}", file=sys.stderr)
            print(f"Duration: {exec_stats.get('total_duration_seconds', 0):.2f}s", file=sys.stderr)

            specialist_usage = metrics.get('specialist_usage', {})
            print(f"\nUnique Specialists: {specialist_usage.get('unique_specialists', 0)}", file=sys.stderr)

            matching = metrics.get('matching_quality', {})
            print(f"Avg Match Score: {matching.get('avg_match_score', 0):.2f}", file=sys.stderr)

        return 0

    except KeyboardInterrupt:
        print("\nInterrupted by user", file=sys.stderr)
        return 130

    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        if args.debug:
            import traceback
            traceback.print_exc()
        return 1


if __name__ == "__main__":
    sys.exit(main())
