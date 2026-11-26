set -eu
CANDIDATE_CONTROLLER='/mnt/nvme0n1-1/Configs/openclawmgr-acceptance-20261123/assets/candidate-controller.lua' lua - <<'LUA'
local json=require("luci.jsonc")
local function emit(x)
 local t=x.task or {}
 io.write(json.stringify({installed=x.installed,installing=x.installing,task={running=t.running,op=t.op,pid=t.pid}}).."\n")
end
package.loaded["luci.http"]={
 prepare_content=function() end, formvalue=function() return nil end,
 getenv=function() return nil end, write_json=emit, write=function(body) emit(assert(json.parse(body))) end
}
dofile(os.getenv("CANDIDATE_CONTROLLER"))
package.loaded["luci.controller.openclawmgr"].action_status()
LUA
