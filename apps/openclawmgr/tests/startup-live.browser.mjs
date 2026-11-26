// Read-only checks against the real LuCI page after a device installation.
// Sessions stay in the private SSD file; API tokens/URLs never enter evidence.
import fs from 'node:fs'
import assert from 'node:assert/strict'
import {createRequire} from 'node:module'
const {chromium}=createRequire(new URL('../../mise/web/package.json',import.meta.url))('playwright')
const session=JSON.parse(fs.readFileSync(process.env.OPENCLAW_LIVE_SESSION,'utf8'))
const out=process.env.OPENCLAW_LIVE_EVIDENCE;assert(out);fs.mkdirSync(out,{recursive:true})
const browser=await chromium.launch({executablePath:'/config/.cache/ms-playwright/chromium_headless_shell-1200/chrome-headless-shell-linux64/chrome-headless-shell',args:['--no-sandbox']})
const context=await browser.newContext({viewport:{width:1440,height:1000}})
await context.addCookies([{name:'sysauth_http',value:session.admin.sid,url:session.base}])
const page=await context.newPage(),checks=[],pageErrors=[]
page.on('pageerror',e=>pageErrors.push(e.message))
let passed=false,error,status
try{
 const prefix=session.base+'/cgi-bin/luci/admin/services/openclawmgr'
 await page.goto(prefix,{waitUntil:'domcontentloaded',timeout:120000})
 await page.locator('#oclm-status-text').waitFor({timeout:120000})
 const response=await context.request.get(prefix+'/status',{timeout:120000})
 assert.equal(response.status(),200)
 const value=await response.json()
 status={installed:value.installed,running:value.running,installing:value.installing,
  runtime_missing:value.runtime_missing,base_dir:value.base_dir,node_version:value.node_version,
  openclaw_version:value.openclaw_version,runtime_info:value.runtime_info,
  runtime_preparation:value.runtime_preparation}
 assert(value.ok&&value.installed&&value.running&&!value.installing&&!value.runtime_missing,'LuCI must show an installed, running Gateway')
 checks.push({name:'LuCI status reports installed and running',passed:true})
 assert.equal(value.runtime_preparation?.status,'ready')
 assert.equal(value.runtime_info?.abi,'glibc');assert.equal(value.runtime_info?.libc?.version,'2.39')
 checks.push({name:'fixed GNU Node and glibc 2.39 are visible and ready',passed:true})
 const ready=await context.request.get(prefix+'/ready',{timeout:45000})
 assert((await ready.json()).ready,'Gateway HTTP readiness must pass')
 checks.push({name:'Gateway HTTP readiness',passed:true})
 await page.waitForFunction(()=>document.querySelector('#openclawmgr-app')?.shadowRoot?.querySelector('#oclm-status-text')?.textContent==='运行中',null,{timeout:45000})
 assert((await page.locator('#oclm-runtime-abi').innerText()).includes('glibc'))
 checks.push({name:'rendered page shows running and glibc',passed:true})
 // Hide credentials if a future page starts displaying them in inputs.
 await page.locator('input[type="password"]').evaluateAll(inputs=>inputs.forEach(e=>e.style.visibility='hidden'))
 await page.locator('#oclm-address-text').evaluate(e=>e.textContent=e.textContent.replace(/#token=.*/,'#token=[已隐藏]'))
 await page.screenshot({path:out+'/running.png',fullPage:true})
 assert.deepEqual(pageErrors,[]);passed=true
}catch(e){error=String(e.message)}finally{
 await browser.close()
 fs.writeFileSync(out+'/browser.json',JSON.stringify({passed,checks,error,status,pageErrors},null,2)+'\n')
 console.log(JSON.stringify({passed,checks,error}));process.exitCode=passed?0:1
}
