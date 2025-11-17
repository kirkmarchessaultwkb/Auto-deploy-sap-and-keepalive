# Version Extraction Fix - Argo Diagnostic Script

## Problem Description

The `argo-diagnostic.sh` script was experiencing log pollution in version extraction, causing corrupted download URLs.

### Original Issue

```
[INFO] Target version: [2025-11-17 05:03:52] [✅ SUCCESS] Found available version: v2025.11.1
2025.11.1
```

This resulted in corrupted URLs:
```
Download URL: https://github.com/cloudflare/cloudflared/releases/download/[2025-11-17 05:03:52] [✅ SUCCESS] Found available version: v2025.11.1
2025.11.1/cloudflared-linux-arm64
```

### Root Cause

The `get_latest_available_cloudflared_version()` function was mixing log output with the actual return value:

```bash
# PROBLEMATIC CODE:
log_success "Found available version: v$version"  # This gets captured!
echo "$version"                                   # This also gets captured
```

When called with command substitution:
```bash
LATEST_VERSION=$(get_latest_available_cloudflared_version)
```

Both the log message and the version were captured into the variable.

## Solution Implemented

### 1. Removed Log Pollution from Version Function

**Before:**
```bash
if [[ "$http_status" =~ ^2 ]]; then
    log_success "Found available version: v$version"  # ❌ Log pollution
    echo "$version"
    return 0
fi
```

**After:**
```bash
if [[ "$http_status" =~ ^2 ]]; then
    echo "$version"  # ✅ Only the version
    return 0
fi
```

### 2. Added Version Validation and Cleaning

```bash
# Clean and validate version format
LATEST_VERSION=$(echo "$LATEST_VERSION" | tr -d '[:space:]')

# Verify version format (should be like 2025.11.1)
if [[ ! "$LATEST_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    log_error "Invalid version format: '$LATEST_VERSION'"
    log_error "Expected format: X.Y.Z (e.g., 2025.11.1)"
    return 1
fi
```

### 3. Moved Logging to Proper Location

**After version is captured cleanly:**
```bash
LATEST_VERSION=$(get_latest_available_cloudflared_version)

# Validation and logging AFTER capture
log_success "Found available version: v$LATEST_VERSION"
log_info "Target version: $LATEST_VERSION"
log_info "Architecture: $ARCH_CLOUDFLARED"

# Debug output to verify clean version
log_debug "Version: '$LATEST_VERSION' (length: ${#LATEST_VERSION})"
```

## Key Changes Made

### File: `argo-diagnostic.sh`

1. **Lines 448-449**: Removed `log_success` from version function
2. **Lines 469-471**: Removed `log_success` from fallback version function  
3. **Lines 505-513**: Added version validation and proper logging
4. **Line 510**: Added debug output to verify clean version

### New Features

1. **Version Format Validation**: Ensures version matches `X.Y.Z` pattern
2. **Whitespace Cleaning**: Removes any stray whitespace from version
3. **Debug Output**: Shows version content and length for troubleshooting
4. **Error Handling**: Clear error messages for invalid versions

## Testing

### Test Script: `test-version-clean.sh`

Created comprehensive test that verifies:
- ✅ Version extraction returns clean value
- ✅ No log pollution in captured variable
- ✅ Version format validation works
- ✅ URL construction is clean
- ✅ No brackets or timestamps in URLs

### Test Results

```
✅ SUCCESS: Version format is correct (X.Y.Z)
✅ Version: 2025.11.1
✅ Length: 9 characters
✅ SUCCESS: URL is clean
✅ ALL TESTS PASSED - Version extraction is clean!
```

## Impact

### Before Fix
- ❌ Version variable contained log pollution
- ❌ Download URLs were corrupted
- ❌ cloudflared downloads failed
- ❌ Logs were confusing and mixed with data

### After Fix
- ✅ Version variable is clean (e.g., "2025.11.1")
- ✅ Download URLs are correctly formatted
- ✅ cloudflared downloads work properly
- ✅ Logs are clear and separated from data
- ✅ Version validation prevents invalid formats
- ✅ Debug output helps with troubleshooting

## Best Practices Applied

1. **Separation of Concerns**: Functions that return values should not log
2. **Clean Data Flow**: Capture data first, then log about it
3. **Input Validation**: Always validate critical data like versions
4. **Debug Support**: Provide debug output for troubleshooting
5. **Error Handling**: Clear error messages for invalid states

## Usage

The fix is transparent to users. The script now works correctly:

```bash
./argo-diagnostic.sh
```

Expected output (clean version):
```
[INFO] Finding latest available cloudflared version...
[✅ SUCCESS] Found available version: v2025.11.1
[INFO] Target version: 2025.11.1
[INFO] Architecture: amd64
[INFO] Download URL: https://github.com/cloudflare/cloudflared/releases/download/2025.11.1/cloudflared-linux-amd64
```

## Files Modified

1. **`argo-diagnostic.sh`** - Main script with version extraction fix
2. **`test-version-clean.sh`** - Test script to verify the fix

## Verification

Run the test script to verify the fix:
```bash
./test-version-clean.sh
```

All tests should pass, confirming that:
- Version extraction is clean
- URL construction works properly
- No log pollution occurs