{ config, lib, pkgs, ... }: {
  options.renman-ymd.tiling.enable = lib.mkEnableOption "the AeroSpace tiling window manager";

  config = lib.mkIf config.renman-ymd.tiling.enable {
    home.packages = with pkgs; [
      aerospace
    ];

    xdg.configFile."aerospace/aerospace.toml".source = ./aerospace.toml;
  };
}
