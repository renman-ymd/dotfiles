{ config, lib, pkgs, ... }: {
  options.renman-ymd.editor.enable = lib.mkEnableOption "the Emacs daemon as a launchd agent";

  config = lib.mkIf config.renman-ymd.editor.enable {
    launchd.user.agents.emacs = {
      serviceConfig = {
        Label = "org.gnu.emacs.daemon";
        ProgramArguments = [
          # Stable re-signed copy of ${pkgs.emacs-macport}/bin/emacs, maintained
          # by home.activation.emacsDaemonBinary (modules/home/editor). macOS TCC
          # pins permission grants to the executable's code-signing identity,
          # and the ad-hoc-signed store binary changes identity on every update.
          # Side effect of the static path: darwin-rebuild no longer restarts
          # the daemon on emacs bumps; run em-restart to pick up a new version.
          "${config.users.users."renman-ymd".home}/.local/libexec/nix-resigned/emacs"
          "--fg-daemon=main"
          # Force the config location. Emacs prefers
          # ~/.emacs.d/ over the XDG path (~/.config/emacs/)
          # and emacs itself creates that directory
          "--init-directory=${config.users.users."renman-ymd".home}/.config/emacs"
        ];
        # Passing the ghostyy terminfo here make the daemon aware of xterm-ghostty
        EnvironmentVariables = {
          TERMINFO = "${pkgs.ghostty-bin.terminfo}/share/terminfo";
          NIX_SSL_CERT_FILE = config.environment.variables.NIX_SSL_CERT_FILE;
          PATH = "${config.users.users."renman-ymd".home}/.nix-profile/bin:/etc/profiles/per-user/renman-ymd/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/usr/bin:/bin:/usr/sbin:/sbin";
        };
        RunAtLoad = true;
        # "Aqua" means: only start in graphical dekstop session
        LimitLoadToSessionType = "Aqua";
        # redirect output into a Log folder
        StandardOutPath = "/tmp/emacs-daemon.stdout.log";
        StandardErrorPath = "/tmp/emacs-daemon.stderr.log";
        KeepAlive = { Crashed = true; };
      };
    };
  };
}
