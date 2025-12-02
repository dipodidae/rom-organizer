#!/bin/bash
# ROM Organizer - Query Processing
# This file contains query processing logic including shared titles and manual queries

#######################################
# Detect if query contains shared titles (separated by /, &, +, or "and")
# Arguments:
#   Query string to check
# Returns:
#   0 if shared titles detected, 1 otherwise
#######################################
detect_shared_titles() {
  local query="$1"

  # Check for common sharing patterns
  if [[ "$query" =~ $SHARED_TITLE_SEPARATOR_PATTERN || "$query" =~ [[:space:]]and[[:space:]] ]]; then
    log_verbose "Detected potential shared title: $query"
    return 0
  fi

  return 1
}

#######################################
# Split shared query into individual titles
# Arguments:
#   Query string containing separators
# Outputs:
#   Individual titles (one per line) to STDOUT
#######################################
split_shared_query() {
  local query="$1"
  local -a shared_queries=()

  # Replace common connectors with a standard delimiter
  local standardized_query
  standardized_query=$(echo "$query" | sed 's/[\/\&+]/#/g' | sed 's/ and /#/g')

  # Split by delimiter
  IFS='#' read -ra parts <<< "$standardized_query"

  # Trim whitespace from each part and validate
  for part in "${parts[@]}"; do
    part=$(trim "$part")

    if [[ -n "$part" ]]; then
      # Validate sub-query
      if validate_query "$part"; then
        shared_queries+=("$part")
      else
        log_warning "Invalid sub-query in shared title: $part"
      fi
    fi
  done

  # Output results
  printf '%s\n' "${shared_queries[@]}"

  log_verbose "Split shared query into ${#shared_queries[@]} parts"
}

#######################################
# Process manual query with user input
# Arguments:
#   Original query string
#   System name
#   Collection name
#   Rating (optional)
#   Prepend rating flag (optional)
# Returns:
#   0 on success or skip, 1 on failure
#######################################
process_manual_query() {
  local original_query="$1"
  local system="$2"
  local collection="$3"
  local rating="${4:-}"
  local prepend_rating="${5:-true}"

  ui_message "$COLOR_SHARED" "Original query: $original_query"
  ui_muted "Type 'skip' to skip this query and save a skipped marker"

  # Get user input
  local new_query
  if ! new_query=$(ui_input "Enter modified query (or 'skip'): " "$original_query"); then
    ui_muted "Manual query cancelled, skipping without marker"
    return 0
  fi

  # Check for skip command
  if [[ "$new_query" == "skip" ]]; then
    ui_warning "Skipping query and saving skip marker"
    create_skip_marker "$system" "$collection" "$original_query" "$rating"
    return 0
  fi

  # Process the new query
  process_query "$new_query" "$system" "$collection" "$original_query" "$rating" "$prepend_rating"
}

