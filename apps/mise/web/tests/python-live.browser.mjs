// Actual LuCI Python UI and public installer; no mock API or package build.
import fs from 'node:fs'
import path from 'node:path'
import assert from 'node:assert/strict'
import {chromium} from 'playwright'
const session=JSON.parse(fs.readFileSync(process.env.MISE_LIVE_SESSION,'utf8'))
const out=process.env.MISE_LIVE_EVIDENCE
assert(out);fs.mkdirSync(out,{recursive:true})
const redact=value=>[session.admin.sid,session.admin.token].reduce((s,v)=>s.replaceAll(v,'[redacted]'),String(value))
const browser=await chromium.launch({headless:true,executablePath:'/config/.cache/ms-playwright/chromium_headless_shell-1200/chrome-headless-shell-linux64/chrome-headless-shell',args:['--no-sandbox']})
const context=await browser.newContext({acceptDownloads:true,viewport:{width:1440,height:1000}})
await context.addCookies([{name:'sysauth_http',value:session.admin.sid,url:session.base}])
const page=await context.newPage(),checks=[],errors=[]
page.on('pageerror',e=>errors.push(redact(e.message)))
async function api(request){
 const r=await context.request.post(session.base+'/cgi-bin/luci/admin/services/mise/request',{form:{token:session.admin.token,request:JSON.stringify(request)}})
 const value=await r.json();assert.equal(value.ok,true,value.error?.message);return value.value
}
async function check(name,fn){await fn();checks.push({name,passed:true})}
async function waitInstalled(id,exists){
 const deadline=Date.now()+240000
 while(Date.now()<deadline){const s=await api({op:'read'});if(s.runtimes.some(r=>r.instance===id)===exists)return s;await page.waitForTimeout(1000)}
 throw Error('Installed environment did not reach expected state')
}
let passed=false,error,original,removed=false
try{
 const before=await api({op:'read'})
 original=before.runtimes.find(r=>r.entry.tool==='python'&&r.entry.version==='3.13.18'&&r.entry.abi==='musl')
 assert(original&&before.capabilities.python.enabled)
 const row=()=>page.locator(`[data-runtime="${original.instance}"]`)
 await check('real Python receipt pip/venv shown by production LuCI',async()=>{
  await page.goto(session.base+'/cgi-bin/luci/admin/services/mise')
  await page.getByRole('heading',{name:'运行时环境',exact:true}).waitFor()
  await page.getByRole('button',{name:'Python',exact:true}).click()
  assert.equal(await page.locator('.runtime-row').count(),4)
  await row().getByRole('button',{name:'详情',exact:true}).click()
  const dialog=page.locator('dialog.mise-dialog')
  await dialog.getByText(original.probes.pip_version,{exact:true}).waitFor()
  await dialog.getByText('可用 · 创建与 pip 初始化检查通过',{exact:true}).waitFor()
  await page.keyboard.press('Escape')
 })
 await check('actual wrap download and four venv commands match chosen SDK',async()=>{
  await row().getByRole('button',{name:'使用此版本',exact:true}).click()
  for(let i=1;i<=4;i++)assert.ok((await page.getByLabel(`虚拟环境命令 ${i}`,{exact:true}).inputValue()).includes(original.instance))
  await page.getByLabel('虚拟环境目录',{exact:true}).fill(before.path+'/environments/forbidden')
  await page.getByText('不能使用共享 SDK 或管理目录。',{exact:true}).waitFor()
  assert.equal(await page.getByLabel('虚拟环境命令 1',{exact:true}).count(),0)
  await page.getByLabel('虚拟环境目录',{exact:true}).fill(before.path+'/projects/ui-test/.venv')
  const downloading=page.waitForEvent('download');await page.getByRole('button',{name:'下载 wrap 脚本',exact:true}).click()
  const downloaded=await downloading;await downloaded.saveAs(path.join(out,'python-wrap.sh'))
  const script=fs.readFileSync(path.join(out,'python-wrap.sh'),'utf8');assert.ok(script.includes(original.instance)&&script.includes('/usr/share/mise-runtime/execute.lua'))
  await page.keyboard.press('Escape')
 })
 await check('explicit test SDK removal preserves application data and other runtimes',async()=>{
  await row().getByRole('button',{name:'详情',exact:true}).click()
  await page.getByRole('button',{name:'清理环境',exact:true}).click()
  await page.getByText(/固定 wrap 入口将失效/).waitFor()
  await page.getByRole('button',{name:'确认清理',exact:true}).click();removed=true
  await waitInstalled(original.instance,false)
  await page.waitForFunction(()=>!document.querySelector('dialog.mise-dialog'))
  const s=await api({op:'read'});assert.deepEqual(s.runtimes.filter(r=>r.entry.tool!=='python'),before.runtimes.filter(r=>r.entry.tool!=='python'))
 })
 await check('real UI Python install has no pip version selector and verifies bundled tools',async()=>{
  await page.getByRole('button',{name:'＋ 安装环境',exact:true}).click()
  await page.getByLabel('语言',{exact:true}).selectOption('python')
  await page.getByLabel('版本',{exact:true}).selectOption('3.13.18')
  await page.getByLabel('运行环境',{exact:true}).selectOption('musl')
  await page.getByLabel('下载方式',{exact:true}).selectOption('origin')
  assert.equal(await page.getByLabel('npm 版本',{exact:true}).count(),0)
  assert.equal(await page.getByLabel('pip 版本',{exact:true}).count(),0)
  await page.getByRole('button',{name:'检查安装内容',exact:true}).click()
  await page.getByRole('button',{name:'开始安装',exact:true}).click()
  await page.keyboard.press('Escape')
  const s=await waitInstalled(original.instance,true);removed=false
  const added=s.runtimes.find(r=>r.instance===original.instance)
  assert.equal(added.verified,true);assert.equal(added.probes.pip,'passed');assert.equal(added.probes.venv,'passed')
  assert.deepEqual(s.defaults,before.defaults)
  assert.deepEqual(s.runtimes.filter(r=>r.entry.tool!=='python'),before.runtimes.filter(r=>r.entry.tool!=='python'))
  fs.writeFileSync(path.join(out,'python-installed.json'),JSON.stringify(added,null,2)+'\n')
 })
 await check('refreshed Python page keeps QuickStart mobile and theme layout',async()=>{
  await page.setViewportSize({width:390,height:900});await page.reload()
  await page.getByRole('button',{name:'Python',exact:true}).click();await row().waitFor()
  if(await page.locator('.mise-surface').evaluate(el=>el.getBoundingClientRect().width)<326){await page.locator('header .showSide').click()}
  for(const theme of ['light','dark']){
   await page.evaluate(t=>document.body.setAttribute('theme',t),theme)
   await page.waitForFunction(t=>document.querySelector('.mise-surface').dataset.theme===t,theme)
   assert.equal(await page.locator('.mise-surface').evaluate(el=>el.scrollWidth<=el.clientWidth+1),true)
  }
  assert.deepEqual(errors,[])
 })
 passed=true
}catch(e){error=redact(e.message)}finally{
 let restoration
 if(removed&&original){
  try{const s=await api({op:'read'});if(!s.runtimes.some(r=>r.instance===original.instance)){const plan=await api({op:'plan',entry:original.entry.id,source:'origin'});await api({op:'submit',id:plan.id});await waitInstalled(original.instance,true)}restoration='test SDK restored through public API'}
  catch(e){restoration=redact(e.message)}
 }
 await browser.close()
 fs.writeFileSync(path.join(out,'python-live.json'),JSON.stringify({scope:'actual direct-deployed production LuCI and on-device Python installation',passed,checks,error,pageErrors:errors,restoration},null,2)+'\n')
 console.log(JSON.stringify({passed,checks,error,restoration}));process.exitCode=passed?0:1
}
