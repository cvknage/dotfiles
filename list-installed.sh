#!/usr/bin/env bash

# List installed software, grouped by where it came from:
#
#   nix        system, home-manager, and imperative `nix profile` / `nix-env`
#   neovim     plugins from lazy-lock.json, tools from mason
#   browsers   every installed browser - firefox, safari, and the chromium
#              family - with the extensions it has, plus firefox web apps
#   ai         mcp servers declared in nix, plus per-agent mcp servers and
#              plugins for claude, codex, and opencode
#   cargo      crates installed with `cargo install`
#   brew       casks, formulae, and Mac App Store apps (macOS)
#   fedora     dnf-installed packages (Fedora)
#   projects   per-project flake devshell packages, from the direnv cache
#
#   bash list-installed.sh                          # everything
#   bash list-installed.sh neovim browsers          # only these sections
#   bash list-installed.sh --plain | grep -i dark   # one entry per line, no headers
#   bash list-installed.sh --markdown > report.md   # a document
#
# Bold headers are dropped when stdout is not a terminal, so a plain redirect
# never writes escape codes to a file.
#
# Needs jq for every section except nix.

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: list-installed.sh [-p|--plain] [-m|--markdown]
                        [nix|neovim|browsers|ai|cargo|brew|fedora|projects ...]

  -p, --plain      One entry per line, no headers, deduplicated (for grep/pipe).
  -m, --markdown   A markdown document, for redirecting to a .md file.

With no section arguments, every section is listed.
EOF
}

FORMAT=text
SECTIONS=()
for arg in "$@"; do
  case "$arg" in
    -p|--plain) FORMAT=plain ;;
    -m|--markdown) FORMAT=markdown ;;
    -h|--help) usage && exit 0 ;;
    nix|neovim|browsers|ai|cargo|brew|fedora|projects) SECTIONS+=("$arg") ;;
    *) usage >&2 && exit 1 ;;
  esac
done
[ "${#SECTIONS[@]}" -gt 0 ] || SECTIONS=(nix neovim browsers ai cargo brew fedora projects)

# Only a terminal gets escape codes; a redirect or pipe gets clean text.
if [ -t 1 ]; then
  BOLD=$'\033[1m'
  RESET=$'\033[0m'
else
  BOLD=""
  RESET=""
fi

wanted() {
  case " ${SECTIONS[*]} " in *" $1 "*) return 0 ;; *) return 1 ;; esac
}

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
APP_SUPPORT="$HOME/Library/Application Support" # macOS
OS="$(uname -s)"

all=""

# emit <label> <source> <noun> <body> [always]; body is one entry per line and may
# be empty, in which case only `always` prints the heading.
emit() {
  local label=$1 source=$2 noun=$3 body=$4 always=${5:-} count=""
  [ -n "$body" ] || [ -n "$always" ] || return 0
  if [ -n "$body" ]; then all="$all$body"$'\n'; fi
  if [ "$FORMAT" != plain ]; then
    count="$(printf '%s' "$body" | grep -c . || true)"
  fi
  case "$FORMAT" in
    plain) ;;
    markdown)
      # shellcheck disable=SC2016  # the backticks are markdown, not a subshell
      printf '\n## %s\n\n`%s` — %s %s\n\n' "$label" "$source" "$count" "$noun"
      if [ -n "$body" ]; then echo "$body" | sed 's/^/- /'; fi
      ;;
    *)
      printf '\n%s%s%s %s (%s %s)\n\n' "$BOLD" "$label" "$RESET" "$source" "$count" "$noun"
      if [ -n "$body" ]; then echo "$body" | sed 's/^/  /'; fi
      ;;
  esac
}

# note <label> <source> <text>; a remark about a section rather than an entry, so
# it stays out of the plain listing and out of the total.
note() {
  case "$FORMAT" in
    plain) ;;
    markdown)
      # shellcheck disable=SC2016  # the backticks are markdown, not a subshell
      printf '\n## %s\n\n`%s` — %s\n\n' "$1" "$2" "$3"
      ;;
    *) printf '\n%s%s%s %s\n  %s\n' "$BOLD" "$1" "$RESET" "$2" "$3" ;;
  esac
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

app_bundle() {
  local dir
  for dir in /Applications "$HOME/Applications" /System/Applications; do
    if [ -d "$dir/$1.app" ]; then echo "$dir/$1.app"; return 0; fi
  done
  return 1
}

