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
o.rebind("SUPER + H", "Focus on left window", hl.dsp.focus({ direction = "l" }))
o.rebind("SUPER + J", "Focus on below window", hl.dsp.focus({ direction = "d" }))
o.rebind("SUPER + K", "Focus on above window", hl.dsp.focus({ direction = "u" }))
o.rebind("SUPER + L", "Focus on right window", hl.dsp.focus({ direction = "r" }))

-- ALT + M: full width (same as SUPER + ALT + F), next to ALT + TAB.
-- SUPER + M keeps Omarchy's minimize to the dock.
o.bind("ALT + M", "Full width", hl.dsp.window.fullscreen({ mode = "maximized" }))

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

-- Windows-style MRU switching for Workspaces (SUPER + TAB) and Windows (ALT + TAB):
--   * Quick tap (press & release): toggles back and forth between the 2 most recent.
--   * Hold modifier + press TAB multiple times: steps through the full MRU list
--     (SHIFT + TAB steps backwards), committing the chosen item on modifier release.
local ws_mru = {}
local ws_cycling = false
local ws_cycle_mon = nil
local ws_cycle_list = {}
local ws_cycle_index = 1
local ws_cycle_target = nil

local function record_ws(mon_name, ws_id)
  if not mon_name or not ws_id or ws_id <= 0 then
    return
  end
  local list = ws_mru[mon_name] or {}
  for i = #list, 1, -1 do
    if list[i] == ws_id then
      table.remove(list, i)
    end
  end
  table.insert(list, 1, ws_id)
  ws_mru[mon_name] = list
end

local function seed_ws_mru()
  for _, mon in ipairs(hl.get_monitors()) do
    local last = hl.get_last_workspace(mon.name)
    if last and not last.special and last.id > 0 then
      record_ws(mon.name, last.id)
    end
    local active = mon.active_workspace
    if active and not active.special and active.id > 0 then
      record_ws(mon.name, active.id)
    end
  end
end

seed_ws_mru()

hl.on("workspace.active", function(ws)
  if ws_cycling or not ws or ws.special or ws.id <= 0 then
    return
  end
  local mon = ws.monitor or hl.get_active_monitor()
  if mon and mon.name then
    record_ws(mon.name, ws.id)
  end
end)

local function build_ws_cycle_list(mon)
  local active = mon.active_workspace
  local active_id = active and not active.special and active.id or nil
  local existing = {}
  local existing_ids = {}

  for _, ws in ipairs(hl.get_workspaces()) do
    if not ws.special and ws.id > 0 and ws.monitor and ws.monitor.name == mon.name then
      existing[ws.id] = true
      table.insert(existing_ids, ws.id)
    end
  end
  table.sort(existing_ids)

  local list = {}
  local seen = {}
  local function add(id)
    if id and id > 0 and not seen[id] then
      seen[id] = true
      table.insert(list, id)
    end
  end

  if active_id then
    add(active_id)
  end

  for _, id in ipairs(ws_mru[mon.name] or {}) do
    if existing[id] then
      add(id)
    end
  end

  for _, id in ipairs(existing_ids) do
    add(id)
  end

  -- If only one workspace currently exists on this monitor, include the last
  -- visited workspace (even if it was empty and auto-removed) or fallback slot.
  if #list < 2 then
    for _, id in ipairs(ws_mru[mon.name] or {}) do
      add(id)
      if #list >= 2 then
        break
      end
    end
  end
  if #list < 2 then
    local last = hl.get_last_workspace(mon.name)
    if last and not last.special and last.id > 0 then
      add(last.id)
    end
  end
  if #list < 2 and o.workspaces and o.workspaces.workspace_id then
    local slot1 = o.workspaces.workspace_id(mon, 1)
    local slot2 = o.workspaces.workspace_id(mon, 2)
    add(active_id == slot1 and slot2 or slot1)
  end

  return list
end

