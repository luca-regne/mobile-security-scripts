#!/bin/bash
# Script to pull all APKs (base + splits) from a connected Android device using adb
# Usage: dump_apks.sh <filter>
#   Example: dump_apks.sh "com.example.app" # Get a single app by its full package name
#   Example: dump_apks.sh "example" # Get all apps that "example" in package name
#   Example: dump_apks.sh "com.company." # Get all apps from a specific prefix

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source "$SCRIPT_DIR/../utils/pretty_print.sh"

# Function to merge multiple APKs into a single package
merge_apks() {
  local apks_dir="$1"
  local app_name="$2"
  local apkeditor_path="$HOME/tools/mobile/APKEditor.jar"

  if [ ! -f "$apkeditor_path" ]; then
    _warning "APKEditor not found at: $apkeditor_path"
    _warning "Skipping merge. Split APKs remain in: $apks_dir/"
    return 1
  fi

  _info "Merging split APKs into single package..."

  # Get timestamp before merge to identify new files/folders
  local timestamp_before=$(date +%s)

  if java -jar "$apkeditor_path" m -i "$apks_dir" 2>&1; then
    sleep 1  # Small delay to ensure filesystem updates

    local version_dir=$(find . -maxdepth 1 -type d -newer "$apks_dir" ! -name "." ! -name ".." ! -name "$apks_dir" 2>/dev/null | head -n 1)

    local merged_apk=""

    if [ -n "$version_dir" ]; then
      # Look for APK inside the version folder
      merged_apk=$(find "$version_dir" -type f -name "*.apk" 2>/dev/null | head -n 1)

      if [ -n "$merged_apk" ]; then
        _success "Merged APK found in version folder: $merged_apk"
      fi
    fi

    # Fallback: search for recently created APK files in current directory
    if [ -z "$merged_apk" ]; then
      merged_apk=$(find . -maxdepth 1 -type f -name "*.apk" -newer "$apks_dir" 2>/dev/null | head -n 1)
    fi

    if [ -n "$merged_apk" ]; then
      _info "Removing splitted apks...."
      rm "$apks_dir"/*.apk 2>/dev/null
      local final_apk_name="${app_name}_merged.apk"
      _info "Moving merged APK to: $apks_dir/$final_apk_name"
      mv "$merged_apk" "$apks_dir/$final_apk_name"

      # # Clean up version directory if it exists
      # if [ -n "$version_dir" ] && [ -d "$version_dir" ]; then
      #   _info "Cleaning up temporary version folder: $version_dir"
      #   rm -rf "$version_dir"
      # fi
    else
      _warning "Merge completed but merged APK not found in expected location"
      _warning "Please check current directory for version folders"
    fi
  else
    _error "Failed to merge APKs"
    return 1
  fi
}

# Function to pull all APKs for a single package (including splits)
pull_package_apks() {
  local package_name="$1"
  
  # Get all APK paths for this package (base + splits)
  mapfile -t apk_paths < <(adb shell pm path "$package_name" | sed 's/package://')

  if [ ${#apk_paths[@]} -eq 0 ] || [ -z "${apk_paths[0]}" ]; then
    _error "Could not find APK paths for $package_name"
    return 1
  fi

  local apk_count=${#apk_paths[@]}
  local output_dir="$package_name"
  mkdir -p "$output_dir"
  _info "Created directory: $output_dir/"
  
  if [ $apk_count -eq 1 ]; then
    _info "Found 1 APK for $package_name"
    local apk_path="${apk_paths[0]}"

    _info "Pulling: $apk_path"
    adb pull "$apk_path" "$output_dir/"
    _success "APK saved to: $output_dir/$apk_path"
  else
    _info "Found $apk_count APKs for $package_name (split APKs detected)"
    
    local idx=0
    for apk_path in "${apk_paths[@]}"; do
      # Extract filename from path
      local filename=$(basename "$apk_path")
      local output_file="$output_dir/$filename"

      idx=$((idx + 1))
      _info "[$idx/$apk_count] Pulling: $apk_path -> $output_file"
      adb pull "$apk_path" "$output_file"
    done

    _success "All APKs for $package_name saved to: $output_dir/"
    echo ""

    # Merge the split APKs into a single package
    merge_apks "$output_dir" "$app_name"
  fi
}

# Function to process multiple packages
get_multiple_apps() {
  local total=${#packages[@]}
  local current=0

  for package_info in "${packages[@]}"; do
    current=$((current + 1))
    # Extract package name (everything after the last =)
    local package_name=$(echo "$package_info" | sed 's/^.*=//')

    _info "[$current/$total] Processing: $package_name"
    pull_package_apks "$package_name"
    echo ""
  done
}

pull_apks() {
  _info "Searching for packages matching: \"$app\""

  # Get packages and remove 'package:' prefix
  mapfile -t packages < <(adb shell pm list packages -f "$app" | sed 's/package://')

  if [ ${#packages[@]} -eq 0 ] || [ -z "${packages[0]}" ]; then
    _error "No packages found matching '$app'. Please check the app name."
    exit 1
  fi

  packages_found=${#packages[@]}

  if [ $packages_found -gt 1 ]; then
    _info "Found $packages_found packages matching '$app'. All will be processed."
    echo ""
    get_multiple_apps
  else
    # Extract package name (everything after the last =)
    package_name=$(echo "${packages[0]}" | sed 's/^.*=//')
    _info "Found 1 package: $package_name"
    echo ""
    pull_package_apks "$package_name"
  fi
}

main() {
  app="$1"
  pull_apks
}

if [ "$#" -ne 1 ]; then
  _error "Usage: $0 <app_name>"
  exit 1
else
  main "$1"
fi