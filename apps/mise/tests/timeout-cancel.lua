-- Regression for the actual timeout-wrapped download/process path.
local share,root=unpack(arg)
package.path=share..'/lib/?.lua;'..package.path
local sys=require('system');local store=require('store');local tasks=require('tasks')
local n=sys.nixio;local ctx=store.open(root)
local t=tasks.start(ctx,{},function(c,task,work,log)
  tasks.phase(c,task,'timeout-wrapped-child')
  local rc=sys.run({'/bin/sh','-c','echo $$ > "$1"; exec sleep 45','probe',work..'/native-child.pid'},
    {timeout=60,output=log,append=true})
  assert(rc==0)
end)
local child
for _=1,50 do
  local raw=sys.read(root..'/work/'..t.id..'/native-child.pid')
  if raw then child=tonumber(raw);break end;n.nanosleep(0,100000000)
end
assert(child,'native child did not start')
local before=assert(sys.process(child))
local stopped=tasks.recover(ctx,t.id,true)
local survivor=sys.process(child)
local record={task=t.id,worker_group=t.owner.pid,child_pid=child,child_group=before.group,
  reported_status=stopped.status,child_survived=survivor~=nil and survivor.state~='Z',
  lock_removed=not sys.fs.lstat(root..'/.lock'),candidate_removed=not sys.fs.lstat(root..'/work/'..t.id)}
-- Always remove only this regression's known process group after observation.
if record.child_survived then
  local leader=sys.process(before.group)
  record.cleanup_group=before.group
  assert(before.group~=t.owner.pid and before.group>1)
  n.kill(-before.group,15)
  for _=1,30 do local p=sys.process(child);if not p or p.state=='Z'then break end;n.nanosleep(0,100000000)end
  local p=sys.process(child);if p and p.start==before.start and p.state~='Z'then n.kill(-before.group,9)end
end
sys.write(root..'/timeout-cancel-regression.json',record)
io.write(sys.json.stringify(record)..'\n')
os.exit(record.child_survived and 1 or 0)
