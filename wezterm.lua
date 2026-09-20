local wezterm = require 'wezterm'

local config = wezterm.config_builder()

-- Start new tabs with PowerShell 7.
config.default_prog = { 'C:\\Program Files\\PowerShell\\7\\pwsh.exe', '-NoLogo' }

-- Alt+Shift+D: split the current pane and open PowerShell 7 in the new pane.
-- `phys:D` refers to the physical D-key, so this works with a Russian layout too.
config.keys = {
  {
    key = 'phys:D',
    mods = 'ALT|SHIFT',
    action = wezterm.action.SplitPane {
      direction = 'Right',
      size = { Percent = 50 },
    },
  },
}

return config
