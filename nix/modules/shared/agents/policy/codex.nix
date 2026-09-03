{lib}: let
  commands = import ./commands.nix;
  toCommandTokens = prefix:
    lib.filter (token: token != "") (lib.splitString " " prefix);
  toCodexRule = decision: prefix: "prefix_rule(pattern = ${builtins.toJSON (toCommandTokens prefix)}, decision = \"${decision}\")";
in {
  settings = {
    approval_policy = "on-request";
    sandbox_mode = "danger-full-access";
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
