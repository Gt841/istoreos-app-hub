import {chromium} from 'playwright'
import fs from 'node:fs'
import path from 'node:path'
import assert from 'node:assert/strict'
import {execFileSync} from 'node:child_process'
const session=JSON.parse(fs.readFileSync(process.env.MISE_LIVE_SESSION,'utf8')),base=session.base,host=new URL(base).hostname,out=process.env.MISE_LIVE_EVIDENCE
if(!out)throw Error('Evidence path required')
fs.mkdirSync(out,{recursive:true})
const browser=await chromium.launch({headless:true,executablePath:'/config/.cache/ms-playwright/chromium_headless_shell-1200/chrome-headless-shell-linux64/chrome-headless-shell',args:['--no-sandbox']})
const context=await browser.newContext({viewport:{width:1440,height:1000}});await context.addCookies([{name:'sysauth_http',value:session.admin.sid,url:base}])
const page=await context.newPage(),results=[]
const quote=s=>"'"+s.replaceAll("'","'\\''")+"'"
async function api(request){const r=await context.request.post(base+'/cgi-bin/luci/admin/services/mise/request',{form:{token:session.admin.token,request:JSON.stringify(request)}});const v=await r.json();assert.equal(v.ok,true,v.error?.code);return v.value}
const before=await api({op:'read'}),root=before.path,original=before.runtimes[0];assert.ok(original);assert.equal(before.runtimes.length,1)
const prefix="package.path='/usr/share/mise-runtime/lib/?.lua;'..package.path;local sys=require('system');local c=require('contract');local store=require('store');local r=sys.json.parse(io.read('*a'));c.path(r.root);local ctx=store.open(r.root);"
function sshLua(code,request){return execFileSync('ssh',['root@'+host,'lua -e '+quote(prefix+code)],{input:JSON.stringify({root,...request}),encoding:'utf8',timeout:30000}).trim()}
async function check(name,fn){try{await fn();results.push({name,passed:true});console.log('PASS '+name)}catch(e){results.push({name,passed:false,error:e.message});console.log('FAIL '+name+': '+e.message);await page.screenshot({path:path.join(out,'maintenance-failure.png')});throw e}}
async function select(version,abi){await page.getByRole('button',{name:'＋ 安装环境',exact:true}).click();await page.getByLabel('版本',{exact:true}).selectOption(version);await page.getByLabel('运行环境',{exact:true}).selectOption(abi);await page.getByRole('button',{name:'检查安装内容',exact:true}).click();await page.getByRole('button',{name:'开始安装',exact:true}).waitFor()}
async function latestTask(version,abi){const s=await api({op:'read'});return s.tasks.find(t=>t.plan?.entry===s.catalog_revision+'-'+version)||s.tasks.find(t=>t.plan&&t.plan.entry.includes(version)&&t.plan.entry.includes(abi))}
async function waitTask(id,status,timeout=120000){const deadline=Date.now()+timeout;while(Date.now()<deadline){const s=await api({op:'read'}),t=s.tasks.find(t=>t.id===id);if(t?.status===status)return t;if(t?.status==='failed'&&status!=='failed')throw Error('Actual task failed: '+t.error?.code+' '+t.error?.message);await page.waitForTimeout(500)}throw Error('Task did not reach '+status)}
let fault=false
const faultCode="local cat=assert(sys.decode('/usr/share/mise-runtime/catalog.json'));local e;for _,v in ipairs(cat.entries)do if v.tool=='node'and v.version=='24.22.1'and v.abi=='glibc'and v.arch==sys.nixio.uname().machine and #v.artifacts==1 then e=v;break end end;assert(e);local p=r.root..'/cache/'..e.artifacts[1].sha256;"
try{
 await page.goto(base+'/cgi-bin/luci/admin/services/mise');await page.locator('.runtime-row').waitFor()
 await check('real failed install from an unsafe cache entry; UI error and retry',async()=>{
  sshLua(faultCode+"assert(not sys.fs.lstat(p),'fault cache already exists');assert(sys.fs.symlink('/mise-m4-test-unavailable',p));io.write('fault prepared')",{});fault=true
  await select('24.22.1','glibc');const previous=(await api({op:'read'})).tasks.map(t=>t.id);await page.getByRole('button',{name:'开始安装',exact:true}).click()
  let task;for(let i=0;i<40;i++){task=(await api({op:'read'})).tasks.find(t=>!previous.includes(t.id));if(task)break;await page.waitForTimeout(250)}assert.ok(task)
  const failed=await waitTask(task.id,'failed');assert.equal(failed.error.code,'INTEGRITY');await page.locator('.mise-surface').getByRole('dialog').getByText('失败',{exact:true}).waitFor({timeout:20000})
  sshLua(faultCode+"assert(sys.fs.readlink(p)=='/mise-m4-test-unavailable');assert(sys.fs.unlink(p));io.write('fault removed')",{});fault=false
  assert.deepEqual((await api({op:'read'})).runtimes,[original]);await page.getByRole('button',{name:'重新检查',exact:true}).click();await page.getByRole('button',{name:'检查安装内容',exact:true}).click();await page.getByRole('button',{name:'开始安装',exact:true}).click();await page.getByRole('button',{name:'后台继续',exact:true}).click()
  const deadline=Date.now()+1200000;while(Date.now()<deadline){const s=await api({op:'read'});if(s.runtimes.length===2)break;const failed=s.tasks.find(t=>!previous.includes(t.id)&&t.id!==task.id&&t.status==='failed');if(failed)throw Error(failed.error?.message);await page.waitForTimeout(1000)}assert.equal((await api({op:'read'})).runtimes.length,2)
 })
 await check('actual worker interruption, reload and UI recovery collects task processes',async()=>{
  await page.reload();await page.locator('.runtime-row').first().waitFor();await select('24.22.1','musl');const previous=(await api({op:'read'})).tasks.map(t=>t.id);await page.getByRole('button',{name:'开始安装',exact:true}).click();let task
  for(let i=0;i<50;i++){task=(await api({op:'read'})).tasks.find(t=>!previous.includes(t.id));if(task?.phase==='download')break;await page.waitForTimeout(100)}assert.ok(task);assert.equal(task.status,'running')
  sshLua("c.key(r.id);local t=require('tasks').get(ctx,r.id);assert(t.status=='running'and sys.alive(t.owner));local lock=sys.decode(r.root..'/.lock/owner.json');assert(lock.id==r.id and t.owner.pid>1);assert(sys.nixio.kill(t.owner.pid,9));io.write('owned worker interrupted')",{id:task.id})
  await waitTask(task.id,'interrupted');await page.reload();await page.getByRole('button',{name:'查看并恢复',exact:true}).click();await page.locator('.task-row').filter({hasText:'需要恢复'}).getByRole('button',{name:'查看任务',exact:true}).click();await page.getByRole('button',{name:'恢复并清理候选',exact:true}).click();await page.locator('.mise-surface').getByRole('dialog').getByText('已取消',{exact:true}).waitFor({timeout:60000});await page.getByRole('button',{name:'关闭',exact:true}).click()
  assert.equal(sshLua("c.key(r.id);assert(not sys.fs.lstat(r.root..'/.lock'));local entries=store.list(r.root..'/tasks/'..r.id..'/processes');assert(#entries==0);assert(not sys.fs.lstat(r.root..'/work/'..r.id));io.write('cleanup verified')",{id:task.id}),'cleanup verified')
 })
 await check('remove new nondefault SDK through UI, preserve original receipt and clear cache',async()=>{
  await page.getByRole('button',{name:'运行环境',exact:true}).click();const s=await api({op:'read'}),extra=s.runtimes.find(r=>r.instance!==original.instance);assert.ok(extra);await page.reload();await page.locator(`[data-runtime="${extra.instance}"]`).getByRole('button',{name:'详情',exact:true}).click();await page.getByRole('button',{name:'清理环境',exact:true}).click();await page.locator('.mise-surface').getByRole('dialog').getByText(/固定 wrap 入口将失效/).waitFor();await page.getByRole('button',{name:'确认清理',exact:true}).click();await page.waitForFunction(()=>!document.querySelector('dialog'));assert.deepEqual((await api({op:'read'})).runtimes,[original]);await page.getByRole('button',{name:'存储与设置',exact:true}).click();await page.getByRole('button',{name:'清理缓存',exact:true}).click();await page.getByRole('button',{name:'确认清理',exact:true}).click();await page.waitForFunction(()=>!document.querySelector('dialog'));const after=await api({op:'read'});assert.equal(after.cache_bytes,0);assert.deepEqual(after.runtimes,[original]);assert.equal(after.library_references[original.library],1)
  const version=execFileSync('ssh',['root@'+host,quote(root+'/wrap/'+original.instance)+' node --version'],{encoding:'utf8',timeout:30000}).trim();assert.equal(version,'v24.21.0');fs.writeFileSync(path.join(out,'after-maintenance.json'),JSON.stringify(after,null,2)+'\n')
 })
}catch{}finally{
 if(fault)sshLua(faultCode+"if sys.fs.readlink(p)=='/mise-m4-test-unavailable'then sys.fs.unlink(p)end;io.write('fault cleaned')",{})
 await browser.close();const report={passed:results.length===3&&results.every(r=>r.passed),scope:'real installed backend with controlled cache/worker fault injection under explicit acceptance storage',results};fs.writeFileSync(path.join(out,'production-maintenance.json'),JSON.stringify(report,null,2)+'\n');process.exitCode=report.passed?0:1
}
