#!/bin/bash
# ROM Organizer - Core Operations
# This file contains ROM file operations: detection, extraction, copying, rank checking

# Global directory paths (set by config)
declare -g COLLECTIONS_DIR=""

#######################################
# Extract ROM from archive to destination directory
# Arguments:
#   Archive file path
#   Destination directory
# Returns:
#   0 on success, 1 on failure
#######################################
extract_rom() {
  local archive="$1"
  local dest_dir="$2"
  
  log_verbose "Extracting ROM from archive: $archive"
  
  # Create temporary directory for extraction
  local temp_dir
  temp_dir=$(create_temp_file ".extract.d")
  rm -f "$temp_dir"
  mkdir -p "$temp_dir"
  
  local ext
  ext=$(get_extension "$archive")
  
  log_verbose "Archive format: $ext"
  
  # Extract based on format
  case "$ext" in
    zip)
      if ! unzip -q "$archive" -d "$temp_dir" 2>&1 | tee -a "$LOG_FILE"; then
        ui_error "Failed to extract ZIP file: $(basename "$archive")"
        return 1
      fi
      ;;
      
    7z)
      if ! command -v 7z &>/dev/null; then
        ui_error "7z not available for extracting: $(basename "$archive")"
        return 1
      fi
      if ! 7z x "$archive" -o"$temp_dir" >/dev/null 2>&1; then
        ui_error "Failed to extract 7z file: $(basename "$archive")"
        return 1
      fi
      ;;
      
    rar)
      if ! command -v unrar &>/dev/null; then
        ui_error "unrar not available for extracting: $(basename "$archive")"
        return 1
      fi
      if ! unrar x "$archive" "$temp_dir/" >/dev/null 2>&1; then
        ui_error "Failed to extract RAR file: $(basename "$archive")"
        return 1
      fi
      ;;
      
    *)
      ui_error "Unsupported archive format: $ext"
      return 1
      ;;
  esac
  
  # Find and copy ROM files from extracted content
  local rom_found=false
  while IFS= read -r -d '' file; do
    local basename
    basename=$(basename "$file")
    
    if is_rom_file "$basename"; then
      log_verbose "Found ROM in archive: $basename"
      
      if cp "$file" "$dest_dir/"; then
        rom_found=true
        log_verbose "Copied ROM from archive: $basename"
      else
        ui_error "Failed to copy ROM file: $basename"
      fi
    fi
  done < <(find "$temp_dir" -type f -print0 2>/dev/null)
  
  # Cleanup is handled by trap
  
  if [[ "$rom_found" == true ]]; then
    log_verbose "Successfully extracted ROM(s) from archive"
    return 0
  else
    ui_error "No ROM files found in archive: $(basename "$archive")"
    return 1
  fi
}

#######################################
# Build final filename with optional rating prefix
# Arguments:
#   Original basename
#   Rating (optional)
#   Prepend rating flag (optional)
# Outputs:
#   Final filename
#######################################
build_filename() {
  local basename="$1"
  local rating="${2:-}"
  local prepend_rating="${3:-true}"
  
  if [[ "$prepend_rating" != "true" || -z "$rating" ]]; then
    echo "$basename"
    return
  fi
  
  # Split filename and extension
  local name_without_ext
  local file_ext
  name_without_ext=$(get_basename_no_ext "$basename")
  file_ext=$(get_extension "$basename")
  
  # Handle files without extensions
  if [[ "$name_without_ext" == "$basename" ]]; then
    echo "${rating}-${basename}"
  else
    echo "${rating}-${name_without_ext}.${file_ext}"
  fi
}

#######################################
# Copy ROM file to collection directory
# Handles archives by extracting ROMs and regular ROM files directly
# Arguments:
#   Source file path
#   System name
#   Collection name
#   Rating (optional)
#   Prepend rating flag (optional)
# Returns:
#   0 on success, 1 on failure
#######################################
copy_rom_file() {
  local source="$1"
  local system="$2"
  local collection="$3"
  local rating="${4:-}"
  local prepend_rating="${5:-true}"
  
  if ! validate_file_path "$source"; then
    ui_error "Invalid source file: $source"
    return 1
  fi
  
  local dest_dir="$COLLECTIONS_DIR/$system/$collection"
  
  log_verbose "Copying ROM to: $dest_dir"
  log_verbose "  Source: $source"
  log_verbose "  Rating: ${rating:-none}"
  log_verbose "  Prepend: $prepend_rating"
  
  # Handle dry run mode
  if [[ "$DRY_RUN" == true ]]; then
    ui_dry_run_notice "copy $(basename "$source") to $dest_dir"
    return 0
  fi
  
  # Create destination directory
  if ! mkdir -p "$dest_dir"; then
    ui_error "Failed to create directory: $dest_dir"
    return 1
  fi
  
  local basename
  basename=$(basename "$source")
  
  # Check if source is an archive
  if is_archive_file "$basename"; then
    log_verbose "Source is an archive, extracting..."
    ui_muted "Extracting $(basename "$source")..."
    
    # Create temporary directory for extraction
    local temp_dir
    temp_dir=$(create_temp_file ".extract.d")
    rm -f "$temp_dir"
    mkdir -p "$temp_dir"
    
    # Extract ROM from archive
    if extract_rom "$source" "$temp_dir"; then
      # Find extracted ROM files and copy them with rating prefix
      local rom_found=false
      
      while IFS= read -r -d '' extracted_file; do
        local extracted_basename
        extracted_basename=$(basename "$extracted_file")
        
        if is_rom_file "$extracted_basename"; then
          local final_name
          final_name=$(build_filename "$extracted_basename" "$rating" "$prepend_rating")
          
          log_verbose "Copying extracted ROM: $extracted_basename -> $final_name"
          
          if cp "$extracted_file" "$dest_dir/$final_name"; then
            rom_found=true
            ui_success "Extracted $basename to $collection"
            
            if [[ "$prepend_rating" == "true" && -n "$rating" ]]; then
              ui_muted "  → Renamed to: $final_name"
            fi
          else
            ui_error "Failed to copy extracted ROM file: $extracted_basename"
          fi
        fi
      done < <(find "$temp_dir" -type f -print0 2>/dev/null)
      
      if [[ "$rom_found" != true ]]; then
        ui_error "No ROM files found in archive: $basename"
        return 1
      fi
    else
      ui_error "Failed to extract ROM from $basename"
      return 1
    fi
  else
    # Direct ROM file copy
    local final_name
    final_name=$(build_filename "$basename" "$rating" "$prepend_rating")
    
    log_verbose "Copying ROM file: $basename -> $final_name"
    
    if cp "$source" "$dest_dir/$final_name"; then
      ui_success "Copied $basename to $collection"
      
      if [[ "$prepend_rating" == "true" && -n "$rating" ]]; then
        ui_muted "  → Renamed to: $final_name"
      fi
    else
      ui_error "Failed to copy $basename"
      return 1
    fi
  fi
  
  return 0
}

