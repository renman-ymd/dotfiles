{ config, lib, pkgs, ... }:
let
  cfg = config.renman-ymd.editor;
in
{
  options.renman-ymd.editor.enable = lib.mkEnableOption "Emacs, its configuration and editor tooling";

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      wakatime-cli # Private key to write to ~/.wakatime.cfg
      glibtool
    ];

    xdg.configFile = {
      "emacs/early-init.el".source = ./configs/emacs/early-init.el;
      "emacs/init.el".source = ./configs/emacs/init.el;
      "emacs-light/early-init.el".source = ./configs/emacs-light/early-init.el;
      "emacs-light/init.el".source = ./configs/emacs-light/init.el;
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

    # Configs are symlinked via xdg.configFile
    # daemon is managed via launchd in modules/darwin/editor
    programs.emacs = {
      enable = true;
      package = pkgs.emacs-macport;
    };
  };
}
