#!/bin/bash

# =============================================================================
# Test Script for Argo Diagnostic
# Purpose: Validate the argo-diagnostic.sh script functionality
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results
TESTS_PASSED=0
TESTS_FAILED=0

# Logging functions
log_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

log_pass() {
    echo -e "${GREEN}[✓ PASS]${NC} $1"
    ((TESTS_PASSED++))
}

log_fail() {
    echo -e "${RED}[✗ FAIL]${NC} $1"
    ((TESTS_FAILED++))
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# =============================================================================
# Prerequisite Checks
# =============================================================================

check_prerequisites() {
    log_info "=========================================="
    log_info "Checking Prerequisites"
    log_info "=========================================="
    
    # Check if script exists
    log_test "Checking if argo-diagnostic.sh exists..."
    if [[ ! -f "./argo-diagnostic.sh" ]]; then
        log_fail "argo-diagnostic.sh not found in current directory"
        return 1
    fi
    log_pass "argo-diagnostic.sh found"
    
    # Check if script is executable
    log_test "Checking if script is executable..."
    if [[ ! -x "./argo-diagnostic.sh" ]]; then
        log_fail "argo-diagnostic.sh is not executable"
        chmod +x ./argo-diagnostic.sh
        log_info "Made script executable"
    fi
    log_pass "Script is executable"
    
    # Check if bash is available
    log_test "Checking bash version..."
    if ! command -v bash >/dev/null 2>&1; then
        log_fail "bash not found"
        return 1
    fi
    BASH_VERSION=$(bash --version | head -1)
    log_pass "bash found: $BASH_VERSION"
    
    return 0
}

# =============================================================================
# Syntax Checks
# =============================================================================

check_syntax() {
    log_info "=========================================="
    log_info "Checking Syntax"
    log_info "=========================================="
    
    log_test "Validating bash syntax..."
    if bash -n ./argo-diagnostic.sh 2>/tmp/bash-syntax-error.txt; then
        log_pass "Bash syntax is valid"
    else
        log_fail "Bash syntax error"
        cat /tmp/bash-syntax-error.txt
        return 1
    fi
    
    log_test "Checking for CRLF line endings..."
    if grep -q $'\r' ./argo-diagnostic.sh 2>/dev/null; then
        log_fail "CRLF line endings found (should be LF only)"
        return 1
    else
        log_pass "No CRLF line endings found (all LF)"
    fi
    
    return 0
}

# =============================================================================
# Function Checks
# =============================================================================

check_functions() {
    log_info "=========================================="
    log_info "Checking Functions"
    log_info "=========================================="
    
    # Check for critical functions
    CRITICAL_FUNCTIONS=(
        "log_info"
        "log_warn"
        "log_error"
        "log_success"
        "log_debug"
        "load_config"
        "setup_directories"
        "detect_arch"
        "start_keepalive_server"
        "download_cloudflared"
        "start_cloudflared_tunnel"
        "check_service_status"
        "main"
    )
    
    log_test "Checking critical functions..."
    for func in "${CRITICAL_FUNCTIONS[@]}"; do
        if grep -q "^${func}()" ./argo-diagnostic.sh; then
            log_pass "Function found: $func"
        else
            log_fail "Function missing: $func"
            return 1
        fi
    done
    
    return 0
}

# =============================================================================
# Configuration Checks
# =============================================================================

check_configuration() {
    log_info "=========================================="
    log_info "Checking Configuration Handling"
    log_info "=========================================="
    
    # Check if script can handle missing config
    log_test "Checking config file path..."
    if grep -q "CONFIG_FILE=" ./argo-diagnostic.sh; then
        log_pass "CONFIG_FILE variable is defined"
    else
        log_fail "CONFIG_FILE variable not found"
        return 1
    fi
    
    # Check for default port
    log_test "Checking default port..."
    if grep -q "KEEPALIVE_PORT=" ./argo-diagnostic.sh; then
        log_pass "KEEPALIVE_PORT default is set"
    else
        log_fail "KEEPALIVE_PORT default not found"
    fi
    
    return 0
}

# =============================================================================
# Variable Checks
# =============================================================================

check_variables() {
    log_info "=========================================="
    log_info "Checking Variables"
    log_info "=========================================="
    
    # Check directory variables
    VARIABLES=(
        "CONFIG_FILE"
        "WORK_DIR"
        "BIN_DIR"
        "LOG_DIR"
        "KEEPALIVE_PORT"
        "PID_FILE_KEEPALIVE"
        "PID_FILE_CLOUDFLARED"
        "TUNNEL_URL_FILE"
        "LOG_CLOUDFLARED"
    )
    
    log_test "Checking variable definitions..."
    for var in "${VARIABLES[@]}"; do
        if grep -q "^${var}=" ./argo-diagnostic.sh; then
            log_pass "Variable defined: $var"
        else
            log_fail "Variable not defined: $var"
            return 1
        fi
    done
    
    return 0
}

# =============================================================================
# Logging Function Checks
# =============================================================================

check_logging() {
    log_info "=========================================="
    log_info "Checking Logging Functions"
    log_info "=========================================="
    
    # Check for timestamp in logs
    log_test "Checking timestamp format..."
    if grep -q "date +" ./argo-diagnostic.sh; then
        log_pass "Timestamp format is present in logging functions"
    else
        log_fail "Timestamp format not found"
        return 1
    fi
    
    # Check for logging functions
    log_test "Checking for logging functions..."
    LOG_FUNCS=("log_info" "log_warn" "log_error" "log_success")
    for func in "${LOG_FUNCS[@]}"; do
        if grep -q "^${func}()" ./argo-diagnostic.sh; then
            log_pass "Logging function found: $func"
        else
            log_fail "Logging function missing: $func"
            return 1
        fi
    done
    
    return 0
}

# =============================================================================
# Error Handling Checks
# =============================================================================

check_error_handling() {
    log_info "=========================================="
    log_info "Checking Error Handling"
    log_info "=========================================="
    
    # Check for exit conditions
    log_test "Checking exit handling..."
    if grep -q "exit 1" ./argo-diagnostic.sh; then
        log_pass "Exit conditions are present"
    else
        log_fail "No exit conditions found"
        return 1
    fi
    
    # Check for trap handlers
    log_test "Checking trap handlers..."
    if grep -q "trap" ./argo-diagnostic.sh; then
        log_pass "Trap handlers are present"
    else
        log_fail "No trap handlers found"
    fi
    
    # Check for return codes
    log_test "Checking return codes..."
    if grep -q "return 0\|return 1" ./argo-diagnostic.sh; then
        log_pass "Return codes are properly used"
    else
        log_fail "Return codes not found"
        return 1
    fi
    
    return 0
}

# =============================================================================
# Service Startup Checks
# =============================================================================

check_service_startup() {
    log_info "=========================================="
    log_info "Checking Service Startup Logic"
    log_info "=========================================="
    
    # Check keepalive startup
    log_test "Checking keepalive server startup logic..."
    if grep -q "python3 -m http.server" ./argo-diagnostic.sh; then
        log_pass "Python HTTP server command found"
    else
        log_fail "Python HTTP server command not found"
        return 1
    fi
    
    # Check netcat fallback
    log_test "Checking netcat fallback..."
    if grep -q "nc -l" ./argo-diagnostic.sh; then
        log_pass "Netcat fallback is present"
    else
        log_fail "Netcat fallback not found"
    fi
    
    # Check cloudflared startup
    log_test "Checking cloudflared tunnel startup..."
    if grep -q "cloudflared tunnel" ./argo-diagnostic.sh; then
        log_pass "Cloudflared tunnel command found"
    else
        log_fail "Cloudflared tunnel command not found"
        return 1
    fi
    
    return 0
}

# =============================================================================
# Process Management Checks
# =============================================================================

check_process_management() {
    log_info "=========================================="
    log_info "Checking Process Management"
    log_info "=========================================="
    
    # Check PID file handling
    log_test "Checking PID file handling..."
    if grep -q "echo.*PID.*>" ./argo-diagnostic.sh; then
        log_pass "PID file saving is implemented"
    else
        log_fail "PID file saving not found"
        return 1
    fi
    
    # Check process monitoring
    log_test "Checking process monitoring..."
    if grep -q "kill -0" ./argo-diagnostic.sh; then
        log_pass "Process alive checks are implemented"
    else
        log_fail "Process checks not found"
        return 1
    fi
    
    # Check health check loop
    log_test "Checking health check loop..."
    if grep -q "while true" ./argo-diagnostic.sh; then
        log_pass "Continuous monitoring loop is present"
    else
        log_fail "Monitoring loop not found"
    fi
    
    return 0
}

# =============================================================================
# Main Execution Checks
# =============================================================================

check_main_flow() {
    log_info "=========================================="
    log_info "Checking Main Execution Flow"
    log_info "=========================================="
    
    FLOW_STEPS=(
        "print_header"
        "load_config"
        "setup_directories"
        "detect_arch"
        "start_keepalive_server"
        "download_cloudflared"
        "start_cloudflared_tunnel"
        "check_service_status"
        "print_final_summary"
    )
    
    log_test "Checking main flow steps..."
    for step in "${FLOW_STEPS[@]}"; do
        if grep -q "$step" ./argo-diagnostic.sh; then
            log_pass "Main flow step found: $step"
        else
            log_fail "Main flow step missing: $step"
            return 1
        fi
    done
    
    return 0
}

# =============================================================================
# Summary and Results
# =============================================================================

print_summary() {
    log_info "=========================================="
    log_info "Test Summary"
    log_info "=========================================="
    
    TOTAL_TESTS=$((TESTS_PASSED + TESTS_FAILED))
    
    echo ""
    echo "  Total Tests:   $TOTAL_TESTS"
    echo -e "  ${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "  ${RED}Failed: $TESTS_FAILED${NC}"
    echo ""
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}=========================================="
        echo "All tests passed! Script is ready to use."
        echo "=========================================${NC}"
        return 0
    else
        echo -e "${RED}=========================================="
        echo "Some tests failed. Please review above."
        echo "=========================================${NC}"
        return 1
    fi
}

# =============================================================================
# Main Test Execution
# =============================================================================

main() {
    echo ""
    echo "╔════════════════════════════════════════════╗"
    echo "║  Argo Diagnostic Script Test Suite         ║"
    echo "║  Version: 1.0.0                           ║"
    echo "╚════════════════════════════════════════════╝"
    echo ""
    
    # Run all checks
    check_prerequisites || return 1
    echo ""
    
    check_syntax || return 1
    echo ""
    
    check_functions || return 1
    echo ""
    
    check_configuration || return 1
    echo ""
    
    check_variables || return 1
    echo ""
    
    check_logging || return 1
    echo ""
    
    check_error_handling || return 1
    echo ""
    
    check_service_startup || return 1
    echo ""
    
    check_process_management || return 1
    echo ""
    
    check_main_flow || return 1
    echo ""
    
    print_summary
}

# Run main function
main "$@"
exit $?
