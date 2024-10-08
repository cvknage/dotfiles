# `gitui`

Configuration for [gitui](https://github.com/extrawurst/gitui)

-- [Key Config](https://github.com/extrawurst/gitui/blob/master/KEY_CONFIG.md)  

## Install

The install script will download the catppuccin theme, aggregate all config files in to a `./config` directory and create a symlink from `$HOME/.config/gitui` to `./config`
``` 
bash install.sh
```

Add the following to your shells' rc file:
``` bash
gitui_theme() {
  OS="$(uname)"
  case $OS in
  "Linux")
    # gdbus call --session --dest org.freedesktop.portal.Desktop --object-path /org/freedesktop/portal/desktop --method org.freedesktop.portal.Settings.Read org.freedesktop.appearance color-scheme
    if [[ $(gsettings get org.gnome.desktop.interface color-scheme) =~ "dark" ]]; then
      gitui -t catppuccin-mocha.ron
    else
      gitui -t catppuccin-frappe.ron
    fi
    ;;
  "Darwin")
    if [[ "$(osascript -l JavaScript -e "Application('System Events').appearancePreferences.darkMode.get()")" == "true" ]]; then
      gitui -t catppuccin-mocha.ron
    else
      gitui -t catppuccin-frappe.ron
    fi
    ;;
  *)
    gitui -t catppuccin-macchiato.ron
    ;;
  esac
}

alias gitui="gitui_theme"
```

