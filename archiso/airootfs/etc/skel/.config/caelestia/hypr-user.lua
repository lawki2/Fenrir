-- Launch Fenrir's installer automatically when the live session starts.
-- The check for whether this is actually the live ISO lives in the script
-- itself, not here.
hl.on("hyprland.start", function()
    hl.exec_cmd("fenrir-installer-autostart")
end)
