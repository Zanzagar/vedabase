"""rival.py ask-and-vanish SELECTION | take SELECTION SECONDS: another client
of the display, for tests/nudge.sh.

ask-and-vanish  asks the selection's owner for its TARGETS and destroys, in
                the same breath, the window the answer would go to, so the
                answer finds no window
take            owns the selection for SECONDS, then exits"""
import ctypes as C
import sys
import time

x = C.CDLL("libX11.so.6")
x.XOpenDisplay.restype = C.c_void_p
x.XOpenDisplay.argtypes = [C.c_char_p]
x.XDefaultRootWindow.restype = C.c_ulong
x.XDefaultRootWindow.argtypes = [C.c_void_p]
x.XInternAtom.restype = C.c_ulong
x.XInternAtom.argtypes = [C.c_void_p, C.c_char_p, C.c_int]
x.XCreateSimpleWindow.restype = C.c_ulong
x.XCreateSimpleWindow.argtypes = [C.c_void_p, C.c_ulong, C.c_int, C.c_int, C.c_uint, C.c_uint,
                                  C.c_uint, C.c_ulong, C.c_ulong]
x.XConvertSelection.argtypes = [C.c_void_p, C.c_ulong, C.c_ulong, C.c_ulong, C.c_ulong, C.c_ulong]
x.XDestroyWindow.argtypes = [C.c_void_p, C.c_ulong]
x.XSetSelectionOwner.argtypes = [C.c_void_p, C.c_ulong, C.c_ulong, C.c_ulong]
x.XSync.argtypes = [C.c_void_p, C.c_int]

d = x.XOpenDisplay(None)
if not d:
    sys.exit("rival.py: cannot open the display")
mode, selection = sys.argv[1], x.XInternAtom(d, sys.argv[2].encode(), 0)
win = x.XCreateSimpleWindow(d, x.XDefaultRootWindow(d), 0, 0, 1, 1, 0, 0, 0)
if mode == "ask-and-vanish":
    targets = x.XInternAtom(d, b"TARGETS", 0)
    x.XConvertSelection(d, selection, targets, targets, win, 0)
    x.XDestroyWindow(d, win)
    x.XSync(d, 0)
elif mode == "take":
    x.XSetSelectionOwner(d, selection, win, 0)
    x.XSync(d, 0)
    time.sleep(float(sys.argv[3]))
else:
    sys.exit("usage: rival.py ask-and-vanish SELECTION | take SELECTION SECONDS")
