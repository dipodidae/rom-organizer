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
  # Auto-detect base directory if not set
  if [[ -n "${ROM_BASE_DIR:-}" ]]; then
    BASE_DIR="$ROM_BASE_DIR"
    log_verbose "Using ROM_BASE_DIR: $BASE_DIR"
  else
    BASE_DIR="$(dirname "$SCRIPT_DIR")"
    log_verbose "Auto-detected base directory: $BASE_DIR"
  fi
  
  ROMS_DIR="$BASE_DIR"
  OFFICIAL_DIR="$ROMS_DIR/Official"
  TRANSLATIONS_DIR="$ROMS_DIR/Translations"
  LISTS_DIR="$ROMS_DIR/Lists"
  COLLECTIONS_DIR="$ROMS_DIR/Collections"
  
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
  local -a list_files=()
  while IFS= read -r -d '' file; do
    list_files+=("$(basename "$file")")
  done < <(find "$LISTS_DIR" -name "*.txt" -type f -print0 2>/dev/null)
  
  if [[ ${#list_files[@]} -eq 0 ]]; then
    ui_error "No text files found in $LISTS_DIR"
    exit "$EXIT_GENERAL_ERROR"
  fi
  
  local selected_list
  if ! selected_list=$(ui_choose "Select query list:" "${list_files[@]}"); then
    ui_muted "No list selected, exiting"
    exit "$EXIT_USER_CANCELLED"
  fi
  
  local list_file="$LISTS_DIR/$selected_list"
  local collection_name="${selected_list%.*}"
  
  # Select system
  local -a systems=()
  readarray -t systems < <(get_systems)
  
  local selected_system
  if ! selected_system=$(ui_choose "Select system:" "${systems[@]}"); then
    ui_muted "No system selected, exiting"
    exit "$EXIT_USER_CANCELLED"
  fi
  
  ui_success "Processing collection: $collection_name for system: $selected_system"
  
  # Initialize session
  init_session "$collection_name" "$selected_system" "$list_file"
  
  # Count total queries
  local total_queries=0
  while IFS= read -r query <&3; do
    [[ -z "$query" || "$query" =~ ^[[:space:]]*# ]] && continue
    query=$(trim "$query")
    [[ -z "$query" ]] && continue
    ((total_queries++))
  done 3<"$list_file"
  
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
  
  # Process queries
  local line_number=0
  local processed_count=0
  
  while IFS= read -r query <&3; do
    ((line_number++))
    
    # Skip empty lines and comments
    [[ -z "$query" || "$query" =~ ^[[:space:]]*# ]] && continue
    query=$(trim "$query")
    [[ -z "$query" ]] && continue
    
    ((processed_count++))
    STATS[processed]=$processed_count
    
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
    
  done 3<"$list_file"
  
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
