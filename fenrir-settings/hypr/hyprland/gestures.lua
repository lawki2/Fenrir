local vars = require("variables")

hl.config({
    gestures = {
        workspace_swipe_distance                 = 700,
        workspace_swipe_cancel_ratio             = 0.15,
        workspace_swipe_min_speed_to_force       = 5,
        workspace_swipe_direction_lock           = true,
        workspace_swipe_direction_lock_threshold = 10,
        workspace_swipe_create_new               = true,
    },
})

-- The drawers IPC only toggles, so up and down check first and never open what's closed or vice versa.
local function launcher(open)
    local skip = open and "1" or "0"
    return function()
        hl.exec_cmd('[ "$(qs -c caelestia ipc call drawers isOpen launcher)" = ' .. skip .. " ] || qs -c caelestia ipc call drawers toggle launcher")
    end
end

hl.gesture({ fingers = vars.workspaceSwipeFingers, direction = "horizontal", action = "scroll_move" })
hl.gesture({ fingers = vars.workspaceSwipeFingers, direction = "vertical", action = "workspace" })
hl.gesture({ fingers = vars.gestureFingers, direction = "up", action = launcher(true) })
hl.gesture({ fingers = vars.gestureFingers, direction = "down", action = launcher(false) })
