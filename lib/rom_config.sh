#!/bin/bash
# ROM Organizer - Configuration Management
# This file handles configuration loading and validation

# Configuration variables
declare -g CONFIG_FILE=""
declare -gA CONFIG=(
  [auto_select_single]="true"
  [prepend_rating_default]="true"
  [fuzzy_threshold]="15.0"
  [max_results]="100"
  [enable_dry_run]="false"
  [enable_resume]="true"
  [cleanup_sessions_days]="7"
  [create_skip_markers]="true"
)

#######################################
# Load configuration from file
# Arguments:
#   Config file path
# Returns:
#   0 on success, 1 on failure
#######################################
load_config() {
  local config_file="$1"

  if [[ ! -f "$config_file" ]]; then
    log_warning "Config file not found: $config_file"
    return 1
  fi

  log_verbose "Loading configuration from: $config_file"

  # Read configuration (simple KEY=VALUE format)
  while IFS='=' read -r key value; do
    # Skip comments and empty lines
    [[ "$key" =~ ^[[:space:]]*# ]] && continue
    [[ -z "$key" ]] && continue

    # Trim whitespace
    key=$(trim "$key")
    value=$(trim "$value")

    # Remove quotes from value
    value="${value//\"/}"
    value="${value//\'/}"

    # Set configuration value
    CONFIG[$key]="$value"

    log_verbose "Config: $key = $value"
  done < "$config_file"

  CONFIG_FILE="$config_file"

  log_info "Configuration loaded successfully"
  return 0
}

#######################################
# Load default configuration
#######################################
load_default_config() {
  local default_config
  default_config="$SCRIPT_DIR/config/defaults.conf"

  if [[ -f "$default_config" ]]; then
    load_config "$default_config"
  else
    log_verbose "No default config file, using built-in defaults"
  fi
}

#######################################
# Load user configuration
#######################################
load_user_config() {
  local user_config="${HOME}/.config/rom-organizer/config.conf"

  if [[ -f "$user_config" ]]; then
    log_info "Loading user configuration"
    load_config "$user_config"
  else
    log_verbose "No user config file found"
  fi
}

#######################################
# Get configuration value
# Arguments:
#   Configuration key
#   Optional default value
# Outputs:
#   Configuration value or default
#######################################
get_config() {
  local key="$1"
  local default="${2:-}"

  if [[ -n "${CONFIG[$key]:-}" ]]; then
    echo "${CONFIG[$key]}"
  else
    echo "$default"
  fi
}

#######################################
# Set configuration value
# Arguments:
#   Configuration key
#   Configuration value
#######################################
set_config() {
  local key="$1"
  local value="$2"

  CONFIG[$key]="$value"
  log_verbose "Config updated: $key = $value"
}

#######################################
# Validate configuration
# Returns:
#   0 if valid, 1 if invalid
#######################################
validate_config() {
  local valid=true

  # Validate fuzzy threshold
  local threshold="${CONFIG[fuzzy_threshold]}"
  if ! [[ "$threshold" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    log_error "Invalid fuzzy_threshold: $threshold"
    valid=false
  fi

  # Validate max results
  local max_results="${CONFIG[max_results]}"
  if ! [[ "$max_results" =~ ^[0-9]+$ ]]; then
    log_error "Invalid max_results: $max_results"
    valid=false
  fi

  # Validate cleanup days
  local cleanup_days="${CONFIG[cleanup_sessions_days]}"
  if ! [[ "$cleanup_days" =~ ^[0-9]+$ ]]; then
    log_error "Invalid cleanup_sessions_days: $cleanup_days"
    valid=false
  fi

  if [[ "$valid" == true ]]; then
    log_verbose "Configuration validation passed"
    return 0
  else
    log_error "Configuration validation failed"
    return 1
  fi
}

#######################################
# Save configuration to file
# Arguments:
#   Output file path
#######################################
save_config() {
  local output_file="$1"

  mkdir -p "$(dirname "$output_file")"

  cat > "$output_file" <<EOF
# ROM Organizer Configuration
# Generated: $(date '+%Y-%m-%d %H:%M:%S')

# Automatically select single matches without prompting
auto_select_single=${CONFIG[auto_select_single]}

# Prepend rating numbers to filenames by default
prepend_rating_default=${CONFIG[prepend_rating_default]}

# Fuzzy search threshold (lower = more strict matching)
fuzzy_threshold=${CONFIG[fuzzy_threshold]}

# Maximum number of search results to return
max_results=${CONFIG[max_results]}

# Enable dry-run mode by default
enable_dry_run=${CONFIG[enable_dry_run]}

# Enable session resume capability
enable_resume=${CONFIG[enable_resume]}

# Number of days to keep old session files
cleanup_sessions_days=${CONFIG[cleanup_sessions_days]}

# Create skip marker files for skipped queries
create_skip_markers=${CONFIG[create_skip_markers]}

EOF

  log_info "Configuration saved to: $output_file"
}

#######################################
# Initialize configuration system
# Loads default config, then user config, then command-line overrides
#######################################
init_config() {
  log_verbose "Initializing configuration system"

  # Load defaults
  load_default_config

  # Load user config (overrides defaults)
  load_user_config

  # Validate configuration
  if ! validate_config; then
    log_warning "Configuration has errors, some features may not work correctly"
  fi

  return 0
}

#######################################
# Display current configuration
#######################################
show_config() {
  echo "Current Configuration:"
  echo "======================"

  for key in "${!CONFIG[@]}"; do
    echo "  $key = ${CONFIG[$key]}"
  done

  echo ""
  echo "Config file: ${CONFIG_FILE:-none}"
}
