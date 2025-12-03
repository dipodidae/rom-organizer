# ROM Collection Organizer

A modular ROM collection management tool with fuzzy search, automatic organization, and session tracking.

## Introduction

This tool organizes ROM collections by processing query lists and copying matching files into collection directories. It searches across configurable ROM sources with priority-based ranking, handles multi-game cartridges, and tracks operations through session state files.

Features:
- Configurable ROM sources with priority-based search
- Python-powered fuzzy matching with result caching
- Session state tracking with resume capability
- Dry run mode for operation preview
- Shared title detection for multi-game cartridges
- Comprehensive error handling and logging

## Project Structure

```
organizer/
├── rom-organizer.sh          # Main entry point
├── rom-search.py             # Python search engine
├── lib/                      # Core modules
│   ├── rom_constants.sh      # Constants and defaults
│   ├── rom_utils.sh          # Utility functions and validation
│   ├── rom_ui.sh             # User interface wrappers
│   ├── rom_config.sh         # Configuration management and source parsing
│   ├── rom_core.sh           # ROM file operations (copy/extract)
│   ├── rom_search.sh         # Search engine integration
│   ├── rom_query.sh          # Query processing logic
│   └── rom_state.sh          # Session state and statistics
├── config/
│   └── defaults.conf         # Default configuration
└── tests/
    ├── test_basic.sh         # Basic functionality tests
    ├── test_sources.sh       # Source configuration tests
    └── test_search_engine.sh # Python integration tests
```

## Setup and Installation

### Dependencies

Required:
```bash
sudo apt install python3 unzip
```

Optional (for enhanced functionality):
```bash
# Interactive UI
sudo apt install gum

# Additional archive formats
sudo apt install p7zip-full unrar

# Python packages for better performance
python3 -m pip install rapidfuzz regex
```

### Python Environment Setup

Recommended for isolated dependency management:

```bash
cd /path/to/organizer
python3 -m venv rom_env
./rom_env/bin/pip install rapidfuzz regex
```

The script will automatically use `rom_env/bin/python3` if available.

### Permissions

```bash
chmod +x rom-organizer.sh rom-search.py lib/*.sh
```

## Usage

### Basic Commands

```bash
# Interactive mode
./rom-organizer.sh

# Dry run (preview operations)
./rom-organizer.sh --dry-run

# Verbose logging
./rom-organizer.sh --verbose

# Custom configuration
./rom-organizer.sh --config /path/to/config.conf

# Resume interrupted session
./rom-organizer.sh --resume

# Show version
./rom-organizer.sh --version
```

### Directory Structure

Expected layout:

```
ROMBase/
├── Official/                  # Original ROMs (priority: 100)
│   ├── Nintendo - SNES/
│   ├── Nintendo - NES/
│   └── [other systems]/
├── Translations/              # Translations (priority: 200)
│   └── [systems]/
├── Lists/                     # Query files (*.txt)
│   ├── Best Games.txt
│   └── Top 100.txt
└── Collections/               # Output (auto-created)
    └── [system]/
        └── [collection]/
```

