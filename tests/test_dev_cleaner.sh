#!/usr/bin/env bash

# =============================================================================
# Test Suite for dev-cleaner.sh
# =============================================================================
# Usage: bash tests/test_dev_cleaner.sh
#
# Tests CLI flags, helper functions, cleanup functions, and syntax/lint.
# All tests use temporary directories — nothing on your system is modified.
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$SCRIPT_DIR/dev-cleaner.sh"

PASS=0
FAIL=0
TOTAL=0

# --- Test Helpers ---
pass() {
    PASS=$((PASS + 1))
    TOTAL=$((TOTAL + 1))
    echo "  ✅ PASS: $1"
}

fail() {
    FAIL=$((FAIL + 1))
    TOTAL=$((TOTAL + 1))
    echo "  ❌ FAIL: $1"
    if [ -n "$2" ]; then
        echo "         Detail: $2"
    fi
}

section() {
    echo ""
    echo "━━━ $1 ━━━"
}

# =============================================================================
# Group 1: CLI Flag Tests
# =============================================================================
section "Group 1: CLI Flag Tests"

# TC1: --help flag
tc1_output=$(bash "$SCRIPT" --help 2>&1)
tc1_exit=$?
if [ $tc1_exit -eq 0 ] && echo "$tc1_output" | grep -q "Usage:"; then
    pass "TC1: --help prints usage and exits 0"
else
    fail "TC1: --help" "exit=$tc1_exit, output missing 'Usage:'"
fi

# TC2: --version flag
tc2_output=$(bash "$SCRIPT" --version 2>&1)
tc2_exit=$?
if [ $tc2_exit -eq 0 ] && echo "$tc2_output" | grep -q "1.3.0"; then
    pass "TC2: --version prints 1.3.0 and exits 0"
else
    fail "TC2: --version" "exit=$tc2_exit, output: $tc2_output"
fi

# TC3: Unknown flag
tc3_output=$(bash "$SCRIPT" --bogus 2>&1)
tc3_exit=$?
if [ $tc3_exit -eq 1 ]; then
    pass "TC3: Unknown flag --bogus exits 1"
else
    fail "TC3: Unknown flag" "expected exit 1, got $tc3_exit"
fi

# TC4: --flutter-dir with missing path
tc4_output=$(bash "$SCRIPT" --flutter-dir 2>&1)
tc4_exit=$?
if [ $tc4_exit -eq 1 ] && echo "$tc4_output" | grep -qi "error"; then
    pass "TC4: --flutter-dir without path exits 1 with error"
else
    fail "TC4: --flutter-dir missing path" "exit=$tc4_exit"
fi

# TC5: --flutter-dir with nonexistent path
tc5_output=$(bash "$SCRIPT" --flutter-dir /nonexistent/path/xyz 2>&1)
tc5_exit=$?
if [ $tc5_exit -eq 1 ]; then
    pass "TC5: --flutter-dir /nonexistent exits 1"
else
    fail "TC5: --flutter-dir nonexistent" "expected exit 1, got $tc5_exit"
fi

# =============================================================================
# Group 2: Helper Function Unit Tests
# =============================================================================
section "Group 2: Helper Function Unit Tests"

# We need to source just the functions without running the main script.
# Extract functions by sourcing in a controlled way.
# We'll create a helper that sources the functions we need.

FUNC_HELPER=$(mktemp)
cat > "$FUNC_HELPER" << 'HELPER_EOF'
#!/usr/bin/env bash
# Minimal environment to source dev-cleaner functions

# Disable colors for testing
GREEN="" YELLOW="" RED="" BLUE="" CYAN="" MAGENTA="" NC="" BOLD="" FAINT=""

# Set globals
SCRIPT_VERSION="1.3.0"
GITHUB_REPO="test"
DRY_RUN=false
FLUTTER_SEARCH_DIR="."
FLUTTER_DIR_SOURCE="default"

HELPER_EOF

# Extract function definitions from the script (between function markers)
# We'll just source the whole file but override the main execution
cat >> "$FUNC_HELPER" << HELPER_EOF2
# Source all function definitions
# We override 'main_loop', 'clear', 'sudo', 'read' and skip the tail of the script
main_loop() { :; }
clear() { :; }
sudo() { command "\$@" 2>/dev/null; }

# Extract functions from the script by parsing up to the CLI argument handling
HELPER_EOF2

