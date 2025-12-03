# Dynamic ROM Sources - Implementation Summary

## Overview

The ROM Organizer has been upgraded to support **dynamic, configurable ROM sources** instead of hardcoded Official/Translations directories. This enables users to add custom sources like Hacks, Homebrew, Beta versions, etc., with configurable search priorities.

## What Changed

### 1. Configuration System (`config/defaults.conf`)

**New Format:**
```bash
# ROM Source Configuration
# Format: sources=name:path:priority
sources=Official:Official:100
sources=Translations:Translations:200
sources=Hacks:Hacks:150
```

**Fields:**
- `name`: Display name for the source (e.g., "Official", "Hacks")
- `path`: Directory path (relative to base_dir or absolute)
- `priority`: Search priority (higher number = preferred in results)

**Legacy Support:**
- Old `official_dir` and `translations_dir` config keys still work
- Automatically migrated to new format if `sources` not defined

### 2. Configuration Parser (`lib/rom_config.sh`)

**New Functions:**
- `parse_sources()` - Parses source configuration into arrays
- `get_source_count()` - Returns number of configured sources
- `get_source_name(index)` - Get source name by index
- `get_source_path(index)` - Get source path by index
- `get_source_priority(index)` - Get source priority by index
- `get_primary_source()` - Get first/primary source path
- `show_sources()` - Display configured sources

**Global Arrays:**
- `SOURCE_NAMES[]` - Source display names
- `SOURCE_PATHS[]` - Source directory paths
- `SOURCE_PRIORITIES[]` - Source priority values

**Validation:**
- Checks for duplicate source names
- Checks for duplicate paths (case-insensitive)
- Validates priority is a number
- Ensures at least one source is configured

### 3. Directory Setup (`rom-organizer.sh`)

**Updated `setup_directories()`:**
- Calls `parse_sources()` to load source configuration
- Loops through all sources to build full paths
- Validates each source directory exists
- Sets legacy `OFFICIAL_DIR`/`TRANSLATIONS_DIR` for backward compatibility

**Updated `get_systems()`:**
- Uses primary source (index 0) for system enumeration
- Dynamically excludes all configured source directories
- Case-insensitive exclusion matching

### 4. Python Search Engine (`rom-search.py`)

**Updated `RomMatch` Dataclass:**
```python
@dataclass
class RomMatch:
    filename: str
    full_path: str
    source_type: str          # Dynamic source name
    source_priority: int      # Source priority value
    score: float
    size: int
    modified_time: float
```

**Updated `RomSearchEngine.__init__()`:**
- Accepts optional `sources` parameter (list of dicts)
- Falls back to legacy hardcoded sources if not provided
- Supports both legacy and dynamic modes

**Updated Search Functions:**
- `_scan_directory()` - Now accepts source_priority parameter
- `_build_index()` - Scans all configured sources dynamically
- `search()` - Sorts by priority, score, then size
- `get_systems()` - Scans all source directories

**Updated Cache System:**
- Uses `source_hashes` dict instead of hardcoded keys
- Each source tracked independently
- Cache invalidated if any source hash changes

**Command-Line Interface:**
- New `--sources` argument accepts JSON configuration
- Example: `--sources='[{"name":"Official","path":"Official","priority":100}]'`

### 5. Search Integration (`lib/rom_search.sh`)

**Updated `gather_matches()`:**
- Builds JSON sources configuration from bash arrays
- Passes sources to Python via `--sources` argument
- Dynamically includes all configured sources in search

### 6. System Validation (`lib/rom_utils.sh`)

**Updated `validate_system()`:**
- Uses primary source (first in list) for validation
- Falls back to legacy "Official" if sources not loaded
- Supports both absolute and relative paths

## Usage Examples

### Adding ROM Hacks

Edit `config/defaults.conf`:
```bash
sources=Official:Official:100
sources=Hacks:Hacks:150
sources=Translations:Translations:200
```

Result: Translations prioritized, then Hacks, then Official

### Using Absolute Paths

```bash
sources=Official:/media/roms/official:100
sources=Translations:/media/roms/translations:200
sources=External:/mnt/usb/roms:120
```

### Multiple Source Categories

