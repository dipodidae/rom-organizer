# ROM Organizer v2.0 - Architecture Overview

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    rom-organizer.sh                         │
│                   (Main Entry Point)                        │
│  • Parse arguments                                          │
│  • Initialize subsystems                                    │
│  • Orchestrate workflow                                     │
└───────────────────┬─────────────────────────────────────────┘
                    │
        ┌───────────┴───────────┐
        │   Module Dependencies  │
        └───────────┬───────────┘
                    │
    ┌───────────────┼───────────────┐
    │               │               │
    ▼               ▼               ▼
┌────────┐    ┌──────────┐    ┌─────────┐
│Constants│◄───│  Utils   │◄───│   UI    │
└────────┘    └──────────┘    └─────────┘
                    ▲               ▲
                    │               │
    ┌───────────────┼───────────────┼───────────────┐
    │               │               │               │
    ▼               ▼               ▼               ▼
┌────────┐    ┌──────────┐    ┌─────────┐    ┌─────────┐
│ Config │    │   Core   │    │ Search  │    │  Query  │
└────────┘    └──────────┘    └─────────┘    └─────────┘
                    │               │               │
                    └───────────────┼───────────────┘
                                    ▼
                              ┌──────────┐
                              │  State   │
                              └──────────┘
```

## Module Hierarchy

### Layer 1: Foundation
- **rom_constants.sh** - No dependencies, defines all constants
- **rom_utils.sh** - Depends on: constants
- **rom_ui.sh** - Depends on: constants, utils

### Layer 2: Core Systems
- **rom_config.sh** - Depends on: constants, utils
- **rom_core.sh** - Depends on: constants, utils, ui
- **rom_search.sh** - Depends on: constants, utils, ui

### Layer 3: Business Logic
- **rom_query.sh** - Depends on: all Layer 1 & 2 modules
- **rom_state.sh** - Depends on: constants, utils, ui

### Layer 4: Application
- **rom-organizer.sh** - Depends on: all modules

## Data Flow

```
┌──────────────┐
│  Query File  │
└──────┬───────┘
       │ read
       ▼
┌──────────────┐     validate      ┌─────────────┐
│ Parse Query  │─────────────────►│  Validate   │
└──────┬───────┘                   └─────────────┘
       │ validated query
       ▼
┌──────────────┐     query         ┌─────────────┐
│   Search     │◄──────────────────│ Search      │
│   Engine     │                   │  Cache      │
└──────┬───────┘     results       └─────────────┘
       │
       ▼
┌──────────────┐
│ Match List   │
└──────┬───────┘
       │
       ├─► Single match ──► Auto-select
       │
       ├─► Multiple ─────► User Selection ──┐
       │                                     │
       └─► None ─────────► Manual Query     │
                                             │
                                             ▼
                                    ┌─────────────┐
                                    │ File Path   │
                                    └──────┬──────┘
                                           │
                        ┌──────────────────┼──────────────────┐
                        │                  │                  │
                        ▼                  ▼                  ▼
                 ┌────────────┐    ┌────────────┐    ┌────────────┐
                 │   Direct   │    │  Extract   │    │    Skip    │
                 │    Copy    │    │ from ZIP   │    │   Marker   │
                 └─────┬──────┘    └─────┬──────┘    └─────┬──────┘
                       │                 │                  │
                       └────────┬────────┘                  │
                                ▼                           │
                         ┌────────────┐                     │
                         │ Collection │                     │
                         │ Directory  │                     │
                         └─────┬──────┘                     │
                               │                            │
                               └────────────┬───────────────┘
                                            ▼
                                    ┌─────────────┐
                                    │  Log & Stats│
                                    └─────────────┘
```

## Error Handling Flow

```
┌──────────────┐
│  Operation   │
└──────┬───────┘
       │
       ├─► Success ──────────► Log Success
       │                       Update Stats
       │                       Continue
       │
       ├─► User Cancel ──────► Log Cancel
       │                       Save State
       │                       Continue
       │
       └─► Error ──────────┐
                           │
                           ▼
                  ┌─────────────────┐
                  │  Error Trap     │
                  │  Triggered      │
                  └────────┬────────┘
                           │
                  ┌────────┴────────┐
                  │  Cleanup Temps  │
                  │  Log Error      │
                  │  Update State   │
                  └────────┬────────┘
                           │
                  ┌────────┴────────┐
                  │  Can Recover?   │
                  └────┬───────┬────┘
                       │       │
                   Yes │       │ No
                       │       │
                       ▼       ▼
                   Continue   Exit
                              with
                              Error
```

## Session State Management

```
┌──────────────┐
│ Init Session │
└──────┬───────┘
       │
       ▼
┌──────────────────┐
│  Create State    │
│  File in:        │
│  ~/.rom-organizer│
│  /sessions/      │
└──────┬───────────┘
       │
       ▼
┌──────────────────┐
│ Process Queries  │◄─┐
└──────┬───────────┘  │
       │              │
       ├─► After Each Query
       │              │
       ▼              │
┌──────────────────┐  │
│  Update State:   │  │
│  • Last line     │  │
│  • Statistics    │──┘
│  • Timestamp     │
└──────┬───────────┘
       │
       ├─► Interrupted? ──► Save State
       │                    (Resume later)
       │
       └─► Complete ──────► Mark Complete
                            Generate Summary
```

## Configuration System

```
┌──────────────────┐
│  Load Priority:  │
└──────┬───────────┘
       │
       ▼
