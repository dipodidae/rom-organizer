#!/bin/bash
# ROM Organizer - Constants and Configuration
# This file contains all constants, default values, and magic numbers

# shellcheck disable=SC2034  # Constants used by sourcing scripts

# Exit codes (only set if not already defined)
if [[ -z "${EXIT_SUCCESS:-}" ]]; then
  readonly EXIT_SUCCESS=0
  readonly EXIT_GENERAL_ERROR=1
  readonly EXIT_MISSING_DEPS=2
  readonly EXIT_INVALID_CONFIG=3
  readonly EXIT_USER_CANCELLED=4
fi

# Search engine configuration (only set if not already defined)
if [[ -z "${MAX_SEARCH_RESULTS:-}" ]]; then
  readonly MAX_SEARCH_RESULTS=100
  readonly DEFAULT_FUZZY_THRESHOLD=15.0
  readonly CACHE_DIR_NAME=".rom_cache"
fi

# Query processing limits (only set if not already defined)
if [[ -z "${MAX_QUERY_LENGTH:-}" ]]; then
  readonly MAX_QUERY_LENGTH=200
  readonly MIN_RATING_DIGITS=2
  readonly MAX_RATING_DIGITS=5
fi

# File descriptor allocations (only set if not already defined)
if [[ -z "${FD_LIST_FILE:-}" ]]; then
  readonly FD_LIST_FILE=3
  readonly FD_TEMP_PROCESSING=4
  readonly FD_LOGGING=5
fi

# Archive extraction (only set if not already defined)
if [[ -z "${EXTRACT_BUFFER_SIZE:-}" ]]; then
  readonly EXTRACT_BUFFER_SIZE=8192
  readonly MAX_ARCHIVE_SIZE_MB=500
fi

# UI Symbols (only set if not already defined)
if [[ -z "${SYMBOL_SUCCESS:-}" ]]; then
  readonly SYMBOL_SUCCESS="✓"
  readonly SYMBOL_ERROR="✗"
  readonly SYMBOL_WARNING="⚠"
  readonly SYMBOL_INFO="ℹ"
  readonly SYMBOL_MANUAL="🔍"
  readonly SYMBOL_SKIP="⏭️"
  readonly SYMBOL_MARKER="📝"
fi

# Shared title detection patterns (only set if not already defined)
if [[ -z "${SHARED_TITLE_SEPARATOR_PATTERN:-}" ]]; then
  readonly SHARED_TITLE_SEPARATOR_PATTERN='[/&+]'
  readonly SHARED_TITLE_MIN_PARTS=2
fi

# ROM file extensions (organized by system)
declare -gA ROM_EXTENSIONS=(
  # Nintendo NES/Famicom
  [nes]="Nintendo Entertainment System"
  [fds]="Famicom Disk System"
  [nsf]="Nintendo Sound Format"
  [unf]="UNIF Format"
  [unif]="UNIF Format"
  [pal]="NES Palette"
  [prg]="NES Program"
  [chr]="NES Character"
  [unh]="NES Unheadered"

  # Super Nintendo
  [smc]="Super Nintendo"
  [sfc]="Super Famicom"
  [fig]="Super Nintendo"
  [swc]="Super Nintendo"
  [bs]="BS-X Satellaview"
  [dx2]="Game Doctor"
  [mgd]="Multi Game Doctor"
  [mgh]="Multi Game Hunter"
  [ufo]="Super UFO"
  [gd3]="Game Doctor SF3"
  [gd7]="Game Doctor SF7"
  [usa]="Super Nintendo (USA)"
  [eur]="Super Nintendo (EUR)"

  # Game Boy
  [gb]="Game Boy"
  [gbc]="Game Boy Color"
  [sgb]="Super Game Boy"
  [cgb]="Game Boy Color"
  [dmg]="Game Boy DMG"
  [gba]="Game Boy Advance"

  # Nintendo 64
  [n64]="Nintendo 64"
  [z64]="Nintendo 64 (BigEndian)"
  [v64]="Nintendo 64 (ByteSwapped)"
  [u64]="Nintendo 64"

  # GameCube
  [gcm]="GameCube"
  [rvz]="GameCube/Wii RVZ"

  # Wii
  [wbfs]="Wii Backup File System"
  [wad]="Wii Archive"

  # Sega
  [sms]="Sega Master System"
  [gg]="Game Gear"
  [md]="Mega Drive"
  [gen]="Genesis"
  [32x]="Sega 32X"
  [scd]="Sega CD"
  [sg]="SG-1000"
  [pco]="Sega Pico"
  [68k]="Genesis 68K"
  [cdi]="CD-i"
  [gdi]="Dreamcast GD-ROM"

  # Sony PlayStation
  [pbp]="PlayStation Portable"
  [cue]="CD Image Cue Sheet"
  [chd]="Compressed Hunks of Data"
  [ciso]="Compressed ISO"

  # Atari
  [a26]="Atari 2600"
  [a52]="Atari 5200"
  [a78]="Atari 7800"
  [atr]="Atari Disk Image"
  [cas]="Atari Cassette"
  [xfd]="Atari XFD"
  [dcm]="Atari DCM"

  # Generic
  [rom]="Generic ROM"
  [bin]="Binary ROM"
  [img]="Disk Image"
  [iso]="ISO Image"
  [st]="Atari ST"
)

# Archive file extensions (only set if not already defined)
if [[ -z "${ARCHIVE_EXTENSIONS:-}" ]]; then
  readonly ARCHIVE_EXTENSIONS=(
    "zip"
    "7z"
    "rar"
    "tar.gz"
    "tgz"
    "tar.bz2"
    "tbz2"
  )
fi

# Priority system order for UI display (only set if not already defined)
if [[ -z "${PRIORITY_SYSTEMS:-}" ]]; then
  readonly PRIORITY_SYSTEMS=(
    "Nintendo - Super Nintendo Entertainment System"
    "Nintendo - Nintendo Entertainment System (Headerless)"
    "Nintendo - Nintendo Entertainment System (Headered)"
    "Nintendo - Nintendo 64 (BigEndian)"
    "Nintendo - Nintendo 64 (ByteSwapped)"
    "Nintendo - Game Boy"
    "Nintendo - Game Boy Color"
    "Nintendo - Game Boy Advance"
  )
fi

# Color codes for gum styling (only set if not already defined)
if [[ -z "${COLOR_SUCCESS:-}" ]]; then
  readonly COLOR_SUCCESS=2
  readonly COLOR_ERROR=1
  readonly COLOR_WARNING=3
  readonly COLOR_INFO=4
  readonly COLOR_HIGHLIGHT=5
  readonly COLOR_MUTED=8
  readonly COLOR_SHARED=6
fi

# Timeout values (in seconds) (only set if not already defined)
if [[ -z "${SEARCH_TIMEOUT:-}" ]]; then
  readonly SEARCH_TIMEOUT=30
  readonly EXTRACTION_TIMEOUT=300
  readonly COPY_TIMEOUT=60
fi

# Progress tracking (only set if not already defined)
if [[ -z "${PROGRESS_UPDATE_INTERVAL:-}" ]]; then
  readonly PROGRESS_UPDATE_INTERVAL=5
fi

# Version (only set if not already defined)
if [[ -z "${ROM_ORGANIZER_VERSION:-}" ]]; then
  readonly ROM_ORGANIZER_VERSION="2.0.0"
  readonly ROM_ORGANIZER_DATE="2025-12-02"
fi