#######################################
# Process shared title query
# Arguments:
#   Query string
#   System name
#   Collection name
#   Original query (optional)
#   Rating (optional)
#   Prepend rating flag (optional)
# Returns:
#   0 on success, 1 on failure
#######################################
process_shared_title_query() {
  local query="$1"
  local system="$2"
  local collection="$3"
  local original_query="${4:-$query}"
  local rating="${5:-}"
  local prepend_rating="${6:-true}"

  # Split query into sub-queries
  local -a sub_queries=()
  readarray -t sub_queries < <(split_shared_query "$query")

  if [[ ${#sub_queries[@]} -lt $SHARED_TITLE_MIN_PARTS ]]; then
    log_verbose "Not enough valid sub-queries, falling back to standard processing"
    return 1
  fi

  ui_message "$COLOR_SHARED" "Processing shared title: $query"
  ui_muted "Detected ${#sub_queries[@]} related titles: ${sub_queries[*]}"

  # Collect matches for all sub-queries
  local -a all_options=()
  local -a all_file_paths=()

  for sub_query in "${sub_queries[@]}"; do
    ui_info "Finding matches for: $sub_query"

    local results
    results=$(gather_matches "$sub_query" "$system")

    local -a display_names=()
    local -a file_paths=()
    parse_search_results "$results" display_names file_paths

    if [[ ${#display_names[@]} -eq 0 ]]; then
      ui_error "No matches found for: $sub_query"
    else
      ui_success "Found ${#display_names[@]} matches for: $sub_query"

      # Add to combined lists with prefix
      for i in "${!display_names[@]}"; do
        all_options+=("[$sub_query] ${display_names[$i]}")
        all_file_paths+=("${file_paths[$i]}")
      done
    fi
  done

  if [[ ${#all_options[@]} -eq 0 ]]; then
    ui_error "No matches found for any title in: $query"
    return 1
  fi

  # Build selection menu with control options
  local -a menu_options=()
  menu_options+=("🔄 [Shared Rank] Select multiple games")
  menu_options+=("${all_options[@]}")
  menu_options+=("${SYMBOL_MANUAL} Manual query")
  menu_options+=("${SYMBOL_SKIP} Skip without marker")
  menu_options+=("${SYMBOL_MARKER} Skip with marker")

  # Show selection menu
  local choice
  if ! choice=$(ui_choose "Select for shared rank: $query" "${menu_options[@]}"); then
    ui_muted "Selection cancelled, skipping shared title: $query"
    return 0
  fi

  # Handle selection
  case "$choice" in
    "🔄 [Shared Rank] Select multiple games")
      handle_multi_select "$query" "$system" "$collection" "$rating" "$prepend_rating" all_options all_file_paths
      ;;

    "${SYMBOL_MANUAL} Manual query")
      process_manual_query "$original_query" "$system" "$collection" "$rating" "$prepend_rating"
      ;;

    "${SYMBOL_SKIP} Skip without marker")
      ui_muted "Skipped: $query (no marker created)"
      ;;

    "${SYMBOL_MARKER} Skip with marker")
      ui_warning "Skipped: $query (with marker)"
      create_skip_marker "$system" "$collection" "$original_query" "$rating"
      ;;

    "")
      ui_muted "No selection made, skipping: $query"
      ;;

    *)
      # Single selection from matches
      handle_single_selection "$choice" "$system" "$collection" "$rating" "$prepend_rating" all_options all_file_paths
      ;;
  esac

  return 0
}

#######################################
# Handle multi-select for shared rank
# Arguments:
#   Query string
#   System name
#   Collection name
#   Rating
#   Prepend rating flag
#   Options array name
#   File paths array name
#######################################
handle_multi_select() {
  local query="$1"
  local system="$2"
  local collection="$3"
  local rating="$4"
  local prepend_rating="$5"
  local -n options_ref="$6"
  local -n paths_ref="$7"

  ui_message "$COLOR_HIGHLIGHT" "Select multiple games to share rank $rating"

  # Get selections (using gum choose with --no-limit)
  local selected_items
  if ! command -v gum &>/dev/null; then
    ui_error "Multi-select requires gum"
    return 1
  fi

  set +e
  # Don't capture output - let it flow to a file instead
  local temp_selections
  temp_selections=$(mktemp)
  gum choose --no-limit --header "Select games for shared rank $rating:" "${options_ref[@]}" > "$temp_selections"
  local exit_code=$?
  selected_items=$(cat "$temp_selections")
  rm -f "$temp_selections"
  set -e

  if [[ $exit_code -ne 0 || -z "$selected_items" ]]; then
    ui_muted "No games selected for shared rank, skipping"
    return 0
  fi

  # Process each selection
  local success_count=0

  while IFS= read -r selected; do
    # Skip control options
    if [[ "$selected" =~ ^(🔍|⏭️|📝|🔄) ]]; then
      continue
    fi

    # Find matching file path
    for i in "${!options_ref[@]}"; do
      if [[ "${options_ref[$i]}" == "$selected" ]]; then
        ui_muted "Copying: ${selected#*] }"

        if copy_rom_file "${paths_ref[$i]}" "$system" "$collection" "$rating" "$prepend_rating"; then
          ((success_count++))
        fi

        break
      fi
    done
  done <<< "$selected_items"

  if [[ $success_count -gt 0 ]]; then
    ui_success "Added $success_count games with shared rank $rating"
  else
    ui_error "No games were successfully added to the collection"
  fi
}

#######################################
# Handle single selection from match list
# Arguments:
#   Selected option text
#   System name
#   Collection name
#   Rating
#   Prepend rating flag
#   Options array name
#   File paths array name
#######################################
handle_single_selection() {
  local choice="$1"
  local system="$2"
  local collection="$3"
  local rating="$4"
  local prepend_rating="$5"
  local -n options_ref="$6"
  local -n paths_ref="$7"

  # Find matching file path
  for i in "${!options_ref[@]}"; do
    if [[ "${options_ref[$i]}" == "$choice" ]]; then
      if copy_rom_file "${paths_ref[$i]}" "$system" "$collection" "$rating" "$prepend_rating"; then
        ui_success "Added single game with rank $rating: ${choice#*] }"
      fi
      return 0
    fi
  done

  ui_error "Invalid selection"
  return 1
}

#######################################
# Process a single query
# Main entry point for query processing
# Arguments:
#   Query string
#   System name
#   Collection name
#   Original query (optional)
#   Rating (optional)
#   Prepend rating flag (optional)
# Returns:
#   0 on success, 1 on failure
#######################################
process_query() {
  local query="$1"
  local system="$2"
  local collection="$3"
  local original_query="${4:-$query}"
  local rating="${5:-}"
  local prepend_rating="${6:-true}"

  ui_header "Processing: $query"

  # Validate inputs
  if ! validate_query "$query"; then
    ui_error "Invalid query: $query"
    return 1
  fi

  # Check if this is a shared title query
  if detect_shared_titles "$query"; then
    ui_message "$COLOR_SHARED" "Detected shared title format: $query"

    if process_shared_title_query "$query" "$system" "$collection" "$original_query" "$rating" "$prepend_rating"; then
      return 0
    else
      ui_warning "Falling back to standard processing for: $query"
    fi
  fi

  # Gather matches
  local results
  results=$(gather_matches "$query" "$system")

  local -a display_names=()
  local -a file_paths=()
  parse_search_results "$results" display_names file_paths

  # Handle no matches
  if [[ ${#display_names[@]} -eq 0 ]]; then
    ui_error "No matches found for: $query"
    process_manual_query "$original_query" "$system" "$collection" "$rating" "$prepend_rating"
    return 0
  fi

  # Auto-select if only one match
  if [[ ${#display_names[@]} -eq 1 ]]; then
    ui_success "Auto-selected only match: ${display_names[0]}"
    copy_rom_file "${file_paths[0]}" "$system" "$collection" "$rating" "$prepend_rating"
    return 0
  fi

  # Multiple matches - show selection menu
  local choice
  if ! choice=$(ui_select_match "$query" display_names); then
    ui_muted "Selection cancelled, skipping: $query"
    return 0
  fi

  # Handle user selection
  case "$choice" in
    "${SYMBOL_MANUAL} Manual query")
      process_manual_query "$original_query" "$system" "$collection" "$rating" "$prepend_rating"
      ;;

    "${SYMBOL_SKIP} Skip without marker")
      ui_muted "Skipped: $query (no marker created)"
      ;;

    "${SYMBOL_MARKER} Skip with marker")
      ui_warning "Skipped: $query (with marker)"
      create_skip_marker "$system" "$collection" "$original_query" "$rating"
      ;;

    "")
      ui_muted "No selection made, skipping: $query"
      ;;

    *)
      # Find and copy selected file
      for i in "${!display_names[@]}"; do
        if [[ "${display_names[$i]}" == "$choice" ]]; then
          copy_rom_file "${file_paths[$i]}" "$system" "$collection" "$rating" "$prepend_rating"
          break
        fi
      done
      ;;
  esac

  return 0
}
