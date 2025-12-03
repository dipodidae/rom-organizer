# ROM Collection Organizer v2.0.0

A comprehensive, modular ROM collection management tool with advanced search, automatic organization, and session management.

## 🎯 Overview

The ROM Collection Organizer is a refactored, production-ready system for managing large ROM collections. It features a modular architecture, comprehensive error handling, session state management, and an intuitive UI powered by `gum`.

### Key Features

- **Modular Architecture**: Clean separation of concerns across 8 specialized modules
- **Smart Search**: Python-powered fuzzy matching with caching
- **Session Management**: Resume interrupted operations, track statistics
- **Error Recovery**: Comprehensive error handling with automatic cleanup
- **Dry Run Mode**: Preview operations without making changes
- **Shared Titles**: Intelligent handling of multi-game cartridges
- **Progress Tracking**: Real-time statistics and detailed logging
- **Configuration System**: User-customizable settings with defaults

## 📁 Project Structure

```
organizer/
├── rom-organizer.sh          # Main entry point (200 lines)
├── organizer.sh              # Legacy script (preserved)
├── lib/                      # Core modules
│   ├── rom_constants.sh      # Constants and configuration
│   ├── rom_utils.sh          # Utility functions
│   ├── rom_ui.sh             # UI and gum wrappers
│   ├── rom_config.sh         # Configuration management
│   ├── rom_core.sh           # ROM file operations
│   ├── rom_search.sh         # Search engine integration
│   ├── rom_query.sh          # Query processing
│   └── rom_state.sh          # Session state management
├── config/
│   └── defaults.conf         # Default configuration
└── tests/
    └── test_basic.sh         # Test suite
```

## 🚀 Quick Start

### Installation

1. Ensure all dependencies are installed:
   ```bash
   # Required
   sudo apt install gum python3 unzip

   # Optional (for additional archive formats)
   sudo apt install p7zip-full unrar
   ```

2. Set up Python environment (recommended):
   ```bash
   cd /path/to/roms/Scripts
   python3 -m venv rom_env
   ./rom_env/bin/pip install rapidfuzz regex
   ```

3. Make scripts executable:
   ```bash
   chmod +x rom-organizer.sh lib/*.sh
   ```

### Basic Usage

```bash
# Interactive mode
./rom-organizer.sh

# Dry run (preview without changes)
./rom-organizer.sh --dry-run

# Verbose logging
./rom-organizer.sh --verbose

# Custom configuration
./rom-organizer.sh --config /path/to/config.conf
```

## 📖 Usage Guide

### Directory Structure

The script expects this directory structure:

```
ROMBase/
├── Official/              # Original ROMs organized by system (priority: 100)
│   ├── Nintendo - SNES/
│   ├── Nintendo - NES/
│   └── [other systems]/
├── Translations/          # Translated ROMs (priority: 200, preferred)
│   └── [systems]/
├── Hacks/                 # ROM hacks (optional, configurable)
│   └── [systems]/
├── Lists/                 # Query files (*.txt)
│   ├── Best Games.txt
│   └── Top 100.txt
└── Collections/           # Output directory (auto-created)
    └── [system]/
        └── [collection name]/
```

