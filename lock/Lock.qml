// Lock.qml
// Top-level WlSessionLock instance. Singleton-instantiated by shell.qml
// (NOT inside a Variants block — WlSessionLock is itself per-shell;
// per-screen surfaces fan out via the `surface` Component).
//
// Lock state lives in LockService (singleton) so the lock is fully
// reactive and survives shell hot-reload (WlSessionLock inherits Reloadable).

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.lock

WlSessionLock {
    id: sessionLock

    // Reactive: any change to LockService.locked drives the protocol-level
    // lock/unlock. PAM-Success in LockService sets locked=false → here flips
    // to false → compositor releases the screens.
    locked: LockService.locked

    // Quickshell instantiates this Component once per ShellScreen and hands
    // it the screen reference automatically. We use LockSurface (separate
    // file) so the per-screen UI is independently editable / hot-reloadable.
    surface: Component {
        LockSurface { }
    }

    // Surface a confirmation log when the compositor reports all outputs
    // covered (useful when debugging missed-screen scenarios).
    onSecureChanged: {
        if (sessionLock.locked && sessionLock.secure) {
            console.log("[Lock] all screens covered — secure=true");
        }
    }
}
