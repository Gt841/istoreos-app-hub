// Explicit supported tools, not the entire upstream mise registry.
// Presentation labels only. Versions, sizes and capabilities come from the backend.
export type Language='node'|'python'|'go'|'rust'|'zig'|'java'
export type Libc='glibc'|'musl'|'native'
type Tool={name:string;filter:string;mark:string;binary:string;abis:Libc[];defaultAbi:Libc;checks:string;hint:string;usageLabels:string[]}
export const tools:Record<Language,Tool>={
 node:{name:'Node.js',filter:'Node.js / npm',mark:'N',binary:'node',abis:['glibc','musl'],defaultAbi:'glibc',checks:'Node/npm 版本、基础 SQLite 和子进程；应用原生扩展由应用另行检查。',hint:'Node 自带 npm；应用的 npm 包分别管理。',usageLabels:['运行指定版本','使用配套 npm']},
 python:{name:'Python',filter:'Python',mark:'Py',binary:'python3',abis:['glibc','musl'],defaultAbi:'glibc',checks:'SSL、SQLite、ctypes、venv、pip 和子进程。',hint:'包含配套 pip，支持虚拟环境。应用依赖应装入各自虚拟环境，pip 版本由应用在自己的环境中维护，不修改共享 Python。',usageLabels:['运行指定版本','查看配套 pip 版本']},
 go:{name:'Go',filter:'Go',mark:'Go',binary:'go',abis:['native'],defaultAbi:'native',checks:'go/gofmt 版本、go env、纯 Go 示例编译与执行；CGO 不在基础验收范围。',hint:'Go 工具链无需选择 libc。wrap 默认 CGO_ENABLED=0；纯 Go 构建通常不依赖 libc。需要 CGO 时，可显式设置 CGO_ENABLED=1，并自行准备匹配的 C 编译器和库。',usageLabels:['运行指定版本','查看 Go 缓存位置']},
 rust:{name:'Rust',filter:'Rust',mark:'Rs',binary:'rustc',abis:['glibc','musl'],defaultAbi:'glibc',checks:'rustc/cargo 版本、宿主 triple、标准库、最小项目构建执行；本机链接器须另行准备。',hint:'包含 rustc、cargo 和宿主标准库（minimal）。glibc/musl 指编译器运行的宿主环境，不是编译产物的目标平台；实际安装须核验宿主 libc 版本。暂不管理 nightly、附加组件和交叉目标。需要链接器或 C 依赖的项目须自行准备。',usageLabels:['运行指定版本','使用配套 Cargo']},
 zig:{name:'Zig',filter:'Zig',mark:'Z',binary:'zig',abis:['native'],defaultAbi:'native',checks:'zig version、zig env、最小项目编译执行；交叉目标按项目另行验证。',hint:'标准 Zig 工具链无需选择 libc；编译产物的架构和 glibc/musl 目标由 zig 命令参数指定。包含 zig cc/c++，不自动配置 Rust 链接器或 Go CGO。缓存位于持久磁盘，构建产物位置仍由项目或命令决定。',usageLabels:['运行指定版本','查看 Zig 环境']},
 java:{name:'Java',filter:'Java',mark:'J',binary:'java',abis:['glibc'],defaultAbi:'glibc',checks:'Temurin 发行版与完整构建号、java/javac/jar、JVM 原生库、TLS、用户和临时目录、示例编译打包运行。',hint:'提供 Temurin JDK 21/25 LTS，固定到具体构建，包含 java、javac 和 jar。首版使用私有 glibc，暂不开放 musl；Maven/Gradle 由应用自行管理。JAVA_HOME、默认 JVM 用户目录和临时目录均指向持久磁盘。',usageLabels:['运行指定版本','使用 javac 编译','使用 jar 工具']},
}
export const languages=(Object.keys(tools) as Language[]).map(id=>({id,name:tools[id].filter}))
export function abiLabel(abi:Libc){return abi==='native'?'标准工具链':abi==='glibc'?'glibc':'musl'}
export function rustHost(arch:'x86_64'|'aarch64',abi:Libc){return `${arch}-unknown-linux-${abi==='glibc'?'gnu':'musl'}`}
export function versionLabel(language:Language,version:string){return language==='java'?`Temurin JDK ${version.replace(/^temurin-/,'')} · LTS`:version}
export function validVersion(language:Language,version:string){return language==='java'?/^temurin-(21|25)\.\d+\.\d+\+\d+$/.test(version):/^\d+(?:\.\d+)+$/.test(version)}
