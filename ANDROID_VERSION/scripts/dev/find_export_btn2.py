"""Resize Export dialog to reveal hidden Export Project button."""
import time, os, subprocess
import ctypes
from pywinauto import Desktop, Application

PROJECT = r"D:\Projects\BOOKWAR\ANDROID_VERSION\test_project"
GODOT = r"D:\Godot\Godot_v4.6.3-stable_win64.exe"
SS = r"D:\Projects\BOOKWAR\ANDROID_VERSION\tests\e2e\screenshots"

user32 = ctypes.windll.user32

def click(x, y, delay=0.2):
    user32.SetCursorPos(x, y); time.sleep(delay)
    user32.mouse_event(0x0002, 0, 0, 0, 0); time.sleep(0.05)
    user32.mouse_event(0x0004, 0, 0, 0, 0); time.sleep(delay)

def drag(x1, y1, x2, y2, delay=0.2):
    user32.SetCursorPos(x1, y1); time.sleep(delay)
    user32.mouse_event(0x0002, 0, 0, 0, 0); time.sleep(0.1)
    # Move in steps
    steps = 20
    for i in range(steps + 1):
        x = x1 + (x2 - x1) * i // steps
        y = y1 + (y2 - y1) * i // steps
        user32.SetCursorPos(x, y)
        time.sleep(0.02)
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

print("[s] launching Godot...", flush=True)
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

# Restore window (not maximized) so dialog is more visible
user32.ShowWindow(hwnd, 9)  # SW_RESTORE
time.sleep(0.5)
# Now maximize again — should reset window state
user32.ShowWindow(hwnd, 3)
time.sleep(1)
user32.SetForegroundWindow(hwnd); time.sleep(0.5)

# Open Project menu, click Export
click(195, 85, 0.3); time.sleep(0.8)
click(195, 315, 0.3); time.sleep(2.5)
screenshot(f"{SS}\\s_export_open.png")

# Try scrolling within dialog using mouse wheel
print("[s] scrolling down inside dialog...", flush=True)
# Move mouse to center of dialog
user32.SetCursorPos(700, 500)
time.sleep(0.5)
# Scroll wheel down 10 times
for _ in range(10):
    user32.mouse_event(0x0800, 0, 0, -120, 0)  # WHEEL_SCROLL negative = down
    time.sleep(0.1)
time.sleep(1)
screenshot(f"{SS}\\s_after_scroll.png")

# Take wider screenshot at different positions to find button
# Mouse over bottom of dialog and screenshot
for y_probe in [800, 850, 900, 920, 940]:
    click(700, y_probe, 0.15)
    time.sleep(0.3)

screenshot(f"{SS}\\s_final.png")

print("[s] done", flush=True)
try: app.kill()
except: pass
