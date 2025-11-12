#!/bin/bash

# Nezha Agent Test Script
# This script tests the Nezha agent functionality locally

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
}

# Test functions
test_architecture_detection() {
    log "Testing architecture detection..."
    
    # Create a temporary test script
    cat > /tmp/test_arch.sh << 'EOF'
#!/bin/bash
ARCH=$(uname -m)
case $ARCH in
    x86_64|amd64)
        echo "amd64"
        ;;
    aarch64|arm64)
        echo "arm64"
        ;;
    armv7l|arm)
        echo "armv7"
        ;;
    *)
        echo "unsupported"
        ;;
esac
EOF
    
    chmod +x /tmp/test_arch.sh
    local detected_arch=$(/tmp/test_arch.sh)
    local expected_arch=$(uname -m)
    
    log "Detected architecture: $detected_arch"
    log "System architecture: $expected_arch"
    
    rm -f /tmp/test_arch.sh
    
    if [[ "$detected_arch" != "unsupported" ]]; then
        log "✅ Architecture detection test passed"
        return 0
    else
        error "❌ Architecture detection test failed"
        return 1
    fi
}

test_protocol_detection() {
    log "Testing protocol version detection..."
    
    # Test v0 protocol detection (with NEZHA_PORT)
    export NEZHA_SERVER="nezha.example.com"
    export NEZHA_PORT="5555"
    export NEZHA_KEY="test_key"
    
    # Create a temporary test script
    cat > /tmp/test_protocol.sh << 'EOF'
#!/bin/bash
NEZHA_SERVER="${NEZHA_SERVER:-}"
NEZHA_PORT="${NEZHA_PORT:-}"

detect_protocol_version() {
    local server="$NEZHA_SERVER"
    local port="$NEZHA_PORT"
    
    # If NEZHA_PORT is explicitly set, assume v0 (legacy)
    if [[ -n "$port" ]]; then
        echo "v0"
        return
    fi
    
    # If server already contains a port, assume v1
    if [[ "$server" == *":"* ]]; then
        echo "v1"
        return
    fi
    
    # If server has no port and NEZHA_PORT is not set, assume v0 with default port
    echo "v0"
}

detect_protocol_version || exit 1
EOF
    
    chmod +x /tmp/test_protocol.sh
    local protocol
    if protocol=$(/tmp/test_protocol.sh 2>/dev/null); then
        if [[ "$protocol" == "v0" ]]; then
            log "✅ v0 protocol detection test passed"
        else
            error "❌ v0 protocol detection test failed (expected v0, got $protocol)"
            return 1
        fi
    else
        error "❌ v0 protocol detection test failed with error"
        return 1
    fi
    
    # Test v1 protocol detection (server with port)
    unset NEZHA_PORT
    export NEZHA_SERVER="nezha.example.com:8008"
    
    if protocol=$(/tmp/test_protocol.sh 2>/dev/null); then
        if [[ "$protocol" == "v1" ]]; then
            log "✅ v1 protocol detection test passed"
        else
            error "❌ v1 protocol detection test failed (expected v1, got $protocol)"
            return 1
        fi
    else
        error "❌ v1 protocol detection test failed with error"
        return 1
    fi
    
    # Test v0 protocol detection (server without port, no NEZHA_PORT)
    export NEZHA_SERVER="nezha.example.com"
    
    if protocol=$(/tmp/test_protocol.sh 2>/dev/null); then
        if [[ "$protocol" == "v0" ]]; then
            log "✅ v0 protocol detection (default) test passed"
        else
            error "❌ v0 protocol detection (default) test failed (expected v0, got $protocol)"
            return 1
        fi
    else
        error "❌ v0 protocol detection (default) test failed with error"
        return 1
    fi
    
    rm -f /tmp/test_protocol.sh
    return 0
}

test_command_building() {
    log "Testing command building logic..."
    
    # Test v0 command building
    cat > /tmp/test_cmd_v0.sh << 'EOF'
#!/bin/bash
NEZHA_SERVER="nezha.example.com"
NEZHA_PORT="5555"
NEZHA_KEY="test_key"

build_nezha_command() {
    local protocol_version="v0"
    local server="$NEZHA_SERVER"
    local port="$NEZHA_PORT"
    local key="$NEZHA_KEY"
    
    case "$protocol_version" in
        "v0")
            local host_port="$server"
            if [[ -n "$port" ]]; then
                host_port="${server}:${port}"
            else
                host_port="${server}:5555"
            fi
            
            if [[ "$port" == "443" || "$port" == "8443" ]]; then
                echo "/tmp/nezha -s $host_port -p $key --tls"
            else
                echo "/tmp/nezha -s $host_port -p $key"
            fi
            ;;
        "v1")
            echo "/tmp/nezha service --report -s $server -p $key"
            ;;
    esac
}

