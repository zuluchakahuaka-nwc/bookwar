"""Click Export Project button at confirmed (640, 510) and observe build."""
import time, os, subprocess
import ctypes
from pywinauto import Desktop, Application

PROJECT = r"D:\Projects\BOOKWAR\ANDROID_VERSION\test_project"
GODOT = r"D:\Godot\Godot_v4.6.3-stable_win64.exe"
SS = r"D:\Projects\BOOKWAR\ANDROID_VERSION\tests\e2e\screenshots"

user32 = ctypes.windll.user32

def click(x, y, delay=0.25):
    user32.SetCursorPos(x, y)
    time.sleep(delay)
    user32.mouse_event(0x0002, 0, 0, 0, 0)
    time.sleep(0.06)
    user32.mouse_event(0x0004, 0, 0, 0, 0)
    time.sleep(delay)

def screenshot(path):
    subprocess.run(['powershell', '-Command',
        f'Add-Type -AssemblyName System.Windows.Forms,System.Drawing;'
        f'$b=[System.Windows.Forms.Screen]::PrimaryScreen.Bounds;'
        f'$bmp=New-Object System.Drawing.Bitmap($b.Width,$b.Height);'
        f'$g=[System.Drawing.Graphics]::FromImage($bmp);'
        f'$g.CopyFromScreen($b.Location,[System.Drawing.Point]::Empty,$b.Size);'
        f'$bmp.Save(\'{path}\',[System.Drawing.Imaging.ImageFormat]::Png);'
        f'$bmp.Dispose()'], check=False)

print("[u] launching Godot...", flush=True)
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

print(f"[u] hwnd={hwnd}", flush=True)
user32.ShowWindow(hwnd, 3); time.sleep(1)
user32.SetForegroundWindow(hwnd); time.sleep(0.5)

# Open Project menu
click(195, 85, 0.3); time.sleep(0.8)
# Click Export item in dropdown
click(195, 315, 0.3); time.sleep(2.5)
screenshot(f"{SS}\\ui_step1_export_dialog.png")

# Click Export Project button (icon) at (640, 510)
print("[u] clicking Export Project button at (640, 510)...", flush=True)
click(640, 510, 0.4); time.sleep(2)
screenshot(f"{SS}\\ui_step2_after_export_btn.png")

# Save dialog appears. Click filename field at (570, 290)
print("[u] clicking filename field (570, 290)...", flush=True)
click(570, 290, 0.3); time.sleep(0.5)
# Select all + delete
subprocess.run(['powershell', '-Command',
    "Add-Type -AssemblyName System.Windows.Forms;"
    "[System.Windows.Forms.SendKeys]::SendWait('^a{DEL}')"], check=False)
time.sleep(0.3)
# Type filename
subprocess.run(['powershell', '-Command',
    "Add-Type -AssemblyName System.Windows.Forms;"
    "[System.Windows.Forms.SendKeys]::SendWait('test_export.apk')"], check=False)
time.sleep(0.5)
# Enter to save
subprocess.run(['powershell', '-Command',
    "Add-Type -AssemblyName System.Windows.Forms;"
    "[System.Windows.Forms.SendKeys]::SendWait('{ENTER}')"], check=False)
time.sleep(3)
screenshot(f"{SS}\\ui_step2b_after_save.png")

# Take progress screenshots for 90s
for i in range(45):
    screenshot(f"{SS}\\ui_step3_{i:02d}.png")
    time.sleep(2)

# Check APK (Godot saves relative to project, in res://)
apk_default = os.path.join(PROJECT, "test_export.apk")
print(f"[u] APK exists: {os.path.exists(apk_default)}", flush=True)
if os.path.exists(apk_default):
    print(f"[u] APK size: {os.path.getsize(apk_default)}", flush=True)

try: app.kill()
except: pass
print("[u] done", flush=True)
