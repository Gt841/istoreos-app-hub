"""Borrow existing ARM KSpeeder through owned loopback SSH tunnels, then close.

Only the two authorized test hosts, fixed non-secret module and task UID are
used. No service install/start, global UCI rewrite or checksum bypass.
"""
import json
from pathlib import Path
import shlex
import socket
import subprocess
import time

ROOT = Path(__file__).resolve().parents[3]
EVIDENCE = ROOT / 'docs/evidence/mise-runtime-execution-20261123/M7-resume1'
EVIDENCE.mkdir(exist_ok=True)
DEV_PORTS = (35443, 35003)
devices = {
    'arm64': ('192.168.30.93', '/mnt/nvme0n1-1/Configs/mise-runtime-acceptance-20261123/Runtime-live',
              '/mnt/nvme0n1-1/Configs/mise-runtime-acceptance-20261123/M7-sumdb-probe'),
    'x64': ('192.168.30.7', '/mnt/mise-runtime/Runtime-live', '/mnt/mise-runtime/acceptance/M7-sumdb-probe'),
}


def ssh(host, command, data=None, check=True):
    return subprocess.run(['ssh', '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=5', 'root@'+host, command],
                          input=data, capture_output=True, check=check)


def probe(arch):
    host, root, base = devices[arch]
    script = base + '.lua'
    ssh(host, 'cat > ' + shlex.quote(script), (ROOT/'apps/mise/tests/go-accelerated-device.lua').read_bytes())
    start = time.monotonic()
    result = ssh(host, shlex.join(['lua', script, root, base, '65003']), check=False)
    report = json.loads(ssh(host, 'cat '+shlex.quote(base+'/result.json')).stdout)
    report['elapsed_seconds'] = round(time.monotonic() - start, 3)
    report['service_mode'] = 'existing local KSpeeder' if arch == 'arm64' else 'existing ARM KSpeeder via two owned loopback SSH tunnels'
    (EVIDENCE/(arch+'-go-accelerated.json')).write_text(json.dumps(report, indent=2)+'\n')
    # The task trace contains only this known public module and gateway URLs.
    for name in ('download.stderr', 'download.stdout', 'verify.stdout'):
        data = ssh(host, 'cat '+shlex.quote(base+'/private/'+name), check=False)
        if data.returncode == 0:
            (EVIDENCE/(arch+'-'+name+'.txt')).write_bytes(data.stdout)
    print(json.dumps({'arch': arch, 'passed': report.get('passed'), 'rc': result.returncode,
                      'checks': len(report['checks']), 'seconds': report['elapsed_seconds'],
                      'error': report.get('error')}), flush=True)
    assert result.returncode == 0 and report.get('passed'), report.get('error')


def free_port(port):
    with socket.socket() as sock:
        sock.bind(('127.0.0.1', port))


def ready(process, port):
    end = time.monotonic()+15
    while time.monotonic() < end:
        assert process.poll() is None, 'SSH tunnel exited before readiness'
        try:
            with socket.create_connection(('127.0.0.1', port), timeout=1):
                return
        except OSError:
            time.sleep(.2)
    raise RuntimeError('SSH tunnel readiness timeout')


tunnels = []
report = {'scope': 'temporary authenticated loopback-only reuse of existing ARM service', 'started': False}
try:
    probe('arm64')
    for port in DEV_PORTS:
        free_port(port)
    code = "local n=require('nixio');for _,p in ipairs({5003,5443})do local s=assert(n.socket('inet','stream'));assert(s:bind('127.0.0.1',p),'Test port already occupied');s:close()end"
    ssh('192.168.30.7', 'lua -e '+shlex.quote(code))
    options = ['ssh', '-N', '-T', '-o', 'BatchMode=yes', '-o', 'ExitOnForwardFailure=yes',
               '-o', 'ServerAliveInterval=10', '-o', 'ServerAliveCountMax=3']
    first = subprocess.Popen(options + ['-L', '127.0.0.1:35443:127.0.0.1:5443',
                                        '-L', '127.0.0.1:35003:127.0.0.1:5003', 'root@192.168.30.93'],
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    tunnels.append(first)
    for port in DEV_PORTS:
        ready(first, port)
    second = subprocess.Popen(options + ['-R', '127.0.0.1:5443:127.0.0.1:35443',
                                         '-R', '127.0.0.1:5003:127.0.0.1:35003', 'root@192.168.30.7'],
                              stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    tunnels.append(second)
    end = time.monotonic()+15
    while time.monotonic() < end:
        assert second.poll() is None, 'x64 SSH forwarding exited'
        result = ssh('192.168.30.7', 'curl --disable -fsS --noproxy "*" --max-time 2 -o /dev/null http://127.0.0.1:5003/api/v1/capabilities', check=False)
        if result.returncode == 0:
            break
        time.sleep(.2)
    else:
        raise RuntimeError('Forwarded service did not become ready')
    report['started'] = True
    probe('x64')
    report['passed'] = True
finally:
    for process in reversed(tunnels):
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=5)
    report['all_owned_tunnels_stopped'] = all(p.poll() is not None for p in tunnels)
    for port in DEV_PORTS:
        free_port(port)
    report['developer_ports_released'] = True
    (EVIDENCE/'tunnels.json').write_text(json.dumps(report, indent=2)+'\n')
