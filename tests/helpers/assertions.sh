#!/bin/bash

# tests/helpers/assertions.sh
# Custom assertions for BATS tests

fail() {
    echo "$1"
    return 1
}

# Assert that a file exists
# Usage: assert_file_exists <file>
assert_file_exists() {
  local file="$1"
  if [ ! -f "$file" ]; then
    fail "File '$file' does not exist"
  fi
}

# Assert that a file contains a specific string
# Usage: assert_file_contains <file> <string>
assert_file_contains() {
  local file="$1"
  local expected="$2"

  if [ ! -f "$file" ]; then
    fail "File '$file' does not exist"
  fi

  if ! grep -q "$expected" "$file"; then
    fail "File '$file' does not contain '$expected'"
  fi
}

# Assert that a file does NOT contain a specific string
# Usage: assert_file_not_contains <file> <string>
assert_file_not_contains() {
  local file="$1"
  local expected="$2"

  if [ ! -f "$file" ]; then
    fail "File '$file' does not exist"
  fi

  if grep -q "$expected" "$file"; then
    fail "File '$file' should not contain '$expected'"
  fi
}

# Assert that a string is a valid timestamp (YYYY-MM-DD HH:MM:SS)
# Usage: assert_valid_timestamp <string>
assert_valid_timestamp() {
  local timestamp="$1"
  if [[ ! "$timestamp" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}:[0-9]{2}$ ]]; then
    fail "Invalid timestamp format: '$timestamp' (Expected YYYY-MM-DD HH:MM:SS)"
  fi
}

# Assert that a string is a valid date (YYYY-MM-DD)
# Usage: assert_valid_date <string>
assert_valid_date() {
  local date="$1"
  if [[ ! "$date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    fail "Invalid date format: '$date' (Expected YYYY-MM-DD)"
  fi
}
