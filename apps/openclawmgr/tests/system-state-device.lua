-- Quiescent pre/post reboot state. Authentication/config contents stay private.
package.path='/usr/share/mise-runtime/lib/?.lua;'..package.path
local s=require('system');local fs=s.fs
local base,work=assert(arg[1]),assert(arg[2]);s.mkdir(work,448)
local ref=s.decode(base..'/current/runtime.json')
assert(not fs.lstat('/tmp/openclawmgr-installer.lock')and not fs.lstat('/tmp/openclawmgr-M5-tests.lock'),'Finish application/test operations before collecting reboot state')
assert(not fs.lstat(ref.storage_root..'/.lock'),'Shared runtime operation still active')
local env={};for _,key in ipairs({'base_dir','enabled','bind','port'})do local rc,value=s.pipe_capture({'/sbin/uci','-q','get','openclawmgr.main.'..key});env[key]=rc==0 and value:gsub('%s+$','')or''end
assert(env.base_dir==base and env.enabled=='1')
local configs,binaries={},{}
for _,name in ipairs({'mise','agentflow','istoreenhance','openclawmgr'})do
  local file='/etc/config/'..name;if fs.stat(file)then configs[name]=s.sha(file,work)end
end
for _,file in ipairs({'/usr/sbin/agentflow','/usr/sbin/iStoreEnhance','/usr/bin/mise','/usr/share/mise/mise.sh'})do if fs.stat(file)then binaries[file]=s.sha(file,work)end end
local rc=s.run({'curl','--disable','-fsS','--noproxy','*','--max-time','5','-o',work..'/agentflow-health.private','http://127.0.0.1:9000/healthz'},{output=work..'/curl-private.log',timeout=10})
if s.nixio.uname().machine=='aarch64'then
  assert(rc==0,'Existing AgentFlow health regressed')
  assert(configs.agentflow=='3f2e6ba1d3b44cfda11e458b2aefbde804e2f10ad0ae34d9e6fab38f02760548')
  assert(configs.istoreenhance=='b582d00c458adca175864ed0c31aa244d63b7828ce6d76bd634775cd3e64b6eb')
end
local root=require('store').filesystem(ref.storage_root)
local report={passed=true,arch=s.nixio.uname().machine,boot_id=s.boot_id(),configuration_sha256=configs,binary_sha256=binaries,
  runtime=ref,root_filesystem=root,agentflow_health=rc==0,openclaw=env,legacy_default={}}
local code,home=s.pipe_capture({'/sbin/uci','-q','get','mise.main.runtime_dir'})
if code==0 then
  home=home:gsub('%s+$','')
  for _,suffix in ipairs({'/.config/mise/config.toml','/.tool-versions'})do if fs.stat(home..suffix)then report.legacy_default[home..suffix]=s.sha(home..suffix,work)end end
end
s.write(work..'/system-result.json',report);print(s.json.stringify(report))
