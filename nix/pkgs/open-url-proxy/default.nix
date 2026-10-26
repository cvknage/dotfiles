# Lets a sandboxed agent ask the host to open an http(s) URL in the host browser; see main.go.
{
  buildGoModule,
  lib,
}:
buildGoModule {
  pname = "open-url-proxy";
  version = "0.1.0";

  src = lib.cleanSource ./.;

  vendorHash = null;

  # shims/ holds only the opener-named links, so it alone can go on the sandbox PATH.
  postInstall = ''
    mkdir -p $out/shims
    for name in xdg-open open sensible-browser; do
      ln -s ../bin/open-url-proxy $out/shims/$name
    done
  '';

  meta = {
    description = "Unix-socket proxy that opens http(s) URLs in the host browser for sandboxed agents";
    mainProgram = "open-url-proxy";
  };
}
