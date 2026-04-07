{pkgs, ...}: let
  claudeIcon = pkgs.fetchurl {
    url = "https://uxwing.com/wp-content/themes/uxwing/download/brands-and-social-media/claude-ai-icon.png";
    sha256 = "sha256-OZU3i6GPgtPgz8qfTG2tCcndcTqac00ZWEclww+jdTY=";
  };

  runtimeDeps = with pkgs; [
    stable.electron
    nodejs
    python3
    p7zip
    bubblewrap
    curl
    coreutils
    gnused
    gawk
    gnugrep
    findutils
    file
    dbus
    git
    asar
    xdotool # For window focusing
    procps # For pgrep
  ];

  claude-cowork-linux = pkgs.stdenv.mkDerivation {
    pname = "claude-cowork-linux";
    version = "unstable";

    src = pkgs.fetchFromGitHub {
      owner = "johnzfitch";
      repo = "claude-cowork-linux";
      rev = "master";
      hash = "sha256-RKCLi/t+Uio0Z+LTONiHz0LT2Y72zWwt+mNFQDvbnOs=";
    };

    nativeBuildInputs = with pkgs; [makeWrapper];

    dontBuild = true;

    installPhase = ''
            runHook preInstall

            mkdir -p $out/share/claude-cowork-linux
            cp -r . $out/share/claude-cowork-linux/

            mkdir -p $out/bin

            # Setup script - copies repo to writable location and runs install
            cat > $out/bin/claude-cowork-setup << 'SETUP_EOF'
      #!/usr/bin/env bash
      set -e

      INSTALL_DIR="$HOME/.local/share/claude-cowork-linux"
      REPO_SRC="@out@/share/claude-cowork-linux"

      echo "Setting up Claude Cowork Linux..."
      echo "Source: $REPO_SRC"
      echo "Destination: $INSTALL_DIR"

      # Copy repo to writable location
      mkdir -p "$INSTALL_DIR"
      rm -rf "$INSTALL_DIR"/*
      cp -r "$REPO_SRC"/* "$INSTALL_DIR/"
      chmod -R u+w "$INSTALL_DIR"

      # Run the install script from the writable location
      cd "$INSTALL_DIR"
      exec ./install.sh "$@"
      SETUP_EOF
            substituteInPlace $out/bin/claude-cowork-setup --replace "@out@" "$out"
            chmod +x $out/bin/claude-cowork-setup
            wrapProgram $out/bin/claude-cowork-setup \
              --prefix PATH : ${pkgs.lib.makeBinPath runtimeDeps}

            # Launcher script - runs from the actual install location
            cat > $out/bin/claude-desktop << 'LAUNCH_EOF'
      #!/usr/bin/env bash
      INSTALL_DIR="$HOME/.local/share/claude-desktop"

      if [ ! -d "$INSTALL_DIR" ] || [ ! -f "$INSTALL_DIR/launch.sh" ]; then
          echo "Claude Cowork Linux not set up. Run 'claude-cowork-setup' first."
          exit 1
      fi

      # Check if Claude electron is already running
      EXISTING_PID=$(pgrep -f "\.asar-cache/app\.asar" | head -1)

      if [ -n "$EXISTING_PID" ]; then
          echo "Claude Desktop already running (PID: $EXISTING_PID)"

          # Focus existing window
          xdotool search --class "Claude" windowactivate 2>/dev/null || true

          # If we have a URL, run electron again to trigger second-instance event
          if [ -n "$1" ] && [[ "$1" == claude://* ]]; then
              echo "Passing URL to running instance: $1"
              cd "$INSTALL_DIR"
              # Run electron directly with URL - skip full setup
              # This triggers Electron's second-instance mechanism
              electron ".asar-cache/app.asar" --no-sandbox "$1" 2>/dev/null &
              # Give it a moment to signal the first instance, then it should quit
              sleep 1
          fi
          exit 0
      fi

      cd "$INSTALL_DIR"
      exec ./launch.sh "$@"
      LAUNCH_EOF
            chmod +x $out/bin/claude-desktop
            wrapProgram $out/bin/claude-desktop \
              --prefix PATH : ${pkgs.lib.makeBinPath runtimeDeps}

            # Install icon
            mkdir -p $out/share/icons/hicolor/512x512/apps
            cp ${claudeIcon} $out/share/icons/hicolor/512x512/apps/claude.png

            runHook postInstall
    '';

    meta = with pkgs.lib; {
      description = "Claude Desktop with Cowork support for Linux";
      homepage = "https://github.com/johnzfitch/claude-cowork-linux";
      license = licenses.mit;
      platforms = ["x86_64-linux"];
    };
  };
in {
  home.packages = [
    claude-cowork-linux
  ];

  xdg.desktopEntries.claude-desktop = {
    name = "Claude";
    comment = "AI assistant by Anthropic";
    exec = "claude-desktop %U";
    icon = "claude";
    terminal = false;
    type = "Application";
    categories = ["Utility" "Development"];
    mimeType = ["x-scheme-handler/claude"];
    settings = {
      StartupWMClass = "Claude";
    };
  };
}
