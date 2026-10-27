"""lazy-owner.py TEXT [--refusing-old]: take the X clipboard the way Wine 11.0
does for a copy made in Folio, for tests/unicode.sh.

Wine queues its claim on the clipboard without sending it, and the claim goes
out only when the next X event arrives for that connection (lib/x11-nudge.py
says why). This does the same: it watches the root window's properties, as
every Wine thread does, queues the claim, and sleeps until its connection has
something to read. From then on it serves TEXT as UTF8_STRING and, in
Latin-1, as STRING, as Wine does, until another program takes the clipboard
or 60 s pass. It prints "ready" once it is watching and the claim is queued.

With --refusing-old it first owns the clipboard (sent at once) with a window
that refuses every request, as Wine's window for the previous copy does once
a new claim is queued; the queued claim destroys that window first, as Wine's
acquire_selection() does."""
import ctypes as C
import select
import sys
import time

text = sys.argv[1]
refusing_old = sys.argv[2:] == ["--refusing-old"]
x = C.CDLL("libX11.so.6")
Window = Atom = C.c_ulong


class Request(C.Structure):  # XSelectionRequestEvent
    _fields_ = [("type", C.c_int), ("serial", C.c_ulong), ("send_event", C.c_int),
                ("display", C.c_void_p), ("owner", Window), ("requestor", Window),
                ("selection", Atom), ("target", Atom), ("property", Atom), ("time", C.c_ulong)]


class Notify(C.Structure):  # XSelectionEvent
    _fields_ = [("type", C.c_int), ("serial", C.c_ulong), ("send_event", C.c_int),
                ("display", C.c_void_p), ("requestor", Window), ("selection", Atom),
                ("target", Atom), ("property", Atom), ("time", C.c_ulong)]


class Clear(C.Structure):  # XSelectionClearEvent
    _fields_ = [("type", C.c_int), ("serial", C.c_ulong), ("send_event", C.c_int),
                ("display", C.c_void_p), ("window", Window), ("selection", Atom), ("time", C.c_ulong)]


class XEvent(C.Union):
    _fields_ = [("type", C.c_int), ("request", Request), ("notify", Notify), ("clear", Clear),
                ("pad", C.c_long * 24)]


x.XOpenDisplay.restype = C.c_void_p
x.XOpenDisplay.argtypes = [C.c_char_p]
x.XDefaultRootWindow.restype = Window
x.XDefaultRootWindow.argtypes = [C.c_void_p]
x.XInternAtom.restype = Atom
x.XInternAtom.argtypes = [C.c_void_p, C.c_char_p, C.c_int]
x.XCreateSimpleWindow.restype = Window
x.XCreateSimpleWindow.argtypes = [C.c_void_p, Window, C.c_int, C.c_int, C.c_uint, C.c_uint,
                                  C.c_uint, C.c_ulong, C.c_ulong]
x.XDestroyWindow.argtypes = [C.c_void_p, Window]
x.XSelectInput.argtypes = [C.c_void_p, Window, C.c_long]
x.XSetSelectionOwner.argtypes = [C.c_void_p, Atom, Window, C.c_ulong]
x.XChangeProperty.argtypes = [C.c_void_p, Window, Atom, Atom, C.c_int, C.c_int, C.c_void_p, C.c_int]
x.XSendEvent.argtypes = [C.c_void_p, Window, C.c_int, C.c_long, C.POINTER(XEvent)]
x.XSync.argtypes = [C.c_void_p, C.c_int]
x.XPending.argtypes = [C.c_void_p]
x.XNextEvent.argtypes = [C.c_void_p, C.POINTER(XEvent)]
x.XConnectionNumber.argtypes = [C.c_void_p]

d = x.XOpenDisplay(None)
if not d:
    sys.exit("lazy-owner.py: cannot open the display")
root = x.XDefaultRootWindow(d)
CLIPBOARD, TARGETS, UTF8_STRING = (x.XInternAtom(d, n, 0) for n in (b"CLIPBOARD", b"TARGETS", b"UTF8_STRING"))
XA_ATOM, XA_STRING = 4, 31
x.XSelectInput(d, root, 1 << 22)  # PropertyChangeMask, as every Wine thread's connection
old = 0
if refusing_old:
    old = x.XCreateSimpleWindow(d, root, 0, 0, 1, 1, 0, 0, 0)
    x.XSetSelectionOwner(d, CLIPBOARD, old, 0)
x.XSync(d, 0)
# The claim, queued in Xlib's buffer and not sent: no Xlib call until an
# event arrives (select() is not one), as in Wine 11.0.
if old:
    x.XDestroyWindow(d, old)
new = x.XCreateSimpleWindow(d, root, 0, 0, 1, 1, 0, 0, 0)
x.XSetSelectionOwner(d, CLIPBOARD, new, 0)
print("ready", flush=True)
fd = x.XConnectionNumber(d)
end = time.monotonic() + 60
select.select([fd], [], [], 60)


def reply(req):
    prop = req.property or req.target  # property None: an obsolete client
    if req.owner != new:
        prop = 0  # the previous copy's window refuses
    elif req.target == TARGETS:
        atoms = (C.c_ulong * 3)(TARGETS, UTF8_STRING, XA_STRING)
        x.XChangeProperty(d, req.requestor, prop, XA_ATOM, 32, 0, atoms, 3)
    elif req.target in (UTF8_STRING, XA_STRING):
        data = text.encode("utf-8" if req.target == UTF8_STRING else "latin-1", "replace")
        x.XChangeProperty(d, req.requestor, prop, req.target, 8, 0, data, len(data))
    else:
        prop = 0
    ev = XEvent()
    ev.notify.type, ev.notify.display, ev.notify.requestor = 31, d, req.requestor  # SelectionNotify
    ev.notify.selection, ev.notify.target, ev.notify.property, ev.notify.time = (
        req.selection, req.target, prop, req.time)
    x.XSendEvent(d, req.requestor, 0, 0, C.byref(ev))


ev = XEvent()
while time.monotonic() < end:
    while x.XPending(d):  # flushes the claim, then reads what came
        x.XNextEvent(d, C.byref(ev))
        if ev.type == 30:  # SelectionRequest
            reply(ev.request)
        elif ev.type == 29 and ev.clear.window == new:  # SelectionClear: another took it
            sys.exit(0)
    x.XSync(d, 0)
    select.select([fd], [], [], 0.5)
