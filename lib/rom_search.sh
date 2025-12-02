#!/bin/bash
# ROM Organizer - Search Engine Integration
# This file contains search engine wrapper and match gathering logic

# Global configuration (set by main script)
declare -g BASE_DIR=""
declare -g PYTHON_CMD="python3"

#######################################
# Check if Python search engine is available and working
# Returns:
#   0 if available, 1 otherwise
#######################################
check_search_engine() {
  local rom_search_script
  rom_search_script="$SCRIPT_DIR/rom-search.py"

  if [[ ! -f "$rom_search_script" ]]; then
    ui_error "ROM search engine not found at $rom_search_script"
    return 1
  fi

  # Test if Python search engine works
  if ! "$PYTHON_CMD" "$rom_search_script" --help &>/dev/null; then
    ui_error "ROM search engine is not working properly"

    if [[ "$PYTHON_CMD" == "python3" ]]; then
      ui_muted "Try creating a virtual environment and installing packages:"
      ui_muted "  cd Scripts && python3 -m venv rom_env"
      ui_muted "  ./rom_env/bin/pip install rapidfuzz regex"
    fi

    return 1
  fi

  return 0
}

#######################################
# Initialize Python search engine
# Detects virtual environment and checks for performance packages
# Globals:
#   PYTHON_CMD
#######################################
init_search_engine() {
  local script_base
  script_base="$SCRIPT_DIR"

  # Check for virtual environment with performance packages
  local venv_python="$script_base/rom_env/bin/python"

  if [[ -f "$venv_python" ]]; then
    PYTHON_CMD="$venv_python"
    log_verbose "Using virtual environment Python: $PYTHON_CMD"
  else
    PYTHON_CMD="python3"
    log_verbose "Using system Python: $PYTHON_CMD"
  fi

  # Verify search engine is available
  if ! check_search_engine; then
    return 1
  fi

  log_verbose "Using high-performance Python search engine"
  ui_success "Python-based ROM search engine loaded"

  # Check for optional performance packages
  if "$PYTHON_CMD" -c "import rapidfuzz" &>/dev/null; then
    ui_success "rapidfuzz available for ultra-fast fuzzy matching"
  else
    ui_warning "Install 'rapidfuzz' for even faster searches"

    if [[ "$PYTHON_CMD" == "python3" ]]; then
      ui_muted "  cd Scripts && python3 -m venv rom_env && ./rom_env/bin/pip install rapidfuzz"
    fi
  fi

  return 0
}

#######################################
# Gather matching ROM files using Python search engine
# Arguments:
#   Query string to search for
#   System name to search within
# Outputs:
#   Pipe-delimited display_name|file_path pairs to STDOUT
# Returns:
#   0 on success, non-zero on error
#######################################
gather_matches() {
  local query="$1"
  local system="$2"

  if ! validate_query "$query"; then
    log_error "Invalid query: $query"
    return 1
  fi

  if ! validate_system "$system" "$BASE_DIR"; then
    log_error "Invalid system: $system"
    return 1
  fi

  log_verbose "Gathering matches for query '$query' in system '$system'"

  local rom_search_script
  rom_search_script="$SCRIPT_DIR/rom-search.py"

  local cache_dir="$BASE_DIR/$CACHE_DIR_NAME"

  # Create cache directory if it doesn't exist
  mkdir -p "$cache_dir"

  # Build Python search command arguments
  local python_args=(
    "$rom_search_script"
    "$BASE_DIR"
    "$query"
    "$system"
    "--cache-dir=$cache_dir"
    "--max-results=$MAX_SEARCH_RESULTS"
    "--fuzzy-threshold=$DEFAULT_FUZZY_THRESHOLD"
  )

  if [[ "$VERBOSE" == true ]]; then
    python_args+=(--verbose)
  fi

  log_verbose "Running: $PYTHON_CMD ${python_args[*]}"

  # Execute Python search and capture results
  local search_results
  local search_exit_code

  search_results=$("$PYTHON_CMD" "${python_args[@]}" 2>&1)
  search_exit_code=$?

  if [[ $search_exit_code -ne 0 ]]; then
    log_error "Search engine failed with exit code $search_exit_code"
    log_verbose "Search output: $search_results"
    return 1
  fi

  # Output results
  echo "$search_results"

  # Count matches for logging
  local match_count
  match_count=$(echo "$search_results" | grep -c '|' || echo "0")

  log_verbose "Found $match_count matches for query: $query"

  return 0
}

#######################################
# Parse search results into arrays
# Arguments:
#   Search results (pipe-delimited lines)
#   Name of array to store display names
#   Name of array to store file paths
# Returns:
#   0 on success
#######################################
parse_search_results() {
  local results="$1"
  local -n display_names_ref="$2"
  local -n file_paths_ref="$3"

  # Clear arrays
  display_names_ref=()
  file_paths_ref=()

  while IFS='|' read -r display_name file_path; do
    if [[ -n "$display_name" && -n "$file_path" ]]; then
      display_names_ref+=("$display_name")
      file_paths_ref+=("$file_path")

      log_verbose "Match: $display_name -> $file_path"
    fi
  done <<< "$results"

  log_verbose "Parsed ${#display_names[@]} search results"

  return 0
}

#######################################
# Search for ROM and return match count
# Arguments:
#   Query string
#   System name
# Outputs:
#   Number of matches found
#######################################
count_matches() {
  local query="$1"
  local system="$2"

  local results
  results=$(gather_matches "$query" "$system")

  echo "$results" | grep -c '|' || echo "0"
}

#######################################
# Get best match for a query (auto-select if only one match)
# Arguments:
#   Query string
#   System name
# Outputs:
#   File path of best match or empty if no/multiple matches
# Returns:
#   0 if single match found, 1 otherwise
#######################################
get_best_match() {
  local query="$1"
  local system="$2"

  local results
  results=$(gather_matches "$query" "$system")

  local match_count
  match_count=$(echo "$results" | grep -c '|' || echo "0")

  if [[ $match_count -eq 1 ]]; then
    # Extract file path from result
    echo "$results" | cut -d'|' -f2
    return 0
  fi

  log_verbose "No best match (found $match_count matches)"
  return 1
}
