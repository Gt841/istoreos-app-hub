#!/usr/bin/env python3
"""Exercise ownership and lifecycle with only test-owned listeners."""
import hashlib,json,os,pathlib,socket,subprocess,time,urllib.request
root=pathlib.Path(__file__).resolve().parents[4]
script=root/'scripts/ui-design.sh'
out=pathlib.Path(os.environ['MISE_DESIGN_EVIDENCE']);out.mkdir(parents=True,exist_ok=True)
results=[]
def port():
 with socket.socket() as s: s.bind(('127.0.0.1',0));return s.getsockname()[1]
def call(action,p):return subprocess.run([str(script),action,'mise'],env={**os.environ,'ISTORE_UI_DESIGN_PORT':str(p)},capture_output=True,text=True,timeout=55)
def record(name,passed,details=''):results.append(dict(name=name,passed=passed,details=details));assert passed,details
p=port();foreign=subprocess.Popen(['python3','-m','http.server',str(p),'--bind','127.0.0.1'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
try:
 for _ in range(100):
  try:urllib.request.urlopen(f'http://127.0.0.1:{p}/',timeout=.1).close();break
  except Exception:time.sleep(.02)
 r=call('start',p);record('occupied port refused without stopping listener',r.returncode!=0 and foreign.poll() is None,r.stdout+r.stderr)
 owner=hashlib.sha256(str(root).encode()).hexdigest()[:12]
 state=pathlib.Path(os.environ.get('XDG_RUNTIME_DIR','/tmp'))/f'istore-ui-design-{os.getuid()}-{owner}'
 pidfile=state/f'mise-{p}.pid';pidfile.write_text(str(foreign.pid)+'\n')
 r=call('stop',p);record('stale PID pointing to unrelated process is not killed',r.returncode==0 and foreign.poll() is None,r.stdout+r.stderr)
finally:foreign.terminate();foreign.wait(timeout=5)
p=port()
try:
 r=call('start',p);record('owned secondary preview starts',r.returncode==0,r.stdout+r.stderr)
 with urllib.request.urlopen(f'http://127.0.0.1:{p}/health') as response:health=json.load(response)
 record('health identifies exact project and app',health['owner']==str(root) and health['app']=='mise')
 r=call('start',p);record('repeated start reuses owned process',r.returncode==0 and 'Already running' in r.stdout,r.stdout)
 record('status reports owned process', 'Running:' in call('status',p).stdout)
 record('logs show design server', 'mise design:' in call('logs',p).stdout)
finally:
 r=call('stop',p);record('stop shuts down only owned preview',r.returncode==0,r.stdout+r.stderr)
r=call('status',p);record('stopped status clear','Not running.' in r.stdout,r.stdout)
(out/'preview-manager.json').write_text(json.dumps(results,indent=2)+'\n');print(json.dumps(results,indent=2))
