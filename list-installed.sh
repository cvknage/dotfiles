#!/usr/bin/env bash

# List installed software, grouped by where it came from:
#
#   nix        system, home-manager, and imperative `nix profile` / `nix-env`
#   neovim     plugins from lazy-lock.json, tools from mason
#   browsers   firefox and chromium-family extensions, firefox web apps
#   ai         mcp servers declared in nix, plus per-agent mcp servers and
#              plugins for claude, codex, and opencode
#   brew       casks, formulae, and Mac App Store apps (macOS)
#   projects   per-project flake devshell packages, from the direnv cache
#
#   bash list-installed.sh                        # everything
#   bash list-installed.sh neovim browsers        # only these sections
#   bash list-installed.sh --plain | grep -i dark # one entry per line, no headers
#
# Needs jq for every section except nix.

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: list-installed.sh [-p|--plain] [nix|neovim|browsers|ai|brew|projects ...]

  -p, --plain   One entry per line, no headers, deduplicated (for grep/pipe).

With no section arguments, every section is listed.
EOF
}

PLAIN=0
SECTIONS=()
for arg in "$@"; do
  case "$arg" in
    -p|--plain) PLAIN=1 ;;
    -h|--help) usage && exit 0 ;;
    nix|neovim|browsers|ai|brew|projects) SECTIONS+=("$arg") ;;
    *) usage >&2 && exit 1 ;;
  esac
done
[ "${#SECTIONS[@]}" -gt 0 ] || SECTIONS=(nix neovim browsers ai brew projects)

wanted() {
  case " ${SECTIONS[*]} " in *" $1 "*) return 0 ;; *) return 1 ;; esac
}

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
APP_SUPPORT="$HOME/Library/Application Support" # macOS

all=""

# emit <label> <source> <noun> <body>; body is one entry per line, may be empty.
emit() {
  local label=$1 source=$2 noun=$3 body=$4
  [ -n "$body" ] || return 0
  all="$all$body"$'\n'
  if [ "$PLAIN" -eq 0 ]; then
    printf '\n\033[1m%s\033[0m %s (%s %s)\n\n' "$label" "$source" "$(echo "$body" | wc -l)" "$noun"
    echo "$body" | sed 's/^/  /'
  fi
}

# --- nix ----------------------------------------------------------------

# Store paths a profile installs. `home-manager-path` and `system-path` are
# aggregates of many packages, so they are expanded one level.
store_paths_in() {
  local path
  while read -r path; do
    case "$path" in
      *-home-manager-path|*-system-path) nix-store --query --references "$path" ;;
      *) echo "$path" ;;
    esac
  done < <(nix-store --query --references "$(readlink -f "$1")")
}

# Package names installed by a profile, one per line.
# Split outputs (-man, -dev, ...) collapse into the package they belong to.
# Desktop entries and profile plumbing are packaged as their own store paths
# but are launchers and scripts, not software, so they are dropped.
packages_in() {
  store_paths_in "$1" \
    | sed -E -e 's#^/nix/store/[a-z0-9]{32}-##' \
             -e 's#(-[0-9][^-]*)-(man|doc|info|bin|dev|lib|out|devdoc|devman|terminfo|debug)$#\1#' \
    | grep -v -e '\.drv$' -e '^manifest\.nix$' -e '^env-manifest\.nix$' \
              -e '\.desktop$' -e '^hm-session-vars\.sh$' \
    | sort -u
}

list_nix() {
  command -v nix-store >/dev/null || return 0

  # label:path pairs, in the order the profiles take precedence on PATH.
  local profiles=(
    "nix · system:/run/current-system/sw"
    "nix · home-manager:/etc/profiles/per-user/$USER"
    "nix · home-manager:$STATE_HOME/nix/profile"
    "nix · user:$HOME/.nix-profile"
  )
  local entry label path resolved seen=""
  for entry in "${profiles[@]}"; do
    label="${entry%%:*}"
    path="${entry#*:}"
    [ -e "$path" ] || continue

    # Several profile links can resolve to the same store path; report it once.
    resolved="$(readlink -f "$path")"
    case " $seen " in *" $resolved "*) continue ;; esac
    seen="$seen $resolved"

    emit "$label" "$path" packages "$(packages_in "$path")"
  done
}

# Programs nix wraps with extra tools on their PATH. `programs.neovim.
# extraPackages` and friends land in the wrapper, never in a profile, so
# nothing above sees them. Add a command name here to cover another wrapper.
WRAPPED_PROGRAMS=(nvim)

