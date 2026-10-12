# patchelf --set-interpreter points this binary at the host's own glibc
# loader: snx-rs-gui dlopens libwayland-client, libxkbcommon and EGL/GL at
# runtime, and loading the host's copies of those under nix's own (different)
# loader failed with cascading undefined-symbol errors. The host's own loader
# always matches the host's own libraries, so this holds regardless of which
# glibc happens to be newer.
#
# NixOS doesn't need this (its loader already matches the closure) and is
# detected via /etc/NIXOS, not `-e /lib64/ld-linux-x86-64.so.2` -- nix-ld's
# shim lives at that same path.
#
# RPATH only aliases libsqlite3.so -> the host's libsqlite3.so.0: that's the
# one DT_NEEDED entry (verified via `readelf -d`) the host doesn't already
# satisfy under its own soname, since Fedora ships the unversioned name only
# with sqlite-devel installed. Everything else loads straight from /lib64.
{
  pkgs,
  lib,
}:
pkgs.symlinkJoin {
  name = "snx-rs-wrapped-${pkgs.snx-rs.version}";
  paths = [pkgs.snx-rs];
  nativeBuildInputs = [pkgs.patchelf];
  postBuild = ''
          rm $out/bin/snx-rs-gui
          cp ${pkgs.snx-rs}/bin/.snx-rs-gui-wrapped $out/bin/.snx-rs-gui-real-fhs
          chmod +w $out/bin/.snx-rs-gui-real-fhs
          mkdir -p $out/lib/host-sqlite-compat
          ln -s /lib64/libsqlite3.so.0 $out/lib/host-sqlite-compat/libsqlite3.so
          patchelf \
            --set-interpreter /lib64/ld-linux-x86-64.so.2 \
            --set-rpath "$out/lib/host-sqlite-compat" \
            $out/bin/.snx-rs-gui-real-fhs
          cat >$out/bin/snx-rs-gui <<'WRAPPER'
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -e /etc/NIXOS ]; then
      # hardware.graphics.enable already populates /run/opengl-driver.
      export LD_LIBRARY_PATH="${lib.makeLibraryPath [pkgs.wayland pkgs.libxkbcommon]}:/run/opengl-driver/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
      # Hybrid Intel/NVIDIA hosts default to NVIDIA's EGL, which rejects
      # this compositor's display handle; force Mesa since this GUI needs
      # no GPU power.
      if [ -e /run/opengl-driver/share/glvnd/egl_vendor.d/50_mesa.json ]; then
        export __EGL_VENDOR_LIBRARY_FILENAMES=/run/opengl-driver/share/glvnd/egl_vendor.d/50_mesa.json
      fi
      exec ${pkgs.snx-rs}/bin/snx-rs-gui "$@"
    else
      # Hybrid Intel/NVIDIA hosts default to NVIDIA's EGL, which rejects
      # this compositor's display handle; force Mesa since this GUI needs
      # no GPU power.
      if [ -e /usr/share/glvnd/egl_vendor.d/50_mesa.json ]; then
        export __EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/50_mesa.json
      fi
      exec ${builtins.placeholder "out"}/bin/.snx-rs-gui-real-fhs "$@"
    fi
    WRAPPER
          chmod +x $out/bin/snx-rs-gui
  '';
}
