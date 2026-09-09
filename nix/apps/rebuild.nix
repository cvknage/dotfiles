# The linux counterpart of darwin-rebuild: applies both tiers of the matching
# linuxConfigurations machine and installs <distro>-rebuild on the box's PATH.
#
#   linux-rebuild <action> [<distro>] [<machine>] [--flake <path>[#<machine>]]
#
# The action is switch (apply both tiers) or build (build them without
# switching). The machine defaults to the box's short hostname; the distro is
# read from the machine's bundle and never assumed.
{
  inputs,
  name,
  pkgs,
  system,
}: let
  lib = pkgs.lib;
in
  pkgs.writeShellApplication {
    inherit name;
    meta.description = "Install <distro>-rebuild and apply the System Manager and Home Manager tiers";
    runtimeInputs = [
      inputs.system-manager.packages.${system}.default
    ];
    text = ''
      # init.sh symlinks ~/.dotfiles to this checkout, and each tier appends
      # its own attribute, so the path must not carry one.
      flake_ref="$HOME/.dotfiles/nix"

      machine=""

      while [ $# -gt 0 ]; do
        case "$1" in
          --flake)
            flake_ref="$2"
            shift 2
            ;;
          *)
            if [ -z "$action" ]; then
              action="$1"
            fi
            shift
            ;;
        esac
      done

      case "$action" in
        switch | build) ;;
        *)
          echo "Usage: ${name} <action> [--flake <path>[#<machine>]]" >&2
          echo "  action: switch (apply both tiers) or build (build without switching)" >&2
          exit 1
          ;;
      esac

      # Split the flake ref on '#': the part before it is the flake, the part
      # after it the machine. A local flake path must not carry a trailing
      # tier attribute.
      case "$flake_ref" in
        *\#*)
          flake="''${flake_ref%%\#*}"
          machine="''${flake_ref##*\#}"
          ;;
        *)
          flake="$flake_ref"
          ;;
      esac
      if [ -d "$flake" ]; then
        flake="$(cd "$flake" && pwd)"
      fi
      if [ -z "$machine" ]; then
        machine="$(hostname -s)"
      fi

      # Fail loudly, with the configured machines, when the target is not one
      # of them. The distro is never assumed: it is read from the machine's
      # bundle and names the installed command.
      distro="$(nix eval --raw "$flake#linuxConfigurations.$machine.distro" 2>/dev/null)" || {
        echo "Unknown machine '$machine' for ${name}." >&2
        echo "Configured machines: $(nix eval --json "$flake#linuxConfigurations" --apply 'builtins.attrNames' 2>/dev/null)" >&2
        exit 1
      }

      # Fedora's SELinux policy has no fcontext for /nix/store, so systemd
      # (init_t) is denied read access to unit files and drop-ins, and denied
      # execute access to ExecStart scripts, that System Manager symlinks in
      # from the store (nix/README.md's Fedora section). bootstrap.sh
      # registers the store-wide fcontext spec once, but each generation's
      # changed paths land at new store paths, so build first and relabel
      # that closure before System Manager activates it.
      #
      # --no-eval-cache: this build and System Manager's own internal build of
      # the same attribute, moments later, both otherwise touch the flake
      # eval-cache database at nearly the same time and print harmless but
      # noisy "SQLite database is busy" lines. Nix already ignores that error
      # and re-evaluates; skipping the cache on our side avoids the race.
      if [ "$(nix eval --json "$flake#linuxConfigurations.$machine.selinux")" = true ]; then
        echo "==> Relabeling System Manager units for SELinux: $flake#linuxConfigurations.$machine.system"
        selinux_out="$(nix build "$flake#linuxConfigurations.$machine.system" --no-link --no-eval-cache --print-out-paths)"
        mapfile -t selinux_closure < <(nix-store -qR "$selinux_out")
        sudo restorecon -RF "''${selinux_closure[@]}"
      fi

      # home-manager switch, spelled out: build the machine's home tier and
      # run its activate script (the home configuration is built into the
      # machine bundle, so there is no homeConfigurations attr to point
      # --flake at).
      echo "==> Home Manager: $flake#linuxConfigurations.$machine.home"
      home_out="$(nix build "$flake#linuxConfigurations.$machine.home.activationPackage" --no-link --print-out-paths)"

      if [ "$action" = build ]; then
        echo "==> Built both tiers without switching."
        echo "    System Manager: $selinux_out"
        echo "    Home Manager:   $home_out"
        exit 0
      fi

      echo "==> System Manager: $flake#linuxConfigurations.$machine.system"
      scratch="$(mktemp -d)"
      (cd "$scratch" && system-manager switch --flake "$flake#linuxConfigurations.$machine.system" --sudo)
      rm -rf "$scratch"

      "$home_out/activate"

      # Install the distro-specific rebuild command, so later runs skip
      # `nix run` like darwin-rebuild. It is a pure pass-through: the target
      # machine is the box's own short hostname on every run, so a wrong-box
      # run fails loudly instead of applying another machine's tiers.
      install_dir="$HOME/.local/bin"
      mkdir -p "$install_dir"
      printf '#!/usr/bin/env bash\nexec nix run "$HOME/.dotfiles/nix#%s" -- "$@"\n' "${name}" >"$install_dir/''${distro}-rebuild"
      chmod +x "$install_dir/''${distro}-rebuild"
      case ":$PATH:" in
        *":$install_dir:"*) ;;
        *) echo "Note: add $install_dir to PATH to use ''${distro}-rebuild directly." >&2 ;;
      esac
    '';
  }
