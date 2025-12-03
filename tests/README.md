# ROM Organizer Test Suite

This directory contains automated tests for the ROM Organizer project.

## Test Files

### `test_basic.sh`
Original basic test suite covering core functionality:
- Module loading and initialization
- Configuration parsing
- String utilities
- File operations
- Basic validation

### `test_sources.sh` (NEW)
Tests for the dynamic ROM sources system:
- Default source configuration parsing
- Custom source definitions
- Absolute and relative path handling
- Duplicate detection
- Invalid priority handling
- Missing field validation
- Legacy config compatibility
- Source accessor functions
- Priority ordering
- Whitespace trimming

### `test_search_engine.sh` (NEW)
Tests for Python search engine integration:
- Python script availability
- Legacy mode (backward compatibility)
- Dynamic sources via JSON
- Priority-based result ordering
- Cache with dynamic sources
- System enumeration
- Multiple source types
- Absolute path support
- Invalid JSON handling

## Running Tests

### Run All Tests
```bash
cd tests
./test_basic.sh
./test_sources.sh
./test_search_engine.sh
```

### Run Single Test Suite
```bash
cd tests
./test_sources.sh
```

### With Verbose Output
```bash
cd tests
bash -x ./test_sources.sh
```

## GitHub Actions

The test suite is automatically run on push and pull requests via GitHub Actions workflows:

### ShellCheck Workflow (`.github/workflows/shellcheck.yml`)
- Lints all shell scripts
- Checks for common shell scripting issues
- Runs on: main script, library files, test files
- Ignores: `SC2034` (unused variables), `SC1091` (source paths)

### Automated Tests Workflow (`.github/workflows/tests.yml`)
- Installs dependencies (Python, gum, etc.)
- Sets up test environment
- Runs all test suites
- Tests configuration parsing
- Reports pass/fail status

## Test Environment

Tests create temporary directories and files as needed. Cleanup is automatic.

### Required Dependencies
- `bash` (4.0+)
- `python3`
- Standard Unix utilities (grep, wc, etc.)

### Optional Dependencies
- `rapidfuzz` (Python package) - for enhanced search performance
- `gum` - for UI components (skipped in automated tests)

## Writing New Tests

### Test Structure

```bash
test_feature() {
  echo ""
  echo "=== Testing Feature ==="
  
  # Setup
  local temp_file=$(mktemp)
  
  # Execute
  some_function > "$temp_file"
  
  # Assert
  local result
  result=$(cat "$temp_file")
  assert_equals "expected" "$result" "Description of test"
  
  # Cleanup
  rm -f "$temp_file"
}
```

### Assertion Functions

- `assert_equals expected actual description` - Check equality
- `assert_not_empty value description` - Check non-empty value
- `assert_success description` - Mark test as passed
- `assert_failure description [message]` - Mark test as failed
- `assert_contains haystack needle description` - Check substring

### Best Practices

1. **Isolate tests**: Each test should be independent
2. **Clean up**: Remove temporary files/directories
3. **Use descriptive names**: Test function names should describe what they test
4. **Test edge cases**: Include boundary conditions and error cases
5. **Minimize output**: Only show results, not verbose execution
6. **Use timeouts**: Prevent hanging tests in CI

## Test Coverage

Current coverage:
- ✅ Configuration parsing (10 tests)
- ✅ Source management (24 tests)
- ✅ Python search engine (12 tests)
- ✅ Basic utilities (19 tests)
- ⏳ End-to-end workflows (planned)
- ⏳ Error handling (planned)
- ⏳ Session management (planned)

## Continuous Integration

Tests run automatically on:
- Push to `main` or `develop` branches
- Pull requests to `main` or `develop` branches

View results:
- GitHub Actions tab in repository
- PR status checks
- Commit status badges (if configured)

## Troubleshooting

### Tests Fail Locally But Pass in CI
- Check shell version (`bash --version`)
- Verify all dependencies installed
- Check file permissions

### Tests Timeout
- Increase timeout in workflow file
- Check for infinite loops
- Review error handling

### Python Tests Fail
- Ensure Python 3 is installed
- Check `rapidfuzz` installation (optional)
- Verify PYTHONPATH if needed

## Contributing

When adding new features:
1. Write tests first (TDD approach recommended)
2. Ensure all existing tests still pass
3. Add test cases for edge conditions
4. Update this README if adding new test files
5. Run shellcheck before committing

## License

Same as main project.
