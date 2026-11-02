{ config, lib, pkgs, ... }: {
  options.renman-ymd.mac-apps.enable = lib.mkEnableOption "AltTab and Maccy";

  config = lib.mkIf config.renman-ymd.mac-apps.enable {
    home.packages = with pkgs; [
      alt-tab-macos
      maccy
    ];
  };
}
