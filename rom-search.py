#!/usr/bin/env python3
"""
High-Performance ROM Search Engine

This module provides ultra-fast ROM file searching with fuzzy matching,
caching, and parallel processing capabilities.

Features:
- Multi-threaded file discovery
- Fuzzy string matching with configurable thresholds
- Smart caching system for repeated searches
- Memory-efficient processing of large ROM collections
- Support for all common ROM file extensions
- Case-insensitive search with Unicode normalization
"""

import os
import sys
import json
import time
import hashlib
import threading
import unicodedata
import re as regex_module
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import List, Dict, Tuple, Set, Optional, Iterator
from dataclasses import dataclass
from functools import lru_cache
import argparse
import logging

# High-performance libraries
try:
    from rapidfuzz import fuzz, process
    RAPIDFUZZ_AVAILABLE = True
except ImportError:
    import difflib
    RAPIDFUZZ_AVAILABLE = False

try:
    import regex as re
    REGEX_AVAILABLE = True
except ImportError:
    import re
    REGEX_AVAILABLE = False

# Module-level constants
DEFAULT_MAX_WORKERS = 8  # Reduced from 32 - I/O bound work doesn't need many threads
DEFAULT_FUZZY_THRESHOLD = 40.0
CACHE_VERSION = '1.0'
DEFAULT_MAX_RESULTS = 50
DIRECTORY_SAMPLE_SIZE = 100



# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

@dataclass
class RomMatch:
    """Represents a ROM file match with metadata."""
    filename: str
    full_path: str
    source_type: str  # "official" or "translation"
    score: float
    size: int
    modified_time: float

