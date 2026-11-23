set -u
printf '%s\n' '== readonly real Git adapter probe'
OPENCLAWMGR_ACCELERATED=1 timeout -k 2 25 /usr/share/openclawmgr/npm-git.sh ls-remote https://github.com/openclaw/openclaw.git refs/tags/v2026.3.28
rc=$?
printf 'git_adapter_rc=%s\n' "$rc"
printf '%s\n' '== current install tail'
tail -n 7 /var/log/tasks/openclawmgr.log 2>/dev/null || true
