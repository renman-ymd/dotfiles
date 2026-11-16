{ config, lib, pkgs, ... }:
let
  cfg = config.renman-ymd.editor;

  emacsPackages = pkgs.emacs31-nox.pkgs;

  grammars = emacsPackages.treesit-grammars.with-grammars (g: [
    g.tree-sitter-markdown
    g.tree-sitter-markdown-inline
    g.tree-sitter-yaml
    g.tree-sitter-toml
  ]);

  simpc-mode = emacsPackages.trivialBuild {
    pname = "simpc-mode";
    version = "0-unstable-2026-01-09";
    src = pkgs.fetchFromGitHub {
      owner = "rexim";
      repo = "simpc-mode";
      rev = "b4e851e38fad1b9ab3a52ea208f5ce3c4129ecf7";
      hash = "sha256-G3FPAFwM5XVsEXIRD7kYdeWCFk47yr4MjS9Yktch4b0=";
    };
  };

  emacs = emacsPackages.withPackages (e:
    [
      e.catppuccin-theme
      e.nix-mode
      e.nushell-mode
      grammars
    ]
    ++ lib.optional cfg.c.enable simpc-mode
    ++ lib.optional cfg.wakatime.enable e.wakatime-mode);

  editorArgs = [ "-nw" "--init-directory=${config.xdg.configHome}/emacs-light" ];
  editor = lib.concatStringsSep " " ([ "emacs" ] ++ editorArgs);
  editorFromStore = [ "${emacs}/bin/emacs" ] ++ editorArgs;
in
{
  options.renman-ymd.editor = {
    enable = lib.mkEnableOption "Emacs, its configuration and editor tooling";

    c.enable = lib.mkOption {
      type = lib.types.bool;
      default = config.renman-ymd.dev.enable && config.renman-ymd.dev.toolchains.enable;
      defaultText = lib.literalExpression "config.renman-ymd.dev.enable && config.renman-ymd.dev.toolchains.enable";
      description = "Whether the editor core supports C, with simpc-mode and clangd.";
    };

    wakatime.enable = lib.mkEnableOption "WakaTime in Emacs; it needs a key in ~/.wakatime.cfg";
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      emacs
      harper
      glibtool
    ] ++ lib.optional cfg.wakatime.enable pkgs.wakatime-cli;

    xdg.configFile = {
      "emacs/early-init.el".source = ./configs/emacs/early-init.el;
      "emacs/init.el".source = ./configs/emacs/init.el;
      "emacs-light/early-init.el".source = ./configs/emacs-light/early-init.el;
      "emacs-light/init.el".source = ./configs/emacs-light/init.el;
      "direnv/lib/emacs-addon.sh".source = ./emacs-addon.sh;
    };

    programs.zsh.initContent = ''
      export EDITOR='${editor}'
      export VISUAL='${editor}'
    '';

    programs.jujutsu.settings.ui.editor = editorFromStore;
    programs.gh.settings.editor = lib.concatStringsSep " " editorFromStore;

    programs.nushell = {
      extraEnv = builtins.replaceStrings [ "@editor@" ] [ editor ] (builtins.readFile ./env.nu);
      extraConfig = lib.mkAfter (lib.concatStringsSep "\n" (
        [ (builtins.readFile ./config.nu) (builtins.readFile ./em.nu) ]
        ++ lib.optional pkgs.stdenv.hostPlatform.isDarwin (builtins.readFile ./em-restart.darwin.nu)
      ));
    };

    # The emacs daemon (launchd agent in modules/darwin/editor) must run a
    # binary with a stable code-signing identity or TCC grants die on every
    # emacs update. Store binaries are read-only and can't be re-signed in
    # place, so keep a nix-selfsign-signed copy at a fixed path. The .src
    # marker skips the work when the store binary is unchanged; the mv keeps
    # the swap atomic so a running daemon is never invalidated mid-flight.
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
  };
}
