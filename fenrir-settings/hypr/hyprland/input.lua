local vars = require("variables")

hl.config({
    input = {
        kb_layout          = vars.kbLayout,
        kb_options         = vars.kbOptions,
        numlock_by_default = false,
        repeat_delay       = 250,
        repeat_rate        = 35,
        focus_on_close     = 1,
        sensitivity        = vars.pointerSpeed,
        natural_scroll     = vars.mouseNaturalScroll,

        touchpad           = {
            natural_scroll       = vars.touchpadNaturalScroll,
            tap_to_click         = vars.touchpadTapToClick,
            clickfinger_behavior = vars.touchpadClickFinger,
            disable_while_typing = vars.touchpadDisableTyping,
            scroll_factor        = vars.touchpadScrollFactor,
        },
    },

    binds = {
        scroll_event_delay = 0,
    },

    cursor = {
        hotspot_padding = 1,
    },
})
