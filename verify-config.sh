#!/bin/bash
# =============================================================================
# Config.json Verification Script
# Description: Verify config.json has all required fields with valid values
# =============================================================================

# Default config file path (can be overridden)
CONFIG_FILE="${1:-/home/container/config.json}"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Required fields
REQUIRED_FIELDS=(
    "cf_domain"
    "cf_token"
    "uuid"
    "nezha_server"
    "nezha_port"
    "nezha_key"
    "port"
)

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

log_info() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

echo "========================================"
echo "Config.json Verification"
echo "========================================"
echo "Config file: $CONFIG_FILE"
echo ""

# Test 1: File exists
echo "[TEST] Checking if config file exists..."
if [[ -f "$CONFIG_FILE" ]]; then
    log_info "Config file exists"
    ((TESTS_PASSED++))
else
    log_error "Config file not found at: $CONFIG_FILE"
    ((TESTS_FAILED++))
    echo ""
    echo "========================================"
    echo "Summary: $TESTS_PASSED passed, $TESTS_FAILED failed"
    echo "========================================"
    exit 1
fi

# Test 2: Valid JSON syntax
echo "[TEST] Checking JSON syntax..."
if command -v jq >/dev/null 2>&1; then
    if jq empty "$CONFIG_FILE" 2>/dev/null; then
        log_info "JSON syntax is valid"
        ((TESTS_PASSED++))
    else
        log_error "Invalid JSON syntax"
        ((TESTS_FAILED++))
    fi
else
    # Fallback: Try to parse with grep
    if grep -q '^{' "$CONFIG_FILE" && grep -q '^}' "$CONFIG_FILE"; then
        log_warn "Cannot verify JSON syntax (jq not installed), basic check passed"
        ((TESTS_PASSED++))
    else
        log_error "Invalid JSON format (basic check)"
        ((TESTS_FAILED++))
    fi
fi

# Test 3: Check required fields exist and are not empty
echo "[TEST] Checking required fields..."
for field in "${REQUIRED_FIELDS[@]}"; do
    value=$(grep -o "\"$field\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "$CONFIG_FILE" | sed 's/.*"\([^"]*\)".*/\1/' || echo "")
    
    if [[ -z "$value" ]]; then
        log_error "Field '$field' is missing or empty"
        ((TESTS_FAILED++))
    else
        log_info "Field '$field' = '$value'"
        ((TESTS_PASSED++))
    fi
done

# Test 4: Validate UUID format
echo "[TEST] Validating UUID format..."
UUID=$(grep -o '"uuid"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | sed 's/.*"\([^"]*\)".*/\1/' || echo "")
if [[ "$UUID" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]; then
    log_info "UUID format is valid"
    ((TESTS_PASSED++))
else
    log_error "UUID format is invalid (expected: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)"
    ((TESTS_FAILED++))
fi

# Test 5: Validate port is a number
echo "[TEST] Validating port number..."
PORT=$(grep -o '"port"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | sed 's/.*"\([^"]*\)".*/\1/' || echo "")
if [[ "$PORT" =~ ^[0-9]+$ ]] && [[ "$PORT" -ge 1 ]] && [[ "$PORT" -le 65535 ]]; then
    log_info "Port is valid: $PORT"
    ((TESTS_PASSED++))
else
    log_error "Port is invalid (expected: 1-65535)"
    ((TESTS_FAILED++))
fi

# Test 6: Validate nezha_port is a number
echo "[TEST] Validating nezha_port number..."
NEZHA_PORT=$(grep -o '"nezha_port"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | sed 's/.*"\([^"]*\)".*/\1/' || echo "")
if [[ "$NEZHA_PORT" =~ ^[0-9]+$ ]] && [[ "$NEZHA_PORT" -ge 1 ]] && [[ "$NEZHA_PORT" -le 65535 ]]; then
    log_info "Nezha port is valid: $NEZHA_PORT"
    ((TESTS_PASSED++))
else
    log_error "Nezha port is invalid (expected: 1-65535)"
    ((TESTS_FAILED++))
fi

# Test 7: Validate cf_domain format
echo "[TEST] Validating cf_domain format..."
CF_DOMAIN=$(grep -o '"cf_domain"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | sed 's/.*"\([^"]*\)".*/\1/' || echo "")
if [[ "$CF_DOMAIN" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)*$ ]]; then
    log_info "CF domain format is valid: $CF_DOMAIN"
    ((TESTS_PASSED++))
else
    log_error "CF domain format is invalid"
    ((TESTS_FAILED++))
fi

# Test 8: Validate nezha_server format
echo "[TEST] Validating nezha_server format..."
NEZHA_SERVER=$(grep -o '"nezha_server"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | sed 's/.*"\([^"]*\)".*/\1/' || echo "")
if [[ "$NEZHA_SERVER" =~ : ]]; then
    log_info "Nezha server format is valid: $NEZHA_SERVER"
    ((TESTS_PASSED++))
else
    log_warn "Nezha server missing port (expected: host:port)"
    ((TESTS_PASSED++))
fi

echo ""
echo "========================================"
echo "Summary: $TESTS_PASSED passed, $TESTS_FAILED failed"
echo "========================================"

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed!${NC}"
    exit 1
fi
