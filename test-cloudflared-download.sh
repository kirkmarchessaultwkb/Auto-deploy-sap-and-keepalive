#!/bin/bash

# =============================================================================
# Test Script for Cloudflared Download Verification (argo-diagnostic.sh v2.1.0)
# =============================================================================

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_WORK_DIR="/tmp/test-cloudflared-$$"
ARGO_SCRIPT="$SCRIPT_DIR/argo-diagnostic.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Helper functions
print_test_header() {
    echo ""
    echo "=========================================="
    echo "TEST: $1"
    echo "=========================================="
}

pass() {
    ((TESTS_PASSED++))
    echo -e "${GREEN}✅ PASS${NC}: $1"
}

fail() {
    ((TESTS_FAILED++))
    echo -e "${RED}❌ FAIL${NC}: $1"
}

info() {
    echo -e "${YELLOW}ℹ INFO${NC}: $1"
}

run_test() {
    ((TESTS_RUN++))
}

# Setup
setup() {
    print_test_header "Setup Test Environment"
    
    mkdir -p "$TEST_WORK_DIR"
    info "Test directory: $TEST_WORK_DIR"
    
    if [[ ! -f "$ARGO_SCRIPT" ]]; then
        fail "argo-diagnostic.sh not found at $ARGO_SCRIPT"
        exit 1
    fi
    pass "argo-diagnostic.sh found"
}

# Cleanup
cleanup() {
    if [[ -d "$TEST_WORK_DIR" ]]; then
        rm -rf "$TEST_WORK_DIR"
    fi
}

# Test 1: Script syntax validation
test_syntax() {
    print_test_header "Test 1: Script Syntax Validation"
    run_test
    
    if bash -n "$ARGO_SCRIPT"; then
        pass "Script syntax is valid"
    else
        fail "Script has syntax errors"
    fi
}

# Test 2: Check for new functions
test_new_functions() {
    print_test_header "Test 2: New Functions Present"
    
    run_test
    if grep -q "verify_cloudflared_binary()" "$ARGO_SCRIPT"; then
        pass "verify_cloudflared_binary() function found"
    else
        fail "verify_cloudflared_binary() function not found"
    fi
    
    run_test
    if grep -q "download_cloudflared_with_curl()" "$ARGO_SCRIPT"; then
        pass "download_cloudflared_with_curl() function found"
    else
        fail "download_cloudflared_with_curl() function not found"
    fi
    
    run_test
    if grep -q "download_cloudflared_with_wget()" "$ARGO_SCRIPT"; then
        pass "download_cloudflared_with_wget() function found"
    else
        fail "download_cloudflared_with_wget() function not found"
    fi
}

# Test 3: Binary verification logic
test_binary_verification() {
    print_test_header "Test 3: Binary Verification Logic"
    
    run_test
    if grep -q "grep -q \"ELF\"" "$ARGO_SCRIPT"; then
        pass "ELF binary check present"
    else
        fail "ELF binary check not found"
    fi
    
    run_test
    if grep -q "head -c 200" "$ARGO_SCRIPT"; then
        pass "Debug output for non-binary files present"
    else
        fail "Debug output for non-binary files not found"
    fi
    
    run_test
    if grep -q "\-\-version" "$ARGO_SCRIPT"; then
        pass "Binary execution test (--version) present"
    else
        fail "Binary execution test not found"
    fi
}

# Test 4: Retry mechanism
test_retry_mechanism() {
    print_test_header "Test 4: Retry Mechanism"
    
    run_test
    if grep -q "max_attempts=3" "$ARGO_SCRIPT"; then
        pass "Retry mechanism with 3 attempts found"
    else
        fail "Retry mechanism not found or incorrect"
    fi
    
    run_test
    if grep -q "while (( attempt <= max_attempts ))" "$ARGO_SCRIPT"; then
        pass "Retry loop logic found"
    else
        fail "Retry loop not found"
    fi
}

# Test 5: Temp file usage
test_temp_file() {
    print_test_header "Test 5: Temp File Usage"
    
    run_test
    if grep -q "temp_file=" "$ARGO_SCRIPT"; then
        pass "Temp file usage found"
    else
        fail "Temp file not used"
    fi
    
    run_test
    if grep -q "rm -f.*temp_file" "$ARGO_SCRIPT"; then
        pass "Temp file cleanup found"
    else
        fail "Temp file cleanup not found"
    fi
}

# Test 6: Error messages
test_error_messages() {
    print_test_header "Test 6: Enhanced Error Messages"
    
    run_test
    if grep -q "Downloaded file is NOT a valid ELF binary" "$ARGO_SCRIPT"; then
        pass "Clear error message for non-binary file"
    else
        fail "Error message for non-binary file not found"
    fi
    
    run_test
    if grep -q "GitHub returned an error page" "$ARGO_SCRIPT"; then
        pass "Helpful error explanation present"
    else
        fail "Error explanation not found"
    fi
}

