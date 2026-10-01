local vars = require("variables")

local function wsaction(action, range, i)
    return function()
        local activews = hl.get_active_workspace()
        if activews then
            local id = activews.id
            local s  = (i - 1) * 10 + (id % 10)
            local t  = math.floor((id - 1) / 10) * 10 + i
            local z  = (range == "group") and s or t

            if action == "move" then
                return hl.dispatch(hl.dsp.window.move({ workspace = z }))
            else
                return hl.dispatch(hl.dsp.focus({ workspace = z }))
            end
        end
    end
end

local function resize_by_screen(x, y)
    local screen = hl.get_active_monitor()
    if screen and type(screen.width) == "number" and type(screen.height) == "number" then
        if not (x == 0 and y == 0) then
            local w = (x and x > 0) and math.floor(screen.width * x / 100) or screen.width
            local h = (y and y > 0) and math.floor(screen.height * y / 100) or screen.height
            return { x = w, y = h, relative = false }
        end
    end
end

local function resize_active_window(x, y)
    return function() -- returning the function so hl reloads everytime correctly
        local win = hl.get_active_window()
        if win and win.size then
            local w = (win.size.x * (x / 100)) or 800
            local h = (win.size.y * (y / 100)) or 600

            hl.dispatch(hl.dsp.window.resize({ x = w, y = h, relative = true }))
        else
            hl.dispatch(hl.dsp.no_op())
        end
    end
end

local function resizer(window, pattern, x_percent, y_percent, actions, exact, field)
    local value = window and window[field or "title"]
    if value and string.find(value, pattern, 1, exact) then
        local disp = (type(actions) == "table") and actions or { actions }
        for _, x in ipairs(disp) do
            hl.dispatch(x)
        end

        -- Target the matched window explicitly. Without window=, resize/set_prop
        -- act on the currently focused window instead, mangling whatever tiled
        -- window happened to be focused when this matched.
        local sz = resize_by_screen(x_percent, y_percent)
        if sz then
            sz.window = window
            hl.dispatch(hl.dsp.window.resize(sz))
        end
        hl.dispatch(hl.dsp.window.set_prop({ prop = "keep_aspect_ratio", value = "true", window = window }))
    end
end

local function move_actions(win)
    local screen = hl.get_active_monitor()

    if screen and screen.width and screen.height and win and win.size then
        local monitor_height = screen.height / screen.scale
        local monitor_width  = screen.width / screen.scale

        local scale_factor   = (monitor_height / 4) / win.size.y

        local target_width   = win.size.x * scale_factor
        local target_height  = win.size.y * scale_factor

        local x_resize       = math.floor(math.max(200, target_width))
        local y_resize       = math.floor(math.max(150, target_height))

        local offset         = math.min(monitor_width, monitor_height) * 0.03

        local move_x         = math.floor(screen.x + monitor_width - x_resize - offset)
        local move_y         = math.floor(screen.y + monitor_height - y_resize - offset)

        return {
            hl.dsp.window.resize({ x = x_resize, y = y_resize, window = win }),
            hl.dsp.window.move({ x = move_x, y = move_y, relative = false, window = win }),
        }
    end
end

-- Fenrir: scrolling layout helpers; a window's column is nil while it floats
local function column_of(win)
    local layout = win and win.layout
    local col    = type(layout) == "table" and layout.column
    if col and col.index then
        return col
    end
end

local function active_column()
    local win = hl.get_active_window()
    return win, column_of(win)
end

local function last_column_index(ws)
    local last = 0
    for _, w in ipairs(hl.get_workspace_windows(ws)) do
        local col = column_of(w)
        if col and col.index > last then
            last = col.index
        end
    end
    return last
end

local function move_column(dir)
    return function()
        local win, col = active_column()
        if not win then return end

        if col and dir == "left" and col.index > 0 then
            hl.dispatch(hl.dsp.layout("swapcol l"))
        elseif col and dir == "right" and col.index < last_column_index(win.workspace) then
            hl.dispatch(hl.dsp.layout("swapcol r"))
        else
            hl.dispatch(hl.dsp.window.move({ direction = dir }))
        end
    end
end

local function column_msg(msg)
    return function()
        local _, col = active_column()
        if col then
            hl.dispatch(hl.dsp.layout(msg))
        end
    end
end

-- Fenrir: one wheel step per 100 ms, since high-resolution wheels send several events per notch
local wheel_ready = true
local function wheel(action)
    return function()
        if not wheel_ready then return end
        wheel_ready = false
        hl.timer(function() wheel_ready = true end, { timeout = 100, type = "oneshot" })
        hl.dispatch(action)
    end
end

-- Fenrir: widths read back as floats (0.65 comes back as 0.6499...), hence the tolerance
local function next_preset(width, step)
    local presets = {}
    for s in string.gmatch(vars.columnWidthPresets, "[^,]+") do
        local n = tonumber(s)
        if n then table.insert(presets, n) end
    end
    table.sort(presets)

    if step > 0 then
        for _, p in ipairs(presets) do
            if p > width + 0.01 then return p end
        end
    else
        for i = #presets, 1, -1 do
            if presets[i] < width - 0.01 then return presets[i] end
        end
    end
end

local function column_width(step)
    return function()
        local win, col = active_column()
        if col then
            local width = next_preset(col.width, step)
            if width then
                hl.dispatch(hl.dsp.layout("colresize " .. width))
            end
        elseif win then
            resize_active_window(step * 10, 0)()
        end
    end
end

local function centre()
    return function()
        local win, col = active_column()
        if col then
            hl.dispatch(hl.dsp.layout("center"))
        elseif win then
            hl.dispatch(hl.dsp.window.center())
        end
    end
end

local function focus_column(which)
    return function()
        local win = hl.get_active_window()
        local ws  = win and win.workspace or hl.get_active_workspace()
        if not ws then return end

        local target = which == "last" and last_column_index(ws) or 0
        local best, best_age
        for _, w in ipairs(hl.get_workspace_windows(ws)) do
            local col = column_of(w)
            if col and col.index == target then
                -- Fenrir: 0 is the focused window; -1 was never focused, so it counts as oldest
                local age = w.focus_history_id >= 0 and w.focus_history_id or math.huge
                if not best or age < best_age then
                    best, best_age = w, age
                end
            end
        end

        if best then
            hl.dispatch(hl.dsp.focus({ window = "address:" .. best.address }))
        end
    end
end

return {
    resizer              = resizer,
    resize_by_screen     = resize_by_screen,
    resize_active_window = resize_active_window,
    wsaction             = wsaction,
    move_actions         = move_actions,
    active_column        = active_column,
    last_column_index    = last_column_index,
    move_column          = move_column,
    column_msg           = column_msg,
    wheel                = wheel,
    column_width         = column_width,
    centre               = centre,
    focus_column         = focus_column,
}
