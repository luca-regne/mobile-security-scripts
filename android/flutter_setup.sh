#!/bin/bash

# Flutter APK Analysis and Patching Script
# This script pulls a Flutter app from an Android device, patches it with reflutter,
# and reinstalls it to enable code dumping for security analysis.

set -e  # Exit on error

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source "$SCRIPT_DIR/../utils/pretty_print.sh"

# Check if package name is provided
if [ -z "$1" ]; then
    _error "Package name is required"
    echo "Usage: $0 <package.name> [proxy_ip]"
    echo "Example: $0 com.example.app 10.0.5.10"
    exit 1
fi

PACKAGE_NAME="$1"
PROXY_IP="${2:-}"  # Optional proxy IP for reflutter
PACKAGE_FILE=$(echo "$PACKAGE_NAME" | tr '.' '_')

# Tool paths
TOOLS_DIR="$HOME/tools/mobile"
APK_EDITOR="$TOOLS_DIR/APKEditor.jar"
APK_SIGNER="$TOOLS_DIR/uber-apk-signer.jar"

_info "Starting Flutter app analysis for: ${PACKAGE_NAME}"

if [ ! -f "$APK_EDITOR" ]; then
    _error "APKEditor not found at $APK_EDITOR"
    exit 1
fi

if [ ! -f "$APK_SIGNER" ]; then
    _error "uber-apk-signer not found at $APK_SIGNER"
    exit 1
fi

if ! command -v reflutter &> /dev/null; then
    _error "reflutter not found. Please install it first."
    exit 1
fi

if ! adb devices | grep -q "device$"; then
    _error "No Android device connected"
    exit 1
fi

_info "Pulling APK from device..."
adb shell pm path "$PACKAGE_NAME" | sed 's/package://' | while read pks; do
    adb pull "$pks"
done

_info "Merging APK files..."
java -jar "$APK_EDITOR" m -i "$PACKAGE_FILE"

rm -f "${PACKAGE_FILE}_merged.apk"
rm -f "${PACKAGE_FILE}_merged-aligned-debugSigned.apk.idsig"

_info "Patching APK with reflutter..."
if [ -n "$PROXY_IP" ]; then
    echo "$PROXY_IP" | reflutter "${PACKAGE_FILE}_merged.apk"
else
    reflutter "${PACKAGE_FILE}_merged.apk"
fi

_info "Signing patched APK..."
java -jar "$APK_SIGNER" --apks release.RE.apk

_info "Uninstalling old version..."
adb uninstall "$PACKAGE_NAME" 2>/dev/null || _info "App not installed, skipping uninstall"

_info "Installing patched APK..."
adb install release.RE-aligned-debugSigned.apk

_info "Waiting for app to start..."
_success "Please start the app on the device now!"
read -p "Press Enter when the app has started..."

_info "Dumping Dart code..."
adb shell su -c "cat /data/data/${PACKAGE_NAME}/dump.dart" | tee dump.dart

if [ -f dump.dart ]; then
    _success "Dart code dumped to dump.dart"
    if command -v jq &> /dev/null; then
        _info "Formatting JSON output..."
        cat dump.dart | jq . > dump_formatted.json 2>/dev/null || _warning "Not valid JSON format"
    fi
else
    _error "Failed to dump Dart code"
fi

_success "Flutter analysis complete!"
