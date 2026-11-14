#!/usr/bin/env python3
"""Execute owning install recipes and create local, unpublished candidates.

The small make harness verifies install targets. It is not an SDK compilation.
Native package installation/runtime evidence is collected separately.
"""
import argparse
import json
from pathlib import Path
import re
import shutil
import subprocess
from local_ipk import archive, sha, hook, ipk

HUB=Path(__file__).resolve().parents[1]
VERSION="0.3.0-cg1"
KAI_VERSION="1.0.14-cg1"

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    for name in ["guard-amd64","guard-arm64","linkspace-amd64","linkspace-arm64","kai-amd64","kai-arm64","output","work"]:
        parser.add_argument("--"+name,type=Path,required=True)
    args=parser.parse_args();out=args.output.resolve();work=args.work.resolve()
    out.mkdir(parents=True,exist_ok=True);work.mkdir(parents=True,exist_ok=True)
    # Check the actual compiled entrypoint before claiming a release identity.
    for binary,command,expected in [(args.guard_amd64,["version"],VERSION),(args.linkspace_amd64,["backup","version","--json"],VERSION)]:
        value=json.loads(subprocess.check_output([str(binary),*command],text=True))
        if value.get("status")!="succeeded" or value.get("result",{}).get("version")!=expected:
            raise RuntimeError("compiled binary version does not match candidate identity: "+binary.name)
    releases={}
    for name,prefix,inputs in [
        ("changeguard","CHANGEGUARD",[args.guard_amd64,args.guard_arm64]),
        ("linkspace","LINKSPACE",[args.linkspace_amd64,args.linkspace_arm64]),
    ]:
        lines=[]
        for arch,binary in zip(["x86_64","aarch64"],inputs):
            executable="changeguard_bin" if name=="changeguard" else "linkspace"
            files=[(f"{name}-{VERSION}/{executable}",binary.read_bytes(),0o755,"")]
            if name=="linkspace":
                descriptor={"schemaVersion":1,"path":"/usr/bin/linkspace","version":VERSION,"sha256":sha(binary)}
                files.append((f"{name}-{VERSION}/dependency.json",(json.dumps(descriptor)+"\n").encode(),0o644,""))
            path=out/f"{name}-{VERSION}-{arch}.tar.gz";path.write_bytes(archive(files))
            lines.append(f"{prefix}_HASH_{arch}:={sha(path)}\n")
            releases[f"{name}/{arch}"]={"path":str(path),"sha256":sha(path),"binarySHA256":sha(binary)}
        (HUB/f"apps/{name}/{name}/release.mk").write_text("# Local candidate; not publicly published.\n"+"".join(lines))
    kai=HUB/"apps/kaiplus/kaiplus/Makefile";recipe=kai.read_text()
    for arch,binary in zip(["x86_64","aarch64"],[args.kai_amd64,args.kai_arm64]):
        recipe=re.sub(r"KAIPLUS_HASH_"+arch+r":=[0-9a-f]+",f"KAIPLUS_HASH_{arch}:={sha(binary)}",recipe)
        releases[f"kaiplus/{arch}"]={"path":str(binary),"binarySHA256":sha(binary)}
    kai.write_text(recipe)

    sdk=work/"install-harness";(sdk/"include").mkdir(parents=True,exist_ok=True)
    (sdk/"rules.mk").write_text("");(sdk/"include/package.mk").write_text("")
    packages={}
    for name,version,folder,binary,build_name in [
        ("linkspace",VERSION,HUB/"apps/linkspace/linkspace",args.linkspace_amd64,"linkspace"),
        ("changeguard",VERSION,HUB/"apps/changeguard/changeguard",args.guard_amd64,"changeguard_bin"),
        ("optimemachine",VERSION,HUB/"apps/optimemachine/optimemachine",None,""),
        ("luci-app-optimemachine",VERSION,HUB/"apps/optimemachine/luci-app-optimemachine",None,""),
        ("kaiplus",KAI_VERSION,HUB/"apps/kaiplus/kaiplus",args.kai_amd64,"kaiplus"),
    ]:
        build=sdk/"build"/f"{name}-{version}";build.mkdir(parents=True,exist_ok=True)
        if binary:shutil.copy2(binary,build/build_name)
        if name=="linkspace":
            (build/"dependency.json").write_text(json.dumps({"schemaVersion":1,"path":"/usr/bin/linkspace","version":VERSION,"sha256":sha(binary)})+"\n")
        stage=work/f"stage-{name}"
        if stage.exists():shutil.rmtree(stage)
        stage.mkdir()
        make=sdk/f"{name}.mk"
        make.write_text(f"TOPDIR:={sdk}\nARCH:=x86_64\nBUILD_DIR:={sdk}/build\nINCLUDE_DIR:={sdk}/include\n"
            "INSTALL_DIR:=install -d -m0755\nINSTALL_BIN:=install -m0755\nINSTALL_DATA:=install -m0644\nINSTALL_CONF:=install -m0600\nCP:=cp -a\n"
            f"include {folder}/Makefile\n.PHONY: stage\nstage:\n\t$(call Package/{name}/install,{stage})\n")
        subprocess.run(["make","--no-print-directory","-f",str(make),"stage"],cwd=folder,check=True)
        recipe=(folder/"Makefile").read_text()
        declaration=re.search(r"^\s*DEPENDS:=(.*)$",recipe,re.M).group(1)
        depends=re.findall(r"\+([a-zA-Z0-9_.-]+)",declaration)
        # OpenWrt recipes using $(PKG_NAME) retain their original hook text.
        package_key="$(PKG_NAME)" if f"define Package/$(PKG_NAME)" in recipe else name
        scripts={phase:hook(recipe,package_key,phase) for phase in ["preinst","postinst","prerm","postrm"]}
        conffiles=(hook(recipe,package_key,"conffiles") or "").splitlines()
        release=re.search(r"^PKG_RELEASE:=(\S+)",recipe,re.M).group(1)
        packages[name]=ipk(out,name,version+"-"+release,"x86_64",stage,depends,scripts,conffiles)

    # Keep the software-center identity, and exercise the actual shared meta.mk.
    source=HUB/"apps/optimemachine/app-meta-optimemachine"
    mirror=sdk/"meta/apps/optimemachine/app-meta-optimemachine";mirror.mkdir(parents=True,exist_ok=True)
    for name in ["Makefile","entry.sh","logo.png"]:shutil.copy2(source/name,mirror/name)
    shutil.copy2(HUB.parent/"openwrt-app-meta/meta.mk",mirror.parent.parent/"meta.mk")
    stage=work/"stage-app-meta-optimemachine"
    if stage.exists():shutil.rmtree(stage)
    stage.mkdir()
    make=sdk/"meta.mk";make.write_text(f"TOPDIR:={sdk}\nINCLUDE_DIR:={sdk}/include\nBUILD_DIR:={sdk}/build\n"
        "INSTALL_DIR:=install -d -m0755\nINSTALL_BIN:=install -m0755\nINSTALL_DATA:=install -m0644\n"
        "empty:=\nspace:=$(empty) $(empty)\ncomma:=,\ndefine newline\n\n\nendef\n"
        f"include {mirror}/Makefile\n.PHONY: stage\nstage:\n\t$(call Package/app-meta-optimemachine/install,{stage})\n")
    subprocess.run(["make","--no-print-directory","-f",str(make),"stage"],cwd=mirror,check=True)
    json.loads((stage/"usr/lib/opkg/meta/optimemachine.json").read_text())
    meta_recipe=(source/"Makefile").read_text()
    meta_version=re.search(r"^PKG_VERSION:=(\S+)",meta_recipe,re.M).group(1)
    meta_release=re.search(r"^PKG_RELEASE:=(\S+)",meta_recipe,re.M).group(1)
    packages["app-meta-optimemachine"]=ipk(out,"app-meta-optimemachine",meta_version+"-"+meta_release,"all",stage,["changeguard","optimemachine","luci-app-optimemachine"],{},[])
    report={"schemaVersion":1,"publiclyPublished":False,"runtimeInstallTargetsExecuted":True,"sdkCompilation":False,"architecture":"x86_64","releases":releases,"packages":packages}
    (out/"packages.json").write_text(json.dumps(report,indent=2)+"\n")
    print(json.dumps({"packages":list(packages),"output":str(out)}))
if __name__=="__main__":main()
