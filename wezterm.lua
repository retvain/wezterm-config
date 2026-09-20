local wezterm = require 'wezterm'

local config = wezterm.config_builder()

-- Start new tabs with PowerShell 7.
config.default_prog = { 'C:\\Program Files\\PowerShell\\7\\pwsh.exe', '-NoLogo' }

return config
