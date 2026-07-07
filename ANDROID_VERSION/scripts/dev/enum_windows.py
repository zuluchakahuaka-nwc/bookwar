"""Enumerate all windows to find Godot."""
import time
from pywinauto import Desktop, Application

print("[enum] starting Godot...", flush=True)
app = Application(backend="uia").start(
    r'"D:\Godot\Godot_v4.6.3-stable_win64.exe" --path "D:\Projects\BOOKWAR\ANDROID_VERSION\test_project" --editor',
    timeout=60
)
time.sleep(15)

print("[enum] listing all top windows:", flush=True)
for i, w in enumerate(Desktop(backend="uia").windows()):
    try:
        n = w.element_info.name
        cn = w.element_info.class_name
        ctr = ''
        try: ctr = w.element_info.control_type
        except: pass
        pid = w.process_id()
        print(f"  [{i}] ctrl={ctr!r} cls={cn!r} pid={pid} name={n!r}", flush=True)
    except Exception as e:
        print(f"  [{i}] err: {e}", flush=True)

# Check Godot's own windows
print(f"\n[enum] app.process: pid={app.process}", flush=True)
try:
    tops = app.windows()
    print(f"[enum] app.windows count: {len(tops)}", flush=True)
    for t in tops:
        try:
            print(f"  -> {t.element_info.name!r} cls={t.element_info.class_name!r}", flush=True)
        except Exception as e:
            print(f"  -> err: {e}", flush=True)
except Exception as e:
    print(f"[enum] app.windows err: {e}", flush=True)

try: app.kill()
except: pass
print("[enum] done", flush=True)
