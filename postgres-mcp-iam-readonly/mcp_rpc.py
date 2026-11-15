#!/usr/bin/env python3
# Minimal MCP client over stdio JSON-RPC. Usage: mcp_rpc.py "<server command>" calls.json out.json stderr.err
import json,subprocess,sys,time,threading,shlex
cmd,callsf,out,errf=sys.argv[1:5]
calls=json.load(open(callsf)) if callsf!='-' else []
T=120
t0=time.time()
p=subprocess.Popen(cmd,shell=True,executable='/bin/bash',stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=open(errf,'w'),text=True)
msgs={};nonjson=[]
def rd():
    for line in p.stdout:
        if line.lstrip().startswith('{'):
            try:
                o=json.loads(line)
                if 'id' in o: msgs[o['id']]=o
            except Exception as e: nonjson.append(line[:300])
        else: nonjson.append(line[:300])
threading.Thread(target=rd,daemon=True).start()
def send(o):
    try: p.stdin.write(json.dumps(o)+"\n"); p.stdin.flush(); return True
    except Exception: return False
def wait(i):
    s=time.time()
    while time.time()-s<T:
        if i in msgs: return msgs[i],int((time.time()-s)*1000)
        if p.poll() is not None:
            time.sleep(0.3)
            return msgs.get(i),int((time.time()-s)*1000)
        time.sleep(0.02)
    return None,int((time.time()-s)*1000)
res={"command":cmd,"calls":[]}
send({"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"tbf21-rpc","version":"0"}}})
r,ms=wait(1); res["initialize"]=r; res["initialize_ms"]=ms
if r and 'result' in r:
    res["protocolVersion"]=r['result'].get('protocolVersion'); res["serverInfo"]=r['result'].get('serverInfo')
    send({"jsonrpc":"2.0","method":"notifications/initialized"})
    send({"jsonrpc":"2.0","id":2,"method":"tools/list"})
    r,ms=wait(2); res["tools_list"]=r; res["tools_list_ms"]=ms
    i=10
    for c in calls:
        i+=1
        ok=send({"jsonrpc":"2.0","id":i,"method":"tools/call","params":{"name":c["tool"],"arguments":c["arguments"]}})
        r,ms=wait(i)
        res["calls"].append({"label":c.get("label"),"tool":c["tool"],"arguments":c["arguments"],"ms":ms,"response":r,"timeout_or_noresp":r is None})
res["server_exit"]=p.poll(); res["nonjson_stdout"]=nonjson[:30]; res["total_ms"]=int((time.time()-t0)*1000)
json.dump(res,open(out,'w'),ensure_ascii=False,indent=1)
try: p.kill()
except Exception: pass
print(out,"init_ok=",bool(res.get("protocolVersion")),"exit=",res["server_exit"],"total_ms=",res["total_ms"],"calls=",[ (c["label"],c["ms"]) for c in res["calls"]])
