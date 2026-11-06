-- Keep only your personal keybinding overrides here. Add new bindings or
-- unbind defaults before replacing them.
--
-- Managed by the Omarchy path of https://github.com/chunkydamonkey/dotfiles
-- Linked to ~/.config/hypr/bindings.lua by omarchy/install.sh.
-- Re-run that installer after `omarchy refresh hyprland`, which resets this file.

-- See current bindings and descriptions:
--   omarchy menu keybindings --print

-- To disable every Omarchy default binding, set this in
-- ~/.config/hypr/hyprland.lua before require("default.hypr.omarchy"), then add
-- only the bindings you want below:
--   omarchy_default_bindings = false

-- To disable all preinstalled app/webapp bindings, set:
--   omarchy_preinstalled_bindings = false

-- Vim-style focus: same as SUPER + arrows.
-- Replaces: SUPER+J toggle split, SUPER+K keybindings menu, SUPER+L cycle layout.
-- SUPER+M was minimize to dock; now full width (same as SUPER + ALT + F).
o.rebind("SUPER + H", "Focus on left window", hl.dsp.focus({ direction = "l" }))
o.rebind("SUPER + J", "Focus on below window", hl.dsp.focus({ direction = "d" }))
o.rebind("SUPER + K", "Focus on above window", hl.dsp.focus({ direction = "u" }))
o.rebind("SUPER + L", "Focus on right window", hl.dsp.focus({ direction = "r" }))
o.rebind("SUPER + M", "Full width", hl.dsp.window.fullscreen({ mode = "maximized" }))

-- Same as SUPER + SHIFT + arrows.
o.bind("SUPER + SHIFT + H", "Swap window to the left", hl.dsp.window.swap({ direction = "l" }))
o.bind("SUPER + SHIFT + J", "Swap window down", hl.dsp.window.swap({ direction = "d" }))
o.bind("SUPER + SHIFT + K", "Swap window up", hl.dsp.window.swap({ direction = "u" }))
o.bind("SUPER + SHIFT + L", "Swap window to the right", hl.dsp.window.swap({ direction = "r" }))

-- Monitor scale: was SUPER + SLASH / SUPER + ALT + SLASH.
-- SUPER + EQUAL was shrink window left; SUPER + ALT + EQUAL was shrink a little.
hl.unbind("SUPER + SLASH")
hl.unbind("SUPER + ALT + SLASH")
hl.unbind("SUPER + EQUAL")
hl.unbind("SUPER + ALT + EQUAL")
o.bind("SUPER + EQUAL", "Monitor scaling up", "omarchy-hyprland-monitor-scaling up")
o.bind("SUPER + ALT + EQUAL", "Monitor scaling down", "omarchy-hyprland-monitor-scaling down")

-- Hotkeys menu on SUPER + / (was monitor scale up, then briefly SUPER + ?).
-- SUPER + SHIFT + / stays Passwords (restore default after the Super+? attempt).
hl.unbind("SUPER + SHIFT + SLASH")
o.bind("SUPER + SLASH", "Keybindings", "omarchy-menu-keybindings")
o.bind("SUPER + SHIFT + SLASH", "Passwords", { omarchy = "1password" })

-- Dictation keys from before Alt + Space and Right Alt became the defaults.
-- Remove these lines to give the keys back to applications.
if o.dictation_installed and o.dictation_installed() then
  o.bind("SUPER + CTRL + X", "Toggle dictation", "omarchy-dictation toggle")
  o.bind_hold("F9", "Start dictation (push-to-talk)", "omarchy-dictation start", "Stop dictation (push-to-talk)", "omarchy-dictation stop")
end
