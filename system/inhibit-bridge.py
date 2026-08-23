#!/usr/bin/env python3
"""D-Bus idle-inhibit bridge for quickshell-bar.

Quickshell can consume D-Bus services but cannot *provide* one -- every
D-Bus module it ships (Mpris, Notifications, SystemTray, UPower, Polkit,
DBusMenu) is a client implemented C++-side, and there is no generic export
API. So the shell cannot answer an inhibit request itself, and this small
helper does it instead.

Why it is needed at all
-----------------------
IdleMonitor's `respectInhibitors` honours the Wayland idle-inhibit-v1
protocol, which covers apps that take a compositor-level inhibitor. It does
NOT cover the much older D-Bus route, which is what most browsers actually
use for windowed video -- Firefox-family browsers only take the Wayland
inhibitor when the video is fullscreen. hypridle and Plasma's powerdevil
both own these names; when hypridle was removed the names became unowned,
inhibit requests failed silently, and the session locked during playback.

Names and paths
---------------
`/ScreenSaver` is not a typo and not redundant. It is the legacy path, and
it is the one Firefox-family browsers actually call -- their libxul
contains `/ScreenSaver` but not `/org/freedesktop/ScreenSaver`. Exporting
only the canonical path acquires the name, looks healthy, and still misses
the exact caller this exists for. hypridle exports both; so do we.

Output protocol
---------------
One JSON line per state change on stdout, flushed immediately:

    {"count": 1, "holders": ["zen: video playing"]}

The shell reads these with a SplitParser and suppresses its idle stages
while count > 0. An initial line is emitted at startup so the reader always
has a known state.
"""

import json
import os
import sys

try:
    import gi

    gi.require_version("Gio", "2.0")
    from gi.repository import Gio, GLib
except (ImportError, ValueError) as exc:  # pragma: no cover - environment guard
    # Exit 3 is the shell's signal to log once and stop retrying rather than
    # spin on a dependency that will not appear at runtime.
    print(
        "inhibit-bridge: PyGObject (python-gobject) is required: %s" % exc,
        file=sys.stderr,
    )
    sys.exit(3)


SCREENSAVER_NAME = "org.freedesktop.ScreenSaver"
# Canonical path second: some callers use it, but the legacy one is what
# Firefox-family browsers actually hit. Both are exported on the same name.
SCREENSAVER_PATHS = ("/ScreenSaver", "/org/freedesktop/ScreenSaver")

POWERMGMT_NAME = "org.freedesktop.PowerManagement.Inhibit"
POWERMGMT_PATHS = ("/org/freedesktop/PowerManagement/Inhibit",)

SCREENSAVER_XML = """
<node>
  <interface name='org.freedesktop.ScreenSaver'>
    <method name='Inhibit'>
      <arg type='s' name='application_name' direction='in'/>
      <arg type='s' name='reason_for_inhibit' direction='in'/>
      <arg type='u' name='cookie' direction='out'/>
    </method>
    <method name='UnInhibit'>
      <arg type='u' name='cookie' direction='in'/>
    </method>
    <method name='GetActive'>
      <arg type='b' name='active' direction='out'/>
    </method>
    <method name='SimulateUserActivity'/>
  </interface>
</node>
"""

POWERMGMT_XML = """
<node>
  <interface name='org.freedesktop.PowerManagement.Inhibit'>
    <method name='Inhibit'>
      <arg type='s' name='application_name' direction='in'/>
      <arg type='s' name='reason_for_inhibit' direction='in'/>
      <arg type='u' name='cookie' direction='out'/>
    </method>
    <method name='UnInhibit'>
      <arg type='u' name='cookie' direction='in'/>
    </method>
    <method name='HasInhibit'>
      <arg type='b' name='has_inhibit' direction='out'/>
    </method>
  </interface>
</node>
"""


class Registry:
    """Live inhibitors, keyed by cookie.

    Cookies are handed to callers and are the only handle they get back, so
    they must stay unique for the life of the process -- never reused, even
    after release, or a stale UnInhibit from a confused client would drop
    somebody else's inhibitor.
    """

    def __init__(self):
        self._next_cookie = 1
        self._by_cookie = {}
        self._last_emitted = None

    def add(self, sender, app, reason):
        cookie = self._next_cookie
        self._next_cookie += 1
        self._by_cookie[cookie] = {
            "sender": sender,
            "app": (app or "").strip() or "unknown",
            "reason": (reason or "").strip(),
        }
        self.emit()
        return cookie

    def remove(self, cookie, sender=None):
        entry = self._by_cookie.get(cookie)
        if entry is None:
            return False
        # A client may only release its own inhibitor. Without this check any
        # process on the bus could guess a small integer and un-inhibit
        # somebody else's playback.
        if sender is not None and entry["sender"] != sender:
            return False
        del self._by_cookie[cookie]
        self.emit()
        return True

    def drop_sender(self, sender):
        """Release everything held by a departed client.

        This is the difference between a working bridge and one that wedges
        the machine awake: a browser that crashes, or is killed, never sends
        UnInhibit. Without cleanup on disconnect its inhibitor would live
        until the shell restarts.
        """
        stale = [c for c, e in self._by_cookie.items() if e["sender"] == sender]
        if not stale:
            return
        for cookie in stale:
            del self._by_cookie[cookie]
        self.emit()

    def count(self):
        return len(self._by_cookie)

    def holders(self):
        out = []
        for entry in self._by_cookie.values():
            if entry["reason"]:
                out.append("%s: %s" % (entry["app"], entry["reason"]))
            else:
                out.append(entry["app"])
        return out

    def emit(self, force=False):
        payload = {"count": self.count(), "holders": self.holders()}
        line = json.dumps(payload, separators=(",", ":"), sort_keys=True)
        # Dedupe: two clients releasing in the same turn would otherwise emit
        # an identical line twice and churn the reader's bindings.
        if not force and line == self._last_emitted:
            return
        self._last_emitted = line
        print(line, flush=True)


