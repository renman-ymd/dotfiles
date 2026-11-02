{ config, lib, pkgs, ... }:
let
  cfg = config.renman-ymd.shell;
in
{
  options.renman-ymd.shell.enable = lib.mkEnableOption "Nushell, Starship, zoxide, carapace and a bare zsh login shell";

  config = lib.mkIf cfg.enable {
    # Nushell is the only interactive shell. zsh stays as the POSIX login shell
    # (modules/darwin/shell) but must stay bare, so no program may inject
    # prompts, completions or hooks into it -- opt every shell out by default
    # and let nushell back in.
    home.shell = {
      enableShellIntegration = false;
      enableNushellIntegration = true;
    };

    home.packages = with pkgs; [
      starship-jj
    ];

    # competion for common command like docker, cargo...
    programs.carapace = {
      enable = true;
      enableNushellIntegration = true;
    };

    # Login shell only -- interactive work happens in nushell (ghostty spawns
    # it directly). Keep this to the environment that login/non-nushell
    # consumers still need; no prompt, aliases, completions or plugins.
    programs.zsh = {
      enable = true;
      enableCompletion = false;   # nothing here to complete

      initContent = ''
        export EDITOR='emacs -nw -Q'
        export VISUAL='emacs -nw -Q'

        export BROWSER='zen-beta'
      '';
    };

    # nushell prompt
    programs.starship = {
      enable = true;
      enableNushellIntegration = true;
    };

    xdg.configFile = {
      "starship.toml".source = ./configs/starship.toml;
      "starship-jj/starship-jj.toml".source = ./configs/starship-jj.toml;
    };

    programs.zoxide = {
      enable = true;
      enableNushellIntegration = true;
      options = [ "--cmd" "cd" ];
    };

    # interactive only
    programs.nushell = {
      enable = true;
      loadSessionVariables = true;

      shellAliases = {
        cat = "bat --style=auto";
        la = "ls --all";
        ll = "ls --all --long";
        em = "emacsclient -s main -nw";
        emg = "emacsclient -s main -c";
        eml = "emacs -nw --init-dir ~/.config/emacs-light";
        # em-kill defined as def below: parenthesis interpretation
        # em-restart defined as def below: string interpolation
      };

      extraEnv = ''
        $env.PATH = ($env.PATH | prepend [
          ($env.HOME + "/.nix-profile/bin")
          "/etc/profiles/per-user/renman-ymd/bin"
          "/run/current-system/sw/bin"
          "/nix/var/nix/profiles/default/bin"
        ] | uniq)

        if ("SSH_CONNECTION" in $env) {
          $env.EDITOR = "nano"
          $env.VISUAL = "nano"
        } else {
          $env.EDITOR = (
            if ((^emacsclient -s main -e "t" | complete).exit_code) == 0 {
              "emacsclient -s main -nw"
            } else {
              "emacs -nw --init-dir ~/.config/emacs-light"
            }
          )
          $env.VISUAL = "emacsclient -s main -c"
        }
        $env.BROWSER = "zen-beta"
        $env.LESS = "-RFMiS --incsearch --use-color -j.5"
        $env.DELTA_PAGER = "less -RFEX --mouse --wheel-lines=3"

        $env.MANPAGER = "sh -c 'col -bx | bat -l man -p'"
        $env.MANROFFOPT = "-c"

        # $env.NU_LIB_DIRS = (
        #   $env.NU_LIB_DIRS? | default [] | append ($nu.default-config-dir | path join "completions")
        # )
      '';

      # After the zoxide, starship and carapace integrations Home Manager adds.
      extraConfig = lib.mkAfter ''
        source ~/.config/nushell/completions/jj.nu

        def copypath [] { $env.PWD | pbcopy }
        def copyfile [file: path] { open --raw $file | pbcopy }

        def google [query: string] {
          ^open $"https://www.google.com/search?q=($query | url encode)"
        }

        def extract [file: path] {
          let f = ($file | into string)
          if ($f | str ends-with ".tar.gz") or ($f | str ends-with ".tgz") {
            ^tar xzf $file
          } else if ($f | str ends-with ".tar.bz2") {
            ^tar xjf $file
          } else if ($f | str ends-with ".tar.xz") {
            ^tar xJf $file
          } else if ($f | str ends-with ".tar.zst") {
            ^tar --zstd -xf $file
          } else {
            match ($file | path parse | get extension) {
              "zip" => { ^unzip $file }
              "tar" => { ^tar xf $file }
              "gz" => { ^gunzip $file }
              "bz2" => { ^bunzip2 $file }
              "xz" => { ^xz -d $file }
              "7z" => { ^7z x $file }
              "rar" => { ^unrar x $file }
              $ext => { error make { msg: $"Unknown archive type: ($ext)" } }
            }
          }
        }

        def em-kill [] {
          ^emacsclient -s main --eval "(kill-emacs)"
        }

        def em-restart [] {
            ^launchctl kickstart -k $"gui/(^id -u | str trim)/org.gnu.emacs.daemon"
        }

        $env.config.keybindings ++= [{
          name: prepend_sudo
          modifier: alt
          keycode: char_s
          mode: [emacs vi_insert vi_normal]
          event: [
            { edit: MoveToStart }
            { edit: InsertString, value: "sudo " }
          ]
        }]

        # show directory content after every cd
        $env.config.hooks.env_change.PWD ++= [{|before, after|
          if $before != null {
            print $after
            ls --all --short-names | print
          }
        }]
      '';
    };

    # Generate jj nushell completions script
    home.activation.jjNushellCompletions = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p "$HOME/.config/nushell/completions"
      ${pkgs.jujutsu}/bin/jj util completion nushell > "$HOME/.config/nushell/completions/jj.nu"
    '';
  };
}
