-- Options. Lines marked "review" are defaults I chose for you; see the doc.
local U = require("user.util")
local D = require("user.defs")

hl.config({
    general = {
        gaps_in  = 2,                                             -- your AeroSpace inner gap
        gaps_out = { top = 6, right = 4, bottom = 8, left = 4 },  -- your AeroSpace outer gaps
        border_size = 2,
        col = {
            active_border   = "rgba(7aa2f7ff)",
            inactive_border = "rgba(3b4252aa)",
        },
        resize_on_border = false,
        allow_tearing    = false,
        layout = D.temporary_layout, -- fixed workspaces get theirs from rules.lua
    },

    decoration = {
        rounding = 4,
        shadow   = { enabled = false },
        blur     = { enabled = false },
    },

    animations = { enabled = true }, -- everything is off below except the workspace slide

    input = {
        kb_layout    = "fr",
        kb_variant   = "ergol",  -- TODO: "ergol_iso" if you pick Ergo-L's ISO (angle mod) variant
        follow_mouse = 2,        -- review: hovering doesn't move keyboard focus; clicking does
        touchpad = {
            natural_scroll       = true,  -- review: like the Mac
            clickfinger_behavior = true,  -- review: two-finger click is right click, like the Mac
            ["tap-to-click"]     = false, -- review
        },
    },

    gestures = {
        workspace_swipe_use_r = false, -- swipes visit workspaces open on this monitor, like Fn+arrows
    },

    group = {
        auto_group           = true,  -- a new window joins the focused group (3-code, 4-term)
        insert_after_current = true,
        groupbar = { enabled = true, render_titles = true },
    },

    dwindle = {
        force_split    = 2,     -- new windows split to the right or below, never following the mouse
        preserve_split = true,  -- Hyprland 0.56 needs this for togglesplit (Super+/)
        smart_split    = false,
        smart_resizing = false, -- keyboard resizing follows the tiling position, not the mouse
    },

    master = {
        new_status     = "slave",
        orientation    = "left",
        smart_resizing = false,
    },

    scrolling = {
        fullscreen_on_one_column = true,   -- a lone column fills the screen
        column_width             = 0.5,
        focus_fit_method         = 1,      -- bring a focused column into view without centring it
        follow_focus             = true,
        explicit_column_widths   = "0.333, 0.5, 0.667, 1.0", -- Super+R cycles these
        wrap_focus               = false,  -- no left/right wrap in scrolling
        wrap_swapcol             = false,
    },

    binds = {
        window_direction_monitor_fallback = false, -- arrows stay on this monitor; Super+-/= cross
    },

    misc = {
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
        force_default_wallpaper  = 0,
        vrr                      = 2, -- review: variable refresh rate in fullscreen only
    },

    xwayland = {
        force_zero_scaling = true, -- review: X11 apps stay sharp on a fractional scale
    },
})

-- Animations: all off, except the workspace slide that swipes use.
-- Keyboard switches turn the slide off for themselves (util.instant).
hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.animation({ leaf = "global", enabled = false })
hl.animation(U.workspace_animation)

-- Monitors. TODO: check the laptop's output name with `hyprctl monitors`, and pick the scale
-- once you've seen the screen (1.5 gives 1707x1067 of space on the 2560x1600 panel).
hl.monitor({ output = "eDP-1", mode = "preferred", position = "auto", scale = 1.5 })
hl.monitor({ output = "",      mode = "preferred", position = "auto", scale = "auto" })
