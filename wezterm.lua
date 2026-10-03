local wezterm = require 'wezterm'

local config = wezterm.config_builder()

-- Match a 144 Hz display and prefer the discrete GPU for rendering.
config.max_fps = 144
config.front_end = 'WebGpu'
config.webgpu_power_preference = 'HighPerformance'

-- Start new tabs with PowerShell 7.
config.default_prog = { 'C:\\Program Files\\PowerShell\\7\\pwsh.exe', '-NoLogo' }

-- Bundled locally because this Gogh scheme is only built into WezTerm nightly.
config.color_schemes = {
  ['Kanagawa Dragon (Gogh)'] = {
    foreground = '#C5C9C5',
    background = '#181616',
    cursor_bg = '#C8C093',
    cursor_fg = '#181616',
    ansi = {
      '#0D0C0C', '#C4746E', '#8A9A7B', '#C4B28A',
      '#8BA4B0', '#A292A3', '#8EA4A2', '#C8C093',
    },
    brights = {
      '#A6A69C', '#E46876', '#87A987', '#E6C384',
      '#7FB4CA', '#938AA9', '#7AA89F', '#C5C9C5',
    },
  },
}
config.color_scheme = 'Kanagawa Dragon (Gogh)'
config.font = wezterm.font 'JetBrains Mono'
config.font_size = 12.0
-- Keep the cursor steady even while terminal applications redraw frequently.
config.cursor_blink_rate = 0
-- This changes only the tab bar labels, not terminal text.
config.window_frame = {
  font_size = 14.0,
}

-- Ctrl+F12 toggles the native title bar while retaining the tab bar.
wezterm.on('toggle-title-bar', function(window, _)
  local overrides = window:get_config_overrides() or {}

  if overrides.window_decorations == 'RESIZE' then
    overrides.window_decorations = nil
  else
    overrides.window_decorations = 'RESIZE'
  end

  window:set_config_overrides(overrides)
end)

-- Keep an MRU list per window. Formatting runs when the selected tab changes,
-- including when a tab is selected with the mouse or another shortcut.
local tab_history = {}

local function observe_tab(window_id, active_id, live_tabs)
  local state = tab_history[window_id]
  if not state then
    state = { order = {}, active_id = nil, position = 1 }
    tab_history[window_id] = state
  end

  local live = {}
  for _, tab in ipairs(live_tabs) do
    live[tab.tab_id] = true
  end
  for i = #state.order, 1, -1 do
    if not live[state.order[i]] then
      table.remove(state.order, i)
    end
  end

  if state.active_id ~= active_id then
    for i, id in ipairs(state.order) do
      if id == active_id then
        table.remove(state.order, i)
        break
      end
    end
    table.insert(state.order, 1, active_id)
    state.active_id = active_id
    state.position = 1
  else
    for i, id in ipairs(state.order) do
      if id == active_id then
        state.position = i
        break
      end
    end
  end

  return state
end

wezterm.on('format-tab-title', function(tab, tabs)
  if tab.is_active then
    observe_tab(tab.window_id, tab.tab_id, tabs)
  end
end)

local function cycle_tab_history(direction)
  return wezterm.action_callback(function(window, pane)
    local tabs = window:mux_window():tabs_with_info()
    local active_id
    local indexes = {}
    local live_tabs = {}
    for _, item in ipairs(tabs) do
      local id = item.tab:tab_id()
      indexes[id] = item.index
      table.insert(live_tabs, { tab_id = id })
      if item.is_active then
        active_id = id
      end
    end
    if not active_id then
      return
    end

    local state = observe_tab(window:window_id(), active_id, live_tabs)
    if #state.order < 2 then
      return
    end

    state.position = (state.position - 1 + direction) % #state.order + 1
    local target_id = state.order[state.position]
    state.active_id = target_id
    window:perform_action(wezterm.action.ActivateTab(indexes[target_id]), pane)
  end)
end

