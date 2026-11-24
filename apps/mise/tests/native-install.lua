local root=assert(arg[1]);local share='/usr/share/mise-runtime'
package.path=share..'/lib/?.lua;'..package.path
local s=require('system');local store=require('store');local ctx=store.open(root)
local work=root..'/work/native-install-test';s.mkdir(work,448)
local report={scope='on-device native SDK public installer and actual compilation',checks={}}
local function cli(request)
 s.write(work..'/request.json',request)
 local rc=s.run({'/usr/sbin/mise-runtime','request'},{env={MISE_RUNTIME_ROOT=root},stdin=work..'/request.json',output=work..'/response.json',timeout=45})
 local r=s.decode(work..'/response.json');assert(rc==0 and r and r.ok,s.json.stringify(r));return r.value
end
for _,entry in ipairs(s.decode(share..'/catalog.json').entries)do
 if(entry.tool=='go'or entry.tool=='zig')and entry.arch==s.nixio.uname().machine then
  local id=require('contract').instance_id(entry);local existing=s.decode(root..'/environments/'..id..'/receipt.json')
  if not existing then
   local plan=cli({op='plan',entry=entry.id,source='origin'});local task=cli({op='submit',id=plan.id})
   print('START '..entry.id..' '..task.id);io.stdout:flush()
   for _=1,1800 do task=require('tasks').get(ctx,task.id);if task.status~='running'then break end;s.nixio.nanosleep(0,500000000)end
   if task.status~='success'then
    s.write(work..'/install-report.json',{passed=false,entry=entry.id,task=task})
    io.stderr:write(s.json.stringify(task)..'\n'..(s.read(root..'/tasks/'..task.id..'/log')or''));os.exit(1)
   end
  end
  local r=cli({op='inspect',id=id});assert(r.verified and r.probes.compile=='passed'and r.probes.execute=='passed')
  report.checks[#report.checks+1]={entry=entry.id,instance=id,probes=r.probes,passed=true}
  print('PASS '..entry.id);io.stdout:flush()
 end
end
report.passed=#report.checks==4;s.write(work..'/install-report.json',report);print(s.json.stringify(report));assert(report.passed)
