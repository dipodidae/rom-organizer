# ROM Organizer v2.0 - Quick Reference

## Installation

```bash
# 1. Check dependencies
command -v gum python3 unzip

# 2. Run tests
./tests/test_basic.sh

# 3. Ready to use!
./rom-organizer.sh
```

## Common Commands

```bash
# Interactive mode
./rom-organizer.sh

# Preview mode (no changes)
./rom-organizer.sh --dry-run

# Verbose logging
./rom-organizer.sh --verbose

# Help
./rom-organizer.sh --help

# Version info
./rom-organizer.sh --version
```

## File Locations

| Type | Location |
|------|----------|
| **Logs** | `~/.rom-organizer/logs/session_*.log` |
| **Summaries** | `~/.rom-organizer/summaries/summary_*.txt` |
| **Sessions** | `~/.rom-organizer/sessions/session_*.state` |
| **User Config** | `~/.config/rom-organizer/config.conf` |
| **Default Config** | `config/defaults.conf` |

## Module Reference

| Module | Purpose | Key Functions |
|--------|---------|---------------|
| `rom_constants.sh` | Constants, defaults | Version, limits, symbols |
| `rom_utils.sh` | Utilities, logging | `log_*`, `validate_*` |
| `rom_ui.sh` | User interface | `ui_*`, `gum_safe` |
| `rom_config.sh` | Configuration | `load_config`, `get_config` |
| `rom_core.sh` | File operations | `copy_rom_file`, `extract_rom` |
| `rom_search.sh` | Search engine | `gather_matches`, `parse_results` |
| `rom_query.sh` | Query processing | `process_query`, `detect_shared` |
| `rom_state.sh` | Session state | `init_session`, `record_*` |

## Configuration Options

```bash
# ~/.config/rom-organizer/config.conf

auto_select_single=true          # Auto-select single match
prepend_rating_default=true      # Add rating prefix
fuzzy_threshold=15.0             # Search sensitivity
max_results=100                  # Max search results
enable_dry_run=false             # Dry run by default
enable_resume=true               # Allow resume
cleanup_sessions_days=7          # Session retention
create_skip_markers=true         # Create .skipped files
```

## Query List Format

```
# Lists/Best Games.txt

# Comments start with #
Super Mario World
The Legend of Zelda

# Shared titles (multi-game carts)
Game A / Game B

# Empty lines are ignored

```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "gum not found" | Install from https://github.com/charmbracelet/gum |
| "Search engine failed" | Check `rom_search.py` exists, Python 3 installed |
| "Module not found" | Run `chmod +x lib/*.sh` |
| "Permission denied" | Run `chmod +x rom-organizer.sh` |
| Unexpected behavior | Try `--dry-run` first, check logs |

## Quick Debug

```bash
# Enable verbose mode and save log
./rom-organizer.sh --verbose 2>&1 | tee debug.log

# Run tests
./tests/test_basic.sh

# Check configuration
./rom-organizer.sh --help
```

## Workflow

1. **Prepare**
   - Create query list in `Lists/`
   - Run with `--dry-run` first

2. **Execute**
   - Run `./rom-organizer.sh`
   - Select list and system
   - Choose rating preference

3. **Review**
   - Check summary
   - Review logs
   - Verify output in `Collections/`

## Legacy vs v2.0

| Feature | Legacy | v2.0 |
|---------|--------|------|
| Script | `./organizer.sh` | `./rom-organizer.sh` |
| Lines | 1,352 | 324 (main) |
| Modules | 1 file | 8 modules |
| Dry run | ❌ | ✅ |
| Resume | ❌ | ✅ |
| Config | ❌ | ✅ |
| Tests | ❌ | ✅ |

## Key Shortcuts

| Action | Command |
|--------|---------|
| Quick test | `./tests/test_basic.sh` |
| Dry run | `./rom-organizer.sh --dry-run` |
| Last log | `cat ~/.rom-organizer/logs/session_*.log \| tail -100` |
| Last summary | `cat ~/.rom-organizer/summaries/summary_*.txt` |
| Clean sessions | `rm -rf ~/.rom-organizer/sessions/` |

## Architecture at a Glance

```
rom-organizer.sh (main)
├── Constants (rom_constants.sh)
├── Utils (rom_utils.sh)
├── UI (rom_ui.sh)
├── Config (rom_config.sh)
├── Core (rom_core.sh)
├── Search (rom_search.sh)
├── Query (rom_query.sh)
└── State (rom_state.sh)
```

## Statistics

- **Modules**: 8
- **Code**: 3,268 lines
- **Docs**: 1,533 lines
- **Tests**: 19 (100% pass)
- **Main**: 324 lines (85% reduction from 1,352)

## Getting Help

1. **README.md** - Full documentation
2. **MIGRATION.md** - Upgrade guide
3. **ARCHITECTURE.md** - Technical details
4. **REFACTORING_SUMMARY.md** - What changed

## Version

```
ROM Collection Organizer v2.0.0
Released: 2025-12-02
```

---

For detailed information, see README.md