class RomSearchEngine:
    """High-performance ROM search engine with caching and parallel processing."""

    # Common ROM file extensions (optimized set for O(1) lookup)
    ROM_EXTENSIONS = frozenset({
        'zip', '7z', 'rar', 'sfc', 'smd', 'gen', 'nes', 'gb', 'gbc', 'gba',
        'n64', 'z64', 'v64', 'iso', 'cue', 'bin', 'img', 'rom', 'sms', 'gg',
        'pce', 'ws', 'wsc', 'ngp', 'ngc', 'lynx', 'jag', '32x', 'sat', 'cdi',
        'chd', 'nds', 'gba', 'fds', 'nsf', 'spc', 'psf', 'minipsf', 'psf2',
        'ssf', 'dsf', 'gsf', 'usf', 'rsn', 'sap', 'sid', 'gym', 'vgm', 'vgz'
    })

    def __init__(
        self,
        base_dir: str,
        cache_dir: Optional[str] = None,
        fuzzy_threshold: float = DEFAULT_FUZZY_THRESHOLD,
        max_workers: Optional[int] = None
    ) -> None:
        """Initialize the ROM search engine.

        Args:
            base_dir: Base directory containing ROM collections
            cache_dir: Directory for caching search indexes
            fuzzy_threshold: Minimum fuzzy match score (0-100)
            max_workers: Maximum worker threads (default: 8)
        """
        self.base_dir = Path(base_dir).resolve()
        self.official_dir = self.base_dir / "Official"
        self.translations_dir = self.base_dir / "Translations"

        # Performance settings
        self.max_workers = max_workers or DEFAULT_MAX_WORKERS
        self.fuzzy_threshold = fuzzy_threshold        # Cache settings
        self.cache_dir = Path(cache_dir) if cache_dir else self.base_dir / ".rom_cache"
        self.cache_dir.mkdir(exist_ok=True)

        # Internal state
        self._file_index: Dict[str, Dict[str, List[RomMatch]]] = {}
        self._index_lock = threading.RLock()
        self._cache_loaded = False

        logger.info(f"Initialized ROM search engine with {self.max_workers} workers")
        logger.info(f"Fuzzy matching library: {'rapidfuzz' if RAPIDFUZZ_AVAILABLE else 'difflib'}")

    def _get_cache_file_path(self, system: str) -> Path:
        """Get cache file path for a specific system.

        Args:
            system: Name of the gaming system

        Returns:
            Path to the cache file for the system
        """
        return self.cache_dir / f"{system}.json"

    def _calculate_dir_hash(self, directory: Path) -> str:
        """Calculate hash of directory contents for cache validation."""
        if not directory.exists():
            return ""

        hasher = hashlib.md5()
        try:
            stat = directory.stat()
            hasher.update(str(stat.st_mtime).encode())
            hasher.update(str(stat.st_size).encode())

            # Sample files without loading all into memory
            from itertools import islice
            for file_path in islice(directory.rglob("*"), DIRECTORY_SAMPLE_SIZE):
                if file_path.is_file():
                    stat = file_path.stat()
                    hasher.update(str(stat.st_mtime).encode())
                    hasher.update(str(stat.st_size).encode())
        except (OSError, PermissionError):
            pass

        return hasher.hexdigest()

    def _load_cache(self, system: str) -> bool:
        """Load cached file index for a system.

        Args:
            system: Name of the gaming system

        Returns:
            True if cache was loaded successfully, False otherwise
        """
        cache_path = self._get_cache_file_path(system)
        if not cache_path.exists():
            return False

        try:
            with open(cache_path, 'r', encoding='utf-8') as f:
                cache_data = json.load(f)

            # Validate cache version and directory hash
            if cache_data.get('version') != CACHE_VERSION:
                return False

            # Check if directories have changed
            official_hash = self._calculate_dir_hash(self.official_dir / system)
            trans_hash = self._calculate_dir_hash(self.translations_dir / system)

            if (cache_data.get('official_hash') != official_hash or
                cache_data.get('translations_hash') != trans_hash):
                return False

            # Load cached matches
            matches = {}
            for source_type, files in cache_data.get('matches', {}).items():
                matches[source_type] = [
                    RomMatch(
                        filename=match['filename'],
                        full_path=match['full_path'],
                        source_type=match['source_type'],
                        score=match['score'],
                        size=match['size'],
                        modified_time=match['modified_time']
                    ) for match in files
                ]

            with self._index_lock:
                self._file_index[system] = matches

            logger.info(f"Loaded cache for {system}: {sum(len(files) for files in matches.values())} files")
            return True

        except (json.JSONDecodeError, KeyError, TypeError) as e:
            logger.warning(f"Invalid cache file for {system}: {e}")
            return False

    def _save_cache(self, system: str) -> None:
        """Save file index cache for a system."""
        cache_path = self._get_cache_file_path(system)

        try:
            with self._index_lock:
                matches = self._file_index.get(system, {})

            cache_data = {
                'version': CACHE_VERSION,
                'timestamp': time.time(),
                'official_hash': self._calculate_dir_hash(self.official_dir / system),
                'translations_hash': self._calculate_dir_hash(self.translations_dir / system),
                'matches': {
                    source_type: [
                        {
                            'filename': m.filename,
                            'full_path': m.full_path,
                            'source_type': m.source_type,
                            'size': m.size,
                            'modified_time': m.modified_time
                        }
                        for m in files
                    ]
                    for source_type, files in matches.items()
                }
            }

            # Write atomically
            temp_path = cache_path.with_suffix('.tmp')
            with open(temp_path, 'w', encoding='utf-8') as f:
                json.dump(cache_data, f, indent=2)
            temp_path.replace(cache_path)
            logger.info(f"Saved cache for {system}")

        except Exception as e:
            logger.error(f"Failed to save cache for {system}: {e}")

    def _is_rom_file(self, filename: str) -> bool:
        """Check if file has a ROM extension.

        Args:
            filename: Name of the file to check

        Returns:
            True if file has a recognized ROM extension
        """
        ext = filename.lower().split('.')[-1]
        return ext in self.ROM_EXTENSIONS

    def _scan_directory(self, directory: Path, source_type: str) -> List[RomMatch]:
        """Scan directory for ROM files."""
        if not directory.exists():
            return []

        matches = []
        for file_path in directory.rglob("*"):
            if not file_path.is_file():
                continue

            try:
                if not self._is_rom_file(file_path.name):
                    continue

                stat = file_path.stat()
                matches.append(RomMatch(
                    filename=file_path.name,
                    full_path=str(file_path),
                    source_type=source_type,
                    score=100.0,
                    size=stat.st_size,
                    modified_time=stat.st_mtime
                ))
            except (OSError, PermissionError):
                continue

        return matches

    def _build_index(self, system: str) -> Dict[str, List[RomMatch]]:
        """Build file index for a system.

        Scans both official and translation directories for the specified system.

        Args:
            system: Name of the gaming system

        Returns:
            Dictionary mapping source types to lists of RomMatch objects
        """
        logger.info(f"Building index for {system}...")
        start_time = time.time()

        matches = {}

        # Scan official directory
        official_dir = self.official_dir / system
        if official_dir.exists():
            matches['official'] = self._scan_directory(official_dir, 'official')
            logger.info(f"Found {len(matches['official'])} official ROMs")

        # Scan translations directory
        trans_dir = self.translations_dir / system
        if trans_dir.exists():
            matches['translations'] = self._scan_directory(trans_dir, 'translations')
            logger.info(f"Found {len(matches['translations'])} translation ROMs")

        elapsed = time.time() - start_time
        total_files = sum(len(files) for files in matches.values())
        logger.info(f"Built index for {system} in {elapsed:.2f}s ({total_files} files)")

        return matches

    def _ensure_index(self, system: str) -> None:
        """Ensure file index is loaded for a system.

        Loads from cache if available, otherwise builds index from scratch.

        Args:
            system: Name of the gaming system
        """
        with self._index_lock:
            if system in self._file_index:
                return

        # Try to load from cache first
        if not self._load_cache(system):
            # Build index from scratch
            matches = self._build_index(system)

            with self._index_lock:
                self._file_index[system] = matches

            # Save to cache
            self._save_cache(system)

    def _normalize_text(self, text: str) -> str:
        """Normalize text by removing diacritics and lowercasing."""
        if not text:
            return ""
        # Remove diacritics
        normalized = unicodedata.normalize('NFD', text)
        no_diacritics = ''.join(c for c in normalized if not unicodedata.combining(c))
        return no_diacritics.lower()

    def _fuzzy_match_score(self, query: str, filename: str) -> float:
        """Calculate fuzzy match score."""
        if RAPIDFUZZ_AVAILABLE:
            return fuzz.partial_ratio(query.lower(), filename.lower())
        else:
            return difflib.SequenceMatcher(None, query.lower(), filename.lower()).ratio() * 100

    def _contains_all_words(self, query: str, filename: str) -> bool:
        """Check if filename contains query words."""
        if len(query.strip()) < 3:
            return True

        query_words = [w for w in query.lower().split() if len(w) >= 2]
        filename_lower = filename.lower()

        # Count matches
        matches = sum(1 for word in query_words if word in filename_lower)
        required = max(1, int(len(query_words) * 0.6))  # 60% threshold
        if matches >= required:
            return True

        # Try normalized
        norm_query = self._normalize_text(query)
        norm_filename = self._normalize_text(filename)
        norm_words = [w for w in norm_query.split() if len(w) >= 2]
        norm_matches = sum(1 for word in norm_words if word in norm_filename)
        return norm_matches >= max(1, int(len(norm_words) * 0.6))

    def search(
        self,
        query: str,
        system: str,
        max_results: int = DEFAULT_MAX_RESULTS
    ) -> List[RomMatch]:
        """Search for ROMs matching the query in the specified system.

        Args:
            query: Search query string
            system: System name to search in
            max_results: Maximum number of results to return

        Returns:
            List of RomMatch objects sorted by relevance score
        """
        if not query.strip():
            return []

        # Ensure index is built
        self._ensure_index(system)

        start_time = time.time()
        results = []

        with self._index_lock:
            matches = self._file_index.get(system, {})

        # Search in both official and translations
        debug_checked = 0
        debug_passed_word_check = 0
        debug_final_matches = 0

        for source_type, files in matches.items():
            for rom_match in files:
                debug_checked += 1

                # Fast preliminary check: must contain all query words
                if not self._contains_all_words(query, rom_match.filename):
                    continue

                debug_passed_word_check += 1

                # Calculate fuzzy match score
                score = self._fuzzy_match_score(query, rom_match.filename)

                if score >= self.fuzzy_threshold:
                    debug_final_matches += 1
                    results.append(RomMatch(
                        filename=rom_match.filename,
                        full_path=rom_match.full_path,
                        source_type=rom_match.source_type,
                        score=score,
                        size=rom_match.size,
                        modified_time=rom_match.modified_time
                    ))

        # Sort: prioritize translations and higher scores
        results.sort(
            key=lambda x: (
                x.score + (10.0 if x.source_type == 'translations' else 0.0),
                x.source_type == 'translations',
                -x.size
            ),
            reverse=True
        )

        elapsed = time.time() - start_time
        logger.debug(f"Search: {elapsed:.3f}s, checked {debug_checked}, matched {len(results)} for '{query}'")

        return results[:max_results]

    def get_systems(self) -> List[str]:
        """Get list of available gaming systems.

        Scans both official and translation directories.

        Returns:
            Sorted list of system names
        """
        systems = set()

        # Scan official directory
        if self.official_dir.exists():
            for item in self.official_dir.iterdir():
                if item.is_dir():
                    systems.add(item.name)

        # Scan translations directory
        if self.translations_dir.exists():
            for item in self.translations_dir.iterdir():
                if item.is_dir():
                    systems.add(item.name)

        return sorted(systems)

    def clear_cache(self, system: Optional[str] = None) -> None:
        """Clear cache for a specific system or all systems.

        Args:
            system: System name to clear cache for, or None to clear all
        """
        if system:
            cache_path = self._get_cache_file_path(system)
            if cache_path.exists():
                cache_path.unlink()
                logger.info(f"Cleared cache for {system}")

            with self._index_lock:
                self._file_index.pop(system, None)
        else:
            # Clear all cache files
            for cache_file in self.cache_dir.glob("*.json"):
                cache_file.unlink()
            logger.info("Cleared all cache files")

            with self._index_lock:
                self._file_index.clear()

    def get_stats(self) -> Dict[str, object]:
        """Get search engine statistics.

        Returns:
            Dictionary containing:
            - systems_indexed: Number of systems currently indexed
            - total_files: Total number of ROM files indexed
            - cache_dir: Path to cache directory
            - max_workers: Number of worker threads
            - fuzzy_threshold: Current fuzzy match threshold
            - rapidfuzz_available: Whether rapidfuzz library is available
        """
        with self._index_lock:
            total_files = sum(
                len(files) for system_matches in self._file_index.values()
                for files in system_matches.values()
            )

            return {
                'systems_indexed': len(self._file_index),
                'total_files': total_files,
                'cache_dir': str(self.cache_dir),
                'max_workers': self.max_workers,
                'fuzzy_threshold': self.fuzzy_threshold,
                'rapidfuzz_available': RAPIDFUZZ_AVAILABLE
            }


