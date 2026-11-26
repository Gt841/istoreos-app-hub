local root,base,label=assert(arg[1]),assert(arg[2]),assert(arg[3])
package.path='/usr/share/mise-runtime/lib/?.lua;'..package.path
local s=require('system');local fs=s.fs;local r
for _,id in ipairs(require('store').list(root..'/environments'))do
 local value=s.decode(root..'/environments/'..id..'/receipt.json')
 if value and value.entry.tool=='python'and value.entry.version=='3.12.16'and value.entry.abi=='glibc'then r=value;break end
end
assert(r);local project=base..'/applications/65001/3.12.16-glibc';local v=project..'/.venv'
local config=v..'/pip.conf';local escaped=project..'/pip-target-'..label
assert(not fs.lstat(config)and not fs.lstat(escaped))
s.write(config,'[install]\ntarget = '..escaped..'\n');assert(fs.chown(config,65001,65001))
local ok,rc=pcall(s.run,{'/usr/share/mise-runtime/native/bin/exec-user','65001','65001',r.instance,'--venv',v,'pip','install','--force-reinstall','--no-index','--no-deps','--no-compile',project..'/istore_runtime_probe-1.0-py3-none-any.whl'},{env={MISE_RUNTIME_ROOT=root,ISTORE_RUNTIME_ACCELERATION='origin'},output=base..'/pip-config-'..label..'.log',timeout=60})
assert(fs.unlink(config))
local report={scope='real venv site pip.conf must not redirect install target',passed=ok and rc~=0 and not fs.lstat(escaped),rc=ok and rc or tostring(rc),escaped_target_created=fs.lstat(escaped)~=nil,original_config_absent=not fs.lstat(config)}
s.write(base..'/pip-config-'..label..'.json',report);print(s.json.stringify(report));assert(report.passed)
