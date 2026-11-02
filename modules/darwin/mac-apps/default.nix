{ config, lib, ... }: {
  options.renman-ymd.mac-apps.enable = lib.mkEnableOption "Homebrew and Mac App Store desktop apps";

  config = lib.mkIf config.renman-ymd.mac-apps.enable {
    homebrew = {
      casks = [
        "utm"
        "claude"
      ];
      masApps = {
        "Floaty" = 6755633285;
        "Keynotes" = 361285480;
      };
    };
  };
}
