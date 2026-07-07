"""Auto-install Godot Android build template via UI automation."""
import sys, time, os
from pywinauto.application import Application
from pywinauto import Desktop

PROJECT = r"D:\Projects\BOOKWAR\ANDROID_VERSION\test_project"
GODOT = r"D:\Godot\Godot_v4.6.3-stable_win64.exe"
SCREENSHOT = r"D:\Projects\BOOKWAR\ANDROID_VERSION\tests\e2e\screenshots\install_template.png"

print(f"[auto] launching Godot editor on {PROJECT}", flush=True)
app = Application().start(f'"{GODOT}" --path "{PROJECT}" --editor', timeout=60)
time.sleep(12)

# Connect to Godot window
dlg = None
for attempt in range(10):
    try:
        wins = Desktop(backend="uia").windows()
        for w in wins:
            title = w.window_text() if hasattr(w, 'window_text') else ''
            try:
                t = w.element_info.name
            except Exception:
                t = ''
            if 'Godot Engine' in (t or '') or 'Godot' in (title or ''):
                dlg = w
                break
    except Exception as e:
        print(f"[auto] attempt {attempt}: {e}", flush=True)
    if dlg: break
    time.sleep(1)

if not dlg:
    print("[auto] FATAL: Godot window not found", flush=True)
    app.kill()
    sys.exit(1)

print(f"[auto] found window: {dlg.element_info.name}", flush=True)
try:
    dlg.set_focus()
except Exception as e:
    print(f"[auto] set_focus warn: {e}", flush=True)
time.sleep(1)

# Try to access Project menu via menu_select (works for native menus)
print("[auto] attempting menu_select Project -> Install Android Build Template", flush=True)
ok = False
for path in [
    ['Project', 'Install Android Build Template...'],
    ['Project', 'Install Android Build Template'],
]:
    try:
        dlg.menu_select('->'.join(path))
        print(f"[auto] menu_select OK: {path}", flush=True)
        ok = True
        break
    except Exception as e:
        print(f"[auto] menu_select {path} failed: {e}", flush=True)

time.sleep(2)

# Find confirm dialog and click Yes/Install
if ok:
    print("[auto] looking for confirm dialog...", flush=True)
    for i in range(8):
        try:
            desks = Desktop(backend="uia").windows()
            for w in desks:
                n = ''
                try: n = w.element_info.name
                except: pass
                if any(k in (n or '') for k in ['Install', 'Android', 'Template', 'Confirm', 'Godot']):
                    print(f"[auto] dialog candidate: {n}", flush=True)
                    for btn_text in ['Yes', 'Install', 'OK', 'Да', 'Установить']:
                        try:
                            btn = w.child_window(title=btn_text)
                            if btn.exists(timeout=0.5):
                                btn.click_input()
                                print(f"[auto] clicked: {btn_text}", flush=True)
                                time.sleep(3)
                                break
                        except Exception:
                            pass
        except Exception as e:
            print(f"[auto] dialog scan: {e}", flush=True)
        time.sleep(1)

time.sleep(2)

# Screenshot via Win32
import subprocess
subprocess.run(['powershell', '-Command',
    f'Add-Type -AssemblyName System.Windows.Forms,System.Drawing;'
    f'$b=[System.Windows.Forms.Screen]::PrimaryScreen.Bounds;'
    f'$bmp=New-Object System.Drawing.Bitmap($b.Width,$b.Height);'
    f'$g=[System.Drawing.Graphics]::FromImage($bmp);'
    f'$g.CopyFromScreen($b.Location,[System.Drawing.Point]::Empty,$b.Size);'
    f'$bmp.Save(\'{SCREENSHOT}\',[System.Drawing.Imaging.ImageFormat]::Png);'
    f'$bmp.Dispose()'], check=False)

build_dir = os.path.join(PROJECT, 'android', 'build')
print(f"[auto] android/build exists: {os.path.exists(build_dir)}", flush=True)

try:
    app.kill()
except Exception:
    pass

print("[auto] done", flush=True)
