{ config, lib, pkgs, ... }: {
  options.renman-ymd.terminal.enable = lib.mkEnableOption "the Ghostty system package";

  config = lib.mkIf config.renman-ymd.terminal.enable {
    environment.systemPackages = [
      pkgs.ghostty-bin
    ];
  };
}