list_wrapped() {
  local cmd wrapper body
  for cmd in "${WRAPPED_PROGRAMS[@]}"; do
    command -v "$cmd" >/dev/null || continue
    wrapper="$(readlink -f "$(command -v "$cmd")")"
    # Only a generated wrapper script bakes in store paths; an unwrapped
    # binary matches nothing and is skipped.
    body="$( (grep PATH "$wrapper" 2>/dev/null || true) \
      | grep -oE "/nix/store/[a-z0-9]{32}-[^:']*/bin" \
      | sed -E -e 's#^/nix/store/[a-z0-9]{32}-##' -e 's#/bin$##' \
      | sort -f -u || true)"
    emit "nix · $cmd wrapper" "$wrapper" packages "$body"
  done
}

# --- neovim -------------------------------------------------------------

list_lazy() {
  local lock="$CONFIG_HOME/nvim/lazy-lock.json"
  local dir="$DATA_HOME/nvim/lazy"
  local names="" plugin

  # The lock file covers every plugin the config can enable, including ones
  # this host never installs, so the cloned directories are the real list.
  [ -d "$dir" ] || return 0
  for plugin in "$dir"/*/; do
    [ -d "$plugin" ] || continue
    plugin="${plugin%/}"
    plugin="${plugin##*/}"
    # `<name>.cloning` is an in-progress or abandoned clone.
    case "$plugin" in *.cloning) continue ;; esac
    names="$names$plugin"$'\n'
  done

  # The lock file only supplies the commit each plugin is pinned to.
  if [ -f "$lock" ]; then
    names="$(printf '%s' "$names" | jq -R -r --slurpfile lock "$lock" '
      ($lock[0][.].commit // "") as $commit
      | if $commit == "" then . else "\(.) (\($commit[0:7]))" end
    ')"
  fi
  emit "neovim · lazy" "$dir" plugins "$(printf '%s' "$names" | sort -f)"
}

list_mason() {
  local dir="$DATA_HOME/nvim/mason/packages"
  [ -d "$dir" ] || return 0

  local body="" pkg name id version
  for pkg in "$dir"/*/; do
    [ -f "$pkg/mason-receipt.json" ] || continue
    name="$(jq -r '.name' "$pkg/mason-receipt.json")"
    # Package URLs look like `pkg:github/luals/lua-language-server@3.18.2`.
    id="$(jq -r '.source.id // ""' "$pkg/mason-receipt.json")"
    case "$id" in
      *@*) version="${id##*@}" && body="$body$name (${version%%\?*})"$'\n' ;;
      *) body="$body$name"$'\n' ;;
    esac
  done
  emit "neovim · mason" "$dir" tools "$(printf '%s' "$body" | sort -f)"
}

# --- browsers -----------------------------------------------------------

list_firefox() {
  local root profile ext_json
  for root in "$CONFIG_HOME/mozilla/firefox" "$HOME/.mozilla/firefox" \
              "$APP_SUPPORT/Firefox/Profiles"; do
    [ -d "$root" ] || continue
    for ext_json in "$root"/*/extensions.json; do
      [ -f "$ext_json" ] || continue
      profile="$(basename "$(dirname "$ext_json")")"
      # Everything shipping with firefox itself lives in an `app-builtin*` or
      # `app-system-*` location; the rest is what was actually installed.
      emit "browser · firefox" "$profile" extensions "$(jq -r '
        .addons[]
        | select(.location | test("^app-(builtin|system)") | not)
        | "\(.defaultLocale.name // .id) (\(.version))"
      ' "$ext_json" | sort -f)"
    done
  done
}

