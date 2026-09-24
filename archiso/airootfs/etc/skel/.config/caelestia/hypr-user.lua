-- Fenrir's own startup: the login splash on installed systems, and the
-- installer on the live image (that script checks for itself).
hl.on("hyprland.start", function()
    -- Covers the desktop loading in after login; quits itself once faded.
    -- Never on the live image, where it would only cover the installer.
    hl.exec_cmd("sh -c '[ -f /etc/fenrir-packages.x86_64 ] || quickshell -c fenrir-splash'")
    hl.exec_cmd("fenrir-installer-autostart")
end)
