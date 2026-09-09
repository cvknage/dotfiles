# Enforces the agent sandbox's deniedPaths policy at the Docker Engine API layer; see main.go for why.
{
  buildGoModule,
  lib,
}:
buildGoModule {
  pname = "docker-agent-proxy";
  version = "0.1.0";

  src = lib.cleanSource ./.;

  vendorHash = null;

  meta = {
    description = "Docker Engine API proxy enforcing the agent sandbox's bind-mount denylist";
    mainProgram = "docker-agent-proxy";
  };
}