registry = Registry()


def resolve_app(connection, sender):
    """Best-effort process name for a caller that did not name itself.

    Callers routed through xdg-desktop-portal arrive with an empty
    application_name -- the portal forwards the request without attributing
    it -- which would otherwise surface as a useless "unknown" in the
    shell's status output. Falling back to the sending process name at least
    says *which* program is keeping the machine awake.
    """
    try:
        reply = connection.call_sync(
            "org.freedesktop.DBus",
            "/org/freedesktop/DBus",
            "org.freedesktop.DBus",
            "GetConnectionUnixProcessID",
            GLib.Variant("(s)", (sender,)),
            GLib.VariantType("(u)"),
            Gio.DBusCallFlags.NONE,
            1000,
            None,
        )
        pid = reply.unpack()[0]
        # cmdline before comm: comm is capped at 15 bytes by the kernel, so
        # "xdg-desktop-portal-gtk" arrives as "xdg-desktop-por".
        try:
            with open("/proc/%d/cmdline" % pid, "rb") as handle:
                argv0 = handle.read().split(b"\0")[0].decode("utf-8", "replace")
            if argv0:
                return os.path.basename(argv0)
        except OSError:
            pass
        with open("/proc/%d/comm" % pid, "r") as handle:
            return handle.read().strip()
    except Exception:
        # Caller already gone, /proc unreadable, or the bus was slow. Not
        # worth failing an inhibit over a cosmetic label.
        return ""


def handle_method_call(
    connection, sender, _path, interface_name, method_name, parameters, invocation
):
    if method_name == "Inhibit":
        app, reason = parameters.unpack()
        if not (app or "").strip():
            app = resolve_app(connection, sender)
        cookie = registry.add(sender, app, reason)
        invocation.return_value(GLib.Variant("(u)", (cookie,)))
        return

    if method_name == "UnInhibit":
        (cookie,) = parameters.unpack()
        registry.remove(cookie, sender)
        invocation.return_value(None)
        return

    if method_name == "GetActive":
        # "Is the screensaver active", not "is it inhibited". We never blank
        # via this interface, so this is always false.
        invocation.return_value(GLib.Variant("(b)", (False,)))
        return

    if method_name == "HasInhibit":
        invocation.return_value(GLib.Variant("(b)", (registry.count() > 0,)))
        return

    if method_name == "SimulateUserActivity":
        # Accepted and ignored. Faking input to reset the idle timer would
        # need the compositor's cooperation, and the callers that use this
        # (mostly media players) already hold a real inhibitor.
        invocation.return_value(None)
        return

    invocation.return_dbus_error(
        "org.freedesktop.DBus.Error.UnknownMethod",
        "%s.%s is not implemented" % (interface_name, method_name),
    )


def register_paths(connection, xml, paths):
    node = Gio.DBusNodeInfo.new_for_xml(xml)
    interface = node.interfaces[0]
    # register_object() is deprecated in PyGObject 3.56 and warns on stderr,
    # which the shell would faithfully log on every startup. The closures
    # variant is the supported spelling and takes a plain callable; fall back
    # for older PyGObject where it does not exist.
    register = getattr(connection, "register_object_with_closures2", None)
    if register is None:  # pragma: no cover - older PyGObject
        register = connection.register_object
    for path in paths:
        register(path, interface, handle_method_call, None, None)


def main():
    loop = GLib.MainLoop()
    bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)

    register_paths(bus, SCREENSAVER_XML, SCREENSAVER_PATHS)
    register_paths(bus, POWERMGMT_XML, POWERMGMT_PATHS)

    # Release a client's inhibitors the moment it drops off the bus.
    def on_name_owner_changed(
        _conn, _sender, _path, _iface, _signal, params, *_user
    ):
        name, _old_owner, new_owner = params.unpack()
        # Unique names only (":1.42"); well-known names churn for unrelated
        # reasons and are never recorded as a cookie's sender.
        if name.startswith(":") and new_owner == "":
            registry.drop_sender(name)

    bus.signal_subscribe(
        "org.freedesktop.DBus",
        "org.freedesktop.DBus",
        "NameOwnerChanged",
        "/org/freedesktop/DBus",
        None,
        Gio.DBusSignalFlags.NONE,
        on_name_owner_changed,
        None,
    )

    def on_name_lost(_connection, name):
        # Something else owns it -- most likely a desktop environment's own
        # power manager. Say so and keep running: the other name may still be
        # ours, and the shell keeps Wayland-level inhibits either way.
        print(
            "inhibit-bridge: could not acquire %s (already owned)" % name,
            file=sys.stderr,
            flush=True,
        )

    for name in (SCREENSAVER_NAME, POWERMGMT_NAME):
        Gio.bus_own_name(
            Gio.BusType.SESSION,
            name,
            Gio.BusNameOwnerFlags.NONE,
            None,
            None,
            on_name_lost,
        )

    # Emit a baseline so the reader starts from a known state rather than
    # waiting for the first inhibit to learn the count is zero.
    registry.emit(force=True)
    loop.run()


if __name__ == "__main__":
    main()
