local wezterm = require 'wezterm'
local resurrect_ok, resurrect = pcall(
  wezterm.plugin.require,
  'https://github.com/YedPool/Wezurrect'
)

local config = wezterm.config_builder()

-- Persist windows, tabs, pane layout and recent scrollback outside this Git repo.
-- The saved JSON files are intentionally local because they can contain terminal output.
if resurrect_ok then
  resurrect.state_manager.change_state_save_dir(
    wezterm.home_dir .. '\\AppData\\Local\\WezTerm\\resurrect'
  )
  resurrect.state_manager.set_max_nlines(5000)
  -- Restore only scrollback. Never replay a foreground program such as Claude.
  resurrect.tab_state.default_on_pane_restore = function(pane_tree)
    if pane_tree.text then
      local pane = pane_tree.pane
      pane:inject_output(pane_tree.text:gsub('%s+$', ''))
      pane:send_text '\r\n'
    end
  end
  resurrect.state_manager.periodic_save {
    interval_seconds = 30,
    save_workspaces = true,
    save_windows = true,
    save_tabs = true,
  }
  wezterm.on('gui-startup', resurrect.state_manager.resurrect_on_gui_startup)
else
  wezterm.log_warn('Wezurrect session persistence plugin could not be loaded')
end

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

-- Alt+Shift+D: split the current pane and open PowerShell 7 in the new pane.
-- `phys:D` refers to the physical D-key, so this works with a Russian layout too.
config.keys = {
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
  -- Standard Windows clipboard shortcuts; physical keys work in any layout.
  {
    key = 'phys:C',
    mods = 'CTRL',
    action = wezterm.action.CopyTo 'Clipboard',
  },
  {
    key = 'phys:V',
    mods = 'CTRL',
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
  -- Keep the built-in Ctrl+R configuration reload shortcut.
  {
    key = 'r',
    mods = 'CTRL',
    action = wezterm.action.ReloadConfiguration,
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