# Copy function definitions (lines 54 to ~660) from the script
sed -n '54,663p' "$SCRIPT" >> "$FUNC_HELPER"

# TC6: format_freed_space
tc6_result_kb=$(bash -c "source '$FUNC_HELPER'; format_freed_space 500")
tc6_result_mb=$(bash -c "source '$FUNC_HELPER'; format_freed_space 2048")
tc6_result_gb=$(bash -c "source '$FUNC_HELPER'; format_freed_space 2097152")
tc6_result_zero=$(bash -c "source '$FUNC_HELPER'; format_freed_space 0")

tc6_pass=true
if [ "$tc6_result_kb" != "500 KB" ]; then tc6_pass=false; fi
if [ "$tc6_result_mb" != "2 MB" ]; then tc6_pass=false; fi
if [ "$tc6_result_gb" != "2 GB" ]; then tc6_pass=false; fi
if [ "$tc6_result_zero" != "0 KB" ]; then tc6_pass=false; fi

if $tc6_pass; then
    pass "TC6: format_freed_space returns correct KB/MB/GB"
else
    fail "TC6: format_freed_space" "kb='$tc6_result_kb' mb='$tc6_result_mb' gb='$tc6_result_gb' zero='$tc6_result_zero'"
fi

# TC7: safe_rm in dry-run does NOT delete
TMPDIR_TC7=$(mktemp -d)
echo "test content" > "$TMPDIR_TC7/testfile.txt"
tc7_output=$(bash -c "
    source '$FUNC_HELPER'
    DRY_RUN=true
    safe_rm '$TMPDIR_TC7/testfile.txt'
")
if [ -f "$TMPDIR_TC7/testfile.txt" ] && echo "$tc7_output" | grep -q "DRY-RUN"; then
    pass "TC7: safe_rm dry-run does NOT delete file, prints DRY-RUN"
else
    fail "TC7: safe_rm dry-run" "file_exists=$([ -f "$TMPDIR_TC7/testfile.txt" ] && echo yes || echo no), output: $tc7_output"
fi
rm -rf "$TMPDIR_TC7"

# TC8: safe_rm in normal mode deletes file
TMPDIR_TC8=$(mktemp -d)
echo "test content" > "$TMPDIR_TC8/testfile.txt"
bash -c "
    source '$FUNC_HELPER'
    DRY_RUN=false
    safe_rm '$TMPDIR_TC8/testfile.txt'
"
if [ ! -f "$TMPDIR_TC8/testfile.txt" ]; then
    pass "TC8: safe_rm normal mode deletes file"
else
    fail "TC8: safe_rm normal mode" "file still exists"
fi
rm -rf "$TMPDIR_TC8"

# TC9: safe_rm -rf deletes directory recursively
TMPDIR_TC9=$(mktemp -d)
mkdir -p "$TMPDIR_TC9/subdir/nested"
echo "test" > "$TMPDIR_TC9/subdir/nested/file.txt"
bash -c "
    source '$FUNC_HELPER'
    DRY_RUN=false
    safe_rm -rf '$TMPDIR_TC9/subdir'
"
if [ ! -d "$TMPDIR_TC9/subdir" ]; then
    pass "TC9: safe_rm -rf deletes directory recursively"
else
    fail "TC9: safe_rm -rf" "directory still exists"
fi
rm -rf "$TMPDIR_TC9"

# TC10: safe_rm on non-existent path
tc10_output=$(bash -c "
    source '$FUNC_HELPER'
    DRY_RUN=false
    safe_rm '/nonexistent/path/abc123'
" 2>&1)
tc10_exit=$?
if [ $tc10_exit -eq 0 ]; then
    pass "TC10: safe_rm on non-existent path exits 0 (no error)"
else
    fail "TC10: safe_rm non-existent" "exit=$tc10_exit"
fi

# =============================================================================
# Group 3: Cleanup Function Tests (with temp fixtures)
# =============================================================================
section "Group 3: Cleanup Function Tests"

# TC11: cleanup_rust in dry-run with fake ~/.cargo
TMPDIR_TC11=$(mktemp -d)
mkdir -p "$TMPDIR_TC11/.cargo/registry/cache"
mkdir -p "$TMPDIR_TC11/.cargo/registry/src"
mkdir -p "$TMPDIR_TC11/.cargo/git/checkouts"
echo "cached" > "$TMPDIR_TC11/.cargo/registry/cache/somecrate"
tc11_output=$(bash -c "
    export HOME='$TMPDIR_TC11'
    source '$FUNC_HELPER'
    DRY_RUN=true
    cleanup_rust
")
# Verify files still exist (dry-run should not delete)
if [ -f "$TMPDIR_TC11/.cargo/registry/cache/somecrate" ] && echo "$tc11_output" | grep -q "DRY-RUN"; then
    pass "TC11: cleanup_rust dry-run preserves files, prints DRY-RUN"
else
    fail "TC11: cleanup_rust dry-run" "file_exists=$([ -f "$TMPDIR_TC11/.cargo/registry/cache/somecrate" ] && echo yes || echo no)"
fi
rm -rf "$TMPDIR_TC11"

# TC12: cleanup_python in dry-run
tc12_output=$(bash -c "
    source '$FUNC_HELPER'
    DRY_RUN=true
    cleanup_python
" 2>&1)
# Should either print DRY-RUN (if pip exists) or "not found" (if no pip)
if echo "$tc12_output" | grep -q "DRY-RUN\|not found"; then
    pass "TC12: cleanup_python dry-run prints DRY-RUN or not-found"
else
    fail "TC12: cleanup_python dry-run" "output: $tc12_output"
fi

# TC13: cleanup_docker in dry-run
tc13_output=$(bash -c "
    source '$FUNC_HELPER'
    DRY_RUN=true
    cleanup_docker
" 2>&1)
if echo "$tc13_output" | grep -q "DRY-RUN\|not found\|Docker not found"; then
    pass "TC13: cleanup_docker dry-run prints DRY-RUN or not-found"
else
    fail "TC13: cleanup_docker dry-run" "output: $tc13_output"
fi

# TC14: cleanup_flutter restores working directory
TMPDIR_TC14=$(mktemp -d)
TMPDIR_TC14_PROJ="$TMPDIR_TC14/myproject"
mkdir -p "$TMPDIR_TC14_PROJ"
echo "name: test" > "$TMPDIR_TC14_PROJ/pubspec.yaml"
mkdir -p "$TMPDIR_TC14_PROJ/build"
mkdir -p "$TMPDIR_TC14_PROJ/.dart_tool"

original_dir=$(pwd)
tc14_output=$(bash -c "
    source '$FUNC_HELPER'
    DRY_RUN=true
    # Mock flutter command
    flutter() { if [ \"\$1\" = 'cache' ]; then return 0; fi; }
    export -f flutter
    cd '$TMPDIR_TC14'
    before_dir=\$(pwd)
    cleanup_flutter '$TMPDIR_TC14'
    after_dir=\$(pwd)
    if [ \"\$before_dir\" = \"\$after_dir\" ]; then
        echo 'DIR_RESTORED'
    else
        echo \"DIR_CHANGED from \$before_dir to \$after_dir\"
    fi
")
if echo "$tc14_output" | grep -q "DIR_RESTORED"; then
    pass "TC14: cleanup_flutter restores working directory"
else
    fail "TC14: cleanup_flutter directory restore" "output: $tc14_output"
fi
rm -rf "$TMPDIR_TC14"

# =============================================================================
# Group 4: Syntax & Lint
# =============================================================================
section "Group 4: Syntax & Lint"

# TC15: bash -n syntax check
tc15_output=$(bash -n "$SCRIPT" 2>&1)
tc15_exit=$?
if [ $tc15_exit -eq 0 ]; then
    pass "TC15: bash -n syntax check passes"
else
    fail "TC15: bash -n syntax check" "$tc15_output"
fi

# TC16: shellcheck (if available)
if command -v shellcheck &>/dev/null; then
    tc16_output=$(shellcheck -x "$SCRIPT" 2>&1)
    tc16_exit=$?
    if [ $tc16_exit -eq 0 ]; then
        pass "TC16: shellcheck passes with no issues"
    else
        # Count issues rather than hard-fail (shellcheck can be strict)
        issue_count=$(echo "$tc16_output" | grep -c "^In ")
        fail "TC16: shellcheck found $issue_count issue(s)" "Run: shellcheck -x $SCRIPT"
    fi
else
    echo "  ⏭️  SKIP: TC16: shellcheck not installed"
fi

# =============================================================================
# Cleanup
# =============================================================================
rm -f "$FUNC_HELPER"

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Results: $PASS passed, $FAIL failed, $TOTAL total"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $FAIL -gt 0 ]; then
    exit 1
else
    echo "  All tests passed! 🎉"
    exit 0
fi
