{
  config,
  dotfiles,
  homeContext,
  lib,
  ...
}: let
  # Session-continuity rituals shared by every agent (Claude, Codex, OpenCode),
  # symlinked from the live checkout so edits need no rebuild. The set is read
  # from the flake source -- the `dotfiles` symlink is out-of-store, unreadable
  # in pure eval.
  ritualSkills = builtins.filter (name: !lib.hasPrefix "." name) (builtins.attrNames (builtins.readDir ../../../../../agents/skills));
  skillSource = name: "${dotfiles}/agents/skills/${name}";
in {
  home.file = lib.mkMerge [
    # Claude Code reads personal skills from its own config root.
    (lib.listToAttrs (map (name: {
        name = ".claude/skills/${name}";
        value.source = skillSource name;
      })
      ritualSkills))

    # Codex discovers user-level skills from the shared agents directory.
    (lib.listToAttrs (map (name: {
        name = ".agents/skills/${name}";
        value.source = skillSource name;
      })
      ritualSkills))

    # OpenCode follows the agent on work hosts, where it is disabled.
    (lib.listToAttrs (map (name: {
        name = "${config.xdg.configHome}/opencode/skills/${name}";
        value = {
          enable = !(homeContext.isWork config);
          source = skillSource name;
        };
      })
      ritualSkills))
  ];
}
