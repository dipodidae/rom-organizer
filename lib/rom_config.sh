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

# ROM Source configuration arrays
declare -ga SOURCE_NAMES=()
declare -ga SOURCE_PATHS=()
declare -ga SOURCE_PRIORITIES=()
declare -g SOURCES_LOADED=false

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

#######################################
# Parse ROM source configuration
# Reads 'sources' entries from config and populates SOURCE_* arrays
# Format: sources=name:path:priority
# Arguments:
#   None (reads from CONFIG associative array)
# Returns:
#   0 on success, 1 on failure
#######################################
parse_sources() {
  local -a temp_sources=()
  local -A seen_names=()
  local -A seen_paths=()

  # Reset arrays
  SOURCE_NAMES=()
  SOURCE_PATHS=()
  SOURCE_PRIORITIES=()

  # Read config file again to get all 'sources' entries (since CONFIG doesn't handle multiples)
  if [[ -f "${CONFIG_FILE:-}" ]]; then
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

      # Collect source entries
      if [[ "$key" == "sources" ]]; then
        temp_sources+=("$value")
      fi
    done < "$CONFIG_FILE"
  fi

  # If no sources found, try legacy config (official_dir, translations_dir)
  if [[ ${#temp_sources[@]} -eq 0 ]]; then
    log_verbose "No 'sources' config found, attempting legacy config migration"

    local official_dir="${CONFIG[official_dir]:-}"
    local translations_dir="${CONFIG[translations_dir]:-}"

    if [[ -n "$official_dir" ]]; then
      temp_sources+=("Official:$official_dir:100")
      log_verbose "Added legacy Official source: $official_dir"
    fi

    if [[ -n "$translations_dir" ]]; then
      temp_sources+=("Translations:$translations_dir:200")
      log_verbose "Added legacy Translations source: $translations_dir"
    fi

    # If still nothing, use hardcoded defaults
    if [[ ${#temp_sources[@]} -eq 0 ]]; then
      log_warning "No sources configured, using hardcoded defaults"
      temp_sources=("Official:Official:100" "Translations:Translations:200")
    fi
  fi

  # Parse each source entry
  local index=0
  for source_entry in "${temp_sources[@]}"; do
    # Split by colon
    IFS=':' read -r name path priority <<< "$source_entry"

    # Trim components
    name=$(trim "$name")
    path=$(trim "$path")
    priority=$(trim "$priority")

    # Validate required fields
    if [[ -z "$name" ]]; then
      log_error "Source entry missing name: $source_entry"
      return 1
    fi

    if [[ -z "$path" ]]; then
      log_error "Source '$name' missing path"
      return 1
    fi

    if [[ -z "$priority" ]]; then
      log_warning "Source '$name' missing priority, defaulting to $((100 + index * 50))"
      priority=$((100 + index * 50))
    fi

    # Validate priority is a number
    if ! [[ "$priority" =~ ^[0-9]+$ ]]; then
      log_error "Source '$name' has invalid priority: $priority (must be a number)"
      return 1
    fi

    # Check for duplicate names
    if [[ -n "${seen_names[$name]:-}" ]]; then
      log_error "Duplicate source name: $name"
      return 1
    fi
    seen_names[$name]=1

    # Check for duplicate paths (case-insensitive)
    local path_lower="${path,,}"
    if [[ -n "${seen_paths[$path_lower]:-}" ]]; then
      log_error "Duplicate source path: $path (used by ${seen_paths[$path_lower]})"
      return 1
    fi
    seen_paths[$path_lower]="$name"

    # Add to arrays
    SOURCE_NAMES+=("$name")
    SOURCE_PATHS+=("$path")
    SOURCE_PRIORITIES+=("$priority")

    log_verbose "Source $index: name='$name', path='$path', priority=$priority"
    ((index++))
  done

  if [[ ${#SOURCE_NAMES[@]} -eq 0 ]]; then
    log_error "No valid sources configured"
    return 1
  fi

  SOURCES_LOADED=true
  log_info "Loaded ${#SOURCE_NAMES[@]} ROM source(s)"
  return 0
}

#######################################
# Get source count
# Returns:
#   Number of configured sources
#######################################
get_source_count() {
  echo "${#SOURCE_NAMES[@]}"
}

#######################################
# Get source name by index
# Arguments:
#   Index (0-based)
# Returns:
#   Source name or empty string
#######################################
get_source_name() {
  local index=$1
  if [[ $index -ge 0 && $index -lt ${#SOURCE_NAMES[@]} ]]; then
    echo "${SOURCE_NAMES[$index]}"
  fi
}

#######################################
# Get source path by index
# Arguments:
#   Index (0-based)
# Returns:
#   Source path or empty string
#######################################
get_source_path() {
  local index=$1
  if [[ $index -ge 0 && $index -lt ${#SOURCE_PATHS[@]} ]]; then
    echo "${SOURCE_PATHS[$index]}"
  fi
}

#######################################
# Get source priority by index
# Arguments:
#   Index (0-based)
# Returns:
#   Source priority or empty string
#######################################
get_source_priority() {
  local index=$1
  if [[ $index -ge 0 && $index -lt ${#SOURCE_PRIORITIES[@]} ]]; then
    echo "${SOURCE_PRIORITIES[$index]}"
  fi
}

#######################################
# Get primary source (first/index 0)
# Returns:
#   Primary source path
#######################################
get_primary_source() {
  get_source_path 0
}

#######################################
# Display source configuration
#######################################
show_sources() {
  echo "ROM Sources (in order):"
  echo "======================="

  if [[ ${#SOURCE_NAMES[@]} -eq 0 ]]; then
    echo "  No sources configured"
    return
  fi

  for i in "${!SOURCE_NAMES[@]}"; do
    echo "  [$i] ${SOURCE_NAMES[$i]}"
    echo "      Path: ${SOURCE_PATHS[$i]}"
    echo "      Priority: ${SOURCE_PRIORITIES[$i]}"
  done
}
