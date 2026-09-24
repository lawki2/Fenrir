import QtQuick
import Quickshell
import Caelestia.Config
import qs.services
import qs.modules.welcome

Scope {
    Component.onCompleted: {
        // Force certain singletons to load on shell init instead of lazily

        IdleInhibitor;
        GameMode;
        Notifs;
        Players;
        Brightness;
        Weather.reload();

        // Fenrir: night light's schedule, update checks and the first-login welcome run on their own.
        NightLight;
        Updates;
        Welcome;

        if (GlobalConfig.utilities.vpn.enabled)
            VPN;
    }
}
