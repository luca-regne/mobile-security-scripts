#!/bin/sh

# Use ADB to configure the device’s proxy

adb forward tcp:8080 tcp:8080
adb shell "settings put global http_proxy 127.0.0.1:8080"