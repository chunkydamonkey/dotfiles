local wezterm = require("wezterm")
local mux = wezterm.mux
local act = wezterm.action

local config = wezterm.config_builder()

-- ── OS detection (works on all three platforms) ─────────────────────────────
local triple = wezterm.target_triple:lower()
local is_windows = triple:find("windows") ~= nil
local is_macos = triple:find("darwin") ~= nil
local is_linux = triple:find("linux") ~= nil

-- Open maximized (not fullscreen) on first window.
wezterm.on("gui-startup", function(cmd)
  local _tab, _pane, window = mux.spawn_window(cmd or {})
  window:gui_window():maximize()
end)

-- Load fonts bundled next to this config (repo/wezterm/fonts). No system
-- install and no hardcoded user paths, so this is portable across machines.
config.font_dirs = { wezterm.config_dir .. "/fonts" }

-- ── Appearance (scaffolded from Kun Chen's config) ──────────────────────────
config.color_scheme = "rose-pine-moon"
config.font = wezterm.font("Hack Nerd Font") -- Hack ships Regular + Bold only
config.font_size = 12.0
config.max_fps = 120

-- One unified bar (window buttons integrated into the tab bar), always visible
-- (even with a single tab open).
config.window_decorations = "INTEGRATED_BUTTONS|RESIZE"
config.hide_tab_bar_if_only_one_tab = false
config.window_frame = {
  font = wezterm.font("Hack Nerd Font", { weight = "Bold" }),
  font_size = 10.0,
}

-- Dim inactive panes so the focused pane stands out.
config.inactive_pane_hsb = {
  saturation = 0.0,
  brightness = 0.5,
}

-- ── Per-OS window translucency / sizing ─────────────────────────────────────
if is_windows then
  config.win32_system_backdrop = "Acrylic"
  config.window_background_opacity = 0.7
  config.window_frame.font_size = 10.0
elseif is_macos then
  config.window_background_opacity = 0.8
  config.macos_window_background_blur = 50
  config.font_size = 15.0
  config.window_frame.font_size = 13.0
elseif is_linux then
  config.window_background_opacity = 0.9
  config.window_frame.font_size = 11.0
end

-- ── Keys ────────────────────────────────────────────────────────────────────
-- Same split shapes as tmux (Ctrl+b | / -), but WezTerm uses Ctrl+Shift+Alt
-- so it doesn't steal tmux's prefix or WezTerm paste (Ctrl+Shift+V):
--   Ctrl+Shift+Alt+|  →  left | right   (like tmux prefix+| / %)
--   Ctrl+Shift+Alt+-  →  top / bottom   (like tmux prefix+- / ")
-- Note: with Shift held, the physical "-" key is often reported as "_",
-- so we bind both. (Some layouts may surface "+"; bind that too.)
--
-- Quick Select default is Ctrl+Shift+Space — easy to hit by accident while
-- holding Ctrl+Shift for paste/copy. Move it to Ctrl+Shift+Y; free Space chord.
local split_vertical = act.SplitVertical { domain = "CurrentPaneDomain" }
local split_horizontal = act.SplitHorizontal { domain = "CurrentPaneDomain" }
config.keys = {
  { key = "|", mods = "CTRL|SHIFT|ALT", action = split_horizontal },
  { key = "\\", mods = "CTRL|SHIFT|ALT", action = split_horizontal }, -- same key unshifted on US
  { key = "-", mods = "CTRL|SHIFT|ALT", action = split_vertical },
  { key = "_", mods = "CTRL|SHIFT|ALT", action = split_vertical },
  { key = "+", mods = "CTRL|SHIFT|ALT", action = split_vertical },

  -- Paste like a normal desktop app (Ctrl+V). WezTerm handles this before the
  -- shell/nvim sees it. Tradeoff: nvim won't get Ctrl+V for visual-block mode
  -- (use Ctrl+Q for block select in nvim, or :help CTRL-V-alternative).
  -- With Shift held, the key is often "V" not "v" — bind both (same as -/_).
  { key = "v", mods = "CTRL", action = act.PasteFrom "Clipboard" },
  { key = "V", mods = "CTRL", action = act.PasteFrom "Clipboard" },
  { key = "v", mods = "CTRL|SHIFT", action = act.PasteFrom "Clipboard" },
  { key = "V", mods = "CTRL|SHIFT", action = act.PasteFrom "Clipboard" },
  { key = "Insert", mods = "SHIFT", action = act.PasteFrom "Clipboard" },
  -- Copy: keep Ctrl+Shift+C so Ctrl+C still interrupts processes in the shell
  { key = "c", mods = "CTRL|SHIFT", action = act.CopyTo "Clipboard" },
  { key = "C", mods = "CTRL|SHIFT", action = act.CopyTo "Clipboard" },

  -- Move Quick Select off Ctrl+Shift+Space (was hijacking paste attempts)
  {
    key = "phys:Space",
    mods = "CTRL|SHIFT",
    action = act.DisableDefaultAssignment,
  },
  { key = "y", mods = "CTRL|SHIFT", action = act.QuickSelect },
}

-- Right-click paste (handy when keys fight you)
config.mouse_bindings = {
  {
    event = { Down = { streak = 1, button = "Right" } },
    mods = "NONE",
    action = act.PasteFrom "Clipboard",
  },
}

return config
