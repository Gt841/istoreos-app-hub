set -eu
root="/mnt/nvme0n1-1/Configs/openclawmgr-glibc-acceptance-20261123/recovered-probe-runtime"
node="$root/probe-node/bin/node"
cd "$root/probe_modules"
"$node" -p 'JSON.stringify({arch:process.arch,glibc:process.report.getReport().header.glibcVersionRuntime,npmLibc:process.env.npm_config_libc})'
PATH="$root/probe-node/bin:/usr/sbin:/usr/bin:/sbin:/bin" "$root/probe-node/bin/npm" config get libc
"$node" -e 'const c=require("node:child_process").fork(process.argv[1],[],{stdio:["ignore","inherit","inherit","ipc"]});c.on("exit",n=>{console.log("forkExit="+n);process.exitCode=n;});' "$root/probe_modules/probe.cjs"
