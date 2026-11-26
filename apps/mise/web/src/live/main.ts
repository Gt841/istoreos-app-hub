import {createApp} from 'vue'
import ProductionApp from './ProductionApp.vue'
import {LiveService} from './service'
import '../styles/quickstart/palette.css'
import '../styles/product.css'
import '../styles/quickstart/buttons.css'
const root=document.getElementById('mise-app')
if(!root?.dataset.endpoint||!root.dataset.token)throw Error('Missing authenticated runtime host')
const sync=()=>{const theme=document.body.dataset.quickstartTheme||document.body.getAttribute('theme');root.dataset.theme=theme==='dark'||((!theme||theme==='normal')&&matchMedia('(prefers-color-scheme:dark)').matches)?'dark':'light'}
const observer=new MutationObserver(sync),query=matchMedia('(prefers-color-scheme:dark)');sync();observer.observe(document.body,{attributes:true,attributeFilter:['theme','data-quickstart-theme']});query.addEventListener('change',sync)
createApp(ProductionApp,{service:new LiveService(root.dataset.endpoint,root.dataset.token,root.dataset.writable==='1')}).mount(root)
