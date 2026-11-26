// Real LuCI dialog geometry regression. Read-only: never submit installs or cleanup.
import {chromium} from "playwright"
import fs from "node:fs"
import path from "node:path"
import assert from "node:assert/strict"
const session=JSON.parse(fs.readFileSync(process.env.MISE_LIVE_SESSION,"utf8"))
const out=process.env.MISE_LIVE_EVIDENCE;assert(out);fs.mkdirSync(out,{recursive:true})
const browser=await chromium.launch({headless:true,executablePath:"/config/.cache/ms-playwright/chromium_headless_shell-1200/chrome-headless-shell-linux64/chrome-headless-shell",args:["--no-sandbox"]})
const context=await browser.newContext();await context.addCookies([{name:"sysauth_http",value:session.admin.sid,url:session.base}])
const page=await context.newPage(),checks=[],errors=[];page.on("pageerror",e=>errors.push(e.message))
async function geometry(name){
 const dialog=page.locator("dialog[open]").last();await dialog.waitFor()
 const g=await dialog.evaluate(el=>{const r=el.getBoundingClientRect(),s=getComputedStyle(el),header=el.querySelector("header"),hr=header.getBoundingClientRect();return {x:r.x,y:r.y,width:r.width,height:r.height,vw:innerWidth,vh:innerHeight,scrollWidth:el.scrollWidth,clientWidth:el.clientWidth,header:{x:hr.x,y:hr.y,width:hr.width,height:hr.height,position:getComputedStyle(header).position},titleUncovered:(()=>{const title=header.querySelector("h2"),r=title.getBoundingClientRect();return title.contains(document.elementFromPoint(r.x+r.width/2,r.y+r.height/2))})(),footerBottom:el.querySelector("footer")?.getBoundingClientRect().bottom,css:{position:s.position,margin:s.margin,inset:s.inset,transform:s.transform}}})
 await page.screenshot({path:path.join(out,name+".png"),fullPage:false})
 try{assert.ok(Math.abs(g.x+g.width/2-g.vw/2)<=2,"dialog must be horizontally centered");assert.ok(Math.abs(g.y+g.height/2-g.vh/2)<=2,"dialog must be vertically centered");assert.ok(g.x>=12&&g.y>=12&&g.x+g.width<=g.vw-12&&g.y+g.height<=g.vh-12,"dialog must stay inside viewport");assert.ok(g.scrollWidth<=g.clientWidth+1,"dialog must not scroll horizontally");assert.ok(g.header.x>=g.x&&g.header.x+g.header.width<=g.x+g.width+1&&g.header.y>=g.y&&g.header.y+g.header.height<=g.y+g.height,"header must stay inside dialog");assert.ok(g.titleUncovered,"dialog title must not be covered by host decoration");assert.ok(!g.footerBottom||g.footerBottom<=g.y+g.height,"dialog actions must stay visible");checks.push({name,passed:true,geometry:g})}catch(e){checks.push({name,passed:false,error:e.message,geometry:g})}
}
try{
 for(const [width,height] of [[1382,751],[390,751],[320,751],[1024,480]])for(const theme of ["light","dark"]){
  const suffix=width+"-"+height+"-"+theme;await page.setViewportSize({width,height});await page.goto(session.base+"/cgi-bin/luci/admin/services/mise");await page.locator(".runtime-row").first().waitFor();await page.evaluate(t=>document.body.setAttribute("theme",t),theme);await page.waitForFunction(t=>document.querySelector(".mise-surface").dataset.theme===t,theme)
  await page.getByRole("button",{name:"＋ 安装环境",exact:true}).click();await geometry("install-"+suffix);await page.keyboard.press("Escape")
  const row=page.locator(".runtime-row").first(),usage=row.getByRole("button",{name:"使用此版本",exact:true});await usage.click();await geometry("usage-"+suffix);await page.keyboard.press("Escape");assert.equal(await usage.evaluate(e=>e===document.activeElement),true)
  await row.getByRole("button",{name:"详情",exact:true}).click();await geometry("detail-"+suffix);await page.getByRole("button",{name:"清理环境",exact:true}).click();await geometry("confirm-"+suffix);await page.keyboard.press("Escape");await page.keyboard.press("Escape")
 }
}catch(e){errors.push(String(e.message).replaceAll(session.admin.sid,"[redacted]").replaceAll(session.admin.token,"[redacted]"))}finally{await browser.close();const passed=checks.length===32&&checks.every(c=>c.passed)&&errors.length===0;fs.writeFileSync(path.join(out,"dialog-layout.json"),JSON.stringify({passed,checks,errors},null,2)+"\n");console.log(JSON.stringify({passed,checks,errors}));process.exitCode=passed?0:1}
