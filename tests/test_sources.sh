#!/bin/bash
# Test Suite for Dynamic ROM Sources
# Tests source configuration parsing, validation, and integration

# Relaxed error handling for tests
set -uo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Get script directory
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(dirname "$TEST_DIR")"

# Source required modules
source "$SCRIPT_DIR/lib/rom_constants.sh"
source "$SCRIPT_DIR/lib/rom_utils.sh"
source "$SCRIPT_DIR/lib/rom_ui.sh"
source "$SCRIPT_DIR/lib/rom_config.sh"

# Initialize logging (suppress output in CI)
LOG_FILE="/tmp/test_sources_$$.log"
export VERBOSE=false
init_logging >/dev/null 2>&1

#######################################
# Test Helper Functions
#######################################

assert_equals() {
  local expected="$1"
  local actual="$2"
  local test_name="$3"

  ((TESTS_RUN++))

  if [[ "$expected" == "$actual" ]]; then
    echo -e "${GREEN}✓${NC} $test_name"
    ((TESTS_PASSED++))
  else
    echo -e "${RED}✗${NC} $test_name"
    echo "  Expected: $expected"
    echo "  Actual:   $actual"
    ((TESTS_FAILED++))
  fi
}

assert_not_empty() {
  local value="$1"
  local test_name="$2"

  ((TESTS_RUN++))

  if [[ -n "$value" ]]; then
    echo -e "${GREEN}✓${NC} $test_name"
    ((TESTS_PASSED++))
  else
    echo -e "${RED}✗${NC} $test_name"
    echo "  Expected non-empty value"
    ((TESTS_FAILED++))
  fi
}

assert_success() {
  local test_name="$1"

  ((TESTS_RUN++))
  echo -e "${GREEN}✓${NC} $test_name"
  ((TESTS_PASSED++))
}

assert_failure() {
  local test_name="$1"

  ((TESTS_RUN++))
  echo -e "${RED}✗${NC} $test_name"
  ((TESTS_FAILED++))
}

#######################################
# Test Cases
#######################################

test_default_sources() {
  echo ""
  echo "=== Testing Default Sources ==="

  # Reset and load default config
  init_config
  CONFIG_FILE="$SCRIPT_DIR/config/defaults.conf"
  parse_sources

  local count
  count=$(get_source_count)
  assert_equals "2" "$count" "Default source count should be 2"

  local name0
  name0=$(get_source_name 0)
  assert_equals "Official" "$name0" "First source name should be 'Official'"

  local name1
  name1=$(get_source_name 1)
  assert_equals "Translations" "$name1" "Second source name should be 'Translations'"

  local priority0
  priority0=$(get_source_priority 0)
  assert_equals "100" "$priority0" "Official priority should be 100"

  local priority1
  priority1=$(get_source_priority 1)
  assert_equals "200" "$priority1" "Translations priority should be 200"

  local primary
  primary=$(get_primary_source)
  assert_equals "Official" "$primary" "Primary source should be 'Official'"
}

test_custom_sources() {
  echo ""
  echo "=== Testing Custom Sources ==="

  # Create temporary config with custom sources
  local temp_config
  temp_config=$(mktemp)
  cat > "$temp_config" <<EOF
sources=Official:Official:100
sources=Hacks:Hacks:150
sources=Translations:Translations:200
sources=Homebrew:Homebrew:120
EOF

  CONFIG_FILE="$temp_config"
  parse_sources

  local count
  count=$(get_source_count)
  assert_equals "4" "$count" "Custom source count should be 4"

  local name2
  name2=$(get_source_name 2)
  assert_equals "Translations" "$name2" "Third source should be 'Translations'"

  local priority2
  priority2=$(get_source_priority 2)
  assert_equals "200" "$priority2" "Translations priority should be 200"

  rm -f "$temp_config"
}

test_absolute_paths() {
  echo ""
  echo "=== Testing Absolute Paths ==="

  local temp_config
  temp_config=$(mktemp)
  cat > "$temp_config" <<EOF
sources=Official:/tmp/roms/official:100
sources=Translations:/tmp/roms/translations:200
EOF

  CONFIG_FILE="$temp_config"
  parse_sources

  local path0
  path0=$(get_source_path 0)
  assert_equals "/tmp/roms/official" "$path0" "Absolute path should be preserved"

  rm -f "$temp_config"
}

test_duplicate_detection() {
  echo ""
  echo "=== Testing Duplicate Detection ==="

  local temp_config
  temp_config=$(mktemp)
  cat > "$temp_config" <<EOF
sources=Official:Official:100
sources=Official:Translations:200
EOF

  CONFIG_FILE="$temp_config"

  if parse_sources 2>/dev/null; then
    assert_failure "Should reject duplicate source names"
  else
    assert_success "Correctly rejects duplicate source names"
  fi

  rm -f "$temp_config"
}

