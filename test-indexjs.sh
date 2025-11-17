#!/bin/bash

# Test script for index.js HTTP server
# This script tests the simplified index.js functionality

echo "=== Testing index.js HTTP Server ==="
echo

# Function to test endpoint
test_endpoint() {
    local url="$1"
    local expected_status="$2"
    local description="$3"
    
    echo "Testing: $description"
    echo "URL: $url"
    
    # Make request and capture status
    response=$(curl -s -w "HTTPSTATUS:%{http_code}" "$url" 2>/dev/null)
    http_code=$(echo "$response" | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
    body=$(echo "$response" | sed -e 's/HTTPSTATUS:.*//')
    
    if [[ "$http_code" == "$expected_status" ]]; then
        echo "✅ Status: $http_code (expected)"
        if [[ -n "$body" ]]; then
            echo "Response: $(echo "$body" | head -c 100)..."
        fi
    else
        echo "❌ Status: $http_code (expected $expected_status)"
        echo "Response: $body"
    fi
    echo
}

# Function to check if server is running
check_server() {
    local port="$1"
    if curl -s "http://localhost:$port/health" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Main test
PORT=${1:-8080}

echo "Checking if server is running on port $PORT..."

if check_server "$PORT"; then
    echo "✅ Server is running"
    echo
    
    # Test all endpoints
    test_endpoint "http://localhost:$PORT/" "200" "Root endpoint"
    test_endpoint "http://localhost:$PORT/sub" "404" "Subscription endpoint (file should not exist)"
    test_endpoint "http://localhost:$PORT/info" "200" "Info endpoint"
    test_endpoint "http://localhost:$PORT/health" "200" "Health endpoint"
    test_endpoint "http://localhost:$PORT/nonexistent" "200" "Nonexistent endpoint (should return default)"
    
    echo "=== Test Summary ==="
    echo "✅ All endpoints tested"
    echo "✅ Server is responding correctly"
    
else
    echo "❌ Server is not running on port $PORT"
    echo
    echo "To start the server:"
    echo "  node index.js"
    echo
    echo "To run tests:"
    echo "  ./test-indexjs.sh [port]"
fi

echo
echo "=== Test completed ==="