Sources are fully configurable. See [Configuration](#configuration) for custom sources.

### Query File Format

Create `.txt` files in the `Lists/` directory:

```
# Best SNES Games
Super Mario World
The Legend of Zelda: A Link to the Past
Super Metroid

# Multi-game cartridges (shared titles)
Super Mario All-Stars / Super Mario World
```

Lines starting with `#` are comments. Blank lines are ignored.

### Example Workflow

1. Create a query list: `Lists/SNES Favorites.txt`
2. Run: `./rom-organizer.sh`
3. Select system: `Nintendo - SNES`
4. Select list: `SNES Favorites`
5. For each query, select matching ROM or skip
6. ROMs are copied to `Collections/Nintendo - SNES/SNES Favorites/`

## Configuration

### Default Settings

File: `config/defaults.conf`

```bash
# Base directory for all ROMs
base_dir=/mnt/drive/Roms

# ROM Sources (format: name:path:priority)
sources=Official:Official:100
sources=Translations:Translations:200

# Directory paths
lists_dir=Lists
collections_dir=Collections

# Search behavior
auto_select_single=true           # Auto-select single matches
prepend_rating_default=true       # Add rating prefix to filenames
fuzzy_threshold=15.0              # Match sensitivity (0-100, lower = stricter)
max_results=100                   # Maximum search results

# Session settings
enable_dry_run=false
enable_resume=true
cleanup_sessions_days=7
create_skip_markers=true
```

### Source Configuration

Format: `sources=name:path:priority`

- **name**: Display name
- **path**: Relative to `base_dir` or absolute path
- **priority**: Higher values preferred in search results

#### Adding Custom Sources

Hacks:
```bash
sources=Official:Official:100
sources=Hacks:Hacks:150
sources=Translations:Translations:200
```

Homebrew:
```bash
sources=Official:Official:100
sources=Homebrew:Homebrew:120
sources=Translations:Translations:200
```

Absolute paths:
```bash
sources=Official:/media/roms/official:100
sources=External:/mnt/backup/roms:150
sources=Translations:/media/roms/translations:200
```

Priority guidelines:
- 100-149: Original ROMs
- 150-199: Modifications (hacks, homebrew)
- 200+: Translations (typically preferred)

### User Configuration

Create `~/.config/rom-organizer/config.conf` to override defaults:

```bash
fuzzy_threshold=10.0
max_results=50

sources=Official:Official:100
sources=MyHacks:Hacks:180
sources=Translations:Translations:200
```

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `ROM_BASE_DIR` | Override base directory | Auto-detected |
| `TEST_MODE` | Disable error traps | `false` |

## Architecture

### Module Overview

The codebase is organized into 8 specialized modules:

| Module | Responsibility |
|--------|---------------|
| `rom_constants.sh` | Version info, constants, UI symbols |
| `rom_utils.sh` | Logging, validation, string utilities |
| `rom_ui.sh` | User interface, gum wrappers |
| `rom_config.sh` | Configuration loading, source parsing |
| `rom_core.sh` | File operations (copy, extract) |
| `rom_search.sh` | Python search engine integration |
| `rom_query.sh` | Query parsing, shared title detection |
| `rom_state.sh` | Session tracking, statistics |

### Dependency Hierarchy

```
Layer 1 (Foundation):
  rom_constants.sh
  rom_utils.sh (depends: constants)
  rom_ui.sh (depends: constants, utils)

Layer 2 (Core Systems):
  rom_config.sh (depends: constants, utils)
  rom_core.sh (depends: constants, utils, ui)
  rom_search.sh (depends: constants, utils, ui)

Layer 3 (Business Logic):
  rom_query.sh (depends: Layer 1 & 2)
  rom_state.sh (depends: constants, utils, ui)

Layer 4 (Application):
  rom-organizer.sh (depends: all modules)
```

### Data Flow

```
Query File → Parse → Validate → Search (Python) → User Selection
                ↓                    ↓                  ↓
          Session State        Cache Update        Copy/Extract
                                                        ↓
                                                   Statistics
```

### Search Engine

The Python search engine (`rom-search.py`):
- Accepts JSON configuration with dynamic sources
- Scans source directories for ROM files
- Performs fuzzy matching using rapidfuzz (or difflib fallback)
- Sorts results by priority, then match score
- Caches results with source-specific hashing

### Error Handling

Multi-layer approach:
1. Strict mode: `set -euo pipefail`
2. Error traps: Custom ERR handler
3. Exit traps: Cleanup temporary files
4. Input validation: Pre-operation checks
5. Safe wrappers: `gum_safe` for interactive commands

## Testing

### Test Suites

Run all tests:
```bash
cd tests
./test_basic.sh          # 19 tests: core functionality
./test_sources.sh        # 24 tests: source configuration
./test_search_engine.sh  # 12 tests: Python integration
```

### Expected Output

```
ROM Organizer Test Suite
=========================
[✓] Module loading
[✓] Configuration parsing
[✓] String utilities
...
Tests Run: 19
Tests Passed: 19
Tests Failed: 0

All tests passed!
```

### Continuous Integration

GitHub Actions workflows:
- `.github/workflows/shellcheck.yml`: Linting
- `.github/workflows/tests.yml`: Automated test execution

## Troubleshooting

### Common Issues

**"gum not found"**

The script works without gum (uses fallback prompts). To install:
```bash
# Ubuntu/Debian
wget https://github.com/charmbracelet/gum/releases/download/v0.11.0/gum_0.11.0_amd64.deb
sudo dpkg -i gum_0.11.0_amd64.deb

# macOS
brew install gum
```

**"ROM search engine not found"**

Verify:
```bash
ls -l rom-search.py
python3 --version
```

Ensure `rom-search.py` is in the same directory as `rom-organizer.sh`.

**"No ROM files found in archive"**

Check archive contents:
```bash
unzip -l "ROM file.zip"
7z l "ROM file.7z"
```

Verify ROM extensions: `.smc`, `.sfc`, `.nes`, `.gb`, `.gba`, `.md`, `.gen`, etc.

**Session file permissions**

```bash
mkdir -p ~/.rom-organizer/{sessions,logs,summaries}
chmod 755 ~/.rom-organizer
```

**Python dependencies**

If rapidfuzz is unavailable, the script falls back to difflib (slower). Install:
```bash
pip3 install rapidfuzz regex
# or use virtual environment
./rom_env/bin/pip install rapidfuzz regex
```

### Debug Mode

Enable verbose logging:
```bash
./rom-organizer.sh --verbose 2>&1 | tee debug.log
```

Check logs:
```bash
ls -lt ~/.rom-organizer/logs/
tail -f ~/.rom-organizer/logs/session_*.log
```

### Session Recovery

View active sessions:
```bash
ls ~/.rom-organizer/sessions/*.state
cat ~/.rom-organizer/sessions/session_*.state
```

Resume or clean up:
```bash
./rom-organizer.sh --resume
# or manually remove
rm ~/.rom-organizer/sessions/session_*.state
```
