{lib}: let
  names = ["private" "work"];
in
  lib.genAttrs names (name:
    {inherit name;}
    // lib.listToAttrs (map (other: lib.nameValuePair "is${lib.toSentenceCase other}" (name == other)) names))
