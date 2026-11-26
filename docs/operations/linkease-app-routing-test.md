# LinkEase application routing and test runbook

## Purpose

This runbook records the KAI routing incident as a reusable contract for every
LinkEase application. A plugin's LuCI button must express an application ID;
the shared resolver selects the uhttpd `/apps` route, the shared LAN entry, or
an application-declared direct listener. Individual controllers must not duplicate proxy detection, host, or
authentication URL construction.

Every LuCI package that exposes this launch flow directly depends on both
`luci-lib-linkeaseauth` and `linkease-app-entry`. Its runtime package also
depends on `linkease-app-entry` when it owns the application manifest. This
intentional overlap prevents a future runtime-package refactor from silently
breaking the LuCI launch button.

The stable shared-auth launch API is:

```text
/cgi-bin/luci/admin/services/linkease_apps/open?id=<app-id>
```

The diagnostic API is:

```text
/cgi-bin/luci/admin/services/linkease_apps/status?id=<app-id>
```

Both preserve the browser's current host. This matters for LAN IPs, WAN IPs,
DDNS names, non-default uhttpd ports, and an outer reverse proxy.

## The KAI incident

The router UI was opened through `http://192.168.30.7:10000`, while KAI listened
on port `8197`. An application-specific button built its own authentication URL
and lost uhttpd's `:10000`. A later implementation always selected
`/apps/kai/web/`, even after the uhttpd proxy mapping was removed.

The correct public contract is `/apps/kai/`. KAI itself redirects that root to
`/apps/kai/web/`; callers must not encode that implementation detail.

## Software-center entry is not the application-open action

KAI establishes two different user intents that future plugins must preserve:

1. `META_LUCI_ENTRY` and app-meta `entry.sh` describe where the software
   center enters the installed plugin. If the plugin has a LuCI management
   page, these values must point to that page.
2. The management page's explicit **Open** button describes the user's intent
   to enter the application UI. Only that action calls
   `/cgi-bin/luci/admin/services/linkease_apps/open?id=<app-id>`.

Do not put the shared open action directly in app-meta for a plugin with
configuration, enable/disable, port, token, storage, diagnostics, or external
access controls. Doing so skips the page the user needs to manage the service.
The static `META_LUCI_ENTRY` and every dynamic `entry.sh` `href` must agree.

Current management-first mappings are:

| Application | Software-center/LuCI entry | Open button target |
| --- | --- | --- |
| CLASSIC KAI | `/cgi-bin/luci/admin/services/kaiplus/classic` | `linkease_apps/open?id=kai` |
| FastNet | `/cgi-bin/luci/admin/services/fastnet` | `linkease_apps/open?id=fastnet` |
| Docker Manager | `/cgi-bin/luci/admin/services/dockermanager` | `linkease_apps/open?id=dockermanager` |
| BaiduDrive | `/cgi-bin/luci/admin/services/baidudrive` | `linkease_apps/open?id=baidudrive` |
| KSpeeder | `/cgi-bin/luci/admin/services/istoreenhance` | `linkease_apps/open?id=kspeeder` |
| AgentFlow | `/cgi-bin/luci/admin/services/agentflow` | `linkease_apps/open?id=agentflow` |

KSpeeder remains management-first. Its explicit Open action uses the shared
Auth Bridge; its software-center entry remains the normal LuCI management
page.

A genuinely headless plugin with no management page may use the shared open
action directly from app-meta, but that is the exception and must be covered by
a product contract test.

KAI's manifest therefore declares:

```json
{
  "standalone": {
    "basePath": "/apps/kai/",
    "externalOpen": { "enabled": true }
  },
  "desktop": {
    "mode": "iframe",
    "target": {
      "hostMode": "request-host",
      "path": "/apps/kai/",
      "port": { "keys": { "uci": "kai.@kai[0].port" } }
    }
  }
}
```

Expected resolution:

| uhttpd `/apps` proxy and worker | Result |
| --- | --- |
| available | `http://<current-authority>/apps/kai/` |
| unavailable, shared LAN worker available | `http://<current-host>:19290/apps/kai/` (worker redirects to KAI) |
| both shared routes unavailable | `http://<current-host>:<kai-port>/apps/kai/` |

For the test router those are respectively
`http://192.168.30.7:10000/apps/kai/` and
`http://192.168.30.7:8197/apps/kai/`.

## Shared resolution contract

The resolver in `luci.model.linkease.apps_openwrt` uses this order:

1. choose `/apps/<id>/` only when uhttpd proxy support, its `/apps` mapping,
   and an active LinkEase entry worker are all present;
