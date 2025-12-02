# ROM Organizer v2.0 - Complete File Index

## 📋 Overview

This document provides a complete index of all files in the ROM Organizer v2.0 refactoring project.

## 📁 Directory Structure

```
organizer/
├── rom-organizer.sh              # Main entry point (v2.0)
├── organizer.sh                  # Legacy script (preserved)
│
├── lib/                          # Core modules
│   ├── rom_constants.sh          # Constants and defaults
│   ├── rom_utils.sh              # Utility functions
│   ├── rom_ui.sh                 # User interface
│   ├── rom_config.sh             # Configuration management
│   ├── rom_core.sh               # File operations
│   ├── rom_search.sh             # Search integration
│   ├── rom_query.sh              # Query processing
│   └── rom_state.sh              # Session state
│
├── config/                       # Configuration
│   └── defaults.conf             # Default settings
│
├── tests/                        # Test suite
│   └── test_basic.sh             # Basic functionality tests
│
└── docs/                         # Documentation
    ├── README.md                 # User guide
    ├── MIGRATION.md              # Migration guide
    ├── ARCHITECTURE.md           # Technical architecture
    ├── REFACTORING_SUMMARY.md   # Refactoring summary
    ├── QUICKREF.md               # Quick reference
    └── INDEX.md                  # This file
```

## 📊 File Statistics

| Category | Files | Lines | Percentage |
|----------|-------|-------|------------|
| **Code** | 10 | 3,268 | 67.6% |
| **Documentation** | 5 | 1,533 | 31.7% |
| **Configuration** | 1 | 34 | 0.7% |
| **Total** | 16 | 4,835 | 100% |

## 📖 Documentation Files

### README.md (377 lines)
**Purpose**: Primary user documentation  
**Audience**: End users  
**Contents**:
- Features overview
- Installation guide
- Usage instructions
- Configuration reference
- Troubleshooting guide
- Examples and workflows

### MIGRATION.md (440 lines)
**Purpose**: Migration guide from legacy to v2.0  
**Audience**: Existing users  
**Contents**:
- What changed
- Breaking changes (none!)
- Feature comparison
- Step-by-step migration
- Rollback plan
- Testing recommendations

### ARCHITECTURE.md (450 lines)
**Purpose**: Technical architecture documentation  
**Audience**: Developers, maintainers  
**Contents**:
- System architecture diagrams
- Module hierarchy
- Data flow diagrams
- Error handling flow
- Design principles
- Performance characteristics

### REFACTORING_SUMMARY.md (266 lines)
**Purpose**: Summary of refactoring effort  
**Audience**: Project stakeholders  
**Contents**:
- Executive summary
- Metrics and improvements
- Files created
- Testing results
- Migration path
- Lessons learned

### QUICKREF.md (200 lines)
**Purpose**: Quick reference guide  
**Audience**: All users  
**Contents**:
- Common commands
- File locations
- Module reference
- Configuration options
- Troubleshooting quick fixes
- Version info

## 💻 Code Files

### Main Entry Point

#### rom-organizer.sh (324 lines)
**Purpose**: Main application entry point  
**Dependencies**: All lib modules  
**Key Functions**:
- `parse_arguments()` - Command-line parsing
- `check_dependencies()` - Verify requirements
- `setup_directories()` - Initialize paths
- `get_systems()` - List available systems
- `main()` - Main workflow orchestration

### Library Modules

#### lib/rom_constants.sh (198 lines)
**Purpose**: Constants, defaults, configuration values  
**Dependencies**: None (foundation)  
**Key Contents**:
- Exit codes
- Search configuration
- Query limits
- File descriptors
- UI symbols
- ROM extensions
- Archive formats
- Color codes
- Version info

#### lib/rom_utils.sh (431 lines)
**Purpose**: Utility functions and helpers  
**Dependencies**: rom_constants.sh  
**Key Functions**:
- `log_verbose()`, `log_info()`, `log_error()` - Logging
- `validate_query()`, `validate_file_path()` - Validation
- `trim()`, `get_extension()` - String utilities
- `is_rom_file()`, `is_archive_file()` - File detection
- `format_rating()`, `calculate_rating_digits()` - Rating helpers
- `error_handler()`, `cleanup_temp_files()` - Error handling