-- Alt+Shift+D: split the current pane and open PowerShell 7 in the new pane.
-- `phys:D` refers to the physical D-key, so this works with a Russian layout too.
config.keys = {
  -- Alt+Shift+F: fuzzy-find a pane across every open window and workspace.
  -- The mux is queried only when the shortcut is pressed; nothing is cached or polled.
  {
    key = 'phys:F',
    mods = 'ALT|SHIFT',
    action = wezterm.action_callback(function(window, pane)
      local choices = {}
      local targets = {}

      for _, mux_window in ipairs(wezterm.mux.all_windows()) do
        local workspace = mux_window:get_workspace()

        for _, tab in ipairs(mux_window:tabs()) do
          local tab_title = tab:get_title()
          if tab_title == '' then
            tab_title = tab:active_pane():get_title()
          end

          for _, target_pane in ipairs(tab:panes()) do
            local cwd = target_pane:get_current_working_dir()
            if cwd then
              cwd = type(cwd) == 'string' and cwd or cwd.file_path
            end

            local pane_id = tostring(target_pane:pane_id())
            targets[pane_id] = {
              pane = target_pane,
              window = mux_window,
              workspace = workspace,
            }
            table.insert(choices, {
              id = pane_id,
              label = string.format(
                '[%s]  %s  |  %s  |  %s',
                workspace,
                tab_title,
                target_pane:get_title(),
                cwd or 'cwd unavailable'
              ),
            })
          end
        end
      end

      window:perform_action(wezterm.action.InputSelector {
        title = 'Find pane',
        fuzzy = true,
        fuzzy_description = 'Fuzzy find pane: ',
        choices = choices,
        action = wezterm.action_callback(function(_, _, id, _)
          local target = id and targets[id]
          if not target then
            return
          end

          if wezterm.mux.get_active_workspace() ~= target.workspace then
            wezterm.mux.set_active_workspace(target.workspace)
          end

          target.pane:activate()
          local gui_window = target.window:gui_window()
          if gui_window then
            gui_window:focus()
          end
        end),
      }, pane)
    end),
  },
  -- Ctrl+F12: hide/show the native title bar with minimize, maximize and close buttons.
  {
    key = 'F12',
    mods = 'CTRL',
    action = wezterm.action.EmitEvent 'toggle-title-bar',
  },
  -- Ctrl+N: open a complete new WezTerm window.
  {
    key = 'N',
    mods = 'CTRL',
    action = wezterm.action.SpawnWindow,
  },
  -- Ctrl+C copies and clears a selection, or interrupts the terminal app.
  {
    key = 'phys:C',
    mods = 'CTRL',
    action = wezterm.action_callback(function(window, pane)
      if window:get_selection_text_for_pane(pane) ~= '' then
        window:perform_action(wezterm.action.CopyTo 'Clipboard', pane)
        window:perform_action(wezterm.action.ClearSelection, pane)
      else
        window:perform_action(wezterm.action.SendKey { key = 'c', mods = 'CTRL' }, pane)
      end
    end),
  },
  {
    key = 'phys:V',
    mods = 'CTRL',
    action = wezterm.action.PasteFrom 'Clipboard',
  },
  -- Ctrl+Shift+C/V: clipboard shortcuts; physical keys work in any layout.
  {
    key = 'phys:C',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.CopyTo 'Clipboard',
  },
  {
    key = 'phys:V',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.PasteFrom 'Clipboard',
  },
  -- Ctrl+Shift+O: fuzzy-search tabs by their title from any keyboard layout.
  {
    key = 'phys:O',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.ShowLauncherArgs { flags = 'FUZZY|TABS' },
  },
  -- Ctrl+Shift+N: open a new window from the physical N key in any layout.
  {
    key = 'phys:N',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.SpawnWindow,
  },
  -- Ctrl+Shift+T: open a new tab from the physical T key in any layout.
  {
    key = 'phys:T',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.SpawnTab 'CurrentPaneDomain',
  },
  -- Cycle through recently visited tabs in both directions.
  {
    key = 'Tab',
    mods = 'CTRL',
    action = cycle_tab_history(1),
  },
  {
    key = 'Tab',
    mods = 'CTRL|SHIFT',
    action = cycle_tab_history(-1),
  },
  -- Ctrl+1 through Ctrl+9: activate a tab by its position.
  {
    key = '1',
    mods = 'CTRL',
    action = wezterm.action.ActivateTab(0),
  },
  {
    key = '2',
    mods = 'CTRL',
    action = wezterm.action.ActivateTab(1),
  },
  {
    key = '3',
    mods = 'CTRL',
    action = wezterm.action.ActivateTab(2),
  },
  {
    key = '4',
    mods = 'CTRL',
    action = wezterm.action.ActivateTab(3),
  },
  {
    key = '5',
    mods = 'CTRL',
    action = wezterm.action.ActivateTab(4),
  },
  {
    key = '6',
    mods = 'CTRL',
    action = wezterm.action.ActivateTab(5),
  },
  {
    key = '7',
    mods = 'CTRL',
    action = wezterm.action.ActivateTab(6),
  },
  {
    key = '8',
    mods = 'CTRL',
    action = wezterm.action.ActivateTab(7),
  },
  {
    key = '9',
    mods = 'CTRL',
    action = wezterm.action.ActivateTab(8),
  },
  -- Ctrl+Alt+Arrow: move through the tab list.
  {
    key = 'LeftArrow',
    mods = 'CTRL|ALT',
    action = wezterm.action.ActivateTabRelative(-1),
  },
  {
    key = 'RightArrow',
    mods = 'CTRL|ALT',
    action = wezterm.action.ActivateTabRelative(1),
  },
  -- Ctrl+Shift+J/K: move the active tab left/right using physical keys in any layout.
  {
    key = 'phys:J',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.MoveTabRelative(-1),
  },
  {
    key = 'phys:K',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.MoveTabRelative(1),
  },
  -- Ctrl+Shift+W: close the current tab.
  {
    -- Use the physical W key so the shortcut also works with a Russian layout.
    key = 'phys:W',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.CloseCurrentTab { confirm = true },
  },
  -- Alt+Shift+W: close the active pane; its tab closes when it is the last pane.
  {
    key = 'phys:W',
    mods = 'ALT|SHIFT',
    action = wezterm.action.CloseCurrentPane { confirm = true },
  },
  -- Ctrl+Shift+R: set a custom title for the current tab.
  {
    -- Use the physical R key so the shortcut also works with a Russian layout.
    key = 'phys:R',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.PromptInputLine {
      description = 'Tab name:',
      action = wezterm.action_callback(function(_, pane, line)
        if line then
          pane:tab():set_title(line)
        end
      end),
    },
  },
  -- Let Ctrl+R reach the shell (PSReadLine's reverse command-history search)
  -- instead of invoking WezTerm's default configuration reload action.
  {
    key = 'r',
    mods = 'CTRL',
    action = wezterm.action.DisableDefaultAssignment,
  },
  {
    key = 'R',
    mods = 'CTRL',
    action = wezterm.action.DisableDefaultAssignment,
  },
  -- Alt+Arrow: move focus to an adjacent pane.
  {
    key = 'LeftArrow',
    mods = 'ALT',
    action = wezterm.action.ActivatePaneDirection 'Left',
  },
  {
    key = 'RightArrow',
    mods = 'ALT',
    action = wezterm.action.ActivatePaneDirection 'Right',
  },
  {
    key = 'UpArrow',
    mods = 'ALT',
    action = wezterm.action.ActivatePaneDirection 'Up',
  },
  {
    key = 'DownArrow',
    mods = 'ALT',
    action = wezterm.action.ActivatePaneDirection 'Down',
  },
  -- Alt+Shift+Arrow: resize the active pane by moving the matching divider.
  {
    key = 'LeftArrow',
    mods = 'ALT|SHIFT',
    action = wezterm.action.AdjustPaneSize { 'Left', 2 },
  },
  {
    key = 'RightArrow',
    mods = 'ALT|SHIFT',
    action = wezterm.action.AdjustPaneSize { 'Right', 2 },
  },
  {
    key = 'UpArrow',
    mods = 'ALT|SHIFT',
    action = wezterm.action.AdjustPaneSize { 'Up', 2 },
  },
  {
    key = 'DownArrow',
    mods = 'ALT|SHIFT',
    action = wezterm.action.AdjustPaneSize { 'Down', 2 },
  },
  -- Alt+Shift+O: split the active pane top/bottom, placing the new pane below.
  {
    key = 'phys:O',
    mods = 'ALT|SHIFT',
    action = wezterm.action.SplitPane {
      direction = 'Down',
      size = { Percent = 50 },
    },
  },
  {
    key = 'phys:D',
    mods = 'ALT|SHIFT',
    action = wezterm.action.SplitPane {
      direction = 'Right',
      size = { Percent = 50 },
    },
  },
  -- Alt+Shift+I: rotate panes; with two panes this swaps left/right (or top/bottom).
  -- The physical I key makes the shortcut independent of the active keyboard layout.
  {
    key = 'phys:I',
    mods = 'ALT|SHIFT',
    action = wezterm.action.RotatePanes 'Clockwise',
  },
}

return config
