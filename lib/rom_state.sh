#!/bin/bash
# ROM Organizer - State Management
# This file handles session state, operation logging, and resume capability

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/rom_constants.sh
source "$SCRIPT_DIR/rom_constants.sh"
# shellcheck source=lib/rom_utils.sh
source "$SCRIPT_DIR/rom_utils.sh"
# shellcheck source=lib/rom_ui.sh
source "$SCRIPT_DIR/rom_ui.sh"

# Session state file location
declare -g STATE_FILE=""
declare -g SESSION_ID=""

# Operation statistics
declare -gA STATS=(
  [total]=0
  [processed]=0
  [success]=0
  [skipped]=0
  [errors]=0
  [auto_selected]=0
  [manual]=0
)

#######################################
# Initialize session state
# Arguments:
#   Collection name
#   System name
#   List file path
#######################################
init_session() {
  local collection="$1"
  local system="$2"
  local list_file="$3"
  
  SESSION_ID=$(date +%Y%m%d_%H%M%S)
  STATE_FILE="${HOME}/.rom-organizer/sessions/session_${SESSION_ID}.state"
  
  mkdir -p "$(dirname "$STATE_FILE")"
  
  # Write initial state
  cat > "$STATE_FILE" <<EOF
# ROM Organizer Session State
# Session ID: $SESSION_ID
# Created: $(date '+%Y-%m-%d %H:%M:%S')

COLLECTION=$collection
SYSTEM=$system
LIST_FILE=$list_file
LAST_PROCESSED=0
STATUS=active
EOF
  
  log_info "Session initialized: $SESSION_ID"
  log_verbose "State file: $STATE_FILE"
}

#######################################
# Load session state from file
# Arguments:
#   State file path
# Returns:
#   0 on success, 1 on failure
#######################################
load_session() {
  local state_file="$1"
  
  if [[ ! -f "$state_file" ]]; then
    log_error "State file not found: $state_file"
    return 1
  fi
  
  # shellcheck source=/dev/null
  source "$state_file"
  
  STATE_FILE="$state_file"
  
  log_info "Session loaded from: $state_file"
  log_verbose "Collection: ${COLLECTION:-unknown}"
  log_verbose "System: ${SYSTEM:-unknown}"
  log_verbose "Last processed: ${LAST_PROCESSED:-0}"
  
  return 0
}

#######################################
# Update session state
# Arguments:
#   Last processed line number
#######################################
update_session() {
  local last_processed="$1"
  
  if [[ -z "$STATE_FILE" ]]; then
    return 0
  fi
  
  # Update LAST_PROCESSED in state file
  sed -i "s/^LAST_PROCESSED=.*/LAST_PROCESSED=$last_processed/" "$STATE_FILE"
  
  log_verbose "Updated session state: last_processed=$last_processed"
}

#######################################
# Mark session as complete
#######################################
complete_session() {
  if [[ -z "$STATE_FILE" ]]; then
    return 0
  fi
  
  sed -i "s/^STATUS=.*/STATUS=complete/" "$STATE_FILE"
  
  # Add completion timestamp
  echo "COMPLETED=$(date '+%Y-%m-%d %H:%M:%S')" >> "$STATE_FILE"
  
  log_info "Session marked as complete"
}

#######################################
# Find active sessions
# Outputs:
#   List of active session state files
#######################################
find_active_sessions() {
  local sessions_dir="${HOME}/.rom-organizer/sessions"
  
  if [[ ! -d "$sessions_dir" ]]; then
    return 0
  fi
  
  find "$sessions_dir" -name "session_*.state" -type f 2>/dev/null | while read -r state_file; do
    if grep -q "^STATUS=active" "$state_file" 2>/dev/null; then
      echo "$state_file"
    fi
  done
}

#######################################
# Increment operation statistic
# Arguments:
#   Stat name (success, skipped, errors, etc.)
#   Optional increment value (default: 1)
#######################################
increment_stat() {
  local stat_name="$1"
  local increment="${2:-1}"
  
  if [[ -n "${STATS[$stat_name]:-}" ]]; then
    STATS[$stat_name]=$((STATS[$stat_name] + increment))
  else
    log_warning "Unknown stat: $stat_name"
  fi
}