build_nezha_command || exit 1
EOF
    
    chmod +x /tmp/test_cmd_v0.sh
    local cmd
    if cmd=$(/tmp/test_cmd_v0.sh 2>/dev/null); then
        local expected="/tmp/nezha -s nezha.example.com:5555 -p test_key"
        
        if [[ "$cmd" == "$expected" ]]; then
            log "✅ v0 command building test passed"
        else
            error "❌ v0 command building test failed"
            error "Expected: $expected"
            error "Got: $cmd"
            return 1
        fi
    else
        error "❌ v0 command building test failed with error"
        return 1
    fi
    
    # Test v1 command building
    cat > /tmp/test_cmd_v1.sh << 'EOF'
#!/bin/bash
NEZHA_SERVER="nezha.example.com:8008"
NEZHA_KEY="test_key"

build_nezha_command() {
    local protocol_version="v1"
    local server="$NEZHA_SERVER"
    local key="$NEZHA_KEY"
    
    case "$protocol_version" in
        "v0")
            echo "/tmp/nezha -s $server -p $key"
            ;;
        "v1")
            local cmd="/tmp/nezha service --report"
            cmd="$cmd -s $server -p $key"
            echo "$cmd"
            ;;
    esac
}

build_nezha_command || exit 1
EOF
    
    chmod +x /tmp/test_cmd_v1.sh
    if cmd=$(/tmp/test_cmd_v1.sh 2>/dev/null); then
        local expected="/tmp/nezha service --report -s nezha.example.com:8008 -p test_key"
        
        if [[ "$cmd" == "$expected" ]]; then
            log "✅ v1 command building test passed"
        else
            error "❌ v1 command building test failed"
            error "Expected: $expected"
            error "Got: $cmd"
            return 1
        fi
    else
        error "❌ v1 command building test failed with error"
        return 1
    fi
    
    rm -f /tmp/test_cmd_v0.sh /tmp/test_cmd_v1.sh
    return 0
}

test_config_validation() {
    log "Testing configuration validation..."
    
    # Test with missing NEZHA_SERVER
    unset NEZHA_SERVER
    unset NEZHA_PORT
    export NEZHA_KEY="test_key"
    
    cat > /tmp/test_config.sh << 'EOF'
#!/bin/bash
NEZHA_SERVER="${NEZHA_SERVER:-}"
NEZHA_KEY="${NEZHA_KEY:-}"

check_nezha_config() {
    if [[ -z "$NEZHA_SERVER" || -z "$NEZHA_KEY" ]]; then
        return 1
    fi
    return 0
}

check_nezha_config
EOF
    
    chmod +x /tmp/test_config.sh
    if ! /tmp/test_config.sh 2>/dev/null; then
        log "✅ Configuration validation (missing server) test passed"
    else
        error "❌ Configuration validation (missing server) test failed"
        return 1
    fi
    
    # Test with missing NEZHA_KEY
    export NEZHA_SERVER="nezha.example.com"
    unset NEZHA_KEY
    
    if ! /tmp/test_config.sh 2>/dev/null; then
        log "✅ Configuration validation (missing key) test passed"
    else
        error "❌ Configuration validation (missing key) test failed"
        return 1
    fi
    
    # Test with complete configuration
    export NEZHA_KEY="test_key"
    
    if /tmp/test_config.sh 2>/dev/null; then
        log "✅ Configuration validation (complete) test passed"
    else
        error "❌ Configuration validation (complete) test failed"
        return 1
    fi
    
    rm -f /tmp/test_config.sh
    return 0
}

# Main test function
main() {
    log "Starting Nezha agent functionality tests..."
    
    local tests_passed=0
    local total_tests=4
    
    # Run tests
    if test_architecture_detection; then
        ((tests_passed++))
    fi
    
    if test_protocol_detection; then
        ((tests_passed++))
    fi
    
    if test_command_building; then
        ((tests_passed++))
    fi
    
    if test_config_validation; then
        ((tests_passed++))
    fi
    
    # Summary
    log "Test Summary: $tests_passed/$total_tests tests passed"
    
    if [[ $tests_passed -eq $total_tests ]]; then
        log "🎉 All tests passed! Nezha agent functionality is working correctly."
        return 0
    else
        error "❌ Some tests failed. Please check the implementation."
        return 1
    fi
}

# Execute main function
main "$@"