# A collection of alias to enhance android pentest

# drozer port foward
alias dzfwd="adb forward tcp:31415 tcp:31415"

# drozer console connect
alias dzc="drozer console connect"

# Start screen-copy in background fowarding all output to /dev/null
alias scrcpy='scrcpy 2>/dev/null 1>&2 &'

# Start frida server in background fowarding all output to /dev/null
alias fsrv='adb shell su -c /data/local/tmp/frida 2>/dev/null 1>&2 &'

# List processes from Apps current running from USB connected device   
alias fpai='frida-ps -Ua'

# Dump apks from a package name in a connected device
dump_apk(){
    adb shell pm path $1 | sed 's/package://' | while read pks; do adb pull $pks; done
}