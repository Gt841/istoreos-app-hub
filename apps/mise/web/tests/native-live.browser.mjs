// Actual LuCI Go/Zig UI and public installer; no mock API or package build.
import fs from 'node:fs'
import path from 'node:path'
import assert from 'node:assert/strict'
import {chromium} from 'playwright'
const session=JSON.parse(fs.readFileSync(process.env.MISE_LIVE_SESSION,'utf8'))
const tool=process.env.MISE_LIVE_TOOL;assert.ok(['go','zig'].includes(tool))
const display=tool==='go'?'Go':'Zig',wanted=tool==='go'?'1.27.4':'0.17.1'
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
 original=before.runtimes.find(r=>r.entry.tool===tool&&r.entry.version===wanted)
 assert(original&&before.capabilities[tool].enabled)
 const row=()=>page.locator(`[data-runtime="${original.instance}"]`)
 await check('real native SDK receipt shown by production LuCI',async()=>{
  await page.goto(session.base+'/cgi-bin/luci/admin/services/mise')
  await page.getByRole('heading',{name:'运行时环境',exact:true}).waitFor()
  await page.getByRole('button',{name:display,exact:true}).click()
  assert.equal(await page.locator('.runtime-row').count(),2)
  await row().getByRole('button',{name:'详情',exact:true}).click()
  const dialog=page.locator('dialog.mise-dialog')
  await dialog.getByText('✓ 安装验证通过',{exact:true}).waitFor()
  await page.keyboard.press('Escape')
 })
 await check('actual native wrap and language-specific commands',async()=>{
  await row().getByRole('button',{name:'使用此版本',exact:true}).click()
  const first=await page.getByLabel('使用命令 1',{exact:true}).inputValue()
  assert.ok(first.includes(original.instance)&&first.includes(tool==='go'?'go version':'zig version'))
  assert.equal(await page.getByLabel('虚拟环境目录',{exact:true}).count(),0)
  const downloading=page.waitForEvent('download');await page.getByRole('button',{name:'下载 wrap 脚本',exact:true}).click()
  const downloaded=await downloading;await downloaded.saveAs(path.join(out,tool+'-wrap.sh'))
  const script=fs.readFileSync(path.join(out,tool+'-wrap.sh'),'utf8');assert.ok(script.includes(original.instance)&&script.includes('/usr/share/mise-runtime/execute.lua'))
  await page.keyboard.press('Escape')
 })
 await check('explicit test SDK removal preserves application data and other runtimes',async()=>{
  await row().getByRole('button',{name:'详情',exact:true}).click()
  await page.getByRole('button',{name:'清理环境',exact:true}).click()
  await page.getByText(/固定 wrap 入口将失效/).waitFor()
  await page.getByRole('button',{name:'确认清理',exact:true}).click();removed=true
  await waitInstalled(original.instance,false)
  await page.waitForFunction(()=>!document.querySelector('dialog.mise-dialog'))
  const s=await api({op:'read'});assert.deepEqual(s.runtimes.filter(r=>r.entry.tool!==tool),before.runtimes.filter(r=>r.entry.tool!==tool))
 })
 await check('real native UI install has no libc/npm/pip selectors and compiles a real program',async()=>{
  await page.getByRole('button',{name:'＋ 安装环境',exact:true}).click()
  await page.getByLabel('语言',{exact:true}).selectOption(tool)
  await page.getByLabel('版本',{exact:true}).selectOption(wanted)
  assert.equal(await page.getByLabel('运行环境',{exact:true}).count(),0)
  assert.equal(await page.getByLabel('下载方式',{exact:true}).locator('option[value="ks-cli"]').evaluate(el=>el.disabled),false,'Healthy local iStoreEnhance must enable the acceleration option')
  await page.getByLabel('下载方式',{exact:true}).selectOption('ks-cli')
  assert.equal(await page.getByLabel('npm 版本',{exact:true}).count(),0)
  assert.equal(await page.getByLabel('pip 版本',{exact:true}).count(),0)
  await page.getByRole('button',{name:'检查安装内容',exact:true}).click()
  await page.getByRole('button',{name:'开始安装',exact:true}).click()
  await page.keyboard.press('Escape')
  const s=await waitInstalled(original.instance,true);removed=false
  const added=s.runtimes.find(r=>r.instance===original.instance)
  assert.equal(added.verified,true);assert.equal(added.probes.compile,'passed');assert.equal(added.probes.execute,'passed')
  assert.deepEqual(s.defaults,before.defaults)
  assert.deepEqual(s.runtimes.filter(r=>r.entry.tool!==tool),before.runtimes.filter(r=>r.entry.tool!==tool))
  fs.writeFileSync(path.join(out,tool+'-installed.json'),JSON.stringify(added,null,2)+'\n')
 })
 await check('refreshed native page keeps QuickStart mobile and theme layout',async()=>{
  await page.setViewportSize({width:390,height:900});await page.reload()
  await page.getByRole('button',{name:display,exact:true}).click();await row().waitFor()
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
  try{const s=await api({op:'read'});if(!s.runtimes.some(r=>r.instance===original.instance)){const plan=await api({op:'plan',entry:original.entry.id,source:'ks-cli'});await api({op:'submit',id:plan.id});await waitInstalled(original.instance,true)}restoration='test native SDK restored through public API'}
  catch(e){restoration=redact(e.message)}
 }
 await browser.close()
 fs.writeFileSync(path.join(out,'native-live.json'),JSON.stringify({scope:'actual direct-deployed production LuCI and on-device native toolchain installation',passed,checks,error,pageErrors:errors,restoration},null,2)+'\n')
 console.log(JSON.stringify({passed,checks,error,restoration}));process.exitCode=passed?0:1
}
