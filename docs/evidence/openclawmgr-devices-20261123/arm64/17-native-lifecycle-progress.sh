set -u
printf '%s\n' '== native lifecycle events'
grep -E 'postinstall|preinstall|^> |Downloading|Preparing|Error|error|Installation phase|Checking' /var/log/tasks/openclawmgr.log | tail -n 18 || true
printf '%s\n' '== latest'
tail -n 5 /var/log/tasks/openclawmgr.log