2. otherwise choose the LAN-capable shared listener reported by the running
   supervisor, normally `http://<request-host>:19290/apps/<id>/`;
3. otherwise choose a manifest-enabled application direct listener;
4. otherwise return `503` without enabling a port or starting a process.

For a direct URL, the path precedence is:

1. `standalone.externalOpen.path`;
2. iframe `desktop.target.path`, or backend `externalBasePath`;
3. the application's public base path.

This distinction prevents the KSpeeder failure mode: its shared route is
`/apps/kspeeder/`, but its direct listener serves `/`, so the fallback URL must
be `http://<host>:5003/`, not `http://<host>:5003/apps/kspeeder/`.

## Application differences

| Pattern | Applications | Direct behavior when shared entry is absent |
| --- | --- | --- |
| legacy app-base service | CLASSIC KAI | same `/apps/<id>/` path on the app port |
| module with different direct root | KSpeeder | explicit `externalOpen.path`, currently `/` |
| private Web with SDK | BaiduDrive | unavailable; only the Web listener is private, SDK/P2P remains unchanged |
| Unix-only | Docker Manager, KaiPlus | unavailable; no application TCP fallback |
| private app-base or terminal | AgentFlow, Codex, OpenCode, Kimi, Claude Code | unavailable; loopback backend ports are never browser fallbacks |
| existing optional application TCP | apps declaring that capability | use only an explicitly supported enabled listener |
| browser-direct iframe | FastNet | redirect to its configured service port; do not proxy measurement traffic |
| LinkEaseFull builtin | OpenWrt embed | no standalone fallback; requires LinkEaseFull |

Do not normalize these applications into one transport model. They share the
launch decision and manifest vocabulary, while each plugin retains its backend
transport and public-path semantics.

## Source-level verification

Before behavioral tests, verify the package dependency closure. Every LuCI
caller must match both shared packages, while runtime packages must retain
`linkease-app-entry` and must not gain `linkeasefull`:

```sh
for file in \
  apps/dockermanager/luci-app-dockermanager/Makefile \
  apps/fastnet/luci-app-fastnet/Makefile \
  apps/istoreenhance/luci-app-istoreenhance/Makefile \
  apps/agentflow/luci-app-agentflow/Makefile \
  apps/baidudrive/luci-app-baidudrive/Makefile \
  apps/kaiplus/luci-app-kaiplus/Makefile
do
  grep -Eq '^LUCI_DEPENDS:=.*\+luci-lib-linkeaseauth.*\+linkease-app-entry' "$file" || exit 1
done

for file in \
  apps/kai/kai/Makefile \
  apps/dockermanager/dockermanager/Makefile \
  apps/fastnet/fastnet/Makefile \
  apps/istoreenhance/istoreenhance/Makefile \
  apps/agentflow/agentflow/Makefile \
  apps/baidudrive/baidudrive/Makefile \
  apps/kaiplus/kaiplus/Makefile
do
  grep -Eq '^([[:space:]]*)DEPENDS:=.*\+linkease-app-entry' "$file" || exit 1
done

if grep -R '^\(LUCI_\)\?DEPENDS:=.*+linkeasefull' \
  apps/{kai,dockermanager,fastnet,istoreenhance,agentflow,baidudrive,kaiplus}/*/Makefile
then
  exit 1
fi
```

The OpenWrt embed is deliberately excluded because it is a LinkEaseFull-only
builtin rather than an independent application.

Also verify that management-first app-meta packages do not bypass their LuCI
pages:

```sh
if rg 'linkease_apps/open' \
  apps/{kai,fastnet,dockermanager,baidudrive,istoreenhance,agentflow}/app-meta-* \
  --glob Makefile --glob entry.sh
then
  exit 1
fi
```

Run the package contracts from the repository root:

```sh
python3 -m unittest \
  apps/kai/tests/test_kai_desktop_plugin_contract.py \
  apps/istoreenhance/tests/test_istoreenhance_package_contract.py \
  apps/dockermanager/tests/test_dockermanager_package_contract.py \
  apps/fastnet/tests/test_fastnet_package_contract.py \
  apps/baidudrive/tests/test_baidudrive_openwrt_contract.py \
  apps/kaiplus/tests/test_kaiplus_openwrt_contract.py \
  apps/agentflow/luci-app-agentflow/tests/test_agentflow_luci_open_contract.py \
  apps/linkeasefull/tests/test_linkease_apps_package_contract.py

sh apps/kai/tests/test-local-agent-contract.sh
```

