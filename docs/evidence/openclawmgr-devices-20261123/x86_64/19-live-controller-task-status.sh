set -eu
CANDIDATE_CONTROLLER='/mnt/vio4-0/Configs/openclawmgr-acceptance-20261123/assets/candidate-controller.lua' lua - <<'LUA'
local json=require("luci.jsonc")
package.loaded["luci.http"]={
 prepare_content=function() end,
 formvalue=function() return nil end,
 write=function(body)
  local x=assert(json.parse(body))
  local t=x.task or {}
  io.write(json.stringify({installed=x.installed,installing=x.installing,task={running=t.running,op=t.op,pid=t.pid}}).."\n")
 end,
}
dofile(os.getenv("CANDIDATE_CONTROLLER"))
package.loaded["luci.controller.openclawmgr"].action_status()
LUA
