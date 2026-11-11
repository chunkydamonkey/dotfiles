local wezterm = require("wezterm")
local mux = wezterm.mux
local act = wezterm.action

local config = wezterm.config_builder()

-- ── OS detection (works on all three platforms) ─────────────────────────────
local triple = wezterm.target_triple:lower()
local is_windows = triple:find("windows") ~= nil
local is_macos = triple:find("darwin") ~= nil
local is_linux = triple:find("linux") ~= nil
local powershell_exe = "pwsh"
if is_windows then
  local has_pwsh = wezterm.run_child_process({ "where.exe", "pwsh.exe" })
  powershell_exe = has_pwsh and "pwsh.exe" or "powershell.exe"
end

-- Host home (Windows path on Win, Unix path elsewhere). Per-distro WSL homes
-- are filled in below (domain name → absolute Linux path, e.g. /home/you).
local home = wezterm.home_dir
local wsl_homes = {} -- [domain_name] = "/home/..."
config.default_cwd = home

-- Open maximized (not fullscreen) on first window.
-- When cmd is nil/empty, spawn_window({}) can land on the local domain (cmd.exe
-- on Windows) even if default_domain is set — pass the domain explicitly.
-- Always start at home (do not inherit a random cwd from the launcher).
wezterm.on("gui-startup", function(cmd)
  local args = cmd or {}
  if not args.domain and config.default_domain then
    args.domain = { DomainName = config.default_domain }
  end
  if not args.cwd then
    local domain = config.default_domain
    if domain and wsl_homes[domain] then
      args.cwd = wsl_homes[domain]
    else
      args.cwd = home
    end
  end
  local _tab, _pane, window = mux.spawn_window(args)
  -- Hyprland tiles the window. Maximizing here fights that layout.
  if not is_linux then
    window:gui_window():maximize()
  end
end)

-- Load fonts bundled next to this config (repo/wezterm/fonts). No system
-- install and no hardcoded user paths, so this is portable across machines.
config.font_dirs = { wezterm.config_dir .. "/fonts" }

