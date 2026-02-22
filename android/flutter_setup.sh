#!/bin/bash

# Flutter APK Analysis and Patching Script
# This script pulls a Flutter app from an Android device, patches it with reflutter,
# and reinstalls it to enable code dumping for security analysis.

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if package name is provided
if [ -z "$1" ]; then
    echo -e "${RED}Error: Package name is required${NC}"
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

echo -e "${GREEN}Starting Flutter app analysis for: ${PACKAGE_NAME}${NC}"

if [ ! -f "$APK_EDITOR" ]; then
    echo -e "${RED}Error: APKEditor not found at $APK_EDITOR${NC}"
    exit 1
fi

if [ ! -f "$APK_SIGNER" ]; then
    echo -e "${RED}Error: uber-apk-signer not found at $APK_SIGNER${NC}"
    exit 1
fi

if ! command -v reflutter &> /dev/null; then
    echo -e "${RED}Error: reflutter not found. Please install it first.${NC}"
    exit 1
fi

if ! adb devices | grep -q "device$"; then
    echo -e "${RED}Error: No Android device connected${NC}"
    exit 1
fi

echo -e "${YELLOW} Pulling APK from device...${NC}"
adb shell pm path "$PACKAGE_NAME" | sed 's/package://' | while read pks; do
    adb pull "$pks"
done

echo -e "${YELLOW} Merging APK files...${NC}"
java -jar "$APK_EDITOR" m -i "$PACKAGE_FILE"

rm -f "${PACKAGE_FILE}_merged.apk"
rm -f "${PACKAGE_FILE}_merged-aligned-debugSigned.apk.idsig"

echo -e "${YELLOW} Patching APK with reflutter...${NC}"
if [ -n "$PROXY_IP" ]; then
    echo "$PROXY_IP" | reflutter "${PACKAGE_FILE}_merged.apk"
else
    reflutter "${PACKAGE_FILE}_merged.apk"
fi

echo -e "${YELLOW} Signing patched APK...${NC}"
java -jar "$APK_SIGNER" --apks release.RE.apk

echo -e "${YELLOW} Uninstalling old version...${NC}"
adb uninstall "$PACKAGE_NAME" 2>/dev/null || echo "App not installed, skipping uninstall"

echo -e "${YELLOW} Installing patched APK...${NC}"
adb install release.RE-aligned-debugSigned.apk

echo -e "${YELLOW} Waiting for app to start...${NC}"
echo -e "${GREEN}Please start the app on the device now!${NC}"
read -p "Press Enter when the app has started..."

echo -e "${YELLOW}Dumping Dart code...${NC}"
adb shell su -c "cat /data/data/${PACKAGE_NAME}/dump.dart" | tee dump.dart

if [ -f dump.dart ]; then
    echo -e "${GREEN}Dart code dumped to dump.dart${NC}"
    if command -v jq &> /dev/null; then
        echo -e "${YELLOW}Formatting JSON output...${NC}"
        cat dump.dart | jq . > dump_formatted.json 2>/dev/null || echo "Not valid JSON format"
    fi
else
    echo -e "${RED}Failed to dump Dart code${NC}"
fi

echo -e "${GREEN}Flutter analysis complete!${NC}"