test_invalid_priority() {
  echo ""
  echo "=== Testing Invalid Priority ==="

  local temp_config
  temp_config=$(mktemp)
  cat > "$temp_config" <<EOF
sources=Official:Official:abc
EOF

  CONFIG_FILE="$temp_config"

  if parse_sources 2>/dev/null; then
    assert_failure "Should reject non-numeric priority"
  else
    assert_success "Correctly rejects non-numeric priority"
  fi

  rm -f "$temp_config"
}

test_missing_fields() {
  echo ""
  echo "=== Testing Missing Fields ==="

  local temp_config
  temp_config=$(mktemp)

  # Missing name
  echo "sources=:Official:100" > "$temp_config"
  CONFIG_FILE="$temp_config"

  if parse_sources 2>/dev/null; then
    assert_failure "Should reject missing name"
  else
    assert_success "Correctly rejects missing source name"
  fi

  # Missing path
  echo "sources=Official::100" > "$temp_config"
  CONFIG_FILE="$temp_config"

  if parse_sources 2>/dev/null; then
    assert_failure "Should reject missing path"
  else
    assert_success "Correctly rejects missing source path"
  fi

  rm -f "$temp_config"
}

test_legacy_config() {
  echo ""
  echo "=== Testing Legacy Config Compatibility ==="

  local temp_config
  temp_config=$(mktemp)
  cat > "$temp_config" <<EOF
official_dir=Official
translations_dir=Translations
EOF

  CONFIG_FILE="$temp_config"

  # Load config first
  CONFIG[official_dir]="Official"
  CONFIG[translations_dir]="Translations"

  parse_sources

  local count
  count=$(get_source_count)
  assert_equals "2" "$count" "Legacy config should create 2 sources"

  local name0
  name0=$(get_source_name 0)
  assert_equals "Official" "$name0" "Legacy Official source should work"

  rm -f "$temp_config"
}

test_source_accessor_functions() {
  echo ""
  echo "=== Testing Source Accessor Functions ==="

  CONFIG_FILE="$SCRIPT_DIR/config/defaults.conf"
  parse_sources

  local name
  name=$(get_source_name 0)
  assert_not_empty "$name" "get_source_name(0) should return value"

  local path
  path=$(get_source_path 0)
  assert_not_empty "$path" "get_source_path(0) should return value"

  local priority
  priority=$(get_source_priority 0)
  assert_not_empty "$priority" "get_source_priority(0) should return value"

  # Test out of bounds
  local invalid
  invalid=$(get_source_name 999)
  assert_equals "" "$invalid" "Out of bounds index should return empty"
}

test_priority_ordering() {
  echo ""
  echo "=== Testing Priority Ordering ==="

  local temp_config
  temp_config=$(mktemp)
  cat > "$temp_config" <<EOF
sources=Low:Low:50
sources=High:High:300
sources=Medium:Medium:150
EOF

  CONFIG_FILE="$temp_config"
  parse_sources

  # Sources should be in config order, not sorted by priority
  local name0
  name0=$(get_source_name 0)
  assert_equals "Low" "$name0" "Sources should maintain config order"

  local priority1
  priority1=$(get_source_priority 1)
  assert_equals "300" "$priority1" "High priority preserved"

  rm -f "$temp_config"
}

test_whitespace_handling() {
  echo ""
  echo "=== Testing Whitespace Handling ==="

  local temp_config
  temp_config=$(mktemp)
  cat > "$temp_config" <<EOF
sources=  Official  :  Official  :  100
sources=Translations:Translations:200
EOF

  CONFIG_FILE="$temp_config"
  parse_sources

  local name0
  name0=$(get_source_name 0)
  assert_equals "Official" "$name0" "Whitespace should be trimmed from name"

  local path0
  path0=$(get_source_path 0)
  assert_equals "Official" "$path0" "Whitespace should be trimmed from path"

  rm -f "$temp_config"
}

#######################################
# Run All Tests
#######################################

main() {
  echo "ROM Organizer - Source Configuration Test Suite"
  echo "================================================"

  test_default_sources
  test_custom_sources
  test_absolute_paths
  test_duplicate_detection
  test_invalid_priority
  test_missing_fields
  test_legacy_config
  test_source_accessor_functions
  test_priority_ordering
  test_whitespace_handling

  echo ""
  echo "================================================"
  echo "Test Results"
  echo "================================================"
  echo "Tests Run:    $TESTS_RUN"
  echo "Tests Passed: $TESTS_PASSED"
  echo "Tests Failed: $TESTS_FAILED"
  echo ""

  if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
  else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
  fi
}

main "$@"
