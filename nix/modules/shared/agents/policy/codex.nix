{
  lib,
  paths,
}: let
  commands = import ./commands.nix;
  trustedProjects = lib.listToAttrs (
    map (root: {
      name = root;
      value = {trust_level = "trusted";};
    })
    paths.workspaceRoots
  );
  toCommandTokens = prefix:
    lib.filter (token: token != "") (lib.splitString " " prefix);
  toCodexRule = decision: prefix: "prefix_rule(pattern = ${builtins.toJSON (toCommandTokens prefix)}, decision = \"${decision}\")";
in {
  settings = {
    approval_policy = "on-request";
    sandbox_mode = "danger-full-access";
    # Nix owns the workspace trust entries so rebuilds do not wipe them.
    projects = trustedProjects;
  };
  requirements = {
    allowed_approval_policies = ["on-request"];
    allowed_sandbox_modes = ["read-only" "danger-full-access"];
  };
  rules = lib.concatLines (
    (map (toCodexRule "forbidden") commands.deny)
    ++ (map (toCodexRule "prompt") commands.ask)
  );
}
