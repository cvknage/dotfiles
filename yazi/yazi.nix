{pkgs, ...}: let

  /* Manage plugins with ya pack CLI
  yazi-plugins = pkgs.fetchFromGitHub {
    # https://github.com/yazi-rs/plugins
    owner = "yazi-rs";
    repo = "plugins";
    rev = "c7feb90930a20ac8782305ed28ab4d9715124833";
    hash = "sha256-Q+i1U+2uNlThf3+fFMUkWk9m7ZJ4z0mwVsrmqPFKVcE=";
  };
  toggle-view = pkgs.fetchFromGitHub {
    # https://github.com/dawsers/toggle-view.yazi
    owner = "dawsers";
    repo = "toggle-view.yazi";
    rev = "9ae57f904d616f4462e829521ec1ad10727ec7ed";
    hash = "sha256-LBL+pCsnEt9bneiNYeVem6TvhRlk6eB5k/qD0+N2Tj8=";
  };
  */

in {
  programs.yazi = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;
    shellWrapperName = "y";

    /* Manage plugins with ya pack CLI
    settings = {
      manager = {
        show_hidden = true;
      };
      preview = {
        max_width = 2500;
        max_height = 2500;
      };
    };

    initLua = ''
      require("session"):setup {
        sync_yanked = true,
      }
    '';

    keymap = {
      manager.prepend_keymap = [
        {
          on = "T";
          run = "plugin max-preview";
          desc = "Maximize or restore the preview pane";
        }
        {
          on = ["c" "m"];
          run = "plugin chmod";
          desc = "Chmod on selected files";
        }
        {
          on = ["u" "p"];
          run = "plugin toggle-view --args=parent";
          desc = "UI toggle parent";
        }
        {
          on = ["u" "P"];
          run = "plugin toggle-view --args=preview";
          desc = "UI toggle Preview";
        }
      ];
    };

    plugins = {
      chmod = "${yazi-plugins}/chmod.yazi";
      max-preview = "${yazi-plugins}/max-preview.yazi";
      toggle-view = "${toggle-view}";
    };
    */

  };
}
