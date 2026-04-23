{lib}: let
  toAttrSet = value: patterns:
    lib.listToAttrs (map (pattern: {
        name = pattern;
        inherit value;
      })
      patterns);

  wrapClaudeBash = patterns: map (pattern: "Bash(${pattern})") patterns;

  stripTrailingCommandWildcard = pattern:
    if lib.hasSuffix " *" pattern
    then lib.removeSuffix " *" pattern
    else pattern;

  isCodexConvertiblePattern = pattern: let
    normalized = stripTrailingCommandWildcard pattern;
  in
    normalized
    != ""
    && !(lib.hasInfix "*" normalized)
    && !(lib.hasInfix "?" normalized)
    && !(lib.hasInfix "[" normalized)
    && !(lib.hasInfix "]" normalized);

  splitCommandTokens = pattern:
    lib.filter (token: token != "") (lib.splitString " " (stripTrailingCommandWildcard pattern));

  hasTokenPrefix = prefixTokens: commandTokens:
    builtins.length prefixTokens
    <= builtins.length commandTokens
    && lib.take (builtins.length prefixTokens) commandTokens == prefixTokens;

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

  mkCodexExecPolicyRules = permissions: let
    normalizePatterns = patterns:
      lib.unique (map stripTrailingCommandWildcard (builtins.filter isCodexConvertiblePattern patterns));

    promptAndDenyTokens = map splitCommandTokens (normalizePatterns (permissions.bash.ask ++ permissions.bash.deny));

    allowPatterns = builtins.filter (pattern: let
      tokens = splitCommandTokens pattern;
    in
      !builtins.any (otherTokens:
        builtins.length otherTokens < builtins.length tokens && hasTokenPrefix otherTokens tokens)
      promptAndDenyTokens)
    (normalizePatterns permissions.bash.allow);

    promptPatterns = normalizePatterns permissions.bash.ask;
    denyPatterns = normalizePatterns permissions.bash.deny;

    unsupportedPatterns = lib.unique (builtins.filter (pattern: !isCodexConvertiblePattern pattern) (
      permissions.bash.allow ++ permissions.bash.ask ++ permissions.bash.deny
    ));

    mkRule = decision: pattern: let
      tokens = splitCommandTokens pattern;
    in "prefix_rule(pattern = ${builtins.toJSON tokens}, decision = \"${decision}\")";

    ruleLines =
      (map (mkRule "forbidden") denyPatterns)
      ++ (map (mkRule "prompt") promptPatterns)
      ++ (map (mkRule "allow") allowPatterns);

    unsupportedComments = map (pattern: "# Unsupported Codex execpolicy pattern omitted: ${pattern}") unsupportedPatterns;
  in
    lib.concatLines (
      [
        "# Generated from nix/modules/home/agents/command-permissions.nix"
        "# Mirrors shared bash permissions as closely as Codex execpolicy allows."
      ]
      ++ unsupportedComments
      ++ [""]
      ++ ruleLines
    );
in {
  inherit
    mkClaudeBashPermissions
    mkClaudeScopedPathRules
    mkCodexExecPolicyRules
    mkOpencodeScopedPathRules
    mkOpencodeBashPermissions
    ;
}
