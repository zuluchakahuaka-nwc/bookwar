"""Open Export dialog and capture error."""
import time, os, subprocess, sys
import ctypes
from ctypes import wintypes
from pywinauto import Desktop, Application

PROJECT = r"D:\Projects\BOOKWAR\ANDROID_VERSION\test_project"
GODOT = r"D:\Godot\Godot_v4.6.3-stable_win64.exe"
SS = r"D:\Projects\BOOKWAR\ANDROID_VERSION\tests\e2e\screenshots"

user32 = ctypes.windll.user32

def click(x, y, delay=0.2):
    user32.SetCursorPos(x, y)
    time.sleep(delay)
    user32.mouse_event(0x0002, 0, 0, 0, 0)
    time.sleep(0.05)
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

print("[e] launching Godot...", flush=True)
app = Application().start(f'"{GODOT}" --path "{PROJECT}" --editor', timeout=60)
time.sleep(13)

hwnd = 0
for i in range(20):
    for w in Desktop(backend="uia").windows():
        try:
            if w.element_info.class_name == 'Engine' and w.element_info.name == 'Godot Engine':
                hwnd = w.element_info.handle
                break
        except: pass
    if hwnd: break
    time.sleep(0.5)

print(f"[e] hwnd={hwnd}", flush=True)
user32.ShowWindow(hwnd, 3)
time.sleep(1)
user32.SetForegroundWindow(hwnd)
time.sleep(0.5)

screenshot(f"{SS}\\export_step0_initial.png")

# Open Project menu
print("[e] opening Project menu...", flush=True)
click(195, 85, 0.3)
time.sleep(0.8)

# Per OCR: 'Export...' at X=115, Y=315 on screenshot
# Use center of item which is right of X=115, so click at X=195
print("[e] clicking Export at (195, 315)...", flush=True)
click(195, 315, 0.3)
time.sleep(2.5)

screenshot(f"{SS}\\export_step_final.png")

# Try scrolling within Export dialog to see errors, also wait
time.sleep(2)
screenshot(f"{SS}\\export_step_final2.png")

print("[e] done", flush=True)
try: app.kill()
except: pass
