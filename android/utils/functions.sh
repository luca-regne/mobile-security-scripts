# A collection of functions to enhance android pentest, bug bounty, research or reversing

# Dump apks from a package name in a connected device
dump_apk(){
    adb shell pm path $1 | sed 's/package://' | while read pks; do adb pull $pks; done
}