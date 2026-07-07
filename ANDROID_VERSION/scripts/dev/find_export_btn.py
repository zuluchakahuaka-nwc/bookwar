"""Try clicking actual Export Project button (not save icon)."""
import time, os, subprocess
import ctypes
from pywinauto import Desktop, Application

PROJECT = r"D:\Projects\BOOKWAR\ANDROID_VERSION\test_project"
GODOT = r"D:\Godot\Godot_v4.6.3-stable_win64.exe"
SS = r"D:\Projects\BOOKWAR\ANDROID_VERSION\tests\e2e\screenshots"

user32 = ctypes.windll.user32

def click(x, y, delay=0.25):
    user32.SetCursorPos(x, y); time.sleep(delay)
    user32.mouse_event(0x0002, 0, 0, 0, 0); time.sleep(0.05)
    user32.mouse_event(0x0004, 0, 0, 0, 0); time.sleep(delay)

def screenshot(path):
    subprocess.run(['powershell', '-Command',
        f'Add-Type -AssemblyName System.Windows.Forms,System.Drawing;'
        f'$b=[System.Windows.Forms.Screen]::PrimaryScreen.Bounds;'
        f'$bmp=New-Object System.Drawing.Bitmap($b.Width,$b.Height);'
        f'$g=[System.Drawing.Graphics]::FromImage($bmp);'
        f'$g.CopyFromScreen($b.Location,[System.Drawing.Point]::Empty,$b.Size);'
        f'$bmp.Save(\'{path}\',[System.Drawing.Imaging.ImageFormat]::Png);'
        f'$bmp.Dispose()'], check=False)

print("[r] launching Godot...", flush=True)
app = Application().start(f'"{GODOT}" --path "{PROJECT}" --editor', timeout=60)
time.sleep(14)

hwnd = 0
for i in range(20):
    for w in Desktop(backend="uia").windows():
        try:
            if w.element_info.class_name == 'Engine' and w.element_info.name == 'Godot Engine':
                hwnd = w.element_info.handle; break
        except: pass
    if hwnd: break
    time.sleep(0.5)

user32.ShowWindow(hwnd, 3); time.sleep(1)
user32.SetForegroundWindow(hwnd); time.sleep(0.5)

# Open Project menu, click Export
click(195, 85, 0.3); time.sleep(0.8)
click(195, 315, 0.3); time.sleep(2.5)

# Try multiple positions for Export Project button
# Bottom of dialog varies. Try y=560, 580, 600, 620, 640
positions = [(560, 560), (640, 580), (740, 600), (640, 620), (740, 640)]
for px, py in positions:
    print(f"[r] trying Export Project at ({px},{py})", flush=True)
    click(px, py, 0.3); time.sleep(1.5)
    screenshot(f"{SS}\\r_try_{px}_{py}.png")
    # Check if Save dialog appeared
    save_found = False
    for w in Desktop(backend="uia").windows():
        try: n = w.element_info.name
        except: continue
        if 'Save' in (n or '') or 'file' in (n or '').lower():
            save_found = True
            print(f"[r] SAVE dialog found!", flush=True)
            break
    if save_found:
        # Click filename field, type name, Save
        click(570, 290, 0.3); time.sleep(0.4)
        subprocess.run(['powershell', '-Command',
            "Add-Type -AssemblyName System.Windows.Forms;"
            "[System.Windows.Forms.SendKeys]::SendWait('^a{DEL}test_export.apk{ENTER}')"], check=False)
        time.sleep(3)
        screenshot(f"{SS}\\r_after_save.png")
        # Take 60s of progress
        for i in range(30):
            screenshot(f"{SS}\\r_progress_{i:02d}.png")
            time.sleep(2)
        break
    # Close whatever opened with Escape, reopen if needed
    subprocess.run(['powershell', '-Command',
        "Add-Type -AssemblyName System.Windows.Forms;"
        "[System.Windows.Forms.SendKeys]::SendWait('{ESC}')"], check=False)
    time.sleep(0.5)

apk = os.path.join(PROJECT, "test_export.apk")
print(f"[r] APK: {os.path.exists(apk)} size={os.path.getsize(apk) if os.path.exists(apk) else 0}", flush=True)

try: app.kill()
except: pass
print("[r] done", flush=True)