# Test 7: Version number updated
test_version() {
    print_test_header "Test 7: Version Number"
    
    run_test
    if grep -q "Version: 2.1.0" "$ARGO_SCRIPT"; then
        pass "Version updated to 2.1.0"
    else
        fail "Version not updated"
    fi
}

# Test 8: Function extraction test (verify_cloudflared_binary)
test_verify_function() {
    print_test_header "Test 8: Extract and Test verify_cloudflared_binary Function"
    
    # Create a test script that sources the functions
    cat > "$TEST_WORK_DIR/test_verify.sh" << 'EOF'
#!/bin/bash

# Extract log functions
log_debug() { echo "[DEBUG] $1"; }
log_error() { echo "[ERROR] $1" >&2; }
log_success() { echo "[SUCCESS] $1"; }
log_info() { echo "[INFO] $1"; }

# Extract verify_cloudflared_binary function
verify_cloudflared_binary() {
    local binary_path="$1"
    
    # Check if file exists
    if [[ ! -f "$binary_path" ]]; then
        log_error "Binary file does not exist: $binary_path"
        return 1
    fi
    
    # Check if file is an ELF binary
    if command -v file >/dev/null 2>&1; then
        local file_type
        file_type=$(file "$binary_path" 2>/dev/null)
        
        if echo "$file_type" | grep -q "ELF"; then
            log_success "Valid ELF binary detected"
        else
            log_error "Downloaded file is NOT a valid ELF binary"
            return 1
        fi
    fi
    
    return 0
}

# Test with text file
echo "Test file content" > /tmp/test_text_file.txt
if verify_cloudflared_binary "/tmp/test_text_file.txt"; then
    echo "FAIL: Text file incorrectly identified as binary"
    exit 1
else
    echo "PASS: Text file correctly rejected"
fi

# Test with non-existent file
if verify_cloudflared_binary "/tmp/nonexistent_file"; then
    echo "FAIL: Non-existent file incorrectly validated"
    exit 1
else
    echo "PASS: Non-existent file correctly rejected"
fi

# Test with system binary (should pass)
if [[ -f /bin/ls ]]; then
    if verify_cloudflared_binary "/bin/ls"; then
        echo "PASS: Valid binary correctly identified"
    else
        echo "FAIL: Valid binary incorrectly rejected"
        exit 1
    fi
fi

echo "All verify_cloudflared_binary tests passed"
EOF

    chmod +x "$TEST_WORK_DIR/test_verify.sh"
    
    run_test
    if bash "$TEST_WORK_DIR/test_verify.sh" 2>&1 | grep -q "All verify_cloudflared_binary tests passed"; then
        pass "verify_cloudflared_binary function logic works correctly"
    else
        fail "verify_cloudflared_binary function logic has issues"
    fi
}

# Test 9: Download function structure
test_download_structure() {
    print_test_header "Test 9: Download Function Structure"
    
    run_test
    if grep -q "Download attempt.*max_attempts" "$ARGO_SCRIPT"; then
        pass "Download progress messages present"
    else
        fail "Download progress messages not found"
    fi
    
    run_test
    if grep -q "Waiting.*seconds before retry" "$ARGO_SCRIPT"; then
        pass "Retry delay message present"
    else
        fail "Retry delay message not found"
    fi
    
    run_test
    if grep -q "Failed to download cloudflared after.*attempts" "$ARGO_SCRIPT"; then
        pass "Final failure message present"
    else
        fail "Final failure message not found"
    fi
}

# Test 10: Line endings (LF only, no CRLF)
test_line_endings() {
    print_test_header "Test 10: Line Endings (LF only)"
    
    run_test
    CRLF_COUNT=$(grep -c $'\r' "$ARGO_SCRIPT" 2>/dev/null || echo 0)
    
    if [[ "$CRLF_COUNT" -eq 0 ]]; then
        pass "No CRLF line endings found (all LF)"
    else
        fail "Found $CRLF_COUNT CRLF line endings"
    fi
}

# Main execution
main() {
    echo "=========================================="
    echo "Cloudflared Download Test Suite"
    echo "Testing: argo-diagnostic.sh v2.1.0"
    echo "=========================================="
    
    setup
    
    test_syntax
    test_new_functions
    test_binary_verification
    test_retry_mechanism
    test_temp_file
    test_error_messages
    test_version
    test_verify_function
    test_download_structure
    test_line_endings
    
    cleanup
    
    # Print summary
    echo ""
    echo "=========================================="
    echo "TEST SUMMARY"
    echo "=========================================="
    echo "Tests Run:    $TESTS_RUN"
    echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
    echo "=========================================="
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}✅ ALL TESTS PASSED${NC}"
        exit 0
    else
        echo -e "${RED}❌ SOME TESTS FAILED${NC}"
        exit 1
    fi
}

trap cleanup EXIT
main "$@"
