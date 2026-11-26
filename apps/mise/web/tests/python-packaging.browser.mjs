import {chromium} from 'playwright'
import fs from 'node:fs'
import path from 'node:path'
import assert from 'node:assert/strict'
const base=process.env.MISE_DESIGN_URL||'http://127.0.0.1:5180',out=process.env.MISE_DESIGN_EVIDENCE
if(!out)throw Error('MISE_DESIGN_EVIDENCE required')
fs.mkdirSync(out,{recursive:true})
const browser=await chromium.launch({headless:true,executablePath:process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE||'/config/.cache/ms-playwright/chromium_headless_shell-1200/chrome-headless-shell-linux64/chrome-headless-shell',args:['--no-sandbox']})
const context=await browser.newContext({viewport:{width:1440,height:1000}}),page=await context.newPage(),results=[],errors=[],requests=[]
page.on('pageerror',e=>errors.push(e.message));page.on('request',r=>requests.push(r.url()))
const dialog=()=>page.getByRole('dialog'),state=async()=>(await page.request.get(base+'/__design/api/state')).json()
async function capture(file){await page.evaluate(()=>scrollTo(0,0));await page.locator('.host-system-menu').evaluate(async el=>{await Promise.all(el.getAnimations().map(a=>a.finished.catch(()=>{})));await new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)))});await page.screenshot({path:path.join(out,file),fullPage:true})}
async function check(name,fn){try{await fn();results.push({name,passed:true});console.log('PASS '+name)}catch(e){results.push({name,passed:false,error:e.stack});console.log('FAIL '+name+': '+e.message);await capture('python-failure-'+results.length+'.png').catch(()=>{})}}
async function scene(name='ready',arch='x86_64'){
 await page.goto(base+'/mise');await page.waitForFunction(()=>document.querySelector('.design-host')?.dataset.previewReady==='true')
 const controls=page.locator('.design-controls');await controls.evaluate(el=>el.open=true);const generation=Number(await page.locator('.design-host').getAttribute('data-preview-generation'))
 await page.getByLabel('预览场景',{exact:true}).selectOption(name);await page.getByLabel('示例架构').selectOption(arch);await page.getByRole('button',{name:'载入场景',exact:true}).click();await page.waitForFunction(g=>{const el=document.querySelector('.design-host');return el.dataset.previewReady==='true'&&Number(el.dataset.previewGeneration)>g},generation);await controls.evaluate(el=>el.open=false)
}
async function installPython(abi='musl'){
 await page.getByRole('button',{name:'Python',exact:true}).click();await page.getByRole('button',{name:'＋ 安装环境',exact:true}).click();await dialog().getByLabel('运行环境',{exact:true}).selectOption(abi)
 assert.equal(await dialog().getByLabel('pip 版本',{exact:true}).count(),0);assert.equal(await dialog().getByLabel('npm 版本',{exact:true}).count(),0);await dialog().getByText(/包含配套 pip，支持虚拟环境/).waitFor()
 await dialog().getByRole('button',{name:'检查安装内容',exact:true}).click();await dialog().getByText('包含配套 pip，支持虚拟环境；无需选择 pip 版本',{exact:true}).waitFor();await dialog().getByRole('button',{name:'开始安装',exact:true}).click()
}
async function done(status='success'){let complete=false;for(let i=0;i<100;i++){const s=await state();if(s.tasks[0]?.status===status){complete=true;break}await page.waitForTimeout(150)}assert.ok(complete,`expected ${status}`);await dialog().getByText((await state()).tasks[0].result,{exact:true}).waitFor()}
for(const arch of ['x86_64','aarch64'])await check(`Python ${arch} 配套 pip/venv 复核、验证、详情只读及使用方法`,async()=>{
 await scene('ready',arch);await installPython();await done();assert.ok((await state()).tasks[0].phases.includes('配套 pip/venv 准备与验证'));await dialog().getByRole('button',{name:'查看使用方法'}).click();await dialog().getByLabel('虚拟环境目录',{exact:true}).waitFor();assert.match(await dialog().getByLabel('虚拟环境命令 1').inputValue(),/--create-venv/);await dialog().getByRole('button',{name:'完成',exact:true}).click();await page.locator(`[data-runtime="python-3.13.3-${arch}-musl"]`).getByRole('button',{name:'详情',exact:true}).click();await dialog().getByText('25.0.1（设计样例）',{exact:true}).waitFor();await dialog().getByText('可用 · 创建与 pip 初始化检查通过（设计样例）',{exact:true}).waitFor();assert.equal(await dialog().getByRole('combobox').count(),0);await page.keyboard.press('Escape')
})
await check('未知工具状态不伪造版本或验证通过',async()=>{
 await scene('python-unknown');await page.getByRole('button',{name:'Python',exact:true}).click();const row=page.locator('[data-runtime="python-3.13.3-x86_64-glibc"]');await row.getByText('待验证',{exact:true}).waitFor();await row.getByRole('button',{name:'详情',exact:true}).click();await dialog().getByText('尚未读取版本（设计样例）',{exact:true}).waitFor();await dialog().getByText('尚未验证（设计样例）',{exact:true}).waitFor();await dialog().getByText('尚未完成全部验证',{exact:true}).waitFor();assert.equal(await dialog().getByText(/25\.0\.1/).count(),0)
})
await check('pip/venv 失败不提交候选，重试后可完成',async()=>{
 await scene('python-tools');const before=(await state()).runtimes;await installPython();await done('failed');assert.deepEqual((await state()).runtimes,before);await dialog().getByText('配套 pip/venv 验证失败，候选已清理，未提交环境。',{exact:true}).waitFor();await dialog().getByRole('button',{name:'重新检查'}).click();await dialog().getByRole('button',{name:'检查安装内容',exact:true}).click();await dialog().getByRole('button',{name:'开始安装',exact:true}).click();await done()
})
await check('独立 pip 版本 API 被拒绝',async()=>{
 await scene();const r=await page.request.post(base+'/__design/api/action',{data:{action:'plan',input:{kind:'install',language:'python',version:'3.13.3',libc:'musl',pip:'latest',source:'origin'}}});assert.equal(r.status(),400);assert.match((await r.json()).error,/独立版本/)
})
await check('虚拟环境目录校验、四条命令、引用转义、复制与脚本下载',async()=>{
 await scene();await page.getByRole('button',{name:'Python',exact:true}).click();await page.locator('[data-runtime="python-3.13.3-x86_64-glibc"]').getByRole('button',{name:'使用此版本'}).click();const before=(await state()).tasks.length
 for(const p of ['/root/test','/tmp/venv','/mnt/data/../root','/mnt/data/Configs/Runtime/environments/x']){await dialog().getByLabel('虚拟环境目录',{exact:true}).fill(p);await dialog().getByRole('alert').waitFor();assert.equal(await dialog().getByLabel('虚拟环境命令 1').count(),0)}
 await dialog().getByLabel('虚拟环境目录',{exact:true}).fill("/mnt/data/app one's/.venv");assert.ok((await dialog().getByLabel('虚拟环境命令 1').inputValue()).includes("'\\''"));assert.match(await dialog().getByLabel('虚拟环境命令 2').inputValue(),/--venv .* pip install -r requirements.txt/);assert.match(await dialog().getByLabel('虚拟环境命令 3').inputValue(),/python app.py/);assert.match(await dialog().getByLabel('虚拟环境命令 4').inputValue(),/--shell/);await dialog().getByRole('button',{name:'复制',exact:true}).last().click();await dialog().getByRole('status').waitFor();assert.equal((await state()).tasks.length,before)
 const download=page.waitForEvent('download');await dialog().getByRole('button',{name:'下载 wrap 样例'}).click();await(await download).saveAs(path.join(out,'python-venv-wrap.sh'));const source=fs.readFileSync(path.join(out,'python-venv-wrap.sh'),'utf8');for(const key of ['--create-venv','--venv','__PYVENV_LAUNCHER__','PIP_REQUIRE_VIRTUALENV=true','未回退共享 Python'])assert.ok(source.includes(key),key);assert.ok(!source.includes('export LD_LIBRARY_PATH'))
})
await check('npm 默认配套版本、高级选项收起、兼容选择与语言/版本重置',async()=>{
 await scene('first');await page.getByRole('button',{name:'设置存储位置'}).first().click();await page.getByLabel('运行环境存放位置').fill('/mnt/data/Runtime');await page.getByRole('button',{name:'保存设置'}).click();await page.getByRole('navigation',{name:'运行时管理'}).getByRole('button',{name:'运行环境',exact:true}).click();await page.getByRole('button',{name:'＋ 安装环境',exact:true}).click()
 assert.equal(await dialog().getByLabel('npm 版本',{exact:true}).isVisible(),false);await dialog().getByText('默认使用配套 npm 11.12.1；当前选择 11.12.1。',{exact:true}).waitFor();await dialog().getByText('高级选项 · npm 版本',{exact:true}).click();await dialog().getByLabel('npm 版本',{exact:true}).selectOption('10.9.2');await dialog().getByRole('button',{name:'检查安装内容',exact:true}).click();await dialog().getByText('Node.js 24.22.1 / npm 10.9.2',{exact:true}).waitFor();await dialog().getByRole('button',{name:'上一步',exact:true}).click();await dialog().getByLabel('版本',{exact:true}).selectOption('22.16.0');assert.equal(await dialog().getByLabel('npm 版本',{exact:true}).inputValue(),'10.9.2');await dialog().getByLabel('语言',{exact:true}).selectOption('python');assert.equal(await dialog().getByText('高级选项 · npm 版本',{exact:true}).count(),0);await dialog().getByLabel('语言',{exact:true}).selectOption('node');assert.equal(await dialog().getByLabel('npm 版本',{exact:true}).isVisible(),false);assert.equal(await dialog().getByLabel('npm 版本',{exact:true}).inputValue(),'11.12.1')
})
await check('Python 虚拟环境与 npm 高级选项桌面/320/390 手机深浅主题',async()=>{
 await scene();for(const width of [1440,390,320])for(const theme of ['light','dark']){
  await page.setViewportSize({width,height:width===1440?1000:844});await page.locator('[data-theme-selector]>summary').click();await page.getByRole('radio',{name:theme==='light'?/^浅色/:/^深色/}).click();await page.waitForFunction(t=>document.querySelector('.mise-surface').dataset.theme===t,theme)
  await page.getByRole('button',{name:'Python',exact:true}).click();await page.getByRole('button',{name:'＋ 安装环境',exact:true}).click();await capture(`python-${width}-${theme}-install.png`);await page.keyboard.press('Escape');await page.locator('[data-runtime="python-3.13.3-x86_64-glibc"]').getByRole('button',{name:'使用此版本'}).click();await dialog().getByLabel('虚拟环境命令 4').waitFor();assert.equal(await dialog().evaluate(el=>el.getBoundingClientRect().left>=0&&el.getBoundingClientRect().right<=innerWidth),true);assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true);await capture(`python-${width}-${theme}-usage.png`);await page.keyboard.press('Escape')
  await page.getByRole('button',{name:'Node.js / npm',exact:true}).click();await page.getByRole('button',{name:'＋ 安装环境',exact:true}).click();await dialog().getByText('高级选项 · npm 版本',{exact:true}).click();await capture(`npm-${width}-${theme}-advanced.png`);await page.keyboard.press('Escape')
 }
 assert.deepEqual(errors,[]);assert.ok(requests.every(url=>url.startsWith(base)))
})
await browser.close();const report={passed:results.every(r=>r.passed),results,pageErrors:errors};fs.writeFileSync(path.join(out,'python-packaging-browser.json'),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({checks:results.length,passed:results.filter(r=>r.passed).length}));process.exitCode=report.passed?0:1