#######################################
# Record successful operation
# Arguments:
#   Query string
#   File path
#   Operation type (copy, extract, skip)
#######################################
record_success() {
  local query="$1"
  local file_path="$2"
  local operation="${3:-copy}"
  
  increment_stat "success"
  
  log_info "SUCCESS: $operation - $query -> $file_path"
}

#######################################
# Record skipped operation
# Arguments:
#   Query string
#   Reason
#######################################
record_skip() {
  local query="$1"
  local reason="${2:-user_request}"
  
  increment_stat "skipped"
  
  log_info "SKIPPED: $query (reason: $reason)"
}

#######################################
# Record error
# Arguments:
#   Query string
#   Error message
#######################################
record_error() {
  local query="$1"
  local error_msg="$2"
  
  increment_stat "errors"
  
  log_error "ERROR: $query - $error_msg"
}

#######################################
# Generate operation summary report
# Outputs:
#   Formatted summary to STDOUT
#######################################
generate_summary() {
  local total=${STATS[total]}
  local processed=${STATS[processed]}
  local success=${STATS[success]}
  local skipped=${STATS[skipped]}
  local errors=${STATS[errors]}
  local auto_selected=${STATS[auto_selected]}
  local manual=${STATS[manual]}
  
  cat <<EOF

=======================================================
                 OPERATION SUMMARY
=======================================================

Total Queries:           $total
Processed:               $processed
  - Successful:          $success
  - Auto-selected:       $auto_selected
  - Manual queries:      $manual
  - Skipped:             $skipped
  - Errors:              $errors

Success Rate:            $(awk "BEGIN {printf \"%.1f%%\", ($success / $processed) * 100}" 2>/dev/null || echo "N/A")

Session ID:              ${SESSION_ID:-N/A}
Log File:                ${LOG_FILE:-N/A}

=======================================================

EOF
}

#######################################
# Write operation summary to file
# Arguments:
#   Output file path
#######################################
write_summary() {
  local output_file="$1"
  
  generate_summary > "$output_file"
  
  log_info "Summary written to: $output_file"
}

#######################################
# Display statistics during operation
#######################################
display_progress_stats() {
  local processed=${STATS[processed]}
  local total=${STATS[total]}
  local success=${STATS[success]}
  local skipped=${STATS[skipped]}
  local errors=${STATS[errors]}
  
  if [[ $total -gt 0 ]]; then
    local percent
    percent=$(awk "BEGIN {printf \"%.0f\", ($processed / $total) * 100}" 2>/dev/null || echo "0")
    
    ui_info "Progress: $processed/$total ($percent%) | Success: $success | Skipped: $skipped | Errors: $errors"
  fi
}

#######################################
# Create operation log entry
# Arguments:
#   Entry type (INFO, SUCCESS, ERROR, SKIP)
#   Query
#   Details
#######################################
log_operation() {
  local entry_type="$1"
  local query="$2"
  local details="${3:-}"
  
  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  
  local log_entry="[$timestamp] [$entry_type] Query: $query"
  
  if [[ -n "$details" ]]; then
    log_entry="$log_entry | $details"
  fi
  
  echo "$log_entry" >> "$LOG_FILE"
}

#######################################
# Export session data for analysis
# Arguments:
#   Export file path (JSON format)
#######################################
export_session_data() {
  local export_file="$1"
  
  cat > "$export_file" <<EOF
{
  "session_id": "${SESSION_ID:-unknown}",
  "timestamp": "$(date -Iseconds)",
  "statistics": {
    "total": ${STATS[total]},
    "processed": ${STATS[processed]},
    "success": ${STATS[success]},
    "skipped": ${STATS[skipped]},
    "errors": ${STATS[errors]},
    "auto_selected": ${STATS[auto_selected]},
    "manual": ${STATS[manual]}
  },
  "state_file": "${STATE_FILE:-}",
  "log_file": "${LOG_FILE:-}"
}
EOF
  
  log_info "Session data exported to: $export_file"
}

#######################################
# Clean up old session files
# Arguments:
#   Days to keep (default: 7)
#######################################
cleanup_old_sessions() {
  local days="${1:-7}"
  local sessions_dir="${HOME}/.rom-organizer/sessions"
  
  if [[ ! -d "$sessions_dir" ]]; then
    return 0
  fi
  
  log_info "Cleaning up session files older than $days days"
  
  find "$sessions_dir" -name "session_*.state" -type f -mtime "+$days" -delete 2>/dev/null || true
  
  log_verbose "Old session files cleaned up"
}
