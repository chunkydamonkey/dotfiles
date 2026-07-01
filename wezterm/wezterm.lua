local wezterm = require("wezterm")

local config = wezterm.config_builder()

-- ── OS detection (works on all three platforms) ─────────────────────────────
local triple = wezterm.target_triple:lower()
local is_windows = triple:find("windows") ~= nil
local is_macos = triple:find("darwin") ~= nil
local is_linux = triple:find("linux") ~= nil

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

return config
