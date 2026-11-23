set -eu
CANDIDATE_CONTROLLER='/mnt/vio4-0/Configs/openclawmgr-acceptance-20261123/assets/candidate-controller.lua' lua - <<'LUA'
local json=require("luci.jsonc")
local function emit(x)
 io.write(json.stringify({installed=x.installed,installing=x.installing,task_running=x.task_running,task_op=x.task_op}).."\n")
end
package.loaded["luci.http"]={prepare_content=function() end,formvalue=function() return nil end,getenv=function() return nil end,write_json=emit}
dofile(os.getenv("CANDIDATE_CONTROLLER"))
package.loaded["luci.controller.openclawmgr"].action_status()
LUA
printf '%s\n' '== task tail'
tail -n 5 /var/log/tasks/openclawmgr.log
