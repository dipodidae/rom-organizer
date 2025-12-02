#!/bin/bash
# ROM Organizer - Basic Test Suite
# Simple tests to verify module functionality

# Note: Not using set -e since we're testing for failures
set -uo pipefail

# Set test mode to disable error traps
export TEST_MODE=true

# Colors for test output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

# Source modules
source "$LIB_DIR/rom_constants.sh"
source "$LIB_DIR/rom_utils.sh"
source "$LIB_DIR/rom_ui.sh"

# Test helper functions
assert_equals() {
  local expected="$1"
  local actual="$2"
  local test_name="${3:-test}"
  
  ((TESTS_RUN++))
  
  if [[ "$expected" == "$actual" ]]; then
    echo -e "${GREEN}✓${NC} PASS: $test_name"
    ((TESTS_PASSED++))
    return 0
  else
    echo -e "${RED}✗${NC} FAIL: $test_name"
    echo "  Expected: $expected"
    echo "  Actual:   $actual"
    ((TESTS_FAILED++))
    return 1
  fi
}

assert_true() {
  local condition="$1"
  local test_name="${2:-test}"
  
  ((TESTS_RUN++))
  
  if eval "$condition"; then
    echo -e "${GREEN}✓${NC} PASS: $test_name"
    ((TESTS_PASSED++))
    return 0
  else
    echo -e "${RED}✗${NC} FAIL: $test_name (condition false)"
    ((TESTS_FAILED++))
    return 1
  fi
}

# Test suite
echo "ROM Organizer Test Suite"
echo "========================="
echo ""

# Test 1: Module loading
echo "Testing module loading..."
assert_true "[[ -n \"\$ROM_ORGANIZER_VERSION\" ]]" "Constants module loaded"
assert_true "command -v log_verbose &>/dev/null" "Utils module loaded"
assert_true "command -v ui_message &>/dev/null" "UI module loaded"

# Test 2: Utility functions
echo ""
echo "Testing utility functions..."

result=$(get_extension "test.rom")
assert_equals "rom" "$result" "get_extension() with .rom"

result=$(get_extension "game.smc")
assert_equals "smc" "$result" "get_extension() with .smc"

result=$(get_basename_no_ext "mario.zip")
assert_equals "mario" "$result" "get_basename_no_ext()"

result=$(trim "  hello world  ")
assert_equals "hello world" "$result" "trim() whitespace"

# Test 3: ROM file detection
echo ""
echo "Testing ROM file detection..."

if is_rom_file "game.smc"; then
  echo -e "${GREEN}✓${NC} PASS: is_rom_file() detects .smc"
  ((TESTS_PASSED++))
else
  echo -e "${RED}✗${NC} FAIL: is_rom_file() should detect .smc"
  ((TESTS_FAILED++))
fi
((TESTS_RUN++))

if is_rom_file "game.nes"; then
  echo -e "${GREEN}✓${NC} PASS: is_rom_file() detects .nes"
  ((TESTS_PASSED++))
else
  echo -e "${RED}✗${NC} FAIL: is_rom_file() should detect .nes"
  ((TESTS_FAILED++))
fi
((TESTS_RUN++))

if ! is_rom_file "readme.txt"; then
  echo -e "${GREEN}✓${NC} PASS: is_rom_file() rejects .txt"
  ((TESTS_PASSED++))
else
  echo -e "${RED}✗${NC} FAIL: is_rom_file() should reject .txt"
  ((TESTS_FAILED++))
fi
((TESTS_RUN++))

# Test 4: Archive detection
echo ""
echo "Testing archive detection..."

if is_archive_file "game.zip"; then
  echo -e "${GREEN}✓${NC} PASS: is_archive_file() detects .zip"
  ((TESTS_PASSED++))
else
  echo -e "${RED}✗${NC} FAIL: is_archive_file() should detect .zip"
  ((TESTS_FAILED++))
fi
((TESTS_RUN++))

if ! is_archive_file "game.smc"; then
  echo -e "${GREEN}✓${NC} PASS: is_archive_file() rejects .smc"
  ((TESTS_PASSED++))
else
  echo -e "${RED}✗${NC} FAIL: is_archive_file() should reject .smc"
  ((TESTS_FAILED++))
fi
((TESTS_RUN++))

# Test 5: Rating functions
echo ""
echo "Testing rating functions..."

result=$(calculate_rating_digits 50)
assert_equals "2" "$result" "calculate_rating_digits(50)"

result=$(calculate_rating_digits 500)
assert_equals "3" "$result" "calculate_rating_digits(500)"

result=$(format_rating 5 3)
assert_equals "005" "$result" "format_rating(5, 3)"

result=$(format_rating 42 4)
assert_equals "0042" "$result" "format_rating(42, 4)"

# Test 6: Validation functions
echo ""
echo "Testing validation functions..."

if validate_query "Super Mario 64"; then
  echo -e "${GREEN}✓${NC} PASS: validate_query() accepts valid query"
  ((TESTS_PASSED++))
else
  echo -e "${RED}✗${NC} FAIL: validate_query() should accept valid query"
  ((TESTS_FAILED++))
fi
((TESTS_RUN++))

if ! validate_query ""; then
  echo -e "${GREEN}✓${NC} PASS: validate_query() rejects empty query"
  ((TESTS_PASSED++))
else
  echo -e "${RED}✗${NC} FAIL: validate_query() should reject empty query"
  ((TESTS_FAILED++))
fi
((TESTS_RUN++))

# Very long query (over MAX_QUERY_LENGTH)
long_query=$(printf 'a%.0s' {1..250})
if ! validate_query "$long_query"; then
  echo -e "${GREEN}✓${NC} PASS: validate_query() rejects too-long query"
  ((TESTS_PASSED++))
else
  echo -e "${RED}✗${NC} FAIL: validate_query() should reject too-long query"
  ((TESTS_FAILED++))
fi
((TESTS_RUN++))

# Test Summary
echo ""
echo "========================="
echo "Test Summary"
echo "========================="
echo "Tests Run:    $TESTS_RUN"
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"

if [[ $TESTS_FAILED -eq 0 ]]; then
  echo ""
  echo -e "${GREEN}All tests passed!${NC}"
  exit 0
else
  echo ""
  echo -e "${RED}Some tests failed.${NC}"
  exit 1
fi
