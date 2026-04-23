#!/usr/bin/env python3
"""Extract normalized Fitbit/Google Health daily metric updates from JSON."""

from __future__ import annotations

import json
import re
import sys
from datetime import datetime
from typing import Any, Iterable


def coerce_number(value: Any) -> float | None:
    if isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        return float(value)
    if isinstance(value, str):
        cleaned = value.replace(",", "").strip()
        if re.fullmatch(r"-?\d+(?:\.\d+)?", cleaned):
            return float(cleaned)
    return None


def format_value(value: float) -> str:
    rounded = round(value)
    if abs(value - rounded) < 1e-9:
        return str(int(rounded))
    return f"{value:.2f}".rstrip("0").rstrip(".")


def parse_day_from_dict(date_dict: Any) -> str | None:
    if not isinstance(date_dict, dict):
        return None

    year = date_dict.get("year")
    month = date_dict.get("month")
    day = date_dict.get("day")
    if year is None or month is None or day is None:
        return None

    try:
        return f"{int(year):04d}-{int(month):02d}-{int(day):02d}"
    except (TypeError, ValueError):
        return None


def parse_day_from_iso(raw: Any) -> str | None:
    if not raw:
        return None

    text = str(raw).strip()
    match = re.search(r"(\d{4}-\d{2}-\d{2})", text)
    if match:
        return match.group(1)

    try:
        return datetime.fromisoformat(text.replace("Z", "+00:00")).strftime("%Y-%m-%d")
    except ValueError:
        return None


def walk_dicts(obj: Any) -> Iterable[dict[str, Any]]:
    if isinstance(obj, dict):
        yield obj
        for value in obj.values():
            yield from walk_dicts(value)
    elif isinstance(obj, list):
        for value in obj:
            yield from walk_dicts(value)


def walk_numeric(obj: Any, path: tuple[str, ...] = ()) -> Iterable[tuple[tuple[str, ...], float]]:
    if isinstance(obj, dict):
        for key, value in obj.items():
            yield from walk_numeric(value, path + (str(key),))
    elif isinstance(obj, list):
        for value in obj:
            yield from walk_numeric(value, path)
    else:
        number = coerce_number(obj)
        if number is not None:
            yield path, number


def pick_day(metric: str, item: dict[str, Any]) -> str | None:
    if metric == "sleep_minutes":
        interval = item.get("sleep", {}).get("interval", {})
        for key in ("endTime", "startTime"):
            day = parse_day_from_iso(interval.get(key))
            if day:
                return day

    for candidate in walk_dicts(item):
        if "date" in candidate:
            day = parse_day_from_dict(candidate.get("date"))
            if day:
                return day

    for candidate in walk_dicts(item):
        for key in ("endTime", "startTime", "physicalTime"):
            day = parse_day_from_iso(candidate.get(key))
            if day:
                return day

    return None


def pick_generic_value(item: dict[str, Any], container_names: tuple[str, ...], preferred_terms: tuple[str, ...]) -> float | None:
    containers: list[dict[str, Any]] = []
    for name in container_names:
        candidate = item.get(name)
        if isinstance(candidate, dict):
            containers.append(candidate)
    if not containers:
        containers = [item]

    excluded_terms = {"year", "month", "day", "hours", "minutes", "seconds", "nanos"}
    flattened: list[tuple[tuple[str, ...], float]] = []
    for container in containers:
        flattened.extend(walk_numeric(container))

    for term in preferred_terms:
        for path, value in flattened:
            joined = ".".join(part.lower() for part in path)
            if term in joined and not any(excluded in joined for excluded in excluded_terms):
                return value

    for path, value in flattened:
        joined = ".".join(part.lower() for part in path)
        if not any(excluded in joined for excluded in excluded_terms):
            return value

    return None


def emit_updates(updates: dict[str, float]) -> None:
    for day in sorted(updates):
        print(f"{day}|{format_value(updates[day])}")


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: fitbit_metrics.py <metric>", file=sys.stderr)
        return 2

    metric = sys.argv[1]
    response_json = sys.stdin.read()
    payload = json.loads(response_json) if response_json.strip() else {}
    points = payload.get("rollupDataPoints") or payload.get("dataPoints") or []

    if metric == "steps":
        updates: dict[str, float] = {}
        for item in points:
            day = pick_day(metric, item)
            value = coerce_number(item.get("steps", {}).get("countSum"))
            if value is None:
                value = coerce_number(item.get("steps", {}).get("count"))
            if day and value is not None:
                updates[day] = value
        emit_updates(updates)
        return 0

    if metric == "sleep_minutes":
        updates = {}
        priorities: dict[str, int] = {}
        for item in points:
            sleep = item.get("sleep", {})
            day = pick_day(metric, item)
            value = coerce_number(sleep.get("summary", {}).get("minutesAsleep"))
            if day is None or value is None:
                continue
            priority = 1 if sleep.get("metadata", {}).get("main") else 0
            current_priority = priorities.get(day, -1)
            current_value = updates.get(day, -1)
            if priority > current_priority or (priority == current_priority and value > current_value):
                priorities[day] = priority
                updates[day] = value
        emit_updates(updates)
        return 0

    if metric == "resting_heart_rate":
        updates = {}
        for item in points:
            day = pick_day(metric, item)
            value = pick_generic_value(
                item,
                ("dailyRestingHeartRate", "restingHeartRate", "heartRate"),
                ("restingheartrate", "resting_heart_rate", "beatsperminute", "bpm", "value"),
            )
            if day and value is not None:
                updates[day] = value
        emit_updates(updates)
        return 0

    if metric == "hrv":
        updates = {}
        for item in points:
            day = pick_day(metric, item)
            value = pick_generic_value(
                item,
                ("dailyHeartRateVariability", "heartRateVariability"),
                ("rmssd", "milliseconds", "millis", "value"),
            )
            if day and value is not None:
                updates[day] = value
        emit_updates(updates)
        return 0

    print(f"Unsupported Fitbit metric: {metric}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
