"""Click Export button and capture result."""
import time, os, subprocess, sys
import ctypes
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

print("[x] launching Godot...", flush=True)
app = Application().start(f'"{GODOT}" --path "{PROJECT}" --editor', timeout=60)
time.sleep(13)

hwnd = 0
for i in range(20):
    for w in Desktop(backend="uia").windows():
        try:
            if w.element_info.class_name == 'Engine' and w.element_info.name == 'Godot Engine':
                hwnd = w.element_info.handle; break
        except: pass
    if hwnd: break
    time.sleep(0.5)

print(f"[x] hwnd={hwnd}", flush=True)
user32.ShowWindow(hwnd, 3); time.sleep(1)
user32.SetForegroundWindow(hwnd); time.sleep(0.5)

# Open Project menu
click(195, 85, 0.3); time.sleep(0.8)
# Click Export... item
click(195, 315, 0.3); time.sleep(2.5)
screenshot(f"{SS}\\x_step1_export_dialog.png")

# Click Export Project button at (426, 435)
print("[x] clicking Export Project button (426, 435)...", flush=True)
click(426, 435, 0.3); time.sleep(2.5)
screenshot(f"{SS}\\x_step2_after_export_click.png")

# Maybe save dialog appeared. Take multiple screenshots during build
for i in range(15):
    time.sleep(2)
    screenshot(f"{SS}\\x_step3_{i:02d}.png")

print("[x] done", flush=True)
try: app.kill()
except: pass