# Extension names, one per line, from a chromium `Preferences`-style file.
# location 5 and 10 are components bundled with the browser. Extensions naming
# themselves `__MSG_*__` localize at runtime, so fall back to their id.
chromium_extensions_in() {
  jq -r '
    (.extensions.settings // {})
    | to_entries[]
    | select(.value.manifest != null)
    | select(.value.location as $loc | [5, 10] | index($loc) | not)
    | (.value.manifest.name // "") as $n
    | (if ($n == "" or ($n | startswith("__MSG_"))) then .key else $n end) as $name
    | "\($name) (\(.value.manifest.version // "?"))"
  ' "$1"
}

# Web apps installed as their own firefox profile by `programs.firefoxpwa`.
list_firefox_pwa() {
  local config
  for config in "$DATA_HOME/firefoxpwa/config.json" "$APP_SUPPORT/firefoxpwa/config.json"; do
    [ -f "$config" ] || continue
    emit "browser · firefox pwa" "$config" apps "$(jq -r '
      (.sites // {})
      | to_entries[]
      | .value.config.name // .value.manifest.name // .key
    ' "$config" | sort -f)"
  done
}

list_chromium() {
  local root profile prefs body
  for root in "$CONFIG_HOME"/{chromium,ungoogled-chromium,google-chrome*,microsoft-edge,vivaldi,BraveSoftware/Brave-Browser} \
              "$APP_SUPPORT"/{Chromium,Google/Chrome,Microsoft\ Edge,Vivaldi,BraveSoftware/Brave-Browser}; do
    [ -d "$root" ] || continue
    for profile in Default "$root"/Profile*; do
      profile="$root/${profile##*/}"
      body=""
      # Chrome moved extension state into `Secure Preferences`; chromium and
      # older profiles still keep it in `Preferences`.
      for prefs in "$profile/Preferences" "$profile/Secure Preferences"; do
        [ -f "$prefs" ] || continue
        body="$body$(chromium_extensions_in "$prefs")"$'\n'
      done
      emit "browser · ${root##*/}" "${profile##*/}" extensions \
        "$(printf '%s' "$body" | { grep -v '^$' || true; } | sort -f -u)"
    done
  done
}

# --- project devshells --------------------------------------------------

PROJECT_ROOTS=("$HOME/code")

# Where nix-direnv keeps a project's built devshell. By default that is the
# project's own `.direnv`, but direnvrc can redirect the layout to a central
# cache keyed by a sha1 of the project path — as direnv/direnvrc does here —
# in which case the project directory stays clean.
project_layout() {
  local project=$1 hash
  hash="$(printf '%s' "$project" | sha1sum | cut -d' ' -f1)"
  if [ -d "$CACHE_HOME/direnv/layouts/$hash" ]; then
    echo "$CACHE_HOME/direnv/layouts/$hash"
  elif [ -d "$project/.direnv" ]; then
    echo "$project/.direnv"
  fi
}

# A `buildEnv`/`combinePackages` aggregate is one store path with an opaque
# name like `dotNetSDKs`. SDK-style aggregates lay their contents out as
# `share/<tool>/sdk/<version>`, so report those versions instead.
aggregate_detail() {
  local sdk tool detail=""
  for sdk in "$1"/share/*/sdk/*/; do
    [ -d "$sdk" ] || continue
    sdk="${sdk%/}"
    tool="${sdk%/sdk/*}"
    detail="$detail${tool##*/} ${sdk##*/}, "
  done
  [ -z "$detail" ] || echo "${detail%, }"
}

# Packages a project's flake devshell installs, read from the direnv cache
# rather than by evaluating the flake. A project whose devshell was never
# built has nothing installed and is not listed.
list_projects() {
  local root project layout profile rc body store name detail
  for root in "${PROJECT_ROOTS[@]}"; do
    [ -d "$root" ] || continue
    while read -r project; do
      layout="$(project_layout "$project")"
      [ -n "$layout" ] || continue
      for profile in "$layout"/flake-profile-*; do
        case "$profile" in *.rc) continue ;; esac
        rc="$profile.rc"
        [ -f "$rc" ] || continue
        body=""
        # These hold the devshell's own packages; the profile's store
        # references would also drag in all of stdenv. `mkShell` routes its
        # `packages` argument to nativeBuildInputs, so all three are read.
        while read -r store; do
          name="${store##*/}"
          name="${name#*-}"
          detail="$(aggregate_detail "$store")"
          if [ -n "$detail" ]; then
            body="$body$name ($detail)"$'\n'
          else
            body="$body$name"$'\n'
          fi
        done < <(grep -oE "^(buildInputs|nativeBuildInputs|propagatedBuildInputs)='[^']*'" "$rc" \
          | grep -oE "/nix/store/[a-z0-9]{32}-[^ ']*" | sort -u)
        emit "project · ${project#"$root"/}" "$project" packages \
          "$(printf '%s' "$body" | sort -f -u)"
      done
    done < <(find "$root" -maxdepth 4 \( -name .git -o -name node_modules \) -prune \
      -o \( -name .envrc -o -name flake.nix \) -print 2>/dev/null \
      | sed 's|/[^/]*$||' | sort -u)
  done
}

# --- homebrew -----------------------------------------------------------

# nix-darwin declares casks, formulae and Mac App Store apps but hands the
# install to homebrew, so they live outside the nix store entirely.
# `brew list --versions` prints `name 1.2.3`, and several versions when more
# than one is kept.
brew_list() {
  brew list "$1" --versions \
    | awk '{name = $1; $1 = ""; sub(/^ /, ""); print name " (" $0 ")"}' \
    | sort -f
}

list_brew() {
  command -v brew >/dev/null || return 0
  local prefix
  prefix="$(brew --prefix)"
  emit "brew · formulae" "$prefix" formulae "$(brew_list --formula)"
  emit "brew · casks" "$prefix" casks "$(brew_list --cask)"
}

list_mas() {
  command -v mas >/dev/null || return 0
  # `mas list` prints `<id>  <name>  (<version>)`; the id is not worth showing.
  emit "brew · app store" mas apps \
    "$(mas list | sed -E 's/^[0-9]+[[:space:]]+//' | sort -f)"
}

# --- ai agents ----------------------------------------------------------

# Servers from a `{"mcpServers": {...}}` document, one per line.
mcp_servers_in() {
  jq -r '(.mcpServers // {}) | to_entries[] | "\(.key) (\(.value.type // "stdio"))"' "$1"
}

# What `programs.mcp.servers` declares. Home-manager writes this shared file and
# feeds the same servers to each agent that opts into the integration.
list_nix_mcp() {
  local shared="$CONFIG_HOME/mcp/mcp.json"
  [ -f "$shared" ] || return 0
  emit "ai · nix mcp" "$shared" servers "$(mcp_servers_in "$shared" | sort -f)"
}

list_claude() {
  local config="$HOME/.claude.json"
  local plugins="$HOME/.claude/plugins/installed_plugins.json"
  local mcp_json

  # Plugins carry their own servers; home-manager hands claude the ones from
  # `programs.mcp` as a generated plugin under skills/.
  for mcp_json in "$HOME/.claude/.mcp.json" "$HOME/.claude/skills"/*/.mcp.json; do
    [ -f "$mcp_json" ] || continue
    case "$mcp_json" in *.hm-backup/*) continue ;; esac
    emit "ai · claude mcp" "$mcp_json" servers "$(mcp_servers_in "$mcp_json" | sort -f)"
  done

  # Servers live at the top level (user scope) and under each project.
  if [ -f "$config" ]; then
    emit "ai · claude mcp" "$config" servers "$(jq -r '
      [(.mcpServers // {}) | to_entries[]]
      + [(.projects // {}) | to_entries[] | (.value.mcpServers // {}) | to_entries[]]
      | .[]
      | "\(.key) (\(.value.type // "stdio"))"
    ' "$config" | sort -f -u)"
  fi

  # One entry per install; the same plugin can be installed at several scopes.
  if [ -f "$plugins" ]; then
    emit "ai · claude plugins" "$plugins" plugins "$(jq -r '
      (.plugins // {})
      | to_entries[]
      | .key as $name
      | .value[]
      | "\($name) (\(.version), \(.scope))"
    ' "$plugins" | sort -f -u)"
  fi
}

list_codex() {
  local config="$HOME/.codex/config.toml"
  [ -f "$config" ] || return 0

  # `[mcp_servers.NAME]` opens a server; `[mcp_servers.NAME.env]` and friends
  # are sub-tables of one, so only headers without a second dot count.
  emit "ai · codex mcp" "$config" servers "$(awk '
    /^\[mcp_servers\.[^.]+\]$/ { name = substr($0, 14, length($0) - 14); type = ""; enabled = "true" }
    name != "" && /^type *=/ { gsub(/^type *= *"|"$/, ""); type = $0 }
    name != "" && /^enabled *=/ { gsub(/^enabled *= */, ""); enabled = $0 }
    name != "" && /^$/ { print name " (" type (enabled == "false" ? ", disabled" : "") ")"; name = "" }
    END { if (name != "") print name " (" type (enabled == "false" ? ", disabled" : "") ")" }
  ' "$config" | sort -f)"
}

