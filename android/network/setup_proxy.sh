#!/bin/sh

# To execute this script you must:
#  1. Have ADB connected to device
#  2. Have "su" binary and root access  

# ANDROID_VERSION=$(adb shell getprop ro.build.version.release)
# echo "Testing access to root"

# Use ADB to configure the device’s proxy
adb forward tcp:8080 tcp:8080
adb shell "settings put global http_proxy 127.0.0.1:8080"