#### lib/rom_ui.sh (405 lines)
**Purpose**: User interface and gum wrappers  
**Dependencies**: rom_constants.sh, rom_utils.sh  
**Key Functions**:
- `gum_safe()` - Safe gum command wrapper
- `ui_message()`, `ui_success()`, `ui_error()` - Styled output
- `ui_choose()`, `ui_confirm()`, `ui_input()` - Interactive prompts
- `ui_show_help()`, `ui_show_version()` - Help screens
- `ui_show_summary()` - Operation summaries
- `ui_query_header()` - Query display

#### lib/rom_config.sh (243 lines)
**Purpose**: Configuration management  
**Dependencies**: rom_constants.sh, rom_utils.sh  
**Key Functions**:
- `load_config()` - Load config from file
- `load_default_config()` - Load system defaults
- `load_user_config()` - Load user overrides
- `get_config()`, `set_config()` - Config access
- `validate_config()` - Validate settings
- `save_config()` - Export configuration

#### lib/rom_core.sh (431 lines)
**Purpose**: Core ROM file operations  
**Dependencies**: rom_constants.sh, rom_utils.sh, rom_ui.sh  
**Key Functions**:
- `extract_rom()` - Extract ROM from archive
- `copy_rom_file()` - Copy ROM to collection
- `build_filename()` - Build filename with rating
- `check_rank_exists()` - Check for existing rank
- `find_skipped_files()` - List skip markers
- `create_skip_marker()` - Create skip file
- `list_rom_files()`, `count_rom_files()` - ROM enumeration

#### lib/rom_search.sh (245 lines)
**Purpose**: Search engine integration  
**Dependencies**: rom_constants.sh, rom_utils.sh, rom_ui.sh  
**Key Functions**:
- `init_search_engine()` - Initialize Python engine
- `check_search_engine()` - Verify engine availability
- `gather_matches()` - Search for ROMs
- `parse_search_results()` - Parse search output
- `count_matches()` - Count search results
- `get_best_match()` - Auto-select single match

#### lib/rom_query.sh (428 lines)
**Purpose**: Query processing logic  
**Dependencies**: All previous modules  
**Key Functions**:
- `process_query()` - Main query processor
- `detect_shared_titles()` - Detect shared format
- `split_shared_query()` - Split into sub-queries
- `process_shared_title_query()` - Handle shared titles
- `process_manual_query()` - Manual query input
- `handle_multi_select()` - Multi-selection logic
- `handle_single_selection()` - Single selection

#### lib/rom_state.sh (348 lines)
**Purpose**: Session state and statistics  
**Dependencies**: rom_constants.sh, rom_utils.sh, rom_ui.sh  
**Key Functions**:
- `init_session()` - Create new session
- `load_session()` - Load existing session
- `update_session()` - Update session state
- `complete_session()` - Mark session complete
- `find_active_sessions()` - List active sessions
- `record_success()`, `record_error()`, `record_skip()` - Statistics
- `generate_summary()` - Create summary report
- `export_session_data()` - Export to JSON

### Test Suite

#### tests/test_basic.sh (215 lines)
**Purpose**: Basic functionality tests  
**Dependencies**: rom_constants.sh, rom_utils.sh, rom_ui.sh  
**Test Coverage**:
- Module loading (3 tests)
- Utility functions (4 tests)
- ROM file detection (3 tests)
- Archive detection (2 tests)
- Rating functions (4 tests)
- Validation functions (3 tests)
- **Total: 19 tests, 100% pass rate**

## ⚙️ Configuration Files

### config/defaults.conf (34 lines)
**Purpose**: Default configuration values  
**Format**: KEY=VALUE  
**Settings**:
- `auto_select_single` - Auto-select behavior
- `prepend_rating_default` - Rating prefix default
- `fuzzy_threshold` - Search sensitivity
- `max_results` - Result limit
- `enable_dry_run` - Dry run default
- `enable_resume` - Resume capability
- `cleanup_sessions_days` - Session retention
- `create_skip_markers` - Skip marker creation

