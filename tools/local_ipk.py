"""Deterministic local IPK and owning-recipe helpers; no publishing."""
import gzip,hashlib,io,json,os,re,shutil,subprocess,tarfile
from pathlib import Path

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def archive(files):
    output = io.BytesIO()
    with tarfile.open(fileobj=output, mode="w", format=tarfile.GNU_FORMAT) as target:
        parents = {str(parent) for name, _, _, _ in files for parent in Path(name).parents if str(parent) != "."}
        for name in sorted(parents, key=lambda name: (name.count("/"), name)):
            info = tarfile.TarInfo("./" + name + "/")
            info.type, info.mode, info.mtime = tarfile.DIRTYPE, 0o755, 0
            target.addfile(info)
        for name, data, mode, link in sorted(files):
            info = tarfile.TarInfo("./" + name)
            info.mode, info.uid, info.gid, info.mtime = mode, 0, 0, 0
            if link:
                info.type, info.linkname = tarfile.SYMTYPE, link
                target.addfile(info)
            else:
                info.size = len(data)
                target.addfile(info, io.BytesIO(data))
    return gzip.compress(output.getvalue(), mtime=0)


def files_from(root):
    return [(str(p.relative_to(root)), b"" if p.is_symlink() else p.read_bytes(),
             p.lstat().st_mode & 0o777, os.readlink(p) if p.is_symlink() else "")
            for p in root.rglob("*") if p.is_file() or p.is_symlink()]


def hook(recipe, name, phase):
    match = re.search(r"^define Package/" + re.escape(name) + "/" + phase +
                      r"\n(.*?)^endef", recipe, re.M | re.S)
    return match.group(1).replace("$$", "$") if match else None


def ipk(output, name, version, arch, stage, depends, scripts, conffiles):
    control = (f"Package: {name}\nVersion: {version}\nArchitecture: {arch}\n"
               "Maintainer: LinkEase\nSection: admin\nPriority: optional\n"
               "Description: Local device protection candidate\n")
    if depends:
        control += "Depends: " + ", ".join(depends) + "\n"
    controls = [("control", control.encode(), 0o644, "")]
    controls += [(phase, body.encode(), 0o755, "") for phase, body in scripts.items() if body]
    if conffiles:
        controls.append(("conffiles", ("\n".join(conffiles) + "\n").encode(), 0o644, ""))
    payload = archive(files_from(stage))
    body = archive([("debian-binary", b"2.0\n", 0o644, ""),
                    ("control.tar.gz", archive(controls), 0o644, ""),
                    ("data.tar.gz", payload, 0o644, "")])
    path = output / f"{name}_{version}_{arch}.ipk"
    path.write_bytes(body)
    return {"path": str(path), "sha256": sha(path), "depends": depends}