**Note**: Sources are configurable! See [Configuration](#-configuration) for details on adding custom sources like Hacks, Homebrew, etc.

### Query List Format

Create text files in `Lists/` with one game query per line:

```
# Best SNES Games
Super Mario World
The Legend of Zelda: A Link to the Past
Super Metroid
Chrono Trigger

# Shared titles (multi-game carts)
Super Mario All-Stars / Super Mario World
```

### Command-Line Options

| Option | Description |
|--------|-------------|
| `-h, --help` | Show help message |
| `-v, --verbose` | Enable detailed logging |
| `--dry-run` | Simulate operations without changes |
| `--version` | Show version information |
| `--config FILE` | Use custom configuration file |
| `--resume` | Resume interrupted session |

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `ROM_BASE_DIR` | Override base directory | Auto-detected |
| `TEST_MODE` | Disable error traps for testing | `false` |

## 🏗️ Architecture

### Module Responsibilities

| Module | Responsibility | Key Functions |
|--------|---------------|---------------|
| `rom_constants.sh` | Constants, defaults, magic numbers | Version info, UI symbols, limits |
| `rom_utils.sh` | Utilities, validation, logging | `log_*`, `validate_*`, `trim` |
| `rom_ui.sh` | User interface, gum wrappers | `ui_*`, `gum_safe` |
| `rom_config.sh` | Configuration management | `load_config`, `get_config` |
| `rom_core.sh` | ROM file operations | `copy_rom_file`, `extract_rom` |
| `rom_search.sh` | Search engine integration | `gather_matches`, `parse_search_results` |
| `rom_query.sh` | Query processing logic | `process_query`, `detect_shared_titles` |
| `rom_state.sh` | Session state, statistics | `init_session`, `record_*` |

### Data Flow

```
Query File → Parse → Validate → Search → User Selection → Copy/Extract → Log
                ↓                 ↓                            ↓
            Session State      Search Cache              Statistics
```

### Error Handling

The system uses multiple layers of error handling:

1. **Strict Mode**: `set -euo pipefail` catches most errors
2. **Error Traps**: Custom handler on ERR signal
3. **Exit Traps**: Cleanup temporary files on exit
4. **Validation**: Input validation before operations
5. **Safe Wrappers**: `gum_safe` handles interactive command failures

## ⚙️ Configuration

### Default Settings

Located in `config/defaults.conf`:

```bash
# Directory Configuration
base_dir=/mnt/drive/Roms          # Base directory for all ROMs

# ROM Source Configuration (NEW in v2.0!)
# Format: sources=name:path:priority
# - name: Display name for the source
# - path: Directory path (relative to base_dir or absolute)
# - priority: Search priority (higher number = preferred in results)
#
# Sources are searched in order, with higher priority preferred in results
sources=Official:Official:100
sources=Translations:Translations:200
# sources=Hacks:Hacks:150          # Add custom sources!
# sources=Homebrew:Homebrew:120

# Other Directories
lists_dir=Lists                   # Query list files
collections_dir=Collections        # Output directory

# Search Settings
auto_select_single=true           # Auto-select when only one match
prepend_rating_default=true       # Add rating prefix to filenames
fuzzy_threshold=15.0              # Search sensitivity (0-100)
max_results=100                   # Maximum search results

# Session Settings
enable_dry_run=false              # Dry run by default
enable_resume=true                # Enable session resume
cleanup_sessions_days=7           # Days to keep session files
create_skip_markers=true          # Create .skipped files
```

### Adding Custom ROM Sources

You can add any number of custom ROM sources. The script will:
1. **Search all sources** for matching ROMs
2. **Sort results by priority** (higher number = preferred)
3. **Use the first source** for system directory enumeration

Example configurations:

#### Add ROM Hacks

```bash
sources=Official:Official:100
sources=Hacks:Hacks:150
sources=Translations:Translations:200
```

#### Add Homebrew

```bash
sources=Official:Official:100
sources=Homebrew:Homebrew:120
sources=Translations:Translations:200
```

#### Use Absolute Paths

```bash
sources=Official:/media/roms/official:100
sources=Translations:/media/roms/translations:200
sources=External:/mnt/external/roms:150
```

**Priority Guidelines:**
- `100-149`: Original/Official ROMs
- `150-199`: Modifications (Hacks, Homebrew)
- `200+`: Translations (typically preferred)

### User Configuration

Create `~/.config/rom-organizer/config.conf` to override defaults:

```bash
# My custom settings
fuzzy_threshold=10.0
max_results=50

# Add my custom sources
sources=Official:Official:100
sources=MyHacks:Hacks:180
sources=Translations:Translations:200
```

## 📊 Session Management

### Session State

Sessions are automatically tracked in `~/.rom-organizer/sessions/`:

```
session_YYYYMMDD_HHMMSS.state
```

Contains:
- Collection name
- System name
- Last processed line
- Status (active/complete)

### Operation Logs

Detailed logs are stored in:
```
~/.rom-organizer/logs/session_YYYYMMDD_HHMMSS.log
```

### Summaries

Operation summaries are saved to:
```
~/.rom-organizer/summaries/summary_YYYYMMDD_HHMMSS.txt
```

## 🧪 Testing

Run the test suite:

```bash
./tests/test_basic.sh
```

Expected output:
```
ROM Organizer Test Suite
=========================
...
Tests Run:    19
Tests Passed: 19
Tests Failed: 0

All tests passed!
```

## 🔧 Advanced Features

### Shared Title Processing

The system intelligently detects and handles shared titles:

```
Super Mario All-Stars / Super Mario World
```

Detected patterns:
- `/` (slash)
- `&` (ampersand)
- `+` (plus)
- `and` (word)

You can:
1. Select individual games
2. Select multiple games with shared rank
3. Process manually

### Dry Run Mode

Preview operations without making changes:

```bash
./rom-organizer.sh --dry-run
```

All operations will show `[DRY RUN] Would perform: ...`

### Resume Capability

If interrupted, resume from where you left off:

```bash
./rom-organizer.sh --resume
```

The system will detect active sessions and offer to continue.

## 📝 Migration from Legacy Script

The original `organizer.sh` is preserved for compatibility. New features:

| Feature | Legacy | v2.0 |
|---------|--------|------|
| Modular architecture | ❌ | ✅ |
| Error recovery | ❌ | ✅ |
| Session management | ❌ | ✅ |
| Dry run mode | ❌ | ✅ |
| Configuration files | ❌ | ✅ |
| Comprehensive logging | ❌ | ✅ |
| Test suite | ❌ | ✅ |
| Progress tracking | Basic | Advanced |

Both scripts can coexist. To switch:

```bash
# Legacy
./organizer.sh

# New version
./rom-organizer.sh
```

## 🐛 Troubleshooting

### Common Issues

**"gum not found"**
```bash
# Install gum
brew install gum  # macOS
# or download from: github.com/charmbracelet/gum
```

**"ROM search engine not found"**
- Ensure `rom_search.py` exists in the same directory as the script
- Check Python 3 is installed: `python3 --version`

**"No ROM files found in archive"**
- Verify archive contains ROM files with supported extensions
- Check if 7z/unrar are installed for those formats

**Session file permissions**
```bash
mkdir -p ~/.rom-organizer/{sessions,logs,summaries}
chmod 755 ~/.rom-organizer
```

### Debug Mode

Enable verbose logging to troubleshoot:

```bash
./rom-organizer.sh --verbose 2>&1 | tee debug.log
```

## 📜 License

MIT License - See original script header for details

## 🤝 Contributing

This is a refactored version of an existing ROM management tool. Future improvements:

- [ ] Add resume dialog for active sessions
- [ ] Implement undo functionality
- [ ] Add batch processing mode
- [ ] Create web UI for remote management
- [ ] Add ROM metadata extraction
- [ ] Implement duplicate detection

## 📧 Support

For issues or questions:
1. Check the troubleshooting section
2. Review logs in `~/.rom-organizer/logs/`
3. Run tests: `./tests/test_basic.sh`
4. Enable verbose mode for debugging

## 🙏 Acknowledgments

- Original ROM organizer script
- [Gum](https://github.com/charmbracelet/gum) for beautiful CLI UI
- [RapidFuzz](https://github.com/maxbachmann/RapidFuzz) for fast fuzzy matching
- Python search engine implementation

---

**ROM Collection Organizer v2.0.0** - Built with ❤️ for retro gaming enthusiasts
