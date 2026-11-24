import {chromium} from 'playwright'
import fs from 'node:fs'
import path from 'node:path'
import assert from 'node:assert/strict'
const base=process.env.MISE_DESIGN_URL||'http://127.0.0.1:5180',out=process.env.MISE_DESIGN_EVIDENCE
if(!out)throw Error('MISE_DESIGN_EVIDENCE required')
fs.mkdirSync(out,{recursive:true})
const browser=await chromium.launch({headless:true,executablePath:process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE||'/config/.cache/ms-playwright/chromium_headless_shell-1200/chrome-headless-shell-linux64/chrome-headless-shell',args:['--no-sandbox']})
const context=await browser.newContext({viewport:{width:1440,height:1000}}),page=await context.newPage(),results=[],errors=[]
page.on('pageerror',e=>errors.push(e.message))
const dialog=()=>page.getByRole('dialog')
const state=async()=>(await page.request.get(base+'/__design/api/state')).json()
async function capture(file){await page.evaluate(()=>scrollTo(0,0));await page.locator('.host-system-menu').evaluate(async el=>{await Promise.all(el.getAnimations().map(a=>a.finished.catch(()=>{})));await new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)))});await page.screenshot({path:path.join(out,file),fullPage:true})}
async function check(name,fn){try{await fn();results.push({name,passed:true});console.log('PASS '+name)}catch(e){results.push({name,passed:false,error:e.stack});console.log('FAIL '+name+': '+e.message);await capture('compiler-failure-'+results.length+'.png').catch(()=>{})}}
async function scene(arch='x86_64'){
 await page.goto(base+'/mise');await page.waitForFunction(()=>document.querySelector('.design-host')?.dataset.previewReady==='true')
 const controls=page.locator('.design-controls');await controls.evaluate(el=>el.open=true)
 const generation=Number(await page.locator('.design-host').getAttribute('data-preview-generation'))
 await page.getByLabel('示例架构').selectOption(arch);await page.getByLabel('预览场景',{exact:true}).selectOption('ready');await page.getByRole('button',{name:'载入场景',exact:true}).click()
 await page.waitForFunction(g=>{const el=document.querySelector('.design-host');return el.dataset.previewReady==='true'&&Number(el.dataset.previewGeneration)>g},generation);await controls.evaluate(el=>el.open=false)
}
async function install(language,version,abi){
 await page.getByRole('button',{name:language==='rust'?'Rust':'Zig',exact:true}).click();await page.getByRole('button',{name:'＋ 安装环境',exact:true}).click()
 await dialog().getByLabel('版本',{exact:true}).selectOption(version)
 assert.equal(await dialog().getByLabel('npm 版本',{exact:true}).count(),0)
 if(language==='rust')await dialog().getByLabel('运行环境',{exact:true}).selectOption(abi)
 else assert.equal(await dialog().getByLabel('运行环境',{exact:true}).count(),0)
 await dialog().getByRole('button',{name:'检查安装内容',exact:true}).click()
 if(language==='rust')await dialog().getByText(/minimal：rustc \/ cargo \/ rust-std/).waitFor()
 else await dialog().getByText('标准 Zig 工具链，不安装私有 glibc；产物目标由命令指定',{exact:true}).waitFor()
 await dialog().getByRole('button',{name:'开始安装',exact:true}).click()
 await expectCompleted()
 await dialog().getByRole('button',{name:'查看使用方法'}).click()
}
async function expectCompleted(){let complete=false;for(let i=0;i<100;i++){const s=await state();if(s.tasks[0]?.status==='success'){complete=true;break}await page.waitForTimeout(150)}assert.ok(complete);await dialog().getByRole('button',{name:'查看使用方法'}).waitFor()}
async function download(file){const event=page.waitForEvent('download');await dialog().getByRole('button',{name:'下载 wrap 样例'}).click();await(await event).saveAs(path.join(out,file));return fs.readFileSync(path.join(out,file),'utf8')}
async function cleanup(id){await dialog().getByRole('button',{name:'完成',exact:true}).click();await page.locator(`[data-runtime="${id}"]`).getByRole('button',{name:'详情',exact:true}).click();await dialog().getByRole('button',{name:'清理环境'}).click();await dialog().getByText(/固定 wrap 入口将失效/).waitFor();await dialog().getByRole('button',{name:'确认清理'}).click();assert.equal((await state()).runtimes.some(r=>r.id===id),false)}
for(const arch of ['x86_64','aarch64'])for(const abi of ['glibc','musl'])await check(`Rust ${arch}/${abi} 复核、后台任务、固定 wrap 与清理`,async()=>{
 await scene(arch);const before=await state();await install('rust','1.90.0',abi)
 assert.match(await dialog().getByLabel('使用命令 1').inputValue(),new RegExp(`rust-1.90.0-${arch}-${abi}.*rustc --version`));assert.match(await dialog().getByLabel('使用命令 2').inputValue(),/cargo --version/)
 const source=await download(`rust-${arch}-${abi}-wrap.sh`);assert.ok(source.includes(`1.90.0-${arch}-unknown-linux-${abi==='glibc'?'gnu':'musl'}`));assert.match(source,/CARGO_HOME=/);assert.match(source,/RUSTC="\$runtime\/bin\/rustc"/);assert.ok(!source.includes('npm_config_'))
 const after=await state();assert.deepEqual(after.defaults,before.defaults);assert.equal(after.runtimes.filter(r=>r.libc==='glibc').length,before.runtimes.filter(r=>r.libc==='glibc').length+(abi==='glibc'?1:0));await cleanup(`rust-1.90.0-${arch}-${abi}`)
})
for(const arch of ['x86_64','aarch64'])await check(`Zig ${arch} 标准工具链、固定 wrap 与清理`,async()=>{
 await scene(arch);const before=await state();await install('zig','0.15.2','native')
 assert.match(await dialog().getByLabel('使用命令 1').inputValue(),new RegExp(`zig-0.15.2-${arch}-native.*zig version`));assert.match(await dialog().getByLabel('使用命令 2').inputValue(),/zig env/)
 const source=await download(`zig-${arch}-wrap.sh`);assert.match(source,/ZIG_GLOBAL_CACHE_DIR=/);assert.match(source,/ZIG_LOCAL_CACHE_DIR=/);assert.ok(!source.includes('export LD_LIBRARY_PATH'));assert.equal((await state()).runtimes.filter(r=>r.libc==='glibc').length,before.runtimes.filter(r=>r.libc==='glibc').length);await cleanup(`zig-0.15.2-${arch}-native`)
})
await check('语言切换重置 ABI/npm；五种默认环境只读且禁止删除',async()=>{
 await scene();await page.getByRole('button',{name:'＋ 安装环境',exact:true}).click();await dialog().getByLabel('运行环境',{exact:true}).selectOption('musl')
 for(const [language,abi] of [['zig','native'],['rust','glibc'],['go','native'],['python','glibc'],['node','glibc']]){await dialog().getByLabel('语言',{exact:true}).selectOption(language);assert.equal(await dialog().getByLabel('npm 版本',{exact:true}).count(),language==='node'?1:0);if(abi==='native')assert.equal(await dialog().getByLabel('运行环境',{exact:true}).count(),0);else assert.equal(await dialog().getByLabel('运行环境',{exact:true}).inputValue(),abi)}
 await page.keyboard.press('Escape')
 for(const [language,label] of [['node','Node.js / npm'],['python','Python'],['go','Go'],['rust','Rust'],['zig','Zig']]){await page.getByRole('button',{name:label,exact:true}).click();const s=await state();await page.locator(`[data-runtime="${s.defaults[language]}"]`).getByRole('button',{name:'详情',exact:true}).click();assert.equal(await dialog().getByRole('button',{name:'清理环境'}).isDisabled(),true);await page.keyboard.press('Escape')}
})
await check('五种语言在桌面及 320/390 手机深浅主题下可用且无溢出',async()=>{
 await scene()
 for(const width of [1440,390,320])for(const theme of ['light','dark']){
  await page.setViewportSize({width,height:width===1440?1000:844});await page.locator('[data-theme-selector]>summary').click();await page.getByRole('radio',{name:theme==='light'?/^浅色/:/^深色/}).click();await page.waitForFunction(t=>document.querySelector('.mise-surface').dataset.theme===t,theme)
  for(const language of ['Rust','Zig']){await page.getByRole('button',{name:language,exact:true}).click();assert.equal(await page.getByRole('button',{name:'Zig',exact:true}).isVisible(),true);assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true,`${width}/${theme}/${language}`);await capture(`${language.toLowerCase()}-${width}-${theme}.png`);await page.getByRole('button',{name:'＋ 安装环境',exact:true}).click();assert.equal(await dialog().evaluate(el=>el.getBoundingClientRect().left>=0&&el.getBoundingClientRect().right<=innerWidth),true);await capture(`${language.toLowerCase()}-${width}-${theme}-install.png`);await page.keyboard.press('Escape')}
 }
 assert.deepEqual(errors,[])
})
await browser.close();const report={passed:results.every(r=>r.passed),results,pageErrors:errors};fs.writeFileSync(path.join(out,'compilers-browser.json'),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({checks:results.length,passed:results.filter(r=>r.passed).length}));process.exitCode=report.passed?0:1
