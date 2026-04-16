{ pkgs, lixpkg, ... }: {

  nixpkgs.hostPlatform = "aarch64-darwin";

  # Use Lix as the Nix implementation
  nix.package = lixpkg;
  
  # zsh stays as the login shell (POSIX-compliant)
  programs.zsh.enable = true;

  # System-wide packages
  environment.systemPackages = [
    pkgs.ghostty-bin
  ];

  # Homebrew — GUI apps and nixpkgs gaps
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      upgrade = true;
      # "zap" removes any cask/formula not in this list on darwin-rebuild
      cleanup = "zap";
    };
    casks = [
      "deezer"
      "hammerspoon"
      "utm"
      "nvidia-geforce-now"
    ];
    brews = [ "odin" ];
    masApps = {
      "Whuthering Waves" = 6475033368;
    };
  };

  system.defaults.CustomUserPreferences = {
    "org.hammerspoon.Hammerspoon" = {
      MJConfigFile = "~/.config/nix-darwin/hammerspoon/init.lua";
    };
  };

  launchd.user.agents.hammerspoon = {
    serviceConfig = {
      Label = "org.hammerspoon.Hammerspoon";
      ProgramArguments = [ "/Applications/Hammerspoon.app/Contents/MacOS/Hammerspoon" ];
      RunAtLoad = true;
      # "Aqua" means: only start in graphical dekstop session
      LimitLoadToSessionType = "Aqua";
    };
  };

  launchd.user.agents.emacs = {
    serviceConfig = {
      Label = "org.gnu.emacs.daemon";
      ProgramArguments = [
        "${pkgs.emacs-macport}/bin/emacs"
        "--fg-daemon=main"
      ];
      # Ghostty stores its terminfo inside the.app bundle and sets $TERMINFO
      # Passing it here make the daemon aware of xterm-ghostty
      EnvironmentVariables = {
        TERMINFO = "/Applications/Ghostty.app/Contents/Resources/terminfo";
      };
      RunAtLoad = true;
      LimitLoadToSessionType = "Aqua";
      # redirect output into a Log folder
      StandardOutPath = "/tmp/emacs-daemon.stdout.log";
      StandardErrorPath = "/tmp/emacs-daemon.stderr.log";
      KeepAlive = { Crashed = true; };
    };
  };

  launchd.user.agents.gpg-agent = {
    serviceConfig = {
      Label = "org.gnupg.gpg-agent";
      ProgramArguments = [
        "${pkgs.gnupg}/bin/gpg-agent"
        "--supervised"
      ];
      RunAtLoad = true;
      KeepAlive = { SuccessfulExit = false; };
      StandardOutPath = "/tmp/gpg-agent.stdout.log";
      StandardErrorPath = "/tmp/gpg-agent.stderr.log";
    };
  };

  # Fonts – must be declared here on aarch63-darwin
  # (because of a HM systemd Linux-only dependency)
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
  ];

  users.users."renman-ymd" = {
    name = "renman-ymd";
    home = "/Users/renman-ymd";
  };

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "@admin" "renman-ymd" ];

    # Lix binary cache – avoids building from source because of failing test
    extra-substituters = [ "https://cache.lix.systems" ];
    extra-trusted-public-keys = [ "cache.lix.systems:aBnZUw8zA7H35Cz2RyKFVs3H4PlGTLawyY5KRbvJR8o=" ];

    # Preserved settings from Lix installer-generated nix.conf
    always-allow-substitutes = true;
    max-jobs = "auto";
    bash-prompt-prefix = "(nix:$name) ";
    extra-nix-path = [ "nixpkgs=flake:nixpkgs" ];
  };

  system.primaryUser = "renman-ymd";
  system.stateVersion = 6;
}
