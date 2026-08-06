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
-- When cmd is nil/empty, spawn_window({}) can land on the local domain (cmd.exe
-- on Windows) even if default_domain is set — pass the domain explicitly.
wezterm.on("gui-startup", function(cmd)
  local args = cmd or {}
  if not args.domain and config.default_domain then
    args.domain = { DomainName = config.default_domain }
  end
  local _tab, _pane, window = mux.spawn_window(args)
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
  -- Auto-detect WSL: enumerate installed distros; if any usable one exists,
  -- make it the default domain. No WSL / only helper distros → leave local
  -- (cmd/PowerShell). No distro names are hardcoded.
  local wsl_domains = wezterm.default_wsl_domains()
  -- Not interactive shells (Docker Desktop, Podman machine, etc.)
  local skip = {
    ["docker-desktop"] = true,
    ["docker-desktop-data"] = true,
    ["podman-machine-default"] = true,
  }
  local function distro_key(d)
    return (d.distribution or d.name or ""):lower():gsub("^wsl:", "")
  end
  local usable = {}
  for _, d in ipairs(wsl_domains) do
    if not skip[distro_key(d)] then
      table.insert(usable, d)
    end
  end

  local domain_name = nil
  if #usable > 0 then
    -- WSL's own default is the first name from `wsl --list --quiet`
    -- (UTF-16 on Windows — strip NULs). Fall back to first usable domain.
    local wsl_default = nil
    local ok, stdout = wezterm.run_child_process({ "wsl.exe", "--list", "--quiet" })
    if ok and stdout and #stdout > 0 then
      local text = stdout:gsub("%z", ""):gsub("\r", "")
      wsl_default = text:match("([^\n]+)")
      if wsl_default then
        wsl_default = wsl_default:match("^%s*(.-)%s*$"):lower()
        if skip[wsl_default] then
          wsl_default = nil
        end
      end
    end
    if wsl_default then
      for _, d in ipairs(usable) do
        if distro_key(d) == wsl_default then
          domain_name = d.name
          break
        end
      end
    end
    domain_name = domain_name or usable[1].name
    config.default_domain = domain_name
    config.wsl_domains = wsl_domains
  end

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
