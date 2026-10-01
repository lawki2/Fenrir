local vars = require("variables")

hl.config({
    general = {
        layout            = "scrolling",
        no_focus_fallback = true, -- Fenrir: focus stops at the ends of the row

        allow_tearing     = false, -- Allows `immediate` window rule to work

        gaps_workspaces   = vars.workspaceGaps,
        gaps_in           = vars.windowGapsIn,
        gaps_out          = vars.windowGapsOut,
        border_size       = vars.windowBorderSize,

        col               = {
            active_border   = vars.activeWindowBorderColour,
            inactive_border = vars.inactiveWindowBorderColour,
        },
    },

    scrolling = {
        fullscreen_on_one_column = vars.singleColumnFullWidth,
        focus_fit_method         = vars.centreFocusedColumn and 0 or 1,
        column_width             = vars.columnWidth,
        follow_focus             = true,
        -- Fenrir: with focus following the mouse, hovering scrolls the row only once a fifth of the screen shows the column
        follow_min_visible       = vars.focusFollowsMouse and 0.2 or 0.0,
        explicit_column_widths   = vars.columnWidthPresets,
        wrap_focus               = false,
        wrap_swapcol             = false,
    },
})