#######################################
# Check if a ROM with the given rank already exists in collection
# Arguments:
#   System name
#   Collection name
#   Rating/rank number
# Returns:
#   0 if rank exists, 1 otherwise
#######################################
check_rank_exists() {
  local system="$1"
  local collection="$2"
  local rating="$3"
  
  local dest_dir="$COLLECTIONS_DIR/$system/$collection"
  
  log_verbose "Checking if rank $rating exists in: $dest_dir"
  
  # If destination directory doesn't exist, no ROM exists
  if [[ ! -d "$dest_dir" ]]; then
    log_verbose "Destination directory does not exist"
    return 1
  fi
  
  # Check if any file starts with the rating pattern (e.g., "001-")
  local pattern="${rating}-*"
  
  if compgen -G "$dest_dir/$pattern" >/dev/null 2>&1; then
    log_verbose "Found existing ROM(s) with rank $rating"
    return 0
  else
    log_verbose "No ROM with rank $rating found"
    return 1
  fi
}

#######################################
# Find all .skipped marker files in a collection directory
# Arguments:
#   System name
#   Collection name
# Outputs:
#   List of skipped filenames to STDOUT
#######################################
find_skipped_files() {
  local system="$1"
  local collection="$2"
  local skip_dir="$COLLECTIONS_DIR/$system/$collection"
  
  log_verbose "Finding skipped files in: $skip_dir"
  
  if [[ ! -d "$skip_dir" ]]; then
    log_verbose "Skip directory does not exist"
    return 0
  fi
  
  # Find all .skipped files
  find "$skip_dir" -name "*.skipped" -type f -printf "%f\n" 2>/dev/null || true
}

#######################################
# Extract original query from a .skipped marker file
# Arguments:
#   Skipped filename (e.g., "001-query.skipped")
# Outputs:
#   Original query string
#######################################
extract_query_from_skipped_file() {
  local skipped_file="$1"
  
  log_verbose "Extracting query from skipped file: $skipped_file"
  
  # Remove .skipped extension
  local basename="${skipped_file%.skipped}"
  
  # Remove rating prefix if present (e.g., "001-" or "042-")
  if [[ "$basename" =~ ^[0-9]+-(.+)$ ]]; then
    echo "${BASH_REMATCH[1]}"
  else
    echo "$basename"
  fi
}

#######################################
# Create a skip marker file for a query
# Arguments:
#   System name
#   Collection name
#   Original query
#   Rating (optional)
#######################################
create_skip_marker() {
  local system="$1"
  local collection="$2"
  local query="$3"
  local rating="${4:-}"
  
  local dest_dir="$COLLECTIONS_DIR/$system/$collection"
  
  log_verbose "Creating skip marker for: $query"
  
  # Handle dry run mode
  if [[ "$DRY_RUN" == true ]]; then
    ui_dry_run_notice "create skip marker for: $query"
    return 0
  fi
  
  # Create destination directory if needed
  mkdir -p "$dest_dir"
  
  # Build marker filename
  local marker_name
  if [[ -n "$rating" ]]; then
    marker_name="${rating}-${query}.skipped"
  else
    marker_name="${query}.skipped"
  fi
  
  # Sanitize filename (remove problematic characters)
  marker_name=$(echo "$marker_name" | tr '/' '_' | tr '\\' '_')
  
  local marker_path="$dest_dir/$marker_name"
  
  # Create marker file with metadata
  cat > "$marker_path" <<EOF
# Skipped Query Marker
# Created: $(date '+%Y-%m-%d %H:%M:%S')
# Query: $query
# System: $system
# Collection: $collection
# Rating: ${rating:-none}
EOF
  
  log_verbose "Created skip marker: $marker_path"
  ui_info "Created skip marker for: $query"
  
  return 0
}

#######################################
# Get list of ROM files in a directory
# Arguments:
#   Directory path
# Outputs:
#   List of ROM files (one per line)
#######################################
list_rom_files() {
  local directory="$1"
  
  if [[ ! -d "$directory" ]]; then
    log_verbose "Directory does not exist: $directory"
    return 1
  fi
  
  find "$directory" -type f -print0 2>/dev/null | while IFS= read -r -d '' file; do
    local basename
    basename=$(basename "$file")
    
    if is_rom_file "$basename"; then
      echo "$file"
    fi
  done
}

#######################################
# Count ROM files in a directory
# Arguments:
#   Directory path
# Outputs:
#   Number of ROM files
#######################################
count_rom_files() {
  local directory="$1"
  
  list_rom_files "$directory" | wc -l
}
