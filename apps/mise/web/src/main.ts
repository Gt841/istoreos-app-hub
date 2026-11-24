// Future LuCI mount seam. The live adapter must be supplied by the host; never use fixtures implicitly.
import {createApp} from 'vue'
import RuntimeApp from './RuntimeApp.vue'
import type {RuntimeService} from './services/runtime'
import './styles/quickstart/palette.css'
import './styles/product.css'
import './styles/quickstart/buttons.css'
export function mountRuntime(root:HTMLElement,service:RuntimeService){
 root.classList.add('mise-surface')
 const sync=()=>{const preference=document.body.dataset.quickstartTheme||document.body.getAttribute('theme');root.dataset.theme=preference==='dark'||((!preference||preference==='normal')&&matchMedia('(prefers-color-scheme:dark)').matches)?'dark':'light'}
 const observer=new MutationObserver(sync),query=matchMedia('(prefers-color-scheme:dark)');sync();query.addEventListener('change',sync);observer.observe(document.body,{attributes:true,attributeFilter:['theme','data-quickstart-theme']})
 const app=createApp(RuntimeApp,{service});app.mount(root)
 return ()=>{app.unmount();observer.disconnect();query.removeEventListener('change',sync)}
}