┌──────────────────┐
│ 1. Built-in      │
│    Defaults      │
│    (constants)   │
└──────┬───────────┘
       │
       ▼ (override)
┌──────────────────┐
│ 2. System Config │
│    config/       │
│    defaults.conf │
└──────┬───────────┘
       │
       ▼ (override)
┌──────────────────┐
│ 3. User Config   │
│    ~/.config/    │
│    rom-organizer/│
└──────┬───────────┘
       │
       ▼ (override)
┌──────────────────┐
│ 4. CLI Arguments │
│    --config      │
│    --dry-run     │
└──────┬───────────┘
       │
       ▼
┌──────────────────┐
│  Final Config    │
│  Used by App     │
└──────────────────┘
```

## Search Engine Integration

```
┌──────────────┐
│ User Query   │
└──────┬───────┘
       │
       ▼
┌──────────────────┐
│ rom_search.sh    │
│ (Bash wrapper)   │
└──────┬───────────┘
       │
       ▼
┌──────────────────┐
│ rom_search.py    │
│ (Python engine)  │
└──────┬───────────┘
       │
       ├──────────────┐
       │              │
       ▼              ▼
┌────────────┐  ┌─────────────┐
│  Cache     │  │  ROM Files  │
│  Check     │  │  Scan       │
└─────┬──────┘  └──────┬──────┘
      │                │
      └────┬───────────┘
           │
           ▼
    ┌──────────────┐
    │ Fuzzy Match  │
    │ (RapidFuzz)  │
    └──────┬───────┘
           │
           ▼
    ┌──────────────┐
    │ Rank Results │
    │ by Score     │
    └──────┬───────┘
           │
           ▼
    ┌──────────────┐
    │ Format Output│
    │ name|path    │
    └──────┬───────┘
           │
           ▼
    ┌──────────────┐
    │ Return to    │
    │ Bash         │
    └──────────────┘
```

## File Operations Flow

```
┌──────────────┐
│  Source File │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│  is_rom()    │
│  or          │
│  is_archive()│
└──────┬───────┘
       │
       ├─► ROM ──────────┐
       │                 │
       └─► Archive ──┐   │
                     │   │
                     ▼   │
              ┌────────────┐
              │  Extract   │
              │  to temp   │
              └─────┬──────┘
                    │
                    ▼
              ┌────────────┐
              │ Find ROMs  │
              │ in temp    │
              └─────┬──────┘
                    │
                    └───────┐
                            │
                            ▼
                    ┌────────────┐
                    │ Build      │
                    │ Filename:  │
                    │ [rating]-  │
                    │ [name]     │
                    └─────┬──────┘
                          │
                          ├─► Dry Run? ──► Log Only
                          │
                          └─► Copy ──────► Destination
                                           │
                                           ▼
                                    ┌────────────┐
                                    │  Verify    │
                                    └─────┬──────┘
                                          │
                                          ├─► Success
                                          │
                                          └─► Failure
                                              (Cleanup)
```

## Shared Title Processing

```
Query: "Game A / Game B / Game C"
       │
       ▼
┌────────────────┐
│ Detect Pattern │
│ [/&+] or "and" │
└────────┬───────┘
         │
         ▼
┌────────────────┐
│ Split into:    │
│ • Game A       │
│ • Game B       │
│ • Game C       │
└────────┬───────┘
         │
         ├─► Search for each ──┐
         │                     │
         ▼                     ▼
    ┌─────────┐         ┌─────────┐
    │ Results │         │ Results │
    │ for A   │         │ for B,C │
    └────┬────┘         └────┬────┘
         │                   │
         └─────┬─────────────┘
               │
               ▼
      ┌────────────────┐
      │ Combined List: │
      │ [A] Match 1    │
      │ [A] Match 2    │
      │ [B] Match 1    │
      │ [C] Match 1    │
      └────────┬───────┘
               │
               ▼
      ┌────────────────┐
      │ User Selects:  │
      │ • Single       │
      │ • Multiple     │
      │ • Skip         │
      └────────┬───────┘
               │
               ├─► Multiple ──► Share same rank
               │
               └─► Single ────► Normal rank
```

## Key Design Principles

### 1. **Separation of Concerns**
Each module has a single, well-defined responsibility

### 2. **Error Handling**
Multiple layers: validation → traps → cleanup → logging

### 3. **State Management**
All operations tracked, resumable, logged

### 4. **Testability**
Modules can be tested independently (TEST_MODE)

### 5. **Extensibility**
Easy to add new features by creating new modules

### 6. **Backward Compatibility**
Legacy script preserved, same directory structure

## Performance Characteristics

| Component | Time Complexity | Space Complexity |
|-----------|----------------|------------------|
| Module Loading | O(1) | O(1) |
| Query Parsing | O(n) | O(n) |
| Search (cached) | O(1) | O(1) |
| Search (uncached) | O(m log m) | O(m) |
| File Copy | O(size) | O(1) |
| Extract Archive | O(size) | O(size) |

Where:
- n = number of queries
- m = number of ROM files
- size = file size

## Security Considerations

### Input Validation
- Query length limits
- Path traversal prevention
- Filename sanitization

### Temporary Files
- Created in secure location
- Proper permissions
- Automatic cleanup

### State Files
- User-only permissions
- Safe directory creation
- No sensitive data

---

For implementation details, see individual module files in `lib/`.
