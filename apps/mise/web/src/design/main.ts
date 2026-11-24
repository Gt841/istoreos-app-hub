import {createApp} from 'vue'
import {createRouter,createWebHistory} from 'vue-router'
import DesignHost from './DesignHost.vue'
import {initializeTheme} from '../quickstart/utils/theme'
import '../quickstart/design/shell.css'
import '../quickstart/home/homeSemanticColors.css'
import '../quickstart/home/homeTypography.css'
import '../styles/quickstart/palette.css'
import '../styles/product.css'
import '../styles/quickstart/buttons.css'
import './host.css'
window.vue_lang='zh-cn'
initializeTheme()
const router=createRouter({history:createWebHistory('/'),routes:[{path:'/',redirect:'/mise'},{path:'/:pathMatch(.*)*',component:{render:()=>null}}]})
const app=createApp(DesignHost);app.use(router);router.isReady().then(()=>app.mount('#mise-app'))
