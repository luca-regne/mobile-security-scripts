#!/bin/bash

app="$1"

echo "Dumping APKs for app: $app"

package_name=$(adb shell pm list packages "${app}" | cut -d ":" -f 2)

echo "Package name: $package_name"
package_base_name=$(echo $package_name | tr '.' '_')

packages=$(adb shell pm path "${package_name}" | cut -d ':' -f 2)
for apk in $packages; do
  echo "Pulling APK: $apk"
  apk_name=$(basename "$apk")
  adb pull "$apk" .
done
