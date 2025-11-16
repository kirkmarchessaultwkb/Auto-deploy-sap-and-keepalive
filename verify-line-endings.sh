#!/bin/bash

# ============================================================================
# Line Endings Verification Script
# Purpose: Verify all shell scripts have correct LF line endings
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Line Endings Verification Tool${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

TOTAL_FILES=0
PASSED_FILES=0
FAILED_FILES=0

check_file() {
    local file="$1"
    TOTAL_FILES=$((TOTAL_FILES + 1))
    
    if [ ! -f "$file" ]; then
        echo -e "${YELLOW}⚠️  $file: File not found${NC}"
        return 1
    fi
    
    # Check for CRLF - use a simpler method
    if grep -q $'\r' "$file" 2>/dev/null; then
        local count=$(grep -o $'\r' "$file" 2>/dev/null | wc -l)
        echo -e "${RED}❌ $file: Found $count CRLF line endings${NC}"
        FAILED_FILES=$((FAILED_FILES + 1))
        return 1
    else
        echo -e "${GREEN}✅ $file: LF only (correct)${NC}"
        PASSED_FILES=$((PASSED_FILES + 1))
        return 0
    fi
}

echo -e "${BLUE}Checking Shell Scripts:${NC}"
echo "----------------------------------------"

# Check all .sh files
for file in *.sh; do
    [ -f "$file" ] && check_file "$file"
done

echo ""
echo -e "${BLUE}Checking JavaScript Files:${NC}"
echo "----------------------------------------"

# Check all .js files
for file in *.js; do
    [ -f "$file" ] && check_file "$file"
done

echo ""
echo -e "${BLUE}Checking JSON Files:${NC}"
echo "----------------------------------------"

# Check all .json files
for file in *.json; do
    [ -f "$file" ] && check_file "$file"
done

echo ""
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Verification Summary${NC}"
echo -e "${BLUE}============================================${NC}"
echo -e "Total files checked: ${TOTAL_FILES}"
echo -e "${GREEN}Passed: ${PASSED_FILES}${NC}"
if [ $FAILED_FILES -gt 0 ]; then
    echo -e "${RED}Failed: ${FAILED_FILES}${NC}"
else
    echo -e "Failed: ${FAILED_FILES}"
fi
echo ""

if [ $FAILED_FILES -eq 0 ]; then
    echo -e "${GREEN}✅ All files have correct LF line endings!${NC}"
    echo ""
    echo -e "${BLUE}Git Attributes Configuration:${NC}"
    if [ -f ".gitattributes" ]; then
        echo -e "${GREEN}✅ .gitattributes file exists${NC}"
        echo ""
        echo "Content:"
        cat .gitattributes | grep -E "^\*\.(sh|js|json)" | while read line; do
            echo "  $line"
        done
    else
        echo -e "${YELLOW}⚠️  .gitattributes file not found${NC}"
    fi
    echo ""
    exit 0
else
    echo -e "${RED}❌ Some files have incorrect line endings!${NC}"
    echo ""
    echo -e "${YELLOW}Fix with:${NC}"
    echo "  sed -i 's/\r$//' <filename>"
    echo "  or"
    echo "  dos2unix <filename>"
    echo ""
    exit 1
fi
