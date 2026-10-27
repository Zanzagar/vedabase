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
  x11-nudge.py every N   nudge every N seconds until the display goes away,
                         unless another does so already (then exit 0 at once)
  x11-nudge.py running   exit 0 if one does so on this display, 3 if none does

One 'every' per X server: once its first nudge has gone through, it owns the
selection _VEDABASE_NUDGER, which the server frees when either goes away (the
ICCCM's manager selections work so). A new server, even under the number of
an old one, starts with no owner.

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


class Request(C.Structure):  # XSelectionRequestEvent
    _fields_ = [("type", C.c_int), ("serial", C.c_ulong), ("send_event", C.c_int),
                ("display", C.c_void_p), ("owner", C.c_ulong), ("requestor", C.c_ulong),
                ("selection", C.c_ulong), ("target", C.c_ulong), ("property", C.c_ulong),
                ("time", C.c_ulong)]


class Reply(C.Structure):  # XSelectionEvent
    _fields_ = [("type", C.c_int), ("serial", C.c_ulong), ("send_event", C.c_int),
                ("display", C.c_void_p), ("requestor", C.c_ulong), ("selection", C.c_ulong),
                ("target", C.c_ulong), ("property", C.c_ulong), ("time", C.c_ulong)]


class XEvent(C.Union):
    _fields_ = [("type", C.c_int), ("fixes", SelectionNotify), ("request", Request),
                ("reply", Reply), ("pad", C.c_long * 24)]


if not (sys.argv[1:] in (["once"], ["running"]) or (len(sys.argv) == 3 and sys.argv[1] == "every")):
    print("usage: x11-nudge.py once | every SECONDS | running", file=sys.stderr)
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
x.XCreateSimpleWindow.restype = C.c_ulong
x.XCreateSimpleWindow.argtypes = [C.c_void_p, C.c_ulong, C.c_int, C.c_int, C.c_uint, C.c_uint,
                                  C.c_uint, C.c_ulong, C.c_ulong]
x.XGetSelectionOwner.restype = C.c_ulong
x.XGetSelectionOwner.argtypes = [C.c_void_p, C.c_ulong]
x.XSetSelectionOwner.argtypes = [C.c_void_p, C.c_ulong, C.c_ulong, C.c_ulong]
x.XSendEvent.argtypes = [C.c_void_p, C.c_ulong, C.c_int, C.c_long, C.POINTER(XEvent)]
x.XFlush.argtypes = [C.c_void_p]
x.XPending.argtypes = [C.c_void_p]
x.XNextEvent.argtypes = [C.c_void_p, C.POINTER(XEvent)]
x.XConnectionNumber.argtypes = [C.c_void_p]

ERROR_HANDLER = C.CFUNCTYPE(C.c_int, C.c_void_p, C.c_void_p)


@ERROR_HANDLER
def ignore_error(_display, _error):
    # A requestor whose window is gone before our refusal arrives must not end
    # us, as Xlib's own handler would. Losing the server is not an error here:
    # Xlib's I/O error handler still ends the process then.
    return 0


x.XSetErrorHandler(ignore_error)
d = x.XOpenDisplay(None)
if not d:
    sys.exit(1)
root = x.XDefaultRootWindow(d)
fd = x.XConnectionNumber(d)
prop = x.XInternAtom(d, b"_VEDABASE_NUDGE", 0)
nudger = x.XInternAtom(d, b"_VEDABASE_NUDGER", 0)
ev = XEvent()


def nudge():
    x.XChangeProperty(d, root, prop, 31, 8, 0, b"1", 1)  # XA_STRING, PropModeReplace
    x.XFlush(d)


if sys.argv[1] == "running":
    sys.exit(0 if x.XGetSelectionOwner(d, nudger) else 3)

if sys.argv[1] == "every":
    period = float(sys.argv[2])
    if x.XGetSelectionOwner(d, nudger):
        sys.exit(0)
    win = x.XCreateSimpleWindow(d, root, 0, 0, 1, 1, 0, 0, 0)
    nudge()
    x.XSetSelectionOwner(d, nudger, win, 0)  # CurrentTime
    if x.XGetSelectionOwner(d, nudger) != win:  # a round trip: another came first
        sys.exit(0)
    due = time.monotonic() + period
    while True:
        # Events first, every time round: a flush can read them into Xlib's
        # queue, where the socket no longer shows them. XPending also reads
        # what came, and when the server has gone, Xlib ends this process.
        while x.XPending(d):
            x.XNextEvent(d, C.byref(ev))
            if ev.type == 29:  # SelectionClear: another took over
                sys.exit(0)
            if ev.type == 30:  # SelectionRequest: there is nothing to give
                req = ev.request
                out = XEvent()
                out.reply.type, out.reply.display, out.reply.requestor = 31, d, req.requestor
                out.reply.selection, out.reply.target, out.reply.time = req.selection, req.target, req.time
                x.XSendEvent(d, req.requestor, 0, 0, C.byref(out))
                x.XFlush(d)
        left = due - time.monotonic()
        if left <= 0:
            nudge()
            due = time.monotonic() + period
        else:
            # Readable when an event comes (one that every client gets, such
            # as MappingNotify, or one for the selection), or the server goes.
            select.select([fd], [], [], left)

# once: watch for a new owner before nudging, so that it cannot come unseen.
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
        if ev.type == event_base.value and ev.fixes.owner:
            sys.exit(0)
    left = end - time.monotonic()
    if left <= 0:
        sys.exit(3)
    select.select([fd], [], [], left)
