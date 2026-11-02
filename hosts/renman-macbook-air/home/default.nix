{ pkgs, lib, ... }: {

  imports = [
    ../../../modules/home
    ../../shared-dev/home
  ];

  home.stateVersion = "25.11";

  home.sessionPath = [
    "/opt/homebrew/bin"
    "/opt/homebrew/sbin"
  ];

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

    # --- Dev environments ---
    devenv

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

    # --- Window manager ---
    aerospace

    # --- Miscellaneous ---
    vesktop
    # discord removed: its Squirrel updater refuses updates for nix-signed
    # apps and crash-loops whenever Discord marks an update as required.
    # Use the homebrew cask if the official client is ever needed again.
    discordo
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
    nix-direnv.enable = true;   # faster nix-shell
  };

  # Config file sourced from repo
  xdg.configFile = {
    "bat/config".source = ../../../configs/bat/config;
    "bat/themes".source = ../../../configs/bat/themes;
    # "lazygit/config.yml".source = ../../../configs/lazygit/config.yml;
    "emacs/early-init.el".source = ../../../configs/emacs/early-init.el;
    "emacs/init.el".source = ../../../configs/emacs/init.el;
    "emacs-light/early-init.el".source = ../../../configs/emacs-light/early-init.el;
    "emacs-light/init.el".source = ../../../configs/emacs-light/init.el;
    "aerospace/aerospace.toml".source = ../../../configs/aerospace/aerospace.toml;
    "jj/scripts/pr-create.nu" = {
      source = ../../../configs/jj/scripts/pr-create.nu;
      executable = true;
    };
  };

  # macOS TCC pins permissions (screen recording, accessibility, mic...) to an
  # app's code-signing identity. Nix-built apps are ad-hoc signed, so their
  # identity is the hash of the exact binary and every update silently revokes
  # the grants. Re-sign them with the stable self-signed "nix-selfsign"
  # certificate (login keychain) so grants survive rebuilds. Dev-ID-signed
  # apps (AltTab, Maccy) are left untouched.
  home.activation.resignAdhocApps = lib.hm.dag.entryAfter [ "copyApps" ] ''
    if /usr/bin/security find-certificate -c nix-selfsign > /dev/null 2>&1; then
      for app in "$HOME/Applications/Home Manager Apps"/*.app; do
        [ -e "$app" ] || continue
        # An embedded provisioning profile grants restricted entitlements
        # (Zen: passkeys, keychain groups) that only validate against the
        # vendor's own Developer ID. Re-signing carries the entitlements over
        # but voids the profile, so AMFI refuses the app ("No matching profile
        # found", -413) and launchd fails the spawn with POSIX errno 163.
        # Such apps are vendor-signed anyway, which is already a stable TCC
        # identity, so leave them alone.
        if [ -e "$app/Contents/embedded.provisionprofile" ]; then
          verboseEcho "resignAdhocApps: skipping $app (ships a provisioning profile)"
          continue
        fi
        # Sign anything without a certificate chain (ad-hoc, unsigned, or
        # unreadable signature); leave Developer-ID apps and previously
        # re-signed ones alone. Authority lines only appear at --verbose=2.
        if ! /usr/bin/codesign -dv --verbose=2 "$app" 2>&1 | /usr/bin/grep -q "^Authority="; then
          run /usr/bin/codesign --force --deep --preserve-metadata=entitlements \
            --sign nix-selfsign "$app" \
            || warnEcho "resignAdhocApps: failed to re-sign $app"
        fi
      done
    else
      warnEcho "resignAdhocApps: nix-selfsign certificate not found in keychain, skipping"
    fi
  '';

  # The emacs daemon (launchd agent in darwin.nix) must run a binary with a
  # stable code-signing identity or TCC grants die on every emacs update.
  # Store binaries are read-only and can't be re-signed in place, so keep a
  # nix-selfsign-signed copy at a fixed path. The .src marker skips the work
  # when the store binary is unchanged; the mv keeps the swap atomic so a
  # running daemon is never invalidated mid-flight.
  home.activation.emacsDaemonBinary = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    daemonBin="$HOME/.local/libexec/nix-resigned/emacs"
    srcBin="${pkgs.emacs-macport}/bin/emacs"
    # native-comp: emacs resolves its preloaded .eln files relative to the
    # executable (execdir/../native-lisp), so the copied binary needs this
    # sibling symlink to the package's versioned native-lisp directory.
    run mkdir -p "$(dirname "$daemonBin")"
    run /bin/ln -sfn "${pkgs.emacs-macport}"/lib/emacs/*/native-lisp \
      "$HOME/.local/libexec/native-lisp"
    if [ "$(cat "$daemonBin.src" 2>/dev/null)" != "$srcBin" ]; then
      run cp -f "$srcBin" "$daemonBin.tmp"
      run chmod u+w "$daemonBin.tmp"
      if run /usr/bin/codesign --force --preserve-metadata=entitlements \
           --sign nix-selfsign "$daemonBin.tmp"; then
        run mv -f "$daemonBin.tmp" "$daemonBin"
        run sh -c "echo '$srcBin' > '$daemonBin.src'"
      else
        warnEcho "emacsDaemonBinary: signing failed, daemon binary not updated"
        rm -f "$daemonBin.tmp"
      fi
    fi
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

  # Private keys not in repo.
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      "*" = {
        AddKeysToAgent = "yes";
        UseKeychain = "yes";
      };
      "github.com" = {
        User = "git";
        IdentityFile = "~/.ssh/id_ed25519";
      };
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
