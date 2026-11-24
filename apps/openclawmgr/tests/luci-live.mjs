// Read-only real LuCI regression; session/config secrets never enter evidence.
import fs from 'node:fs'
import path from 'node:path'
import assert from 'node:assert/strict'
import {createRequire} from 'node:module'
const load=createRequire(new URL('../../mise/web/package.json',import.meta.url))
const {chromium}=load('playwright')
const session=JSON.parse(fs.readFileSync(process.env.OPENCLAWMGR_LUCI_SESSION,'utf8'))
const output=process.env.OPENCLAWMGR_LUCI_EVIDENCE
assert(output);fs.mkdirSync(output,{recursive:true})
const secrets=[session.admin.sid,session.admin.token]
const redact=value=>secrets.filter(Boolean).reduce((text,secret)=>text.replaceAll(secret,'[redacted]'),String(value))
const browser=await chromium.launch({headless:true,executablePath:process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE||'/config/.cache/ms-playwright/chromium_headless_shell-1200/chrome-headless-shell-linux64/chrome-headless-shell',args:['--no-sandbox']})
const context=await browser.newContext()
await context.addCookies([{name:'sysauth_http',value:session.admin.sid,url:session.base}])
const checks=[],errors=[]
const page=await context.newPage();page.on('pageerror',error=>errors.push(redact(error.message)))
async function check(name,fn){await fn();checks.push({name,passed:true})}
let passed=false,error
try{
 await check('unauthenticated status does not disclose Gateway credentials',async()=>{
  const anonymous=await browser.newContext()
  try{
   const response=await anonymous.request.get(session.base+'/cgi-bin/luci/admin/services/openclawmgr/status',{maxRedirects:0})
   if(response.status()===200&&(response.headers()['content-type']||'').includes('application/json')){
    const data=await response.json();assert.equal(data.token,undefined);assert.equal(data.token_url,undefined);assert.notEqual(data.ok,true)
   }else assert.ok([200,302,303,401,403].includes(response.status()),'Unexpected unauthenticated response')
  }finally{await anonymous.close()}
 })
 await check('real authenticated status uses the exact running shared SDK',async()=>{
  const response=await context.request.get(session.base+'/cgi-bin/luci/admin/services/openclawmgr/status')
  assert.equal(response.status(),200)
  const data=await response.json();secrets.push(data.token)
  assert.equal(data.ok,true);assert.equal(data.installed,true);assert.equal(data.running,true);assert.equal(data.runtime_missing,false)
  assert.ok(data.node_version.includes('24.22.1'),'Wrong Node version in real status')
  assert.ok(data.openclaw_version.includes('2026.3.28'),'Wrong OpenClaw version in real status')
  assert.equal(data.installing,false)
 })
 await check('deployed OpenClaw page renders actual version without script errors',async()=>{
  await page.goto(session.base+'/cgi-bin/luci/admin/services/openclawmgr/config')
  await page.waitForFunction(()=>document.getElementById('openclawmgr-app')?.shadowRoot?.textContent?.includes('2026.3.28'),{},{timeout:60000})
  assert.deepEqual(errors,[])
 })
 await check('production mise page renders installed public runtimes',async()=>{
  await page.goto(session.base+'/cgi-bin/luci/admin/services/mise')
  await page.getByRole('heading',{name:'运行时环境',exact:true}).waitFor()
  await page.locator('.runtime-row').first().waitFor()
  assert.ok(await page.locator('.runtime-row').count()>=2,'Installed runtime rows missing')
  assert.deepEqual(errors,[])
 })
 passed=true
}catch(caught){error=redact(caught.message)}finally{
 await browser.close()
 fs.writeFileSync(path.join(output,'luci-live.json'),JSON.stringify({passed,scope:'read-only actual deployed LuCI; no package-build claim',checks,pageErrors:errors,error},null,2)+'\n')
 process.exitCode=passed?0:1
 console.log(JSON.stringify({passed,checks,error}))
}
