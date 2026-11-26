-- Exercise ensure for every enabled adapter/ABI using installed real SDKs.
package.path='/usr/share/mise-runtime/lib/?.lua;'..package.path
local s=require('system');local store=require('store');local c=require('contract')
local root,work=arg[1],arg[2];c.path(root);assert(not s.fs.lstat(work));s.mkdir(work,448)
local config=s.read('/etc/config/mise');local selected={};local checks={};local skipped={}
for _,id in ipairs(store.list(root..'/environments'))do
 local r=s.decode(root..'/environments/'..id..'/receipt.json');c.receipt(r)
 local key=r.entry.tool..'/'..r.entry.abi
 if r.verified and not selected[key]then selected[key]=r end
end
for _,key in ipairs({'node/glibc','node/musl','python/glibc','python/musl','go/native','zig/native'})do
 local r=selected[key]
 if not r then skipped[#skipped+1]={case=key,reason='No installed SDK in this acceptance repository'}
 else
 local before=s.sha(root..'/environments/'..r.instance..'/receipt.json',work)
 local result=require('dependency-client').ensure(root,r.entry.id,r.library,'ks-cli',work)
 assert(result.verified and result.instance==r.instance and result.root==root)
 assert(s.sha(root..'/environments/'..r.instance..'/receipt.json',work)==before,'ensure mutated an installed receipt')
 checks[#checks+1]={tool=r.entry.tool,abi=r.entry.abi,version=r.entry.version,passed=true,receipt_unchanged=true}
 print('PASS '..key);io.stdout:flush()
 end
end
assert(#checks>=5,'Expected real Node, both Python ABIs, Go and Zig fixtures')
local report={passed=s.read('/etc/config/mise')==config,checks=checks,skipped=require('wire').array(skipped),scope='real installed SDK execution through public ensure; no new SDK downloads'}
s.write(work..'/result.json',report);print(s.json.stringify(report));os.exit(report.passed and 0 or 1)