# <name>|<profile root under APP_SUPPORT>|<config roots under CONFIG_HOME>|<binaries>
CHROMIUM_BROWSERS=(
  "Chromium|Chromium|chromium:ungoogled-chromium|chromium"
  "Google Chrome|Google/Chrome|google-chrome:google-chrome-beta:google-chrome-unstable|google-chrome-stable"
  "Microsoft Edge|Microsoft Edge|microsoft-edge|microsoft-edge"
  "Brave Browser|BraveSoftware/Brave-Browser|BraveSoftware/Brave-Browser|brave"
  "Vivaldi|Vivaldi|vivaldi|vivaldi"
  "Opera|com.operasoftware.Opera|opera|opera"
)

# Config roots for one chromium browser, :-separated and absolute.
chromium_roots() {
  local root roots=""
  local -a parts=()
  if [ "$OS" = Darwin ]; then echo "$APP_SUPPORT/$1"; return; fi
  IFS=':' read -r -a parts <<<"$2"
  for root in "${parts[@]}"; do roots="$roots$CONFIG_HOME/$root:"; done
  echo "${roots%:}"
}

# <name>, config roots, binaries - the two lists :-separated. macOS goes by the
# bundle; elsewhere either a binary on PATH or an existing config root counts.
browser_present() {
  local bin root bins="${3:-}"
  local -a root_list=()
  if [ "$OS" = Darwin ]; then app_bundle "$1" >/dev/null; return; fi
  # Binary names hold no spaces; root paths may.
  for bin in ${bins//:/ }; do command -v "$bin" >/dev/null && return 0; done
  IFS=':' read -r -a root_list <<<"$2"
  for root in "${root_list[@]}"; do [ -d "$root" ] && return 0; done
  return 1
}

# `<name>` and `<directory>`, tab-separated, per profile in `profiles.ini`; a
# directory not registered there is a leftover, not a profile.
firefox_profiles() {
  local root=$1 ini dir
  for ini in "$root/profiles.ini" "$(dirname "$root")/profiles.ini"; do
    [ -f "$ini" ] || continue
    awk -v base="$(dirname "$ini")" '
      function flush() {
        if (name != "" && path != "")
          print name "\t" (path ~ /^\// ? path : base "/" path)
        name = ""; path = ""
      }
      { gsub(/\r/, "") }
      /^\[Profile[0-9]+\]/ { flush(); next }
      /^\[/ { flush(); next }
      /^Name=/ { sub(/^Name=/, ""); name = $0 }
      /^Path=/ { sub(/^Path=/, ""); path = $0 }
      END { flush() }
    ' "$ini"
    return 0
  done
  for dir in "$root"/*/; do
    [ -f "$dir/extensions.json" ] || continue
    dir="${dir%/}"
    printf '%s\t%s\n' "${dir##*/}" "$dir"
  done
}

# Roots Firefox may write profiles into.
FIREFOX_ROOTS=( "$CONFIG_HOME/mozilla/firefox" "$HOME/.mozilla/firefox" "$APP_SUPPORT/Firefox/Profiles" )

firefox_installed() {
  local root
  if [ "$OS" = Darwin ]; then app_bundle Firefox >/dev/null; return; fi
  command -v firefox >/dev/null && return 0
  for root in "${FIREFOX_ROOTS[@]}"; do [ -d "$root" ] && return 0; done
  return 1
}

list_firefox() {
  local root entries name dir ext_json body any="" seen_root="" src
  firefox_installed || return 0

  for root in "${FIREFOX_ROOTS[@]}"; do
    [ -d "$root" ] || continue
    [ -n "$seen_root" ] || seen_root="$root"
    entries="$(firefox_profiles "$root")"
    [ -n "$entries" ] || continue

    while IFS=$'\t' read -r name dir; do
      [ -n "$name" ] || continue
      ext_json="$dir/extensions.json"
      [ -f "$ext_json" ] || continue
      # Firefox's own addons: an `app-builtin*`/`app-system-*`/`app-global` location,
      # or a `@mozilla.*` id.
      body="$(jq -r '
        .addons[]
        | select(.location | test("^app-(builtin|system|global)") | not)
        | select(.id | test("@mozilla\\.(org|com)$") | not)
        | "\(.defaultLocale.name // .id) (\(.version))"
      ' "$ext_json" | sort -f)"
      [ -n "$body" ] || continue
      any=1
      emit "browser · Firefox" "$name" extensions "$body"
    done <<<"$entries"
  done

  # Installed but nothing to list: still one heading.
  if [ -z "$any" ]; then
    src="${seen_root:-$(command -v firefox 2>/dev/null || true)}"
    [ -n "$src" ] || src="${FIREFOX_ROOTS[0]}"
    emit "browser · Firefox" "$(app_bundle Firefox || printf '%s' "$src")" extensions "" always
  fi
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
  local entry app mac_root linux_roots bins roots root profile prefs body any label src seen_root
  local -a root_list=()
  local roots_present
  for entry in "${CHROMIUM_BROWSERS[@]}"; do
    IFS='|' read -r app mac_root linux_roots bins <<<"$entry"
    roots="$(chromium_roots "$mac_root" "$linux_roots")"
    browser_present "$app" "$roots" "$bins" || continue

    any=""
    # Split on the separator, not on whitespace: an Edge root holds a space.
    IFS=':' read -r -a root_list <<<"$roots"

    # A channel build adds a second root; naming it keeps the headings distinct.
    roots_present=0
    seen_root=""
    for root in "${root_list[@]}"; do
      [ -d "$root" ] || continue
      roots_present=$((roots_present + 1))
      [ -n "$seen_root" ] || seen_root="$root"
    done

    for root in "${root_list[@]}"; do
      label="browser · $app"
      if [ "$roots_present" -gt 1 ]; then label="$label (${root##*/})"; fi
      for profile in Default "$root"/Profile*; do
        profile="$root/${profile##*/}"
        [ -d "$profile" ] || continue
        any=1
        body=""
        # Chrome moved extension state into `Secure Preferences`; chromium and
        # older profiles still keep it in `Preferences`.
        for prefs in "$profile/Preferences" "$profile/Secure Preferences"; do
          [ -f "$prefs" ] || continue
          body="$body$(chromium_extensions_in "$prefs")"$'\n'
        done
        body="$(printf '%s' "$body" | { grep -v '^$' || true; } | sort -f -u)"
        emit "$label" "${profile##*/}" extensions "$body" always
      done
    done

    # Never launched: name what proved it is installed, not a root that is not there.
    if [ -z "$any" ]; then
      src="$seen_root"
      [ -n "$src" ] || src="$(command -v "${bins%%:*}" 2>/dev/null || true)"
      [ -n "$src" ] || src="${roots%%:*}"
      emit "browser · $app" "$(app_bundle "$app" || printf '%s' "$src")" extensions "" always
    fi
  done
}

# Safari's extensions, plists keyed by `<bundle-id> (<team-id>)`; `WebExtensions` is the
# modern kind, `AppExtensions` ship inside a host app.
SAFARI_CONTAINER="$HOME/Library/Containers/com.apple.Safari/Data/Library/Safari"

# `<bundle-id> <host app name>` per extension bundle inside an installed app.
appex_names() {
  local app appex name id
  for app in /Applications/*.app "$HOME/Applications"/*.app /System/Applications/*.app; do
    [ -d "$app" ] || continue
    name="${app##*/}"
    name="${name%.app}"
    for appex in "$app"/Contents/PlugIns/*.appex; do
      [ -d "$appex" ] || continue
      id="$(plutil -extract CFBundleIdentifier raw -o - "$appex/Contents/Info.plist" 2>/dev/null || true)"
      [ -n "$id" ] || continue
      printf '%s %s\n' "$id" "$name"
    done
  done
}

# Bundle ids of the extensions Safari has switched on. The store is XML because its
# entries carry dates, which `plutil -convert json` rejects. An entry with no
# `Enabled` key was never switched on, which is not the same as enabled.
safari_extensions_in() {
  plutil -convert xml1 -o - "$1" 2>/dev/null | awk '
    /<dict>/ { depth++ }
    /<\/dict>/ { depth-- }
    /<key>/ {
      k = $0; sub(/^.*<key>/, "", k); sub(/<\/key>.*/, "", k)
      if (depth == 1) cur = k
      else if (depth == 2) want = (k == "Enabled")
      next
    }
    want && depth == 2 && /<true\/>/ {
      gsub(/ \([A-Z0-9]+\)$/, "", cur)
      print cur
      want = 0
      next
    }
    want && depth == 2 && /<false\/>/ { want = 0; next }
  '
}