The Lua resolver test needs OpenWrt's Lua/LuCI modules. It can be staged on a
test router without installing a package:

```sh
ssh root@192.168.30.7 'mkdir -p /tmp/linkease-apps-lua-test/luci/model/linkease'
scp apps/linkeasefull/luci-lib-linkeaseauth/luasrc/model/linkease/apps.lua \
  apps/linkeasefull/luci-lib-linkeaseauth/luasrc/model/linkease/apps_openwrt.lua \
  root@192.168.30.7:/tmp/linkease-apps-lua-test/luci/model/linkease/
scp apps/linkeasefull/luci-lib-linkeaseauth/tests/test_linkease_apps_openwrt.lua \
  root@192.168.30.7:/tmp/linkease-apps-lua-test/test.lua
ssh root@192.168.30.7 \
  'LINKEASE_APPS_SOURCE_ROOT=/tmp/linkease-apps-lua-test lua /tmp/linkease-apps-lua-test/test.lua'
```

The test covers KAI's app-base path, KSpeeder's `/` direct root, Docker
Manager's disabled/enabled external port, FastNet's browser-direct target, and
the unsupported standalone behavior of the OpenWrt builtin.

## Router acceptance on a non-default uhttpd port

Back up configuration before changing proxy state:

```sh
ssh root@192.168.30.7 \
  'cp /etc/config/uhttpd /root/uhttpd.before-app-routing-test.conf'
```

With the proxy enabled, launching KAI through the shared `open` endpoint must
eventually reach:

```text
http://192.168.30.7:10000/apps/kai/
```

With the `/apps` uhttpd proxy mapping removed and uhttpd reloaded, the same
launch endpoint must eventually reach:

```text
http://192.168.30.7:8197/apps/kai/
```

Repeat the no-proxy test for each installed application using the table above.
Docker Manager and KaiPlus must return unavailable while their external ports
are disabled. Restore the saved uhttpd configuration after the test if the
router is expected to return to proxy mode.

Never store LuCI cookies, passwords, auth state, or session-bearing URLs in
test logs or this repository.


## Unix-only Docker Manager acceptance

Use matching new entry and desktop binaries; old state files without `listen`
do not prove LAN entry availability. Package recipe revisions do not replace
already-published runtime archives.

1. On ordinary uhttpd without `proxy_prefix`, open
   `linkease_apps/open?id=dockermanager`. With either active worker, the resolved
   target must be `http://<device>:19290/apps/dockermanager/`.
2. Restore the supported `/apps` proxy and verify the same action keeps the
   current uhttpd authority, including a non-default port.
3. Confirm the Docker Manager process has `DOCKER_MANAGER_LISTEN_MODE=unix`,
   owns its Unix socket, and has no port 8192 listener, including after upgrade
   from `listen_mode=tcp` / `external_port_enabled=1`.
4. Expire the login session while using the shared LAN port. Navigate through
   the application's relative login action; it must reach LuCI's actual port
   and return to the original application, preserving the query. Test both
   workers, LAN hostname and address access, and a non-default LuCI port.
5. Verify listing, upload, terminal/WebSocket and event streaming through the
   Unix backend. Stopping Desktop must leave the gateway path usable.
6. A custom loopback-only shared listener must not be advertised as LAN-ready.
   Missing both shared routes must report unavailable without changing config.

The shared LAN listener is HTTP. Do not present HTTPS LuCI login as HTTPS
application transport. Remote access requires explicitly exposing the shared
entry through the chosen remote channel; this change publishes no tunnel.

## Managed module qualification and regression

Run `python3 -B -m unittest discover -s apps/linkeasefull/tests -v` for the real
manifest matrix: both workers, uhttpd proxy/no proxy, stopped worker and a private
shared bind. It includes unchanged FastNet/KSpeeder browser-direct exceptions.
The suite executes native init bodies with stale public host/TCP configuration
and mocks only platform side effects; it also exercises active/inactive upgrade
hooks and restart failure.

KaiPlus now probes its Unix socket for readiness; the classic tab's TCP probe
remains separate. Native Open buttons must be unavailable if the process is ready
but the shared entry is not. The source checks do not replace device acceptance:
verify KaiPlus session/event streaming, agent terminals, AgentFlow workflows and
Baidu uploads/downloads on a target with matching entry/Desktop runtimes. Check
that AgentFlow/Baidu Web listeners are loopback and KaiPlus has no TCP Web
listener; do not interpret SDK/P2P ports as Web fallback listeners.