## 🔄 Legacy Files

### organizer.sh (1,352 lines)
**Purpose**: Original monolithic script (preserved)  
**Status**: Functional, maintained for backward compatibility  
**Recommendation**: Migrate to rom-organizer.sh for new features

## 📈 Module Dependencies

```
Layer 1 (Foundation):
  rom_constants.sh (no dependencies)

Layer 2 (Utilities):
  rom_utils.sh → rom_constants.sh
  rom_ui.sh → rom_constants.sh, rom_utils.sh

Layer 3 (Systems):
  rom_config.sh → rom_constants.sh, rom_utils.sh
  rom_core.sh → rom_constants.sh, rom_utils.sh, rom_ui.sh
  rom_search.sh → rom_constants.sh, rom_utils.sh, rom_ui.sh

Layer 4 (Logic):
  rom_query.sh → all Layer 1-3 modules
  rom_state.sh → rom_constants.sh, rom_utils.sh, rom_ui.sh

Layer 5 (Application):
  rom-organizer.sh → all modules
```

## 🎯 Quick Navigation

| I want to... | See file... |
|--------------|-------------|
| Understand features | README.md |
| Migrate from legacy | MIGRATION.md |
| Understand architecture | ARCHITECTURE.md |
| Quick command reference | QUICKREF.md |
| See what changed | REFACTORING_SUMMARY.md |
| Find all files | INDEX.md (this file) |
| Modify constants | lib/rom_constants.sh |
| Add new ROM format | lib/rom_constants.sh (ROM_EXTENSIONS) |
| Change UI messages | lib/rom_ui.sh |
| Add logging | lib/rom_utils.sh |
| Modify search | lib/rom_search.sh |
| Change query logic | lib/rom_query.sh |
| Adjust file operations | lib/rom_core.sh |
| Add configuration option | lib/rom_config.sh, config/defaults.conf |
| Track new statistic | lib/rom_state.sh |

## 🔍 Search Guide

### Find by Functionality

**Searching & Matching**:
- Search implementation: `lib/rom_search.sh`
- Query processing: `lib/rom_query.sh`
- Shared title logic: `lib/rom_query.sh` (lines 14-60)

**File Operations**:
- ROM detection: `lib/rom_utils.sh` (is_rom_file)
- Archive extraction: `lib/rom_core.sh` (extract_rom)
- File copying: `lib/rom_core.sh` (copy_rom_file)

**User Interface**:
- Interactive prompts: `lib/rom_ui.sh`
- Progress display: `lib/rom_ui.sh` (ui_query_header)
- Summaries: `lib/rom_ui.sh` (ui_show_summary)

**Configuration**:
- Config loading: `lib/rom_config.sh`
- Default values: `config/defaults.conf`
- User config: `~/.config/rom-organizer/config.conf` (runtime)

**Session Management**:
- State tracking: `lib/rom_state.sh`
- Session files: `~/.rom-organizer/sessions/` (runtime)
- Logs: `~/.rom-organizer/logs/` (runtime)

## 📝 Version History

- **v2.0.0** (2025-12-02) - Complete refactoring
  - Modular architecture
  - 8 specialized modules
  - Comprehensive documentation
  - Test suite
  - Session management
  - Configuration system

## 🎓 Learning Path

### For Users
1. Start with: **README.md**
2. Then: **QUICKREF.md**
3. If migrating: **MIGRATION.md**

### For Developers
1. Start with: **ARCHITECTURE.md**
2. Then: **REFACTORING_SUMMARY.md**
3. Then: Individual module files in `lib/`
4. Finally: **INDEX.md** (this file)

### For Maintainers
1. All documentation files
2. Module source code
3. Test suite
4. Configuration system

---

**Last Updated**: 2025-12-02  
**Version**: 2.0.0  
**Total Files**: 16  
**Total Lines**: 4,835
