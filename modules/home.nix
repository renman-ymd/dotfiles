{ pkgs, lib, ... }: {

  home.stateVersion = "25.11";

  home.packages = with pkgs; [
    # --- Language runtimes ---
    go
    rustc
    cargo
    clippy
    rustfmt
    python3
    ghc
    cabal-install
    bun
    nodejs
    zig
    jdk
    kotlin
    # odin           # installed via homebrew; nixpkgs lacks maintenance

    # --- C/C++ extras ---
    # clang/clang++ and make are already provided by Xcode CLT
    cmake
    meson
    ninja

    # --- Language servers ---
    gopls
    rust-analyzer
    pyright
    haskell-language-server
    typescript-language-server
    zls
    clang-tools
    kotlin-language-server
    nil

    # --- CLI utilities ---
    ripgrep
    fd
    bat
    eza
    jq
    fzf
    htop
    lazygit
    difftastic

    # --- Markdown viewers ---
    glow        # TUI/Pager
    frogmouth   # Full TUI browser
    go-grip     # Browser preview + live reload

    # --- Document & media ---
    pandoc
    poppler
    wakatime-cli # Private key to write to ~/.wakatime.cfg

    # --- Miscellaneous ---
    vesktop
    starship-jj
    alt-tab-macos
    maccy
    pinentry_mac
    glibtool
  ];

  home.file.".gnupg/gpg-agent.conf".text = ''
    pinentry-program ${pkgs.pinentry_mac}/bin/pinentry-mac
    default-cache-ttl 600
    max-cache-ttl 7200
  '';

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;   # faster nix-shell
  };

  # competion for common command like docker, cargo...
  programs.carapace = {
    enable = true;
    enableNushellIntegration = true;
  };

  # login shell with oh-my-zsh
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    shellAliases = {
      ls = "eza --icons --git";
      tree = "eza --tree --icons --git";
      cat = "bat --style=auto";
      em = "emacsclient -s main -nw";
      emg = "emacsclient -s main -c";
      eml = "emacs -nw --init-dir ~/.config/emacs-light";
      em-kill = "emacsclient -s main --eval '(kill-emacs)'";
      em-restart = ''launchctl kickstart -k "gui/$(id -u)/org.gnu.emacs.daemon"'';
    };

    # initExtraBeforeCompInit = ''
    #   fpath=(${pkgs.zsh-completions}/share/zsh/site-functions $fpath)
    # '';

    plugins = [
      {
        name = "you-should-use";
        src = pkgs.zsh-you-should-use;
        file = "share/zsh/plugins/you-should-use/you-should-use.plugin.zsh";
      }
    ];

    oh-my-zsh = {
      enable = true;
      plugins = [
        "docker"
        "rust"
        "golang"
        "python"
        "bun"
        "history"
        "copypath"
        "copyfile"
        "web-search"
        "extract"
        "sudo"
      ];
    };

    initContent = ''
      if [[ -n $SSH_CONNECTION ]]; then
        export EDITOR='nano'
        export VISUAL='nano'
      else
        if emacsclient -s main -e t &>/dev/null 2>&1; then
          export EDITOR='emacsclient -s main -nw'
        else
          export EDITOR='emacs -nw --init-dir ~/.config/emacs-light'
        fi
        export VISUAL='emacsclient -s main -c'
      fi

      export BROWSER='zen-beta'

      export LESS="-RFMiS --incsearch --use-color -j.5"
      export DELTA_PAGER="less -RFEX --mouse --wheel-lines=3"

      export MANPAGER="sh -c 'col -bx | bat -l man -p'"
      export MANROFFOPT="-c"

      # lazy-load autocompletion for jj (~50ms) rather than on every shell start
      jj() {
        if [ -z "$JJ_LOADED" ]; then
          source <(COMPLETE=zsh command jj)
          JJ_LOADED=true
        fi
        command jj "$@"
      }

      # Show directory content after every cd
      chpwd() { pwd; eza --icons --all }
    '';
  };

  # replaces oh-my-zsh theme, works in both zsh and Nu
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    enableNushellIntegration = true;
  };

  # Config file sourced from repo
  xdg.configFile = {
    "starship.toml".source = ../configs/starship/starship.toml;
    "starship-jj/starship-jj.toml".source = ../configs/starship/starship-jj.toml;
    "bat/config".source = ../configs/bat/config;
    "bat/themes".source = ../configs/bat/themes;
    # "lazygit/config.yml".source = ../configs/lazygit/config.yml;
    "emacs/early-init.el".source = ../configs/emacs/early-init.el;
    "emacs/init.el".source = ../configs/emacs/init.el;
    "emacs-light/early-init.el".source = ../configs/emacs-light/early-init.el;
    "emacs-light/init.el".source = ../configs/emacs-light/init.el;
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
    enableNushellIntegration = true;
    options = [ "--cmd" "cd" ];
  };

  # interactive only
  programs.nushell = {
    enable = true;

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
      ])

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

    extraConfig = ''
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

  # Configs are symlinked via xdg.configFile
  # daemon is managed via launchd in darwin.nix
  programs.emacs = {
    enable = true;
    package = pkgs.emacs-macport;
  };

  programs.ghostty = {
    enable = true;
    package = null; # system package
    settings = {
      theme = "Catppuccin Macchiato";
      font-family = "JetBrainsMono Nerd Font";
      command = "${pkgs.nushell}/bin/nu";
      shell-integration-features = true; # enable all
      macos-option-as-alt = "left";
      macos-window-buttons = "hidden";
      macos-titlebar-style = "tabs";
    };
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      navigate = true;
      dark = true;
      side-by-side = true;
      tabs = 2;
      syntax-theme = "Catppuccin Macchiato";
    };
  };

  programs.git = {
    enable = true;

    lfs.enable = true;

    signing = {
      format = "openpgp";
      key = "CB49EE78601E1E1B";
      signByDefault = true;
    };

    settings = {
      user.name = "Renaud Manet";
      user.email = "renaud.manet@epitech.eu";

      init.defaultBranch = "main";
      pull.rebase = true;
      merge.conflictStyle = "zdiff3";
      core.editor = "emacs -nw --init-dir ~/.config/emacs-light";
      github.user = "renman-ymd";
    };

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

      # --- General ---
      "*.log"
      ".env"
      ".env.local"
      "*.orig"
      "*.rej"
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
        behavior = "own";
      };

      ui = {
        editor = "emacs -nw --init-dir ~/.config/emacs-light";
        default-command = "log";
        graph.style = "square";
        pager = "delta";
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
        logs = [ "log" "-r::all()" ];
        track = [ "bookmark" "track" ];
        tug = [ "bookmark" "move" "--from" "heads(::@- & bookmarks())" "--to" "@-" ];
        difft = [ "diff" "--tool" "difft" ];
        diff-in = [ "diff" "--tool" "difft-inline" ];
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

  # Private keys not in repo.
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks."*" = {
      extraOptions = {
        AddKeysToAgent = "yes";
        UseKeychain = "yes";
      };
    };
    matchBlocks."github.com" = {
      user = "git";
      identityFile = "~/.ssh/id_ed25519";
    };
  };

  # Private keyring not in repo
  # HM services.gpg-agent is systemd only
  programs.gpg = {
    enable = true;
    settings.default-key = "CB49EE78601E1E1B";
  };

  # Zen Browser does not currently support macOS managed preferences
  # so the `policies` option has no effect on Darwin.
  programs.zen-browser = {
    enable = true;
    darwinDefaultsId = "app.zen-browser.zen";
    profiles = {
      default = {
        id = 0;
        isDefault = true;
        extensions.packages = with pkgs.nur.repos.rycee.firefox-addons; [
          ublock-origin
          sponsorblock
          bitwarden
        ];
        settings = {
          "toolkit.telemetry.enabled" = false;
          "app.shield.optoutstudies.enabled" = false;
          "browser.sessionstore.resume_from_crash" = false;
        };
      };
    };
  };
}
