"""Auto-install Godot Android build template via UIA element search."""
import sys, time, os, subprocess
from pywinauto.application import Application
from pywinauto import Desktop

PROJECT = r"D:\Projects\BOOKWAR\ANDROID_VERSION\test_project"
GODOT = r"D:\Godot\Godot_v4.6.3-stable_win64.exe"
SCREENSHOT = r"D:\Projects\BOOKWAR\ANDROID_VERSION\tests\e2e\screenshots\install_template2.png"

print(f"[auto] launching Godot editor on {PROJECT}", flush=True)
app = Application(backend="uia").start(f'"{GODOT}" --path "{PROJECT}" --editor', timeout=60)
time.sleep(14)

# Find Godot top window
dlg = None
for attempt in range(20):
    try:
        for w in Desktop(backend="uia").windows():
            try:
                n = w.element_info.name
                cn = w.element_info.class_name
            except Exception:
                continue
            if n == 'Godot Engine' or cn == 'Engine':
                dlg = w
                break
    except Exception:
        pass
    if dlg: break
    time.sleep(1)

if not dlg:
    print("[auto] FATAL: no Godot window", flush=True)
    app.kill(); sys.exit(1)

print(f"[auto] dlg: {dlg.element_info.name}", flush=True)
try:
    dlg.set_focus()
except Exception as e:
    print(f"[auto] set_focus: {e}", flush=True)
time.sleep(1)

# Print control tree (depth-limited)
def walk(elem, depth=0, max_depth=4):
    if depth > max_depth: return
    try:
        name = elem.element_info.name
        ctype = ''
        try: ctype = elem.element_info.control_type
        except: pass
        if name or ctype in ('MenuBar', 'MenuItem', 'Menu', 'Button'):
            print('  ' * depth + f"[{ctype}] '{name}'", flush=True)
        try:
            children = elem.children()
            for ch in children[:30]:
                walk(ch, depth+1, max_depth)
        except Exception:
            pass
    except Exception:
        pass

print("[auto] walking control tree...", flush=True)
walk(dlg, 0, 3)

# Try to find Project menu button/item
print("[auto] searching for Project menu...", flush=True)
found_proj = None
for tries in range(5):
    try:
        items = dlg.descendants(control_type='MenuItem')
        for it in items:
            try:
                n = it.element_info.name
            except Exception:
                continue
            if n == 'Project':
                found_proj = it
                print(f"[auto] found Project MenuItem: {n}", flush=True)
                break
        if found_proj: break
    except Exception as e:
        print(f"[auto] search err: {e}", flush=True)
    time.sleep(0.5)

if found_proj:
    print("[auto] clicking Project...", flush=True)
    try:
        found_proj.click_input()
    except Exception as e:
        print(f"[auto] click_input: {e}", flush=True)
        try: found_proj.click()
        except Exception as e2: print(f"[auto] click: {e2}", flush=True)
    time.sleep(1)

    # Now find "Install Android Build Template..." menu item
    print("[auto] searching for Install Android Build Template item...", flush=True)
    found_item = None
    for tries in range(8):
        try:
            items = Desktop(backend="uia").windows()
            for w in items:
                try:
                    descendants = w.descendants(control_type='MenuItem')
                except Exception:
                    continue
                for it in descendants:
                    try: n = it.element_info.name
                    except Exception: continue
                    if 'Install Android' in (n or ''):
                        found_item = it
                        print(f"[auto] found: '{n}' in {w.element_info.name}", flush=True)
                        break
                if found_item: break
        except Exception as e:
            print(f"[auto] search2 err: {e}", flush=True)
        if found_item: break
        time.sleep(0.5)

    if found_item:
        try:
            found_item.click_input()
            print("[auto] clicked Install Android Build Template", flush=True)
        except Exception as e:
            print(f"[auto] click err: {e}", flush=True)
        time.sleep(2)

        # Confirm dialog
        print("[auto] confirming dialog...", flush=True)
        for i in range(10):
            try:
                for w in Desktop(backend="uia").windows():
                    try: n = w.element_info.name
                    except Exception: continue
                    if 'Install' in (n or '') or 'Android' in (n or '') or 'Template' in (n or ''):
                        print(f"[auto] dialog: {n}", flush=True)
                        for btn_text in ['Yes', 'Install', 'OK', 'Да', 'Установить', 'ОК']:
                            try:
                                btn = w.child_window(title=btn_text, control_type='Button')
                                if btn.exists(timeout=0.3):
                                    btn.click_input()
                                    print(f"[auto] clicked {btn_text}", flush=True)
                                    time.sleep(3)
                                    break
                            except Exception:
                                pass
            except Exception as e:
                print(f"[auto] confirm err: {e}", flush=True)
            time.sleep(0.5)

time.sleep(3)

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

try: app.kill()
except Exception: pass

print("[auto] done", flush=True)