list_safari() {
  command -v plutil >/dev/null || return 0
  browser_present Safari "$SAFARI_CONTAINER" || return 0

  local plist id ids name names="" ids_all="" unreadable="" body=""
  for plist in "$SAFARI_CONTAINER/WebExtensions/Extensions.plist" \
               "$SAFARI_CONTAINER/AppExtensions/Extensions.plist"; do
    # A store that is not there yet is an empty one, not a failure.
    [ -e "$plist" ] || continue
    if [ ! -r "$plist" ] || ! ids="$(safari_extensions_in "$plist")"; then
      unreadable=1
      continue
    fi
    ids_all="$ids_all$ids"$'\n'
  done
  ids_all="$(printf '%s' "$ids_all" | { grep -v '^$' || true; } | sort -f -u)"

  # Nothing to show and something unreadable: the count is unknowable, not zero.
  if [ -z "$ids_all" ] && { [ -n "$unreadable" ] || [ ! -d "$SAFARI_CONTAINER" ]; }; then
    note "browser · Safari" "$(app_bundle Safari)" \
      "extension list unavailable - absent, or not readable without Full Disk Access"
    return 0
  fi

  if [ -n "$ids_all" ]; then names="$(appex_names)"; fi
  while read -r id; do
    [ -n "$id" ] || continue
    name="$(printf '%s\n' "$names" | awk -v id="$id" '$1 == id { sub(/^[^ ]+ /, ""); print; exit }')"
    body="$body${name:-$id}"$'\n'
  done <<<"$ids_all"

  emit "browser · Safari" "$(app_bundle Safari)" extensions \
    "$(printf '%s' "$body" | { grep -v '^$' || true; } | sort -f)" always
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

# --- cargo --------------------------------------------------------------

# `cargo install` records each crate in .crates2.json, keyed by
# `<name> <version> (<source>+<url>)`. Reading it rather than listing
# ~/.cargo/bin keeps out stray binaries and gives the versions.
list_cargo() {
  local config="${CARGO_HOME:-$HOME/.cargo}/.crates2.json"
  [ -f "$config" ] || return 0
  emit "cargo · installed" "$config" crates "$(jq -r '
    (.installs // {})
    | keys[] as $key
    | (($key | capture("^(?<name>[^ ]+) (?<version>[^ ]+) \\((?<src>[a-z]+)\\+")?) // null) as $m
    | if $m == null then $key
      elif $m.src == "registry" then "\($m.name) (\($m.version))"
      else "\($m.name) (\($m.version), \($m.src))"
      end
  ' "$config" | sort -f)"
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

# --- fedora ---------------------------------------------------------------

# `--userinstalled` is dnf's analogue of `brew leaves`: packages explicitly
# requested rather than pulled in as a dependency of something else. This is
# the distro-owned layer `bootstrap.sh` provisions (nix itself, docker, the
# NVIDIA/Tuxedo drivers, ...); everything on top comes from the nix tiers.
list_fedora() {
  command -v dnf >/dev/null || return 0
  emit "fedora · dnf" dnf packages "$(dnf repoquery --userinstalled \
    --qf '%{name} (%{version}-%{release})\n' 2>/dev/null | sort -f)"
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

if [ "$FORMAT" = markdown ]; then
  printf '# Installed software\n\n%s — %s\n' "$(hostname)" "$(date '+%Y-%m-%d %H:%M')"
fi

if wanted nix; then list_nix && list_wrapped; fi
if wanted neovim; then list_lazy && list_mason; fi
if wanted browsers; then list_firefox && list_firefox_pwa && list_chromium && list_safari; fi
if wanted ai; then list_nix_mcp && list_claude && list_codex && list_opencode; fi
if wanted cargo; then list_cargo; fi
if wanted brew; then list_brew && list_mas; fi
if wanted fedora; then list_fedora; fi
if wanted projects; then list_projects; fi

case "$FORMAT" in
  plain) printf '%s' "$all" | sort -f -u ;;
  markdown) printf '\n---\n\n%s entries in total.\n' "$(printf '%s' "$all" | sort -f -u | wc -l)" ;;
  *) echo ;;
esac
