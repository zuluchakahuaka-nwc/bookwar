"""Mouse-click based Godot automation. Find Project menu by pixel position."""
import time, os, subprocess, sys
import pywinauto
from pywinauto import Desktop, Application
import ctypes
from ctypes import wintypes

PROJECT = r"D:\Projects\BOOKWAR\ANDROID_VERSION\test_project"
GODOT = r"D:\Godot\Godot_v4.6.3-stable_win64.exe"
SS = r"D:\Projects\BOOKWAR\ANDROID_VERSION\tests\e2e\screenshots"

user32 = ctypes.windll.user32

def click(x, y, delay=0.15):
    user32.SetCursorPos(x, y)
    time.sleep(delay)
    user32.mouse_event(0x0002, 0, 0, 0, 0)  # LEFTDOWN
    time.sleep(0.05)
    user32.mouse_event(0x0004, 0, 0, 0, 0)  # LEFTUP
    time.sleep(delay)

def get_window_rect(hwnd):
    rect = wintypes.RECT()
    user32.GetWindowRect(hwnd, ctypes.byref(rect))
    return rect.left, rect.top, rect.right, rect.bottom

def screenshot(path):
    subprocess.run(['powershell', '-Command',
        f'Add-Type -AssemblyName System.Windows.Forms,System.Drawing;'
        f'$b=[System.Windows.Forms.Screen]::PrimaryScreen.Bounds;'
        f'$bmp=New-Object System.Drawing.Bitmap($b.Width,$b.Height);'
        f'$g=[System.Drawing.Graphics]::FromImage($bmp);'
        f'$g.CopyFromScreen($b.Location,[System.Drawing.Point]::Empty,$b.Size);'
        f'$bmp.Save(\'{path}\',[System.Drawing.Imaging.ImageFormat]::Png);'
        f'$bmp.Dispose()'], check=False)

print("[m] launching Godot...", flush=True)
app = Application().start(f'"{GODOT}" --path "{PROJECT}" --editor', timeout=60)
time.sleep(13)

# Find Godot hwnd
hwnd = 0
for i in range(20):
    for w in Desktop(backend="uia").windows():
        try:
            cn = w.element_info.class_name
            n = w.element_info.name
            if cn == 'Engine' and n == 'Godot Engine':
                hwnd = w.element_info.handle
                break
        except: pass
    if hwnd: break
    time.sleep(0.5)

if not hwnd:
    print("[m] no hwnd", flush=True); app.kill(); sys.exit(1)

print(f"[m] hwnd={hwnd}", flush=True)

# Maximize window (3 = SW_MAXIMIZE)
user32.ShowWindow(hwnd, 3)
time.sleep(1)
user32.SetForegroundWindow(hwnd)
time.sleep(0.5)

l, t, r, b = get_window_rect(hwnd)
print(f"[m] window rect: L={l} T={t} R={r} B={b}", flush=True)

screenshot(f"{SS}\\mouse_step0_initial.png")

# Scene opened at (90,85). Project is right of Scene, probably x=180-220.
menu_y = 85  # absolute screen Y for menu bar
proj_x = 195  # absolute screen X for Project menu

print(f"[m] clicking Project menu at ({proj_x}, {menu_y})", flush=True)
click(proj_x, menu_y, 0.3)
time.sleep(1.0)

screenshot(f"{SS}\\mouse_step1_project_open.png")

# DOWN x6 selects Install Android Build Template (6th item, after Project Settings/Find/Version/Export/Pack ZIP/Install)
print("[m] keyboard DOWN x6 + ENTER for Install Android Build Template", flush=True)
subprocess.run(['powershell', '-Command',
    "Add-Type -AssemblyName System.Windows.Forms;"
    "[System.Windows.Forms.SendKeys]::SendWait('{DOWN}{DOWN}{DOWN}{DOWN}{DOWN}{DOWN}~')"], check=False)
time.sleep(2.5)

screenshot(f"{SS}\\mouse_step2_install_click.png")

# If a confirm dialog appears (Install/Yes), try to click it
print("[m] trying to confirm dialog...", flush=True)
for keys in ['%y', '%i', '~', '%y']:
    subprocess.run(['powershell', '-Command',
        f'Add-Type -AssemblyName System.Windows.Forms;'
        f'[System.Windows.Forms.SendKeys]::SendWait(\'{keys}\')'], check=False)
    time.sleep(1.0)
    if os.path.exists(os.path.join(PROJECT, 'android', 'build')):
        break

screenshot(f"{SS}\\mouse_step3_confirm.png")

# If dialog appeared, click Yes (default position center screen)
# Godot dialogs: Yes button typically bottom-right
# Try multiple confirmations via keyboard Enter
import pywinauto.timings
time.sleep(0.5)

# Press Enter to confirm
subprocess.run(['powershell', '-Command',
    "Add-Type -AssemblyName System.Windows.Forms;"
    "[System.Windows.Forms.SendKeys]::SendWait('~')"], check=False)
time.sleep(0.5)
# Press Alt+Y for Yes
subprocess.run(['powershell', '-Command',
    "Add-Type -AssemblyName System.Windows.Forms;"
    "[System.Windows.Forms.SendKeys]::SendWait('%y')"], check=False)
time.sleep(3)

screenshot(f"{SS}\\mouse_step3_after_confirm.png")

build_dir = os.path.join(PROJECT, 'android', 'build')
print(f"[m] android/build exists: {os.path.exists(build_dir)}", flush=True)

try: app.kill()
except: pass

print("[m] done", flush=True)
