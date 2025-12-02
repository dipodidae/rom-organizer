#!/bin/bash
# ROM Organizer - Utility Functions
# This file contains shared utility functions and helpers

# Source constants
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/rom_constants.sh
source "$SCRIPT_DIR/rom_constants.sh"

# Global state
declare -g VERBOSE=false
declare -g DRY_RUN=false
declare -g LOG_FILE=""
declare -gA TEMP_FILES=()

#######################################
# Initialize logging system
# Globals:
#   LOG_FILE
# Arguments:
#   Optional log file path
#######################################
init_logging() {
  if [[ -n "${1:-}" ]]; then
    LOG_FILE="$1"
  else
    LOG_FILE="$(mktemp -t rom-organizer.XXXXXX.log)"
    TEMP_FILES["$LOG_FILE"]=1
  fi
  
  log_info "ROM Organizer v${ROM_ORGANIZER_VERSION} (${ROM_ORGANIZER_DATE})"
  log_info "Log file: $LOG_FILE"
}

#######################################
# Log verbose messages when VERBOSE mode is enabled.
# Globals:
#   VERBOSE
#   LOG_FILE
# Arguments:
#   Message to log
#######################################
log_verbose() {
  local message="$*"
  
  # Always write to log file if available
  if [[ -n "$LOG_FILE" ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [VERBOSE] $message" >> "$LOG_FILE"
  fi
  
  # Display to user only if verbose mode is on
  if [[ "$VERBOSE" == true ]]; then
    echo "[VERBOSE] $message" >&2
  fi
}

#######################################
# Log info messages
# Globals:
#   LOG_FILE
# Arguments:
#   Message to log
#######################################
log_info() {
  local message="$*"
  
  if [[ -n "$LOG_FILE" ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $message" >> "$LOG_FILE"
  fi
  
  echo "[INFO] $message" >&2
}

#######################################
# Log warning messages
# Globals:
#   LOG_FILE
# Arguments:
#   Message to log
#######################################
log_warning() {
  local message="$*"
  
  if [[ -n "$LOG_FILE" ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARNING] $message" >> "$LOG_FILE"
  fi
  
  echo "[WARNING] $message" >&2
}

#######################################
# Log error messages
# Globals:
#   LOG_FILE
# Arguments:
#   Message to log
#######################################
log_error() {
  local message="$*"
  
  if [[ -n "$LOG_FILE" ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $message" >> "$LOG_FILE"
  fi
  
  echo "[ERROR] $message" >&2
}

#######################################
# Error handler for traps
# Globals:
#   LOG_FILE
# Arguments:
#   Line number where error occurred
#   Function name (optional)
#######################################
error_handler() {
  local line_number="$1"
  local function_name="${2:-main}"
  
  log_error "Error occurred in $function_name at line $line_number"
  log_error "Cleaning up and exiting..."
  
  cleanup_temp_files
  
  if command -v gum &>/dev/null; then
    gum style --foreground "$COLOR_ERROR" "Error on line $line_number in $function_name"
  fi
  
  exit "$EXIT_GENERAL_ERROR"
}

#######################################
# Cleanup handler for exit
# Removes all temporary files and performs cleanup
# Globals:
#   TEMP_FILES
#######################################
cleanup_temp_files() {
  log_verbose "Cleaning up temporary files..."
  
  for temp_file in "${!TEMP_FILES[@]}"; do
    if [[ -f "$temp_file" ]]; then
      rm -f "$temp_file" 2>/dev/null || true
      log_verbose "Removed temp file: $temp_file"
    fi
  done
  
  # Clear the array
  TEMP_FILES=()
}

#######################################
# Register a temporary file for cleanup
# Globals:
#   TEMP_FILES
# Arguments:
#   Path to temporary file
#######################################
register_temp_file() {
  local temp_file="$1"
  TEMP_FILES["$temp_file"]=1
  log_verbose "Registered temp file: $temp_file"
}

#######################################
# Create a safe temporary file
# Globals:
#   TEMP_FILES
# Arguments:
#   Optional template suffix
# Outputs:
#   Path to temporary file
#######################################
create_temp_file() {
  local suffix="${1:-.tmp}"
  local temp_file
  temp_file=$(mktemp -t "rom-organizer.XXXXXX${suffix}")
  register_temp_file "$temp_file"
  echo "$temp_file"
}

#######################################
# Validate query string
# Arguments:
#   Query string to validate
# Returns:
#   0 if valid, 1 otherwise
#######################################
validate_query() {
  local query="$1"
  
  # Check if query is empty
  if [[ -z "$query" ]]; then
    log_verbose "Query validation failed: empty query"
    return 1
  fi
  
  # Check query length
  if [[ ${#query} -gt $MAX_QUERY_LENGTH ]]; then
    log_warning "Query is too long (${#query} > $MAX_QUERY_LENGTH): $query"
    return 1
  fi
  
  # Trim whitespace
  query=$(echo "$query" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  
  if [[ -z "$query" ]]; then
    log_verbose "Query validation failed: only whitespace"
    return 1
  fi
  
  return 0
}

#######################################
# Validate file path
# Arguments:
#   File path to validate
# Returns:
#   0 if valid, 1 otherwise
#######################################
validate_file_path() {
  local file_path="$1"
  
  # Check if path is empty
  if [[ -z "$file_path" ]]; then
    log_verbose "File path validation failed: empty path"
    return 1
  fi
  
  # Check if path exists
  if [[ ! -e "$file_path" ]]; then
    log_verbose "File path validation failed: does not exist: $file_path"
    return 1
  fi
  
  return 0
}

#######################################
# Validate system name
# Arguments:
#   System name to validate
#   Base ROM directory
# Returns:
#   0 if valid, 1 otherwise
#######################################
validate_system() {
  local system="$1"
  local base_dir="$2"
  
  # Check if system is empty
  if [[ -z "$system" ]]; then
    log_verbose "System validation failed: empty system name"
    return 1
  fi
  
  # Check if system directory exists in Official
  if [[ ! -d "$base_dir/Official/$system" ]]; then
    log_verbose "System validation failed: directory not found: $base_dir/Official/$system"
    return 1
  fi
  
  return 0
}

#######################################
# Validate rating format
# Arguments:
#   Rating string
#   Expected number of digits
# Returns:
#   0 if valid, 1 otherwise
#######################################
validate_rating() {
  local rating="$1"
  local expected_digits="${2:-$MIN_RATING_DIGITS}"
  
  # Check if rating is numeric
  if [[ ! "$rating" =~ ^[0-9]+$ ]]; then
    log_verbose "Rating validation failed: not numeric: $rating"
    return 1
  fi
  
  # Check digit count
  if [[ ${#rating} -ne $expected_digits ]]; then
    log_verbose "Rating validation failed: expected $expected_digits digits, got ${#rating}"
    return 1
  fi
  
  return 0
}

#######################################
# Trim whitespace from string
# Arguments:
#   String to trim
# Outputs:
#   Trimmed string
#######################################
trim() {
  local str="$1"
  echo "$str" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

#######################################
# Get file extension in lowercase
# Arguments:
#   Filename
# Outputs:
#   Extension (without dot)
#######################################
get_extension() {
  local filename="$1"
  local ext="${filename##*.}"
  echo "${ext,,}"  # Convert to lowercase
}

#######################################
# Get filename without extension
# Arguments:
#   Filename
# Outputs:
#   Filename without extension
#######################################
get_basename_no_ext() {
  local filename="$1"
  echo "${filename%.*}"
}

#######################################
# Check if file is a ROM based on extension
# Arguments:
#   Filename to check
# Returns:
#   0 if file is a ROM, 1 otherwise
#######################################
is_rom_file() {
  local filename="$1"
  local ext
  ext=$(get_extension "$filename")
  
  # Check if extension is in ROM_EXTENSIONS
  if [[ -n "${ROM_EXTENSIONS[$ext]:-}" ]]; then
    return 0
  fi
  
  return 1
}

#######################################
# Check if file is an archive
# Arguments:
#   Filename to check
# Returns:
#   0 if file is an archive, 1 otherwise
#######################################
is_archive_file() {
  local filename="$1"
  local ext
  ext=$(get_extension "$filename")
  
  for archive_ext in "${ARCHIVE_EXTENSIONS[@]}"; do
    if [[ "$ext" == "$archive_ext" || "$filename" == *".$archive_ext" ]]; then
      return 0
    fi
  done
  
  return 1
}

#######################################
# Format size in human readable format
# Arguments:
#   Size in bytes
# Outputs:
#   Formatted size string
#######################################
format_size() {
  local size="$1"
  
  if [[ $size -lt 1024 ]]; then
    echo "${size}B"
  elif [[ $size -lt $((1024 * 1024)) ]]; then
    echo "$((size / 1024))KB"
  elif [[ $size -lt $((1024 * 1024 * 1024)) ]]; then
    echo "$((size / 1024 / 1024))MB"
  else
    echo "$((size / 1024 / 1024 / 1024))GB"
  fi
}

#######################################
# Calculate number of digits needed for rating
# Arguments:
#   Total number of queries
# Outputs:
#   Number of digits
#######################################
calculate_rating_digits() {
  local total="$1"
  local digits=${#total}
  
  if [[ $digits -lt $MIN_RATING_DIGITS ]]; then
    digits=$MIN_RATING_DIGITS
  elif [[ $digits -gt $MAX_RATING_DIGITS ]]; then
    digits=$MAX_RATING_DIGITS
  fi
  
  echo "$digits"
}

#######################################
# Format rating with proper padding
# Arguments:
#   Rating number
#   Number of digits
# Outputs:
#   Padded rating string
#######################################
format_rating() {
  local rating="$1"
  local digits="$2"
  printf "%0${digits}d" "$rating"
}

# Set up error traps (only in production, not in tests)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]] || [[ -z "${TEST_MODE:-}" ]]; then
  trap 'error_handler $LINENO "${FUNCNAME[0]}"' ERR
  trap cleanup_temp_files EXIT
fi
