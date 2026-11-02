{ config, lib, pkgs, ... }: {
  options.renman-ymd.fonts.enable = lib.mkEnableOption "JetBrains Mono Nerd Font";

  config = lib.mkIf config.renman-ymd.fonts.enable {
    # Fonts – must be declared here on aarch63-darwin
    # (because of a HM systemd Linux-only dependency)
    fonts.packages = with pkgs; [
      nerd-fonts.jetbrains-mono
    ];
  };
}
