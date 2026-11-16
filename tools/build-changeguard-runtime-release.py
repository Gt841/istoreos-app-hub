#!/usr/bin/env python3
"""Build deterministic ChangeGuard and LinkSpace OpenWrt runtime archives."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess

from local_ipk import archive


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def git_value(source: Path, *args: str) -> str:
    return subprocess.check_output(["git", "-C", str(source), *args], text=True).strip()


def require_clean(source: Path) -> str:
    dirty = git_value(source, "status", "--porcelain", "--untracked-files=no")
    if dirty:
        raise RuntimeError(f"tracked source changes must be committed before release: {source}")
    return git_value(source, "rev-parse", "HEAD")


def build(source: Path, package: str, command: str, version: str, arch: str, target: Path) -> None:
    env = {**os.environ, "CGO_ENABLED": "0", "GOOS": "linux", "GOARCH": arch}
    subprocess.run(
        [
            "go", "build", "-trimpath", "-buildvcs=false",
            "-ldflags", f"-s -w -X main.version={version}",
            "-o", str(target), command,
        ],
        cwd=source,
        env=env,
        check=True,
    )
    target.chmod(0o755)
    if not target.is_file() or target.stat().st_size == 0:
        raise RuntimeError(f"empty {package} binary for linux/{arch}")


def verify_native(binary: Path, args: list[str], version: str) -> None:
    value = json.loads(subprocess.check_output([str(binary), *args], text=True))
    if value.get("status") != "succeeded" or value.get("result", {}).get("version") != version:
        raise RuntimeError(f"embedded release version mismatch: {binary}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", required=True)
    parser.add_argument("--guard-source", type=Path, required=True)
    parser.add_argument("--linkspace-source", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    if not args.version or args.version == "dev" or any(c not in "0123456789." for c in args.version):
        raise SystemExit("--version must be a stable numeric dotted version")
    output = args.output.resolve()
    if output.exists() and any(output.iterdir()):
        raise SystemExit(f"release output already exists and is not empty: {output}")
    output.mkdir(parents=True, exist_ok=True)

    sources = {
        "changeguard": {"path": args.guard_source.resolve(), "commit": require_clean(args.guard_source)},
        "linkspace": {"path": args.linkspace_source.resolve(), "commit": require_clean(args.linkspace_source)},
    }
    manifest = {"schemaVersion": 1, "version": args.version, "sources": {}, "artifacts": {}}
    for name, item in sources.items():
        manifest["sources"][name] = {"commit": item["commit"]}

    for openwrt_arch, go_arch in (("x86_64", "amd64"), ("aarch64", "arm64")):
        guard = output / f"changeguard-linux-{go_arch}"
        linkspace = output / f"linkspace-linux-{go_arch}"
        build(sources["changeguard"]["path"], "changeguard", "./cmd/changeguard", args.version, go_arch, guard)
        build(sources["linkspace"]["path"], "linkspace", "./cmd/linkspace", args.version, go_arch, linkspace)
        if go_arch == "amd64":
            verify_native(guard, ["version"], args.version)
            verify_native(linkspace, ["backup", "version", "--json"], args.version)

        guard_archive = output / f"changeguard-{args.version}-{openwrt_arch}.tar.gz"
        guard_archive.write_bytes(archive([
            (f"changeguard-{args.version}/changeguard_bin", guard.read_bytes(), 0o755, ""),
        ]))
        dependency = {
            "schemaVersion": 1,
            "path": "/usr/bin/linkspace",
            "version": args.version,
            "sha256": digest(linkspace),
        }
        linkspace_archive = output / f"linkspace-{args.version}-{openwrt_arch}.tar.gz"
        linkspace_archive.write_bytes(archive([
            (f"linkspace-{args.version}/linkspace", linkspace.read_bytes(), 0o755, ""),
            (f"linkspace-{args.version}/dependency.json", (json.dumps(dependency, sort_keys=True) + "\n").encode(), 0o644, ""),
        ]))
        for name, binary, packaged in (
            ("changeguard", guard, guard_archive),
            ("linkspace", linkspace, linkspace_archive),
        ):
            manifest["artifacts"][f"{name}/{openwrt_arch}"] = {
                "file": packaged.name,
                "sha256": digest(packaged),
                "binarySHA256": digest(binary),
            }

    manifest_path = output / "release-manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    published = [output / item["file"] for item in manifest["artifacts"].values()]
    published.append(manifest_path)
    (output / "SHA256SUMS").write_text("".join(f"{digest(path)}  {path.name}\n" for path in sorted(published)))
    print(json.dumps(manifest, sort_keys=True))


if __name__ == "__main__":
    main()
