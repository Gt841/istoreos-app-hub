lua - <<'LUA'
local cmd='/usr/libexec/istorec/openclawmgr.sh upgrade'
print('old_upgrade_detection=' .. tostring(cmd:match('(^|[^%w_])upgrade([^%w_]|$)') ~= nil))
print('frontier_upgrade_detection=' .. tostring(cmd:match('%f[%w_]upgrade%f[^%w_]') ~= nil))
LUA