list_opencode() {
  local config plugin body=""
  for config in "$CONFIG_HOME/opencode/opencode.json" "$CONFIG_HOME/opencode/opencode.jsonc"; do
    [ -f "$config" ] || continue
    emit "ai · opencode mcp" "$config" servers "$(jq -r '
      (.mcp // {})
      | to_entries[]
      | "\(.key) (\(.value.type // "local")\(if .value.enabled == false then ", disabled" else "" end))"
    ' "$config" | sort -f)"
    body="$body$(jq -r '(.plugin // [])[]' "$config")"$'\n'
  done

  # Plugins are npm specs in the config plus loose files dropped in `plugin/`.
  for plugin in "$CONFIG_HOME/opencode/plugin"/*; do
    [ -f "$plugin" ] || continue
    body="$body${plugin##*/}"$'\n'
  done
  emit "ai · opencode plugins" "$CONFIG_HOME/opencode" plugins \
    "$(printf '%s' "$body" | { grep -v '^$' || true; } | sort -f -u)"
}

# --- run ----------------------------------------------------------------

if wanted neovim || wanted browsers || wanted ai; then
  command -v jq >/dev/null \
    || { echo "list-installed.sh: jq is required for every section except nix" >&2 && exit 1; }
fi

if wanted nix; then list_nix && list_wrapped; fi
if wanted neovim; then list_lazy && list_mason; fi
if wanted browsers; then list_firefox && list_firefox_pwa && list_chromium; fi
if wanted ai; then list_nix_mcp && list_claude && list_codex && list_opencode; fi
if wanted brew; then list_brew && list_mas; fi
if wanted projects; then list_projects; fi

if [ "$PLAIN" -eq 1 ]; then
  printf '%s' "$all" | sort -f -u
else
  echo
fi
