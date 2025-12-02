#!/bin/bash
# ROM Organizer - UI Functions
# This file contains all gum-related UI interactions and safe wrappers

#######################################
# Safe wrapper for gum commands that handles errors gracefully
# Arguments:
#   All arguments are passed to gum
# Outputs:
#   gum command output
# Returns:
#   gum exit code
#######################################
gum_safe() {
  local result
  local exit_code

  # Temporarily disable exit on error
  set +e
  result=$("$@" 2>&1)
  exit_code=$?
  set -e

  echo "$result"
  return $exit_code
}

#######################################
# Display a styled message with gum
# Arguments:
#   Color (1-8)
#   Message text
#######################################
ui_message() {
  local color="$1"
  shift
  local message="$*"

  if command -v gum &>/dev/null; then
    gum style --foreground "$color" "$message"
  else
    echo "$message"
  fi
}

#######################################
# Display success message
# Arguments:
#   Message text
#######################################
ui_success() {
  ui_message "$COLOR_SUCCESS" "${SYMBOL_SUCCESS} $*"
}

#######################################
# Display error message
# Arguments:
#   Message text
#######################################
ui_error() {
  ui_message "$COLOR_ERROR" "${SYMBOL_ERROR} $*"
}

#######################################
# Display warning message
# Arguments:
#   Message text
#######################################
ui_warning() {
  ui_message "$COLOR_WARNING" "${SYMBOL_WARNING} $*"
}

#######################################
# Display info message
# Arguments:
#   Message text
#######################################
ui_info() {
  ui_message "$COLOR_INFO" "${SYMBOL_INFO} $*"
}

#######################################
# Display muted/subtle message
# Arguments:
#   Message text
#######################################
ui_muted() {
  ui_message "$COLOR_MUTED" "$*"
}

#######################################
# Display header/title message
# Arguments:
#   Message text
#######################################
ui_header() {
  if command -v gum &>/dev/null; then
    gum style --foreground "$COLOR_HIGHLIGHT" --bold "$*"
  else
    echo "=== $* ==="
  fi
}

#######################################
# Display centered title
# Arguments:
#   Message text
#######################################
ui_title() {
  if command -v gum &>/dev/null; then
    gum style --foreground "$COLOR_HIGHLIGHT" --bold --align center "$*"
  else
    echo "=== $* ==="
  fi
}

#######################################
# Safe wrapper for gum choose with cancellation handling
# Arguments:
#   Header text
#   Options array (passed as remaining arguments)
# Outputs:
#   Selected option or empty string if cancelled
# Returns:
#   0 if selection made, 1 if cancelled
#######################################
ui_choose() {
  local header="$1"
  shift
  local options=("$@")

  log_verbose "ui_choose called with header='$header', ${#options[@]} options"

  if ! command -v gum &>/dev/null; then
    log_error "gum is not available for interactive selection"
    return 1
  fi

  log_verbose "Calling gum choose..."
  local exit_code

  # Temporarily disable exit on error for interactive command
  # Don't capture output here - let it flow through to caller
  set +e
  gum choose --header "$header" "${options[@]}"
  exit_code=$?
  set -e

  log_verbose "gum choose returned exit code: $exit_code"
  if [[ $exit_code -ne 0 ]]; then
    log_verbose "User cancelled selection"
    return 1
  fi

  return 0
}

#######################################
# Safe wrapper for gum confirm
# Arguments:
#   Prompt text
#   Optional default (true/false)
# Returns:
#   0 if confirmed, 1 if declined or cancelled
#######################################
ui_confirm() {
  local prompt="$1"
  local default="${2:-false}"

  log_verbose "ui_confirm called with prompt='$prompt', default='$default'"

  if ! command -v gum &>/dev/null; then
    log_warning "gum not available, assuming default: $default"
    [[ "$default" == "true" ]] && return 0 || return 1
  fi

  local args=("gum" "confirm" "$prompt")
  if [[ "$default" == "true" ]]; then
    args+=(--default=true)
  fi

  log_verbose "ui_confirm: About to run gum confirm"
  
  # Temporarily disable exit on error for interactive command
  set +e
  "${args[@]}"
  local exit_code=$?
  set -e

  log_verbose "ui_confirm: gum confirm returned exit code $exit_code"

  return $exit_code
}

#######################################
# Safe wrapper for gum input
# Arguments:
#   Prompt text
#   Optional placeholder
# Outputs:
#   User input or empty string if cancelled
# Returns:
#   0 if input provided, 1 if cancelled
#######################################
ui_input() {
  local prompt="$1"
  local placeholder="${2:-}"

  if ! command -v gum &>/dev/null; then
    log_error "gum is not available for interactive input"
    return 1
  fi

  local args=("gum" "input" "--prompt" "$prompt")
  if [[ -n "$placeholder" ]]; then
    args+=(--placeholder "$placeholder")
  fi

  local exit_code

  # Temporarily disable exit on error for interactive command
  # Don't capture output - let it pass through directly
  set +e
  "${args[@]}"
  exit_code=$?
  set -e

  if [[ $exit_code -ne 0 ]]; then
    log_verbose "User cancelled input"
    return 1
  fi

  return 0
}

