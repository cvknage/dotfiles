if command -v nixos-rebuild >/dev/null; then
  OS="NixOS"
else
  OS="$(uname)"
fi
case $OS in
  "NixOS")
    ;;
  "Darwin")
    ln -s $(pwd)/au-lab/AUGraphicEQ/* ~/Library/Audio/Presets/Apple/AUGraphicEQ/
    ln -s $(pwd)/au-lab/AUNBandEQ/* ~/Library/Audio/Presets/Apple/AUNBandEQ/
    ;;
  *)
    ;;
esac