-- ── Appearance (scaffolded from Kun Chen's config) ──────────────────────────
config.color_scheme = "rose-pine-moon"
config.font = wezterm.font("Hack Nerd Font") -- Hack ships Regular + Bold only
config.font_size = 12.0
config.max_fps = 120
config.window_background_opacity = 0.95

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

    -- Pin each WSL domain to that distro's $HOME so new tabs/windows land in
    -- Linux ~ (not /mnt/c/Users/...). WezTerm does not expand "~".
    for _, d in ipairs(wsl_domains) do
      if not skip[distro_key(d)] then
        local distro = d.distribution or distro_key(d)
        local ok_h, home_out = wezterm.run_child_process({
          "wsl.exe",
          "-d",
          distro,
          "-e",
          "printenv",
          "HOME",
        })
        if ok_h and home_out and #home_out > 0 then
          local h = home_out:gsub("%z", ""):gsub("\r", ""):match("^%s*(.-)%s*$")
          if h and #h > 0 then
            d.default_cwd = h
            wsl_homes[d.name] = h
          end
        end
      end
    end
    config.wsl_domains = wsl_domains
  end

  config.win32_system_backdrop = "Acrylic"
  config.window_frame.font_size = 10.0
elseif is_macos then
  config.macos_window_background_blur = 50
  config.font_size = 15.0
  config.window_frame.font_size = 13.0
elseif is_linux then
  config.window_frame.font_size = 11.0
  -- Hyprland owns the window. The minimize, maximize, and close buttons
  -- stay on Windows, where INTEGRATED_BUTTONS is set above.
  config.window_decorations = "NONE"
  -- The fancy tab bar is a grey titlebar strip. Hide it for a single tab.
  -- Extra tabs use the retro bar, which takes its colors from rose-pine moon.
  config.hide_tab_bar_if_only_one_tab = true
  config.use_fancy_tab_bar = false
  config.show_new_tab_button_in_tab_bar = false
end

-- Cwd for a new tab/window in the given domain. WSL must use the Linux home
-- path; local/mac/linux use the host home. Avoids inheriting the current pane.
local function home_cwd_for_domain(domain_name)
  if domain_name and wsl_homes[domain_name] then
    return wsl_homes[domain_name]
  end
  return home
end

-- Spawn tab/window at home in the current pane's domain (not "inherit cwd").
local function spawn_tab_at_home()
  return wezterm.action_callback(function(window, pane)
    window:perform_action(
      act.SpawnCommandInNewTab {
        cwd = home_cwd_for_domain(pane:get_domain_name()),
        domain = "CurrentPaneDomain",
      },
      pane
    )
  end)
end

local function spawn_window_at_home()
  return wezterm.action_callback(function(window, pane)
    window:perform_action(
      act.SpawnCommandInNewWindow {
        cwd = home_cwd_for_domain(pane:get_domain_name()),
        domain = "CurrentPaneDomain",
      },
      pane
    )
  end)
end

-- Ctrl+Tab walks tabs in recent order, the same way Super+Tab walks workspaces.
-- A tap flips the last two. Holding Ctrl and tapping Tab walks further back,
-- Ctrl+Shift+Tab reverses, and letting go of Ctrl leaves that tab on top.
-- Ctrl+PageUp and Ctrl+PageDown stay in left-to-right order.
local tab_mru = {}
local tab_cycle = {}

local function record_tab(window_id, tab_id)
  if not window_id or not tab_id or tab_cycle[window_id] then
    return
  end
  local list = tab_mru[window_id] or {}
  for i = #list, 1, -1 do
    if list[i] == tab_id then
      table.remove(list, i)
    end
  end
  table.insert(list, 1, tab_id)
  tab_mru[window_id] = list
end

local function commit_tab_cycle(window)
  local window_id = window:window_id()
  if not tab_cycle[window_id] then
    return
  end
  tab_cycle[window_id] = nil
  local tab = window:mux_window():active_tab()
  if tab then
    record_tab(window_id, tab:tab_id())
  end
end

local function watch_ctrl_release(window)
  local window_id = window:window_id()
  local function tick()
    if not tab_cycle[window_id] then
      return
    end
    local ok, mods = pcall(function()
      return window:keyboard_modifiers()
    end)
    if not ok or type(mods) ~= "string" or not mods:find("CTRL", 1, true) then
      commit_tab_cycle(window)
      return
    end
    wezterm.time.call_after(0.05, tick)
  end
  wezterm.time.call_after(0.05, tick)
end

local function step_recent_tab(delta)
  return wezterm.action_callback(function(window, _pane)
    local window_id = window:window_id()
    local mux = window:mux_window()
    local state = tab_cycle[window_id]
    if not state then
      local active = mux:active_tab()
      if active then
        record_tab(window_id, active:tab_id())
      end
      local alive = {}
      local positional = {}
      for _, tab in ipairs(mux:tabs()) do
        alive[tab:tab_id()] = tab
        table.insert(positional, tab:tab_id())
      end
      local list = {}
      local seen = {}
      local function add(tab_id)
        if tab_id and alive[tab_id] and not seen[tab_id] then
          seen[tab_id] = true
          table.insert(list, tab_id)
        end
      end
      if active then
        add(active:tab_id())
      end
      for _, tab_id in ipairs(tab_mru[window_id] or {}) do
        add(tab_id)
      end
      for _, tab_id in ipairs(positional) do
        add(tab_id)
      end
      if #list < 2 then
        return
      end
      state = { list = list, index = 1 }
      tab_cycle[window_id] = state
      watch_ctrl_release(window)
    end
    local count = #state.list
    state.index = ((state.index - 1 + delta) % count) + 1
    local target = state.list[state.index]
    for _, tab in ipairs(mux:tabs()) do
      if tab:tab_id() == target then
        tab:activate()
        return
      end
    end
  end)
end

wezterm.on("update-status", function(window, _pane)
  local window_id = window:window_id()
  if tab_cycle[window_id] then
    return
  end
  local tab = window:mux_window():active_tab()
  if tab then
    record_tab(window_id, tab:tab_id())
  end
end)

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
  { key = "Tab", mods = "CTRL", action = step_recent_tab(1) },
  { key = "Tab", mods = "CTRL|SHIFT", action = step_recent_tab(-1) },

  { key = "|", mods = "CTRL|SHIFT|ALT", action = split_horizontal },
  { key = "\\", mods = "CTRL|SHIFT|ALT", action = split_horizontal }, -- same key unshifted on US
  { key = "-", mods = "CTRL|SHIFT|ALT", action = split_vertical },
  { key = "_", mods = "CTRL|SHIFT|ALT", action = split_vertical },
  { key = "+", mods = "CTRL|SHIFT|ALT", action = split_vertical },

  -- New tab / window always start at ~ (override default inherit-cwd behavior)
  { key = "t", mods = "CTRL|SHIFT", action = spawn_tab_at_home() },
  { key = "T", mods = "CTRL|SHIFT", action = spawn_tab_at_home() },
  { key = "n", mods = "CTRL|SHIFT", action = spawn_window_at_home() },
  { key = "N", mods = "CTRL|SHIFT", action = spawn_window_at_home() },

  -- Word-delete like GUI editors. WezTerm can't delete words itself — it
  -- forwards keys the shell already understands (bash/zsh readline + PSReadLine):
  --   Shift+Backspace  →  Ctrl+W   (kill word left)
  --   Shift+Delete     →  Alt+D    (kill word right)
  { key = "Backspace", mods = "SHIFT", action = act.SendKey { key = "w", mods = "CTRL" } },
  { key = "Delete", mods = "SHIFT", action = act.SendKey { key = "d", mods = "ALT" } },

  -- Rename current tab (empty name restores the auto title from the shell)
  {
    key = "F2",
    mods = "NONE",
    action = act.PromptInputLine {
      description = "Rename tab",
      action = wezterm.action_callback(function(window, _pane, line)
        if line then
          window:active_tab():set_title(line)
        end
      end),
    },
  },

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

  -- PowerShell in a new tab. On Windows the default domain is often WSL, so
  -- spawn in the local domain explicitly (otherwise pwsh would run inside WSL).
  -- Prefer PowerShell 7 (pwsh); fall back to Windows PowerShell 5.1 if needed.
  {
    key = "P",
    mods = "CTRL|SHIFT|ALT",
    action = act.SpawnCommandInNewTab {
      args = { powershell_exe },
      cwd = home,
      domain = is_windows and { DomainName = "local" } or "CurrentPaneDomain",
    },
  },
}

-- Ctrl+1..9 and Ctrl+0 jump straight to that tab, like Super+1 jumps to a
-- workspace. 1 is the leftmost tab. The number row and the numpad both work,
-- with or without Shift. phys: keeps the numpad binding when NumLock is off.
for i = 1, 9 do
  local activate = act.ActivateTab(i - 1)
  table.insert(config.keys, { key = tostring(i), mods = "CTRL", action = activate })
  table.insert(config.keys, { key = "phys:Keypad" .. i, mods = "CTRL", action = activate })
  table.insert(config.keys, { key = "phys:Keypad" .. i, mods = "CTRL|SHIFT", action = activate })
end
local activate_tenth = act.ActivateTab(9)
table.insert(config.keys, { key = "0", mods = "CTRL", action = activate_tenth })
table.insert(config.keys, { key = "phys:Keypad0", mods = "CTRL", action = activate_tenth })
table.insert(config.keys, { key = "phys:Keypad0", mods = "CTRL|SHIFT", action = activate_tenth })

-- Right-click paste (handy when keys fight you)
config.mouse_bindings = {
  {
    event = { Down = { streak = 1, button = "Right" } },
    mods = "NONE",
    action = act.PasteFrom "Clipboard",
  },
}

return config
