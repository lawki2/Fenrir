local vars = require("variables")
local fn   = require("hyprland.functions")

-- Launcher
hl.bind("SUPER + SUPER_L", hl.dsp.global("caelestia:launcher"), { release = true })
-- Super press and release for the workspace drawer; the release-only twin still arrives under shortcut inhibitors
hl.bind(
    "SUPER_L",
    hl.dsp.global("caelestia:superHold"),
    { ignore_mods = true, non_consuming = true, transparent = true, locked = true }
)
hl.bind(
    "SUPER + SUPER_L",
    hl.dsp.global("caelestia:superHold"),
    { release = true, ignore_mods = true, non_consuming = true, transparent = true, locked = true, dont_inhibit = true }
)

-- Misc
hl.bind(vars.kbSession, hl.dsp.global("caelestia:session"), { description = "kbSession" })
hl.bind(vars.kbShowSidebar, hl.dsp.global("caelestia:sidebar"), { description = "kbShowSidebar" })
hl.bind(vars.kbClearNotifs, hl.dsp.global("caelestia:clearNotifs"), { locked = true, description = "kbClearNotifs" })
hl.bind(vars.kbShowPanels, hl.dsp.global("caelestia:showall"), { description = "kbShowPanels" })
hl.bind(vars.kbLock, hl.dsp.global("caelestia:lock"), { description = "kbLock" })

-- Restore lock
hl.bind(vars.kbRestoreLock, function()
    hl.dispatch(hl.dsp.exec_cmd("caelestia shell -d"))
    hl.dispatch(hl.dsp.global("caelestia:lock"))
end)

