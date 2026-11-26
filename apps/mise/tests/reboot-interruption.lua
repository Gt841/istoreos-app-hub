local share,root,mode=unpack(arg)
package.path=share..'/lib/?.lua;'..package.path
local sys=require('system');local store=require('store');local tasks=require('tasks')
local ctx=store.open(root);local marker=root..'/reboot-interruption.json'
if mode=='prepare'then
  assert(not sys.fs.lstat(marker),'reboot test already prepared')
  local t=tasks.start(ctx,{},function(c,task,w,log)
    sys.write(w..'/candidate','not committed');tasks.phase(c,task,'reboot-interruption')
    assert(sys.run({'/bin/sleep','600'},{timeout=610,output=log})==0)
  end)
  local ready=false
  for _=1,100 do
    if #store.list(root..'/tasks/'..t.id..'/processes')>0 then ready=true;break end
    sys.nixio.nanosleep(0,50000000)
  end
  assert(ready,'command ownership not registered')
  sys.write(marker,{boot=sys.boot_id(),task=t.id,old_data=sys.read(root..'/old-data')})
  print(sys.json.stringify({prepared=true,task=t.id,boot=sys.boot_id()}))
elseif mode=='recover'then
  local before=assert(sys.decode(marker));assert(before.boot~=sys.boot_id(),'device did not actually reboot')
  local t=tasks.get(ctx,before.task);assert(t.status=='running'and not sys.alive(t.owner))
  local result=tasks.recover(ctx,t.id,false)
  assert(result.status=='canceled'and not sys.fs.lstat(root..'/.lock')and not sys.fs.lstat(root..'/work/'..t.id))
  assert(sys.read(root..'/old-data')==before.old_data)
  print(sys.json.stringify({passed=true,task=t.id,status=result.status,before_boot=before.boot,after_boot=sys.boot_id(),old_data_preserved=true}))
else error('prepare or recover required')end
