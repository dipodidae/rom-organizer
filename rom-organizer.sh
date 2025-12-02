#!/bin/bash
# ROM Collection Organizer v2.0.0
# Refactored modular architecture with comprehensive error handling
# and session management

set -euo pipefail  # Strict mode: exit on error, undefined vars, pipe failures

# Determine script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

# Source all modules
# shellcheck source=lib/rom_constants.sh
source "$LIB_DIR/rom_constants.sh"
# shellcheck source=lib/rom_utils.sh
source "$LIB_DIR/rom_utils.sh"
# shellcheck source=lib/rom_ui.sh
source "$LIB_DIR/rom_ui.sh"
# shellcheck source=lib/rom_config.sh
source "$LIB_DIR/rom_config.sh"
# shellcheck source=lib/rom_core.sh
source "$LIB_DIR/rom_core.sh"
# shellcheck source=lib/rom_search.sh
source "$LIB_DIR/rom_search.sh"
# shellcheck source=lib/rom_query.sh
source "$LIB_DIR/rom_query.sh"
# shellcheck source=lib/rom_state.sh
source "$LIB_DIR/rom_state.sh"

# Parse command line arguments
parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      -h|--help)
        ui_show_help
        exit "$EXIT_SUCCESS"
        ;;
      -v|--verbose)
        VERBOSE=true
        shift
        ;;
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      --version)
        ui_show_version
        exit "$EXIT_SUCCESS"
        ;;
      --config)
        if [[ -n "${2:-}" ]]; then
          load_config "$2"
          shift 2
        else
          ui_error "Missing config file argument"
          exit "$EXIT_GENERAL_ERROR"
        fi
        ;;
      --resume)
        # This flag is handled in main()
        shift
        ;;
      *)
        ui_error "Unknown option: $1"
        ui_muted "Use -h or --help for usage information"
        exit "$EXIT_GENERAL_ERROR"
        ;;
    esac
  done
}

