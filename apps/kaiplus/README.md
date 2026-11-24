# KaiPlus and CLASSIC KAI

KaiPlus is the Reasonix product (`reasonix-kai`). CLASSIC KAI is the existing
OpenCode product (`opencode` + the KAI gateway and embedded Web UI). “Classic”
names the product line; it does not pin an obsolete KAI binary version.

`luci-app-kaiplus` owns both management tabs:

| Tab | Configuration | Service | Default port | Data directory suffix |
| --- | --- | --- | --- | --- |
| KaiPlus | `/etc/config/kaiplus` | `/etc/init.d/kaiplus` | 8189 | `Configs/KAIPlus` |
| CLASSIC KAI | `/etc/config/kai` | `/etc/init.d/kai` | 8197 | `Configs/KAI` |

The tabs are `/admin/services/kaiplus/settings` and
`/admin/services/kaiplus/classic` beneath the LuCI base URL. The existing
`/admin/services/kaiplus` entry opens the KaiPlus settings tab.

## Optional classic runtime

Installing `luci-app-kaiplus` does not install `kai`, `kai_session`, `kai-agent`,
or `luci-app-kai`. The CLASSIC KAI tab remains available when KAI is absent and
offers installation through a POST/CSRF-protected taskd job:

```sh
/bin/is-opkg install kai
```

The `kai` package pulls in `kai_session` and the mandatory `kai-agent` bundle,
including the local `kai-skills` files. The classic tab implements its own
configuration and status view, so it does not need the standalone
`luci-app-kai` page. Its standalone source recipe and `syncapps.yaml` LuCI
mapping have been removed. Existing KAI runtime configuration and data are
reused; `kai`, `kai_session`, and `kai-agent` remain packaged separately.
Do not restore `app-meta-kai` or `luci-app-kai`.

After installation, the classic tab reloads to show Enable, Data directory,
and Access port. Save & Apply restarts `/etc/init.d/kai` when enabled and
stops it when disabled. It does not restart KaiPlus or LinkEase. Use distinct
ports and data directories to run both products together. Opening CLASSIC KAI
uses the shared `linkease_apps/open?id=kai` entry resolver, including the
configured authentication and access URL behavior.

The installed classic tab also provides **Update CLASSIC KAI**. The task
refreshes the iStore package index and runs:

```sh
/bin/is-opkg update
/bin/is-opkg upgrade kai kai_session
```

This explicitly upgrades only the classic gateway and runtime engine. It does
not upgrade `luci-app-kai` or the KaiPlus runtime. `kai-agent` remains a mandatory
dependency of `kai`, with a minimum-version requirement; the package manager
can upgrade it when required by a new KAI package. Skills-only updates can
still release `kai-agent` independently.
Updates come from the published iStore package feed; publishing only GitHub
binary archives does not make a version available here. Build and publish the
corresponding IPK/APK packages to the feed first. Normal package upgrades
preserve `/etc/config/kai` and the external KAI data directory. A previously
running, enabled classic service is restarted after the update; otherwise it
is stopped to preserve its prior inactive state. KaiPlus is not restarted.
An update failure remains a failed task with its log and does not report
success. Installation and updating share the same task ID to prevent overlap.

## Package versions and checks

The pending package set uses `kaiplus 1.0.21-r1`,
`luci-app-kaiplus 1.0.11-r4`, and `app-meta-kaiplus 1.0.21-r6`. The runtime
recipe now consumes `kaiplus-binary-1.0.21.tar.gz` from the
`kaiplus-runtime-v1.0.21` GitHub release. Its hash currently identifies the
locally verified candidate built from Reasonix commit
`bd778dd852dc9101cb377eb73ed37ca365179d6e`. Upload the verified release
assets before building/publishing feed packages; if the candidate is rebuilt,
refresh `KAIPLUS_HASH` from the new tarball. This source update does not itself
publish a GitHub release or feed packages. Device
protection uses `changeguard 0.3.5-r1` and `linkspace 0.3.3-r1` from their
matching runtime releases.
Existing `syncapps.yaml` mappings cover all changed packages.

The runtime tarball carries `kaiplus.x86_64`, `kaiplus.aarch64`, and `kaiplus-web.zip`.
The package installs only the matching binary and the single web archive at
`/usr/share/kaiplus/kaiplus-web.zip`; it does not unpack a `www` directory or duplicate
the web assets inside the binary. The init script passes `--web-zip` explicitly.
The server uses zipserve to send individually precompressed Brotli entries to
clients accepting `br`, with streaming identity fallback for other clients.
HTML stays uncompressed for runtime base-path injection and SPA routing.
Publish the tarball, `kaiplus-web.zip`, and `release.json` together from the
same Reasonix release build. Standalone binaries continue to embed the ZIP.

The KaiPlus runtime requires ChangeGuard >= 0.3.5, and ChangeGuard requires
Linkspace >= 0.3.3. These minimum versions belong to runtime package dependencies
so an installation cannot silently reuse incompatible protection components.
The market `config.sh` saves the KaiPlus data and backup directories and starts
the service. The default backup directory is the disk-root `TimeMachine`
folder beside `Configs`; KaiPlus applies that global value to ChangeGuard. A
service-start failure is returned to the installer. The focused first-install check is
`python3 apps/kaiplus/tests/test_fresh_install.py`.

Verify the published runtime archive against the recipe (checks both architectures,
checks the hashes and ELF targets, and runs the matching native version command):

```sh
KAI_VERIFY_PUBLIC_RELEASE=1 python3 apps/kaiplus/tests/test_fresh_install.py
CG_VERIFY_PUBLIC_RELEASE=1 python3 apps/changeguard/tests/test_package_contract.py
```

Before upload, verify the exact local candidate instead:

```sh
KAI_RUNTIME_RELEASE_DIR=/absolute/path/to/reasonix-kai/releases/build \
  python3 apps/kaiplus/tests/test_fresh_install.py -v
```

Run the focused checks without downloading an OpenWrt SDK:

```sh
python3 apps/kaiplus/luci-app-kaiplus/tests/test_classic_kai_entry_contract.py -v
python3 tests/istorex-new-ui-contract-test.py
```

The behavior checks require Node.js and Lua 5.1. If Lua is unavailable locally,
the test supports an SSH interpreter:

```sh
LUA_COMMAND='ssh -o BatchMode=yes root@192.168.30.7 lua -' \
  python3 apps/kaiplus/luci-app-kaiplus/tests/test_classic_kai_entry_contract.py -v
```

The Lua harness runs the real source with filesystem, shell, taskd and UCI
stubs entirely in memory. It does not install packages, write configuration,
or change device services. These checks cover optional installation,
incomplete runtime files, authentication/CSRF rejection, duplicate and failed
tasks, independent service control, browser retries and the post-install
reload. They do not replace browser acceptance of compiled IPK/APK packages.
