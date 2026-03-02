{lib}: let
  toAttrSet = value: patterns:
    lib.listToAttrs (map (pattern: {
        name = pattern;
        inherit value;
      })
      patterns);

  wrapClaudeBash = patterns: map (pattern: "Bash(${pattern})") patterns;

  repoScopePatterns = repoScopes:
    lib.flatten (map (dir: [
        "${dir}"
        "${dir}/**"
      ])
      repoScopes);

  mkOpencodeScopedPathRules = repoScopes:
    lib.listToAttrs (map (pattern: {
        name = "* ${pattern}";
        value = "allow";
      })
      (repoScopePatterns repoScopes));

  mkClaudeScopedPathRules = repoScopes:
    map (pattern: "Bash(* ${pattern})") (repoScopePatterns repoScopes);

  mkOpencodeBashPermissions = permissions: let
    base = {"*" = "deny";};
    allowRules = toAttrSet "allow" permissions.bash.allow;
    askRules = toAttrSet "ask" permissions.bash.ask;
    denyRules = toAttrSet "deny" permissions.bash.deny;
  in
    base
    // allowRules
    // askRules
    // denyRules;

  mkClaudeBashPermissions = permissions: {
    allow = wrapClaudeBash permissions.bash.allow;
    ask = wrapClaudeBash permissions.bash.ask;
    deny = wrapClaudeBash permissions.bash.deny;
  };
in {
  inherit
    mkClaudeBashPermissions
    mkClaudeScopedPathRules
    mkOpencodeScopedPathRules
    mkOpencodeBashPermissions
    ;
}
