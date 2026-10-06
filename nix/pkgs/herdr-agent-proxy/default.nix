# A deny-by-default proxy in front of herdr's control socket; see main.go for why the real socket
# can never be bound straight into the agent sandbox.
{
  buildGoModule,
  lib,
}:
buildGoModule {
  pname = "herdr-agent-proxy";
  version = "0.1.0";

  src = lib.cleanSource ./.;

  vendorHash = null;

  meta = {
    description = "herdr control-socket proxy enforcing the agent sandbox's method allowlist and shell-level jail handoff";
    mainProgram = "herdr-agent-proxy";
  };
}