-- Brightness
hl.bind("XF86MonBrightnessUp", hl.dsp.global("caelestia:brightnessUp"), { locked = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.global("caelestia:brightnessDown"), { locked = true })

-- Media
hl.bind("CTRL + SUPER + Space", hl.dsp.global("caelestia:mediaToggle"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.global("caelestia:mediaToggle"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.global("caelestia:mediaToggle"), { locked = true })
hl.bind("CTRL + SUPER + Equal", hl.dsp.global("caelestia:mediaNext"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.global("caelestia:mediaNext"), { locked = true })
hl.bind("CTRL + SUPER + Minus", hl.dsp.global("caelestia:mediaPrev"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.global("caelestia:mediaPrev"), { locked = true })
hl.bind("XF86AudioStop", hl.dsp.global("caelestia:mediaStop"), { locked = true })

-- Kill/restart
hl.bind("CTRL + SUPER + SHIFT + R", hl.dsp.exec_cmd("qs -c caelestia kill"), { release = true })
hl.bind(
    "CTRL + SUPER + ALT + R",
    hl.dsp.exec_cmd("qs -c caelestia kill; sleep .1; caelestia shell -d"),
    { release = true }
)

for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(vars.kbGoToWs .. " + " .. key, fn.wsaction("focus", "", i), { description = "kbGoToWs" })
    hl.bind(vars.kbMoveWinToWs .. " + " .. key, fn.wsaction("move", "", i), { description = "kbMoveWinToWs" })
    hl.bind(vars.kbGoToWsGroup .. " + " .. key, fn.wsaction("focus", "group", i), { description = "kbGoToWsGroup" })
    hl.bind(
        vars.kbMoveWinToWsGroup .. " + " .. key,
        fn.wsaction("move", "group", i),
        { description = "kbMoveWinToWsGroup" }
    )
end

-- Go to workspace -1/+1
hl.bind("CTRL + SUPER + mouse_down", fn.wheel(hl.dsp.focus({ workspace = "+1" })))
hl.bind("CTRL + SUPER + mouse_up", fn.wheel(hl.dsp.focus({ workspace = "-1" })))
hl.bind(vars.kbPrevWs, hl.dsp.focus({ workspace = "-1" }), { repeating = true, description = "kbPrevWs" })
hl.bind(vars.kbNextWs, hl.dsp.focus({ workspace = "+1" }), { repeating = true, description = "kbNextWs" })
hl.bind("SUPER + Page_Up", hl.dsp.focus({ workspace = "-1" }), { repeating = true })
hl.bind("SUPER + Page_down", hl.dsp.focus({ workspace = "+1" }), { repeating = true })

-- Move window to workspace -1/+1
hl.bind("SUPER + ALT + Page_Up", hl.dsp.window.move({ workspace = "-1" }), { repeating = true })
hl.bind("SUPER + ALT + Page_Down", hl.dsp.window.move({ workspace = "+1" }), { repeating = true })
hl.bind("SUPER + ALT + mouse_down", fn.wheel(hl.dsp.window.move({ workspace = "+1" })))
hl.bind("SUPER + ALT + mouse_up", fn.wheel(hl.dsp.window.move({ workspace = "-1" })))
hl.bind(
    vars.kbMoveWinToWsPrev,
    hl.dsp.window.move({ workspace = "-1" }),
    { repeating = true, description = "kbMoveWinToWsPrev" }
)
hl.bind(
    vars.kbMoveWinToWsNext,
    hl.dsp.window.move({ workspace = "+1" }),
    { repeating = true, description = "kbMoveWinToWsNext" }
)

-- Move window to the special workspace, or back out of it
hl.bind("SUPER + ALT + S", function()
    local win = hl.get_active_window()
    if win and win.workspace and win.workspace.special then
        hl.dispatch(hl.dsp.window.move({ workspace = "e+0" }))
    else
        hl.dispatch(hl.dsp.window.move({ workspace = "special:special" }))
    end
end)

-- Window groups
hl.bind(
    vars.kbWindowGroupCycleNext,
    hl.dsp.window.cycle_next(),
    { repeating = true, description = "kbWindowGroupCycleNext" }
)
hl.bind(
    vars.kbWindowGroupCyclePrev,
    hl.dsp.window.cycle_next({ next = false }),
    { repeating = true, description = "kbWindowGroupCyclePrev" }
)
hl.bind("CTRL + ALT + Tab", hl.dsp.group.next(), { repeating = true })
hl.bind("CTRL + SHIFT + ALT + Tab", hl.dsp.group.prev(), { repeating = true })
hl.bind(vars.kbToggleGroup, hl.dsp.group.toggle(), { description = "kbToggleGroup" })
hl.bind(vars.kbUngroup, hl.dsp.window.move({ out_of_group = true }), { description = "kbUngroup" })
hl.bind("SUPER + SHIFT + Comma", hl.dsp.group.lock_active())

-- Window actions
hl.bind("SUPER + left", hl.dsp.focus({ direction = "left" }))
hl.bind("SUPER + right", hl.dsp.focus({ direction = "right" }))
hl.bind("SUPER + up", hl.dsp.focus({ direction = "up" }))
hl.bind("SUPER + down", hl.dsp.focus({ direction = "down" }))
hl.bind("SUPER + SHIFT + up", hl.dsp.window.move({ direction = "up" }))
hl.bind("SUPER + SHIFT + down", hl.dsp.window.move({ direction = "down" }))
hl.bind("SUPER + SHIFT + Minus", fn.resize_active_window(0, -10), { repeating = true })
hl.bind("SUPER + SHIFT + Equal", fn.resize_active_window(0, 10), { repeating = true })
hl.bind("SUPER + ALT + left", fn.resize_active_window(-10, 0), { repeating = true })
hl.bind("SUPER + ALT + right", fn.resize_active_window(10, 0), { repeating = true })
hl.bind("SUPER + ALT + up", fn.resize_active_window(0, -10), { repeating = true })
hl.bind("SUPER + ALT + down", fn.resize_active_window(0, 10), { repeating = true })

hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(vars.kbMoveWindow, hl.dsp.window.drag(), { mouse = true, description = "kbMoveWindow" })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })
hl.bind(vars.kbResizeWindow, hl.dsp.window.resize(), { mouse = true, description = "kbResizeWindow" })
hl.bind("CTRL + SUPER + Backslash", hl.dsp.window.center())
hl.bind("CTRL + SUPER + ALT + Backslash", function()
    hl.dispatch(hl.dsp.window.resize(fn.resize_by_screen(55, 70)))
    hl.dispatch(hl.dsp.window.center())
end)
hl.bind(vars.kbWindowPip, function()
    local a = hl.get_active_window()
    if a then
        local pip = fn.move_actions(a) or {}
        if not a.floating then table.insert(pip, 1, hl.dsp.window.float()) end
        table.insert(pip, hl.dsp.window.pin({ action = "on", window = "address:" .. a.address }))

        for _, x in ipairs(pip) do
            hl.dispatch(x)
        end
    end
end, { description = "kbWindowPip" })
hl.bind(vars.kbPinWindow, hl.dsp.window.pin(), { description = "kbPinWindow" })
hl.bind(
    vars.kbWindowFullscreen,
    hl.dsp.window.fullscreen({ mode = "fullscreen" }),
    { description = "kbWindowFullscreen" }
)
hl.bind(
    vars.kbWindowBorderedFullscreen,
    hl.dsp.window.fullscreen({ mode = "maximized" }),
    { description = "kbWindowBorderedFullscreen" }
)
hl.bind(vars.kbToggleWindowFloating, hl.dsp.window.float(), { description = "kbToggleWindowFloating" })
hl.bind(vars.kbCloseWindow, hl.dsp.window.close(), { description = "kbCloseWindow" })

-- Scrolling layout columns
hl.bind(vars.kbColumnMoveLeft, fn.move_column("left"), { description = "kbColumnMoveLeft" })
hl.bind(vars.kbColumnMoveRight, fn.move_column("right"), { description = "kbColumnMoveRight" })
hl.bind(vars.kbConsumeOrExpelLeft, fn.column_msg("consume_or_expel prev"), { description = "kbConsumeOrExpelLeft" })
hl.bind(vars.kbConsumeOrExpelRight, fn.column_msg("consume_or_expel next"), { description = "kbConsumeOrExpelRight" })
hl.bind(vars.kbColumnWider, fn.column_width(1), { description = "kbColumnWider" })
hl.bind(vars.kbColumnNarrower, fn.column_width(-1), { description = "kbColumnNarrower" })
hl.bind(vars.kbCentreColumn, fn.centre(), { description = "kbCentreColumn" })
hl.bind(vars.kbColumnFirst, fn.focus_column("first"), { description = "kbColumnFirst" })
hl.bind(vars.kbColumnLast, fn.focus_column("last"), { description = "kbColumnLast" })
hl.bind("SUPER + mouse_down", fn.wheel(fn.column_msg("focus r")))
hl.bind("SUPER + mouse_right", fn.wheel(fn.column_msg("focus r")))
hl.bind("SUPER + mouse_up", fn.wheel(fn.column_msg("focus l")))
hl.bind("SUPER + mouse_left", fn.wheel(fn.column_msg("focus l")))

-- Special workspace toggles
hl.bind(vars.kbSpecialWs, hl.dsp.exec_cmd("caelestia toggle specialws"), { description = "kbSpecialWs" })
hl.bind(vars.kbSystemMonitorWs, hl.dsp.exec_cmd("caelestia toggle sysmon"), { description = "kbSystemMonitorWs" })
hl.bind(vars.kbMusicWs, hl.dsp.exec_cmd("caelestia toggle music"), { description = "kbMusicWs" })
hl.bind(
    vars.kbCommunicationWs,
    hl.dsp.exec_cmd("caelestia toggle communication"),
    { description = "kbCommunicationWs" }
)
hl.bind(vars.kbTodoWs, hl.dsp.exec_cmd("caelestia toggle todo"), { description = "kbTodoWs" })

-- Apps, each in its own unit so running out of memory closes that app rather than the session.
local function app(cmd)
    return hl.dsp.exec_cmd("app2unit -- " .. cmd)
end

hl.bind(vars.kbTerminal, app(vars.terminal), { description = "kbTerminal" })
hl.bind(vars.kbBrowser, app(vars.browser), { description = "kbBrowser" })
hl.bind(vars.kbEditor, app(vars.editor), { description = "kbEditor" })
hl.bind(vars.kbFileExplorer, app(vars.fileExplorer), { description = "kbFileExplorer" })
hl.bind("CTRL + ALT + V", app(vars.audioSettings))

-- Utilities
hl.bind(vars.kbScreenshot, hl.dsp.exec_cmd("caelestia screenshot"), { locked = true, description = "kbScreenshot" })
hl.bind("SUPER + SHIFT + S", hl.dsp.global("caelestia:screenshotFreeze"))
hl.bind("SUPER + SHIFT + ALT + S", hl.dsp.global("caelestia:screenshot"))
hl.bind("SUPER + ALT + R", hl.dsp.exec_cmd("caelestia record -s"))
hl.bind("CTRL + ALT + R", hl.dsp.exec_cmd("caelestia record"))
hl.bind("SUPER + SHIFT + ALT + R", hl.dsp.exec_cmd("caelestia record -r"))
hl.bind("SUPER + SHIFT + C", hl.dsp.exec_cmd("hyprpicker -a"))

-- Volume
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("SUPER + SHIFT + M", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind(
    "XF86AudioRaiseVolume",
    hl.dsp.exec_cmd(
        "wpctl set-mute @DEFAULT_AUDIO_SINK@ 0; wpctl set-volume -l " ..
        (vars.volumeMax / 100) .. " @DEFAULT_AUDIO_SINK@ " .. vars.volumeStep .. "%+"
    ),
    { locked = true, repeating = true }
)
hl.bind(
    "XF86AudioLowerVolume",
    hl.dsp.exec_cmd(
        "wpctl set-mute @DEFAULT_AUDIO_SINK@ 0; wpctl set-volume @DEFAULT_AUDIO_SINK@ " .. vars.volumeStep .. "%-"
    ),
    { locked = true, repeating = true }
)

-- Sleep
hl.bind("SUPER + SHIFT + L", hl.dsp.exec_cmd(vars.sleepGestureCmd), { locked = true })

-- Clipboard and emoji picker
hl.bind(vars.kbClipboard, hl.dsp.exec_cmd("pkill fuzzel || caelestia clipboard"), { description = "kbClipboard" })
hl.bind("SUPER + ALT + V", hl.dsp.exec_cmd("pkill fuzzel || caelestia clipboard -d"))
hl.bind(vars.kbEmoji, hl.dsp.exec_cmd("pkill fuzzel || caelestia emoji -p"), { description = "kbEmoji" })
-- Fenrir: only with more than one layout, so Ctrl+Space stays free for apps otherwise
if vars.kbLayout:find(",") then
    hl.bind(
        vars.kbSwitchLayout,
        hl.dsp.exec_cmd("hyprctl switchxkblayout all next"),
        { description = "kbSwitchLayout" }
    )
end
hl.bind(
    "CTRL + SHIFT + ALT + V",
    hl.dsp.exec_cmd('sleep 0.5s && ydotool type -d 1 "$(cliphist list | head -1 | cliphist decode)"'),
    { locked = true }
)

-- Testing
hl.bind(
    "SUPER + ALT + F12",
    hl.dsp.exec_cmd(
        "notify-send -u low -i dialog-information-symbolic 'Test notification' " ..
        [["Here's a really long message to test truncation and wrapping\nYou can middle click or flick this notification to dismiss it!"]] ..
        " -a 'Shell' -A 'Test1=I got it!' -A 'Test2=Another action'"
    )
)
