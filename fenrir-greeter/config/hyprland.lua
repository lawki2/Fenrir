-- Compositor for the login screen only. Deliberately bare: no bar, no
-- animations, nothing that has to load before someone can type a password.
-- Lua rather than hyprlang to match the rest of Fenrir's Hyprland config.
package.path = package.path .. ";/etc/greetd/?.lua"

hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = 1,
})

-- Written by the installer from the layout chosen during setup, same shape as
-- caelestia's hypr-vars.lua. Without it the greeter is always us, and anyone
-- on another layout mistypes their password with no way to see why.
local ok, layout = pcall(require, "layout")
if not ok or type(layout) ~= "table" then
    layout = {}
end

hl.config({
    input = {
        kb_layout = layout.kbLayout or "us",
    },

    misc = {
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
        force_default_wallpaper  = 0,
    },

    animations = {
        enabled = false,
    },

    decoration = {
        blur = {
            enabled = false,
        },
        shadow = {
            enabled = false,
        },
    },
})

-- Quickshell owns the whole screen; when it exits, so does this Hyprland, and
-- greetd starts the real session. Output goes to a log because a greeter that
-- fails to draw leaves nothing else to debug from.
hl.on("hyprland.start", function()
    hl.exec_cmd("sh -c 'quickshell -p /etc/xdg/quickshell/fenrir-greeter >/tmp/fenrir-greeter.log 2>&1; hyprctl dispatch exit'")
end)
