{ config, lib, pkgs, ... }:
let
  cfg = config.renman-ymd.vcs;
in
{
  options.renman-ymd.vcs.enable = lib.mkEnableOption "jj, git, delta, hunk, gh and lazygit";

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      lazygit
      difftastic
    ];

    xdg.configFile."jj/scripts/pr-create.nu" = {
      source = ./pr-create.nu;
      executable = true;
    };

    programs.nushell = {
      extraEnv = builtins.readFile ./env.nu;
      extraConfig = lib.mkAfter (builtins.readFile ./config.nu);
    };

    # Generate jj nushell completions script
    home.activation.jjNushellCompletions = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p "$HOME/.config/nushell/completions"
      ${pkgs.jujutsu}/bin/jj util completion nushell > "$HOME/.config/nushell/completions/jj.nu"
    '';

    programs.delta = {
      enable = true;
      options = {
        navigate = true;
        dark = true;
        tabs = 2;
        syntax-theme = "Catppuccin Macchiato";
      };
    };

    programs.hunk = {
      enable = true;
      settings = {
        theme = "catppuccin-latte";
        mode = "auto";
        wrap_lines = true;
        sidebar = true;
        line_numbers = true;
        agent_notes = true;
        hunk_metadata = false;
      };
    };

    programs.git = {
      enable = true;

      ignores = [
        # --- macOS ---
        ".DS_Store"
        ".AppleDouble"
        ".LSOverride"
        "Icon\r"           # Icon must end with two \r
        "._*"
        ".DocumentRevisions-V100"
        ".fseventsd"
        ".Spotlight-V100"
        ".TemporaryItems"
        ".Trashes"
        ".VolumeIcon.icns"
        ".com.apple.timemachine.donotpresent"
        ".AppleDB"
        ".AppleDesktop"
        "Network Trash Folder"
        "Temporary Items"
        ".apdisk"
        "*.icloud"

        # --- Emacs ---
        "*~"
        "\\#*\\#"
        "/.emacs.desktop"
        "/.emacs.desktop.lock"
        "*.elc"
        "auto-save-list"
        "tramp"
        ".\\#*"
        ".org-id-locations"
        "*_archive"
        ".dir-locals.el"
        ".projectile"

        # --- VSCode ---
        ".vscode/*"
        "!.vscode/settings.json"
        "!.vscode/tasks.json"
        "!.vscode/launch.json"
        "!.vscode/extensions.json"
        ".history/"

        # --- Nix ---
        "result"
        "result-*"
        ".direnv"

        # --- General ---
        "*.log"
        ".env"
        ".env.local"
        "*.orig"
        "*.rej"
        ".claude/*"
      ];
    };

    # HM auto inject merge-tools.ediff because emacs is enabled
    programs.jujutsu = {
      enable = true;

      settings = {
        user = {
          name = "Renaud Manet";
          email = "renaud.manet@epitech.eu";
        };

        signing = {
          backend = "gpg";
          key = "CB49EE78601E1E1B";
          behavior = "force";
        };

        ui = {
          editor = "emacs -nw --init-dir ~/.config/emacs-light";
          default-command = [ "log" "-n" "10" ];
          graph.style = "square";
          # jj pipes into the pager, so read the width from the terminal itself
          pager = "${pkgs.writeShellScript "delta-auto-side-by-side" ''
            cols=$(stty size 2> /dev/null < /dev/tty | cut -d ' ' -f 2)
            if [ "''${cols:-0}" -ge 160 ]; then
              exec delta --side-by-side "$@"
            fi
            exec delta "$@"
          ''}";
          conflict-marker-style = "git";
          diff-formatter = ":git";
          show-cryptographic-signatures = true;
          diff-editor = ":builtin";
        };

        templates.log_node = ''
          coalesce(
            if(!self, label("elided", "🮀")),
            if(current_working_copy, label("working_copy", "@")),
            if(root, label("root", "┴")),
            if(self && !current_working_copy && !immutable && !conflict && in_branch(self),
              label("not_tracked", "◇")
            ),
            if(immutable, label("immutable", "●"), label("normal", "○")),
          )
        '';

        "template-aliases" = {
          "in_branch(commit)" = ''commit.contained_in("immutable_heads()..bookmarks()")'';
        };

        colors = {
          "node" = { bold = true; };
          "node elided" = { fg = "bright black"; };
          "node working_copy" = { fg = "green"; };
          "node not_tracked" = { bold = false; };
          "node immutable" = { fg = "bright cyan"; };
          "node normal" = { bold = false; };
          "node root" = { fg = "bright white"; };
        };

        aliases = {
          logs = [ "log" "-r::all()" "--no-pager" ];
          track = [ "bookmark" "track" ];
          # Using zsh over nu as the one-liner need command line args
          # which nu do not allow in one-liner, only in script
          branch = [ "util" "exec" "--" "zsh" "-c" ''
            jj bookmark create "$1";
            jj bookmark track "$1";
          '' "jj branch-create" ];
          pr-create = ["util" "exec" "--" "nu" "~/.config/jj/scripts/pr-create.nu"];
          fetch = [ "git" "fetch" ];
          tug = [ "bookmark" "move" "--from" "heads(::@- & bookmarks())" "--to" "@-" ];
          push = [ "util" "exec" "--" "nu" "-c" "jj tug; jj git push"];
          difft = [ "diff" "--tool" "difft" ];
          diff-in = [ "diff" "--tool" "difft-inline" ];
          hpager = [ "--config" "ui.pager=hunk pager" ];
          sbs = [ "--config" "ui.pager=delta --side-by-side" ];
          unified = [ "--config" "ui.pager=delta" ];
        };

        revsets = {
          log = "present(@) | ancestors(immutable_heads().., 3) | present(trunk())";
          "immutable_heads()" = "builtin_immutable_heads() | remote_bookmarks()";
        };

        "revset-aliases" = {
          obkm = "::remote_bookmarks() | ::@";
          bkm = "::bookmarks() | ::@";
        };

        "merge-tools" = {
          difft.diff-args = [ "--color=always" "--display=side-by-side" "$left" "$right" ];
  	difft-inline.diff-args = [ "--color=always" "--display=inline" "$left" "$right" ];
          meld.merge-args = [ "$left" "$base" "$right" "-o" "$output" "--auto-merge" ];
        };

        git = {
          sign-on-push = true;
          subprocess = true;
          colocate = false;
        };
      };
    };

    programs.gh = {
      enable = true;
      settings.git_protocol = "ssh";
      settings.editor = "emacs -nw --init-dir ~/.config/emacs-light";
    };
  };
}
