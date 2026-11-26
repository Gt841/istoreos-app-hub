-- Reproduce procd's root preparation with a non-root application's HOME.
-- Uses the real public ensure path and never changes UCI or application data.
package.path='/usr/share/mise-runtime/lib/?.lua;'..package.path
local s=require('system');local store=require('store');local c=require('contract')
local root,work,home=arg[1],arg[2],arg[3]
c.path(root);c.path(work);c.path(home)
assert(s.nixio.getuid()==0,'Run as administrator')
local owner=assert(s.fs.lstat(home));assert(owner.type=='dir'and owner.uid~=0,'Use an existing application-owned HOME')
assert(not s.fs.lstat(work),'Use a new evidence directory');s.mkdir(work,448)
local runtime_config=s.read('/etc/config/mise');local app_config=s.read('/etc/config/openclawmgr')
local catalog=assert(s.decode('/usr/share/mise-runtime/catalog.json'));local entry
for _,e in ipairs(catalog.entries)do
 if e.tool=='node'and e.version=='24.22.1'and e.abi=='glibc'and e.arch==s.nixio.uname().machine then entry=e;break end
end
assert(entry,'Pinned Node fixture missing from catalog')
local library=require('libraries').definition(entry.arch).id
local id=c.instance_id(entry,nil,library)
local old_receipt=s.read(root..'/environments/'..id..'/receipt.json')
s.nixio.setenv('HOME',home);s.nixio.setenv('ISTORE_RUNTIME_HOME',home)
local ok,result=pcall(require('dependency-client').ensure,root,entry.id,library,'ks-cli',work)
local checks={ensure_success=ok,caller_home_preserved=os.getenv('HOME')==home and os.getenv('ISTORE_RUNTIME_HOME')==home,
 application_home_owner_preserved=s.fs.lstat(home).uid==owner.uid,
 uci_preserved=s.read('/etc/config/mise')==runtime_config and s.read('/etc/config/openclawmgr')==app_config}
if ok then
 checks.fixed_sdk_verified=result.verified and result.root==root and result.instance==id
 checks.receipt_preserved=not old_receipt or s.read(root..'/environments/'..id..'/receipt.json')==old_receipt
 -- The fix must preserve the root/UID ownership boundary for public exec.
 local rc=s.run({root..'/wrap/'..id,'node','--version'},
  {output=work..'/unsafe-root-home.log',timeout=30,env={HOME=home,ISTORE_RUNTIME_HOME=home}})
 checks.root_cannot_execute_in_application_home=rc~=0 and(s.read(work..'/unsafe-root-home.log')or''):find('HOME parent belongs to another UID',1,true)~=nil
end
local passed=true;for _,value in pairs(checks)do if not value then passed=false end end
local report={passed=passed,checks=checks,installed_before=old_receipt~=nil,
 error=not ok and(type(result)=='table'and result.message or tostring(result))or nil}
s.write(work..'/result.json',report);print(s.json.stringify(report));os.exit(passed and 0 or 1)