```bash
sources=Official:Official:100
sources=Homebrew:Homebrew:120
sources=Hacks:Hacks:140
sources=Beta:Beta:160
sources=Translations:Translations:200
```

## Priority Guidelines

Recommended priority ranges:

- **100-149**: Original/Official ROMs
- **150-199**: Modifications (Hacks, Homebrew, Beta)
- **200+**: Translations (typically preferred)

Higher priority sources appear first in search results when match scores are equal.

## Search Behavior

### Old System
```
1. Search Official directory
2. Search Translations directory
3. Sort: Translations +10 bonus, prefer translations
```

### New System
```
1. Search ALL configured sources
2. Calculate fuzzy match scores
3. Sort by:
   a. Source priority (200 > 150 > 100)
   b. Match score (higher = better)
   c. File size (larger = preferred)
```

## Backward Compatibility

### Legacy Config Migration
If `sources` not defined in config:
1. Checks for `official_dir` config key
2. Checks for `translations_dir` config key
3. Falls back to hardcoded defaults:
   - `Official:Official:100`
   - `Translations:Translations:200`

### Legacy Variables
`OFFICIAL_DIR` and `TRANSLATIONS_DIR` still set to first two sources for compatibility with any external scripts.

## Cache Format

### Old Format
```json
{
  "version": "1.0",
  "official_hash": "abc123",
  "translations_hash": "def456",
  "matches": { ... }
}
```

### New Format
```json
{
  "version": "1.0",
  "source_hashes": {
    "Official": "abc123",
    "Translations": "def456",
    "Hacks": "789ghi"
  },
  "matches": {
    "Official": [...],
    "Translations": [...],
    "Hacks": [...]
  }
}
```

Cache automatically invalidated when format changes.

## Files Modified

1. `config/defaults.conf` - Added sources configuration
2. `lib/rom_config.sh` - Source parsing and validation
3. `rom-organizer.sh` - Dynamic directory setup and system enumeration
4. `lib/rom_search.sh` - JSON sources passed to Python
5. `lib/rom_utils.sh` - Dynamic system validation
6. `rom-search.py` - Full dynamic source support
7. `README.md` - Updated documentation
8. `ARCHITECTURE.md` - Added Dynamic ROM Sources section

## Testing Recommendations

1. **Default Configuration**
   - Verify default sources work (Official + Translations)
   - Check system enumeration
   - Run test searches

2. **Custom Sources**
   - Add a third source (e.g., Hacks)
   - Verify priority ordering in results
   - Check cache invalidation

3. **Edge Cases**
   - Empty sources list (should use defaults)
   - Duplicate source names (should error)
   - Non-existent directories (should error)
   - Absolute paths
   - Mixed absolute/relative paths

4. **Legacy Compatibility**
   - Remove sources config, verify fallback to legacy
   - Check OFFICIAL_DIR/TRANSLATIONS_DIR still set

## Migration Guide

### For Users

**Option 1: Keep Existing Setup** (No changes required)
- Script automatically uses Official + Translations

**Option 2: Add Custom Sources**
1. Edit `config/defaults.conf`
2. Add `sources=` entries for each source
3. Set appropriate priorities
4. Clear cache: `rm -rf /path/to/Roms/.rom_cache/*`
5. Run organizer

### For Developers

If you have scripts that depend on `OFFICIAL_DIR` or `TRANSLATIONS_DIR`:
- Variables still set for backward compatibility
- Consider migrating to `SOURCE_FULL_PATHS[]` array
- Use `get_source_path(0)` for primary source

## Performance Impact

- **Minimal**: Source parsing happens once at startup
- **Cache**: Still used, one entry per source
- **Search**: Marginal increase (scans more directories)
- **Memory**: Negligible (small arrays)

## Future Enhancements

Potential improvements:
1. Per-source fuzzy thresholds
2. Source-specific file type filters
3. Source groups (e.g., "Preferred" group)
4. UI to manage sources
5. Source metadata (description, icon, color)
6. Conditional sources (platform-specific)

## Conclusion

The dynamic sources system provides:
- ✅ Full backward compatibility
- ✅ User-configurable sources
- ✅ Priority-based search results
- ✅ Extensible architecture
- ✅ Clean separation of concerns
- ✅ Comprehensive validation

Users can now organize ROMs from multiple sources with fine-grained control over search priorities!
