#!/bin/bash

# Nezha Deployment Validation Script
# Validates that the Nezha integration is properly configured

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

# Check if required files exist
check_files() {
    log "Checking required files..."
    
    local files=(
        "nezha-agent.sh"
        "test-nezha.sh"
        "NEZHA_INTEGRATION.md"
    )
    
    local missing_files=0
    
    for file in "${files[@]}"; do
        if [[ -f "$file" ]]; then
            log "✅ $file exists"
        else
            error "❌ $file is missing"
            ((missing_files++))
        fi
    done
    
    if [[ $missing_files -eq 0 ]]; then
        log "✅ All required files are present"
        return 0
    else
        error "❌ $missing_files required files are missing"
        return 1
    fi
}

# Check file permissions
check_permissions() {
    log "Checking file permissions..."
    
    if [[ -x "nezha-agent.sh" ]]; then
        log "✅ nezha-agent.sh is executable"
    else
        error "❌ nezha-agent.sh is not executable"
        return 1
    fi
    
    if [[ -x "test-nezha.sh" ]]; then
        log "✅ test-nezha.sh is executable"
    else
        error "❌ test-nezha.sh is not executable"
        return 1
    fi
    
    return 0
}

# Check workflow modifications
check_workflow() {
    log "Checking workflow modifications..."
    
    local workflow_file=".github/workflows/自动部署代理节点.yml"
    
    if [[ -f "$workflow_file" ]]; then
        if grep -q "Setup Nezha agent" "$workflow_file"; then
            log "✅ Nezha agent setup step found in workflow"
        else
            error "❌ Nezha agent setup step not found in workflow"
            return 1
        fi
        
        if grep -q "nezha-agent.sh" "$workflow_file"; then
            log "✅ Nezha agent script reference found in workflow"
        else
            error "❌ Nezha agent script reference not found in workflow"
            return 1
        fi
    else
        error "❌ Workflow file not found: $workflow_file"
        return 1
    fi
    
    return 0
}

# Check README updates
check_readme() {
    log "Checking README updates..."
    
    if [[ -f "README.md" ]]; then
        if grep -q "哪吒监控集成" "README.md"; then
            log "✅ Nezha monitoring section found in README"
        else
            error "❌ Nezha monitoring section not found in README"
            return 1
        fi
        
        if grep -q "v0协议配置" "README.md"; then
            log "✅ v0 protocol configuration found in README"
        else
            error "❌ v0 protocol configuration not found in README"
            return 1
        fi
        
        if grep -q "v1协议配置" "README.md"; then
            log "✅ v1 protocol configuration found in README"
        else
            error "❌ v1 protocol configuration not found in README"
            return 1
        fi
    else
        error "❌ README.md not found"
        return 1
    fi
    
    return 0
}

# Run functionality tests
run_tests() {
    log "Running functionality tests..."
    
    if ./test-nezha.sh; then
        log "✅ All functionality tests passed"
        return 0
    else
        error "❌ Some functionality tests failed"
        return 1
    fi
}

# Validate script syntax
validate_syntax() {
    log "Validating script syntax..."
    
    if bash -n nezha-agent.sh; then
        log "✅ nezha-agent.sh syntax is valid"
    else
        error "❌ nezha-agent.sh has syntax errors"
        return 1
    fi
    
    if bash -n test-nezha.sh; then
        log "✅ test-nezha.sh syntax is valid"
    else
        error "❌ test-nezha.sh has syntax errors"
        return 1
    fi
    
    return 0
}

# Main validation function
main() {
    log "Starting Nezha deployment validation..."
    
    local checks_passed=0
    local total_checks=6
    
    # Run all checks
    if check_files; then
        ((checks_passed++))
    fi
    
    if check_permissions; then
        ((checks_passed++))
    fi
    
    if check_workflow; then
        ((checks_passed++))
    fi
    
    if check_readme; then
        ((checks_passed++))
    fi
    
    if validate_syntax; then
        ((checks_passed++))
    fi
    
    if run_tests; then
        ((checks_passed++))
    fi
    
    # Summary
    log "Validation Summary: $checks_passed/$total_checks checks passed"
    
    if [[ $checks_passed -eq $total_checks ]]; then
        log "🎉 All validation checks passed! Nezha integration is ready for deployment."
        return 0
    else
        error "❌ Some validation checks failed. Please address the issues before deployment."
        return 1
    fi
}

# Execute main function
main "$@"