def main() -> None:
    """Command-line interface for the ROM search engine."""
    parser = argparse.ArgumentParser(
        description="High-Performance ROM Search Engine"
    )
    parser.add_argument(
        "base_dir",
        help="Base directory containing ROM collections"
    )
    parser.add_argument("query", help="Search query")
    parser.add_argument("system", help="System to search in")
    parser.add_argument(
        "--max-results",
        type=int,
        default=DEFAULT_MAX_RESULTS,
        help="Maximum results to return"
    )
    parser.add_argument(
        "--fuzzy-threshold",
        type=float,
        default=DEFAULT_FUZZY_THRESHOLD,
        help="Fuzzy match threshold (0-100)"
    )
    parser.add_argument("--cache-dir", help="Cache directory (optional)")
    parser.add_argument("--clear-cache", action="store_true", help="Clear cache before searching")
    parser.add_argument("--stats", action="store_true", help="Show search engine statistics")
    parser.add_argument("--list-systems", action="store_true", help="List available systems")
    parser.add_argument("--verbose", action="store_true", help="Enable verbose logging")

    args = parser.parse_args()

    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)

    # Initialize search engine
    search_engine = RomSearchEngine(
        base_dir=args.base_dir,
        cache_dir=args.cache_dir,
        fuzzy_threshold=args.fuzzy_threshold
    )

    # Handle special commands
    if args.list_systems:
        systems = search_engine.get_systems()
        print("Available systems:")
        for system in systems:
            print(f"  {system}")
        return

    if args.stats:
        stats = search_engine.get_stats()
        print("Search Engine Statistics:")
        for key, value in stats.items():
            print(f"  {key}: {value}")
        return

    if args.clear_cache:
        search_engine.clear_cache()

    # Perform search
    results = search_engine.search(args.query, args.system, args.max_results)

    # Output results in format compatible with bash script
    for result in results:
        icon = "🌍" if result.source_type == "translations" else "🎮"
        print(f"{icon} {result.filename}|{result.full_path}")


if __name__ == "__main__":
    main()