# Check dependencies
check_dependencies() {
  local missing_deps=()

  # Required tools
  for tool in gum unzip python3; do
    if ! command -v "$tool" &>/dev/null; then
      missing_deps+=("$tool")
    fi
  done

  if [[ ${#missing_deps[@]} -gt 0 ]]; then
    echo "Error: The following required tools are not installed: ${missing_deps[*]}"
    echo "Please install them first."
    exit "$EXIT_MISSING_DEPS"
  fi

  # Initialize search engine
  if ! init_search_engine; then
    exit "$EXIT_MISSING_DEPS"
  fi

  # Check optional tools
  local optional_missing=()
  for tool in 7z unrar; do
    if ! command -v "$tool" &>/dev/null; then
      optional_missing+=("$tool")
    fi
  done

  if [[ ${#optional_missing[@]} -gt 0 ]]; then
    ui_warning "Optional tools not found: ${optional_missing[*]}"
    ui_muted "Some archive formats may not be supported."
  fi
}

# Setup directory paths
setup_directories() {
  # Check for base directory from config first, then environment, then auto-detect
  local config_base_dir
  config_base_dir="$(get_config "base_dir")"

  if [[ -n "$config_base_dir" ]]; then
    BASE_DIR="$config_base_dir"
    log_verbose "Using base_dir from config: $BASE_DIR"
  elif [[ -n "${ROM_BASE_DIR:-}" ]]; then
    BASE_DIR="$ROM_BASE_DIR"
    log_verbose "Using ROM_BASE_DIR: $BASE_DIR"
  else
    # Auto-detect: go up two levels from script directory
    # SCRIPT_DIR is typically /path/to/Roms/Scripts/organizer
    # We want BASE_DIR to be /path/to/Roms
    BASE_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
    log_verbose "Auto-detected base directory: $BASE_DIR"
  fi

  # Get directory names from config or use defaults
  local official_subdir translations_subdir lists_subdir collections_subdir
  official_subdir="$(get_config "official_dir" "Official")"
  translations_subdir="$(get_config "translations_dir" "Translations")"
  lists_subdir="$(get_config "lists_dir" "Lists")"
  collections_subdir="$(get_config "collections_dir" "Collections")"

  # Build full paths (support both relative and absolute paths)
  if [[ "$official_subdir" = /* ]]; then
    OFFICIAL_DIR="$official_subdir"
  else
    OFFICIAL_DIR="$BASE_DIR/$official_subdir"
  fi

  if [[ "$translations_subdir" = /* ]]; then
    TRANSLATIONS_DIR="$translations_subdir"
  else
    TRANSLATIONS_DIR="$BASE_DIR/$translations_subdir"
  fi

  if [[ "$lists_subdir" = /* ]]; then
    LISTS_DIR="$lists_subdir"
  else
    LISTS_DIR="$BASE_DIR/$lists_subdir"
  fi

  if [[ "$collections_subdir" = /* ]]; then
    COLLECTIONS_DIR="$collections_subdir"
  else
    COLLECTIONS_DIR="$BASE_DIR/$collections_subdir"
  fi

  # shellcheck disable=SC2034  # ROMS_DIR used by sourcing scripts or for future use
  ROMS_DIR="$BASE_DIR"

  # Validate directories exist
  for dir in "$OFFICIAL_DIR" "$TRANSLATIONS_DIR" "$LISTS_DIR"; do
    if [[ ! -d "$dir" ]]; then
      ui_error "Required directory not found: $dir"
      exit "$EXIT_INVALID_CONFIG"
    fi
  done

  # Create collections directory if needed
  mkdir -p "$COLLECTIONS_DIR"
}

# Get available systems with priority ordering
get_systems() {
  local -a systems=()

  while IFS= read -r -d '' dir; do
    local basename
    basename=$(basename "$dir")
    if [[ "$basename" != "Official" ]]; then
      systems+=("$basename")
    fi
  done < <(find "$OFFICIAL_DIR" -maxdepth 1 -type d -print0 2>/dev/null)

  if [[ ${#systems[@]} -eq 0 ]]; then
    ui_error "No system folders found in $OFFICIAL_DIR"
    exit "$EXIT_INVALID_CONFIG"
  fi

  # Sort with priority systems first
  local -a priority_systems=()
  local -a other_nintendo=()
  local -a other_systems=()

  for system in "${systems[@]}"; do
    local is_priority=false

    for priority in "${PRIORITY_SYSTEMS[@]}"; do
      if [[ "$system" == "$priority" ]]; then
        priority_systems+=("$system")
        is_priority=true
        break
      fi
    done

    if [[ "$is_priority" == false ]]; then
      if [[ "$system" == Nintendo* ]]; then
        other_nintendo+=("$system")
      else
        other_systems+=("$system")
      fi
    fi
  done

  # Sort and combine
  readarray -t other_nintendo < <(printf '%s\n' "${other_nintendo[@]}" | sort)
  readarray -t other_systems < <(printf '%s\n' "${other_systems[@]}" | sort)

  printf '%s\n' "${priority_systems[@]}" "${other_nintendo[@]}" "${other_systems[@]}"
}

# Main workflow
main() {
  # Initialize
  init_logging
  init_config
  parse_arguments "$@"

  log_info "ROM Collection Organizer v${ROM_ORGANIZER_VERSION}"

  if [[ "$DRY_RUN" == true ]]; then
    ui_warning "DRY RUN MODE - No changes will be made"
  fi

  check_dependencies
  setup_directories

  ui_title "ROM Collection Organizer"

  # Select list file
  log_verbose "Searching for list files in: $LISTS_DIR"
  local -a list_files=()
  while IFS= read -r -d '' file; do
    list_files+=("$(basename "$file")")
  done < <(find "$LISTS_DIR" -name "*.txt" -type f -print0 2>/dev/null)

  log_verbose "Found ${#list_files[@]} list files"
  if [[ ${#list_files[@]} -eq 0 ]]; then
    ui_error "No text files found in $LISTS_DIR"
    exit "$EXIT_GENERAL_ERROR"
  fi

  log_verbose "About to display list selection menu"
  local selected_list
  if ! selected_list=$(ui_choose "Select query list:" "${list_files[@]}"); then
    ui_muted "No list selected, exiting"
    exit "$EXIT_USER_CANCELLED"
  fi

  log_verbose "List selected: $selected_list"
  local list_file="$LISTS_DIR/$selected_list"
  local collection_name="${selected_list%.*}"

  # Select system
  log_verbose "Getting available systems"
  local -a systems=()
  readarray -t systems < <(get_systems)

  log_verbose "Found ${#systems[@]} systems"
  log_verbose "About to display system selection menu"
  local selected_system
  if ! selected_system=$(ui_choose "Select system:" "${systems[@]}"); then
    ui_muted "No system selected, exiting"
    exit "$EXIT_USER_CANCELLED"
  fi

  ui_success "Processing collection: $collection_name for system: $selected_system"

  # Initialize session
  init_session "$collection_name" "$selected_system" "$list_file"

  log_info "DEBUG: About to count queries from $list_file"
  
  # Count total queries
  log_verbose "Counting queries in: $list_file"
  if [[ ! -f "$list_file" ]]; then
    log_error "List file not found: $list_file"
    exit "$EXIT_GENERAL_ERROR"
  fi
  
  local total_queries=0
  set +e  # Temporarily disable exit on error for the loop
  while IFS= read -r query <&3; do
    [[ -z "$query" || "$query" =~ ^[[:space:]]*# ]] && continue
    trimmed=$(trim "$query")
    [[ -z "$trimmed" ]] && continue
    query="$trimmed"
    ((total_queries++))
  done 3<"$list_file"
  set -e  # Re-enable exit on error
  
  log_verbose "Counted $total_queries queries"

  STATS[total]=$total_queries
  log_info "Found $total_queries queries in file"

  # Calculate rating digits
  local rating_digits
  rating_digits=$(calculate_rating_digits "$total_queries")

  # Ask about rating prefix
  local prepend_rating
  if ui_confirm "Prepend rating numbers to filenames?" "true"; then
    prepend_rating="true"
    ui_success "Ratings will be prepended with $rating_digits digits"
  else
    prepend_rating="false"
    ui_muted "No ratings will be prepended"
  fi
  
  log_verbose "Starting query processing"

  # Process queries
  log_info "Starting to process queries from: $list_file"
  
  # Verify file is readable
  if [[ ! -r "$list_file" ]]; then
    log_error "Cannot read list file: $list_file"
    exit "$EXIT_GENERAL_ERROR"
  fi
  
  local line_number=0
  local processed_count=0

  log_info "Entering main processing loop"
  
  # Disable exit on error for the read loop
  set +e
  while IFS= read -r query; do
    set -e  # Re-enable for loop body
    
    line_number=$((line_number + 1))
    log_verbose "Read line $line_number: '$query'"

    # Skip empty lines and comments
    if [[ -z "$query" || "$query" =~ ^[[:space:]]*# ]]; then
      log_verbose "Skipping line $line_number (empty or comment)"
      set +e
      continue
    fi
    
    query=$(trim "$query")
    if [[ -z "$query" ]]; then
      log_verbose "Skipping line $line_number (empty after trim)"
      set +e
      continue
    fi

    processed_count=$((processed_count + 1))
    STATS[processed]=$processed_count
    log_info "Processing query $processed_count/$total_queries: $query"

    # Generate rating
    local rating=""
    if [[ "$prepend_rating" == "true" ]]; then
      rating=$(format_rating "$processed_count" "$rating_digits")
    fi

    ui_query_header "$query" "$processed_count" "$total_queries" "$rating"

    # Check if rank already exists
    if [[ "$prepend_rating" == "true" && -n "$rating" ]]; then
      if check_rank_exists "$selected_system" "$collection_name" "$rating"; then
        ui_warning "Skipping: ROM with rank $rating already exists"
        record_skip "$query" "rank_exists"
        continue
      fi
    fi

    # Process query
    if process_query "$query" "$selected_system" "$collection_name" "$query" "$rating" "$prepend_rating"; then
      record_success "$query" "" "processed"
    fi

    # Update session state
    update_session "$line_number"
    
    log_verbose "Finished processing query $processed_count, line $line_number"
    set +e  # Disable for next read iteration

  done < "$list_file"
  set -e  # Re-enable after loop

  log_info "Completed processing loop (processed $processed_count queries)"

  # Complete session
  complete_session

  # Show summary
  ui_show_summary "${STATS[total]}" "${STATS[success]}" "${STATS[skipped]}" "${STATS[errors]}"

  # Write detailed summary
  local summary_file="${HOME}/.rom-organizer/summaries/summary_${SESSION_ID}.txt"
  mkdir -p "$(dirname "$summary_file")"
  write_summary "$summary_file"

  ui_success "Collection processing complete!"
  ui_muted "Summary: $summary_file"
  ui_muted "Log: $LOG_FILE"
}

# Run main
main "$@"
