{
  lib,
  orderBefore,
  paths,
}: let
  commands = import ./commands.nix;
  inherit (paths) agentPaths opencodeGlobalSettingsPaths opencodeProjectSettingsPaths;
  expandCommandPrefixes = lib.concatMap (prefix: [prefix "${prefix} *"]);
  toAttrs = value: list:
    lib.listToAttrs (map (path: {
        name = path;
        inherit value;
      })
      list);
  toOpencodeRules = effect: prefixes: toAttrs effect (expandCommandPrefixes prefixes);
  withDefaultRuleFirst = fallback: rules:
    {
      "*" = orderBefore (builtins.attrNames rules) fallback;
    }
    // rules;
  readRules = {
    "${agentPaths.opencode.authFile}" = "deny";
  };
  editRules =
    toAttrs "ask" opencodeProjectSettingsPaths
    // toAttrs "deny" opencodeGlobalSettingsPaths;
  externalDirectoryRules = lib.foldl' lib.recursiveUpdate {} (map (path: {
      "${path}" = "allow";
      "${path}/**" = "allow";
    })
    agentPaths.opencode.trustedRoots);
  bashRules =
    toOpencodeRules "ask" commands.ask
    // toOpencodeRules "deny" commands.deny;
in {
  settings = {
    "$schema" = "https://opencode.ai/config.json";
    permission = withDefaultRuleFirst "ask" {
      "context7_*" = "allow";
      "nixos_*" = "allow";
      bash = withDefaultRuleFirst "allow" bashRules;
      doom_loop = "ask";
      edit = withDefaultRuleFirst "allow" editRules;
      external_directory = withDefaultRuleFirst "deny" externalDirectoryRules;
      glob = "allow";
      grep = "allow";
      list = "allow";
      lsp = "allow";
      question = "allow";
      read = withDefaultRuleFirst "allow" readRules;
      skill = "allow";
      task = "allow";
      todowrite = "allow";
      webfetch = "allow";
      websearch = "allow";
    };
  };
}
