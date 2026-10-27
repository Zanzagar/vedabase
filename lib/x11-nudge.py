"""x11-nudge.py: get a copy made in Folio onto the X clipboard under Wine 11.0.

Wine 11.0 claims the X clipboard for a copy without sending the claim: its
acquire_selection() (dlls/winex11.drv/clipboard.c) leaves the request in
Xlib's buffer, and win32u 11.0 flushes a thread's X connection only when an
X event arrives for it (process_driver_events, dlls/win32u/message.c), where
10.0 flushed it on every wait. Until then the clipboard holds what it held
before the copy, and a read goes to Wine's window for the previous copy,
which refuses it (xclip then falls back to Latin-1 text). A window manager
changes the root window's properties on every change of focus, which wakes
Wine, so on a desktop a paste into another program normally works; in the
browser viewer, with no window manager, nothing does. Every Wine thread
watches the root window's properties, so changing one wakes them all. Wine
11.14 fixed this upstream (a33000a6, "winex11.drv: Flush display in
acquire_selection()"); with a Wine that has it, this is not needed.

  x11-nudge.py once      nudge, then wait up to half a second for a new owner
                         of the clipboard (there is one if a claim was waiting):
                         exit 0 if one came, 3 if none did
  x11-nudge.py every N   nudge every N seconds until the display goes away

Exit 1: no display; 2: usage. Uses $DISPLAY and $XAUTHORITY."""
import ctypes as C
import select
import sys
import time


class SelectionNotify(C.Structure):  # XFixesSelectionNotifyEvent
    _fields_ = [("type", C.c_int), ("serial", C.c_ulong), ("send_event", C.c_int),
                ("display", C.c_void_p), ("window", C.c_ulong), ("subtype", C.c_int),
                ("owner", C.c_ulong), ("selection", C.c_ulong), ("timestamp", C.c_ulong),
                ("selection_timestamp", C.c_ulong)]


class XEvent(C.Union):
    _fields_ = [("type", C.c_int), ("selection", SelectionNotify), ("pad", C.c_long * 24)]


if not (sys.argv[1:] == ["once"] or (len(sys.argv) == 3 and sys.argv[1] == "every")):
    print("usage: x11-nudge.py once | every SECONDS", file=sys.stderr)
    sys.exit(2)
x = C.CDLL("libX11.so.6")
x.XOpenDisplay.restype = C.c_void_p
x.XOpenDisplay.argtypes = [C.c_char_p]
x.XDefaultRootWindow.restype = C.c_ulong
x.XDefaultRootWindow.argtypes = [C.c_void_p]
x.XInternAtom.restype = C.c_ulong
x.XInternAtom.argtypes = [C.c_void_p, C.c_char_p, C.c_int]
x.XChangeProperty.argtypes = [C.c_void_p, C.c_ulong, C.c_ulong, C.c_ulong, C.c_int, C.c_int,
                              C.c_char_p, C.c_int]
x.XFlush.argtypes = [C.c_void_p]
x.XPending.argtypes = [C.c_void_p]
x.XNextEvent.argtypes = [C.c_void_p, C.POINTER(XEvent)]
x.XConnectionNumber.argtypes = [C.c_void_p]

d = x.XOpenDisplay(None)
if not d:
    sys.exit(1)
root = x.XDefaultRootWindow(d)
fd = x.XConnectionNumber(d)
prop = x.XInternAtom(d, b"_VEDABASE_NUDGE", 0)
ev = XEvent()


def nudge():
    x.XChangeProperty(d, root, prop, 31, 8, 0, b"1", 1)  # XA_STRING, PropModeReplace
    x.XFlush(d)


if sys.argv[1] == "every":
    period = float(sys.argv[2])
    while True:
        nudge()
        # Readable when an event comes that every client gets (MappingNotify),
        # or when the server goes away: Xlib then ends this process.
        if select.select([fd], [], [], period)[0]:
            while x.XPending(d):
                x.XNextEvent(d, C.byref(ev))

# Watch for a new owner before nudging, so that it cannot come unseen.
event_base = C.c_int()
try:
    xf = C.CDLL("libXfixes.so.3")
    xf.XFixesQueryExtension.argtypes = [C.c_void_p, C.POINTER(C.c_int), C.POINTER(C.c_int)]
    xf.XFixesSelectSelectionInput.argtypes = [C.c_void_p, C.c_ulong, C.c_ulong, C.c_ulong]
    watching = bool(xf.XFixesQueryExtension(d, C.byref(event_base), C.byref(C.c_int())))
except OSError:
    watching = False
if watching:
    xf.XFixesSelectSelectionInput(d, root, x.XInternAtom(d, b"CLIPBOARD", 0), 1)  # SetSelectionOwner
nudge()
if not watching:
    time.sleep(0.2)
    sys.exit(3)
end = time.monotonic() + 0.5
while True:
    while x.XPending(d):
        x.XNextEvent(d, C.byref(ev))
        if ev.type == event_base.value and ev.selection.owner:
            sys.exit(0)
    left = end - time.monotonic()
    if left <= 0:
        sys.exit(3)
    select.select([fd], [], [], left)
