set -eu
root="/mnt/nvme0n1-1/Configs/openclawmgr-glibc-acceptance-20261123/recovered-probe-runtime"
cd "$root/probe_modules"
"$root/probe-node/bin/node" -e 'const c=require("node:child_process").fork(process.argv[1],[],{stdio:["ignore","inherit","inherit","ipc"]});c.on("exit",n=>{console.log(JSON.stringify({forkExit:n,parentGlibc:process.report.getReport().header.glibcVersionRuntime,parentExec:process.execPath}));process.exitCode=n;});' "$root/probe_modules/probe.cjs"