#######################################
# Display a progress spinner
# Arguments:
#   Title text
#   Command to run (as string)
# Returns:
#   Exit code of the command
#######################################
ui_spinner() {
  local title="$1"
  local command="$2"

  if command -v gum &>/dev/null; then
    gum spin --title "$title" -- bash -c "$command"
  else
    echo "$title..."
    eval "$command"
  fi
}

#######################################
# Display help/usage information
#######################################
ui_show_help() {
  cat <<'EOF'
ROM Collection Organizer v2.0.0

This script helps organize ROM collections by searching for games based on
text file queries and copying them to organized collections.

Usage: rom-organizer.sh [options]

Options:
  -h, --help        Show this help message
  -v, --verbose     Enable verbose output
  --dry-run         Simulate operations without making changes
  --resume          Resume previous interrupted session
  --config FILE     Use custom configuration file
  --version         Show version information

Environment Variables:
  ROM_BASE_DIR      Override the base directory for ROM collection
                    (default: auto-detect from script location)

Directory Structure:
  Base/
  ├── Official/           (Official ROM releases by system)
  ├── Translations/       (Translated ROMs by system)
  ├── Lists/             (Text files with game queries)
  └── Collections/       (Output directory for organized collections)

Requirements:
  - gum (for interactive UI)
  - python3 (for high-performance search engine)
  - unzip (for ZIP archives)
  - 7z (optional, for 7z archives)
  - unrar (optional, for RAR archives)

Python Performance Packages (recommended):
  - rapidfuzz: pip3 install rapidfuzz (ultra-fast fuzzy matching)
  - regex: pip3 install regex (enhanced regex support)

Examples:
  ./rom-organizer.sh                     # Interactive mode
  ./rom-organizer.sh --dry-run           # Preview without changes
  ./rom-organizer.sh --verbose           # Detailed logging
  ROM_BASE_DIR=/path/to/roms ./rom-organizer.sh  # Custom directory

For more information, see README.md
EOF
}

#######################################
# Display version information
#######################################
ui_show_version() {
  cat <<EOF
ROM Collection Organizer
Version: ${ROM_ORGANIZER_VERSION}
Release Date: ${ROM_ORGANIZER_DATE}

Copyright (c) 2025
License: MIT
EOF
}

#######################################
# Display operation summary
# Arguments:
#   Total processed
#   Success count
#   Skip count
#   Error count
#######################################
ui_show_summary() {
  local total="$1"
  local success="$2"
  local skipped="$3"
  local errors="$4"

  ui_title "Operation Summary"
  echo ""

  ui_info "Total Queries: $total"

  if [[ $success -gt 0 ]]; then
    ui_success "Successfully Processed: $success"
  fi

  if [[ $skipped -gt 0 ]]; then
    ui_warning "Skipped: $skipped"
  fi

  if [[ $errors -gt 0 ]]; then
    ui_error "Errors: $errors"
  else
    ui_success "No errors!"
  fi

  echo ""
}

#######################################
# Display query processing header
# Arguments:
#   Query text
#   Current number
#   Total number
#   Optional rating
#######################################
ui_query_header() {
  local query="$1"
  local current="$2"
  local total="$3"
  local rating="${4:-}"

  ui_message "$COLOR_INFO" "Query $current of $total: $query"

  if [[ -n "$rating" ]]; then
    ui_muted "  Rating: $rating"
  fi
}

#######################################
# Display match selection menu with control options
# Arguments:
#   Query text
#   Array of options (passed by reference via name)
# Outputs:
#   Selected option
# Returns:
#   0 if selected, 1 if cancelled
#######################################
ui_select_match() {
  local query="$1"
  local -n options_ref="$2"

  # Add control options
  local all_options=("${options_ref[@]}")
  all_options+=("${SYMBOL_MANUAL} Manual query")
  all_options+=("${SYMBOL_SKIP} Skip without marker")
  all_options+=("${SYMBOL_MARKER} Skip with marker")

  ui_choose "Select file for: $query" "${all_options[@]}"
}

#######################################
# Display dry run notice
# Arguments:
#   Operation description
#######################################
ui_dry_run_notice() {
  ui_message "$COLOR_WARNING" "[DRY RUN] Would perform: $*"
}

#######################################
# Check if gum is available
# Returns:
#   0 if available, 1 otherwise
#######################################
ui_check_available() {
  command -v gum &>/dev/null
}