local function step_workspace(step)
  local mon = hl.get_active_monitor()
  if not mon then
    return
  end

  if not ws_cycling or ws_cycle_mon ~= mon.name or #ws_cycle_list < 2 then
    ws_cycle_list = build_ws_cycle_list(mon)
    ws_cycle_mon = mon.name
    ws_cycle_index = 1
    ws_cycling = true
  end

  if #ws_cycle_list < 2 then
    return
  end

  ws_cycle_index = ((ws_cycle_index - 1 + step) % #ws_cycle_list) + 1
  local target_id = ws_cycle_list[ws_cycle_index]
  ws_cycle_target = target_id
  hl.dispatch(hl.dsp.focus({ workspace = tostring(target_id) }))
end

local function finish_ws_cycle()
  if not ws_cycling then
    return
  end
  ws_cycling = false
  local mon = ws_cycle_mon and hl.get_monitor(ws_cycle_mon) or hl.get_active_monitor()
  local ws = mon and mon.active_workspace
  local final_id = (ws and not ws.special and ws.id > 0 and ws.id) or ws_cycle_target
  if mon and final_id then
    record_ws(mon.name, final_id)
  end
  ws_cycle_target = nil
end

for _, key in ipairs({ "Super_L", "Super_R" }) do
  hl.bind(key, finish_ws_cycle, {
    release = true,
    transparent = true,
    ignore_mods = true,
    non_consuming = true,
  })
end

o.rebind("SUPER + TAB", "Switch workspace (MRU)", function()
  step_workspace(1)
end)
o.rebind("SUPER + SHIFT + TAB", "Switch workspace back (MRU)", function()
  step_workspace(-1)
end)

local win_mru = {}
local win_cycling = false
local win_cycle_ws = nil
local win_cycle_list = {}
local win_cycle_index = 1
local win_cycle_target = nil

local function record_win(addr)
  if not addr or addr == "" then
    return
  end
  for i = #win_mru, 1, -1 do
    if win_mru[i] == addr then
      table.remove(win_mru, i)
    end
  end
  table.insert(win_mru, 1, addr)
end

local function seed_win_mru()
  local wins = hl.get_windows({ mapped = true })
  table.sort(wins, function(a, b)
    return (a.focus_history_id or 9999) < (b.focus_history_id or 9999)
  end)
  for i = #wins, 1, -1 do
    if wins[i].address then
      record_win(wins[i].address)
    end
  end
end

seed_win_mru()

hl.on("window.active", function(win)
  if win_cycling or not win or not win.address then
    return
  end
  record_win(win.address)
end)

hl.on("window.destroy", function(win)
  if not win or not win.address then
    return
  end
  for i = #win_mru, 1, -1 do
    if win_mru[i] == win.address then
      table.remove(win_mru, i)
    end
  end
end)

local function build_win_cycle_list(ws_id)
  local wins = hl.get_windows({ workspace = ws_id, mapped = true })
  local by_addr = {}
  for _, w in ipairs(wins) do
    if w.address then
      by_addr[w.address] = w
    end
  end

  table.sort(wins, function(a, b)
    return (a.focus_history_id or 9999) < (b.focus_history_id or 9999)
  end)

  local list = {}
  local seen = {}
  local function add(addr)
    if addr and by_addr[addr] and not seen[addr] then
      seen[addr] = true
      table.insert(list, addr)
    end
  end

  local active = hl.get_active_window()
  if active and active.address then
    add(active.address)
  end

  for _, addr in ipairs(win_mru) do
    add(addr)
  end

  for _, w in ipairs(wins) do
    add(w.address)
  end

  return list
end

local function step_window(step)
  local ws = hl.get_active_workspace()
  if not ws then
    return
  end

  if not win_cycling or win_cycle_ws ~= ws.id or #win_cycle_list < 2 then
    win_cycle_list = build_win_cycle_list(ws.id)
    win_cycle_ws = ws.id
    win_cycle_index = 1
    win_cycling = true
  end

  if #win_cycle_list < 2 then
    return
  end

  win_cycle_index = ((win_cycle_index - 1 + step) % #win_cycle_list) + 1
  local target_addr = win_cycle_list[win_cycle_index]
  win_cycle_target = target_addr
  hl.dispatch(hl.dsp.focus({ window = "address:" .. target_addr }))
  hl.dispatch(hl.dsp.window.bring_to_top())
end

local function finish_win_cycle()
  if not win_cycling then
    return
  end
  win_cycling = false
  local win = hl.get_active_window()
  local final_addr = (win and win.address) or win_cycle_target
  if final_addr then
    record_win(final_addr)
  end
  win_cycle_target = nil
end

for _, key in ipairs({ "Alt_L", "Alt_R" }) do
  hl.bind(key, finish_win_cycle, {
    release = true,
    transparent = true,
    ignore_mods = true,
    non_consuming = true,
  })
end

o.rebind("ALT + TAB", "Focus on next window (MRU)", function()
  step_window(1)
end)
o.rebind("ALT + SHIFT + TAB", "Focus on previous window (MRU)", function()
  step_window(-1)
end)

-- SUPER + E: even grid. Floats every window on the workspace into equal cells,
-- 2 as halves, 4 as quarters, a short last row stretched across. Press again
-- to hand them back to tiling.
local grid_gap_out = 10 -- general.gaps_out
local grid_gap_in = 10 -- twice general.gaps_in
local gridded = {}

local function grid_windows(workspace_id)
  local out = {}
  for _, window in ipairs(hl.get_workspace_windows(tostring(workspace_id))) do
    if window.mapped ~= false then
      table.insert(out, window)
    end
  end
  return out
end

local function grid_toggle()
  local workspace = hl.get_active_workspace()
  if not workspace then
    return
  end
  local id = workspace.id
  local windows = grid_windows(id)

  if gridded[id] then
    gridded[id] = nil
    for _, window in ipairs(windows) do
      hl.dispatch(hl.dsp.window.float({ action = "off", window = "address:" .. window.address }))
    end
    return
  end

  local count = #windows
  if count == 0 then
    return
  end
  local monitor = hl.get_active_monitor()
  if not monitor or not monitor.scale or monitor.scale <= 0 then
    return
  end

  local width = monitor.width / monitor.scale
  local height = monitor.height / monitor.scale
  if (monitor.transform or 0) % 2 == 1 then
    width, height = height, width
  end
  local reserved = monitor.reserved or {}
  local left = (monitor.x or 0) + (reserved.left or 0) + grid_gap_out
  local top = (monitor.y or 0) + (reserved.top or 0) + grid_gap_out
  width = width - (reserved.left or 0) - (reserved.right or 0) - grid_gap_out * 2
  height = height - (reserved.top or 0) - (reserved.bottom or 0) - grid_gap_out * 2

  local cols = math.ceil(math.sqrt(count))
  local rows = math.ceil(count / cols)
  local cell_h = (height - grid_gap_in * (rows - 1)) / rows

  gridded[id] = true
  for i, window in ipairs(windows) do
    local row = math.floor((i - 1) / cols)
    local col = (i - 1) % cols
    local in_row = math.min(cols, count - row * cols)
    local cell_w = (width - grid_gap_in * (in_row - 1)) / in_row
    local target = "address:" .. window.address
    -- A maximized (Super+M) or fullscreen window would cover the grid.
    if (window.fullscreen or 0) ~= 0 then
      local mode = window.fullscreen == 1 and "maximized" or "fullscreen"
      hl.dispatch(hl.dsp.window.fullscreen({ mode = mode, action = "unset", window = target }))
    end
    hl.dispatch(hl.dsp.window.float({ action = "on", window = target }))
    hl.dispatch(hl.dsp.window.resize({ x = math.floor(cell_w), y = math.floor(cell_h), relative = false, window = target }))
    hl.dispatch(hl.dsp.window.move({
      x = math.floor(left + col * (cell_w + grid_gap_in)),
      y = math.floor(top + row * (cell_h + grid_gap_in)),
      relative = false,
      window = target,
    }))
  end
end

-- Reachable from `hyprctl repl 'o.grid_toggle()'` to test without the key.
o.grid_toggle = grid_toggle
o.bind("SUPER + E", "Even grid of the workspace's windows (toggle)", grid_toggle)
