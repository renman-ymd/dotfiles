{ config, lib, ... }: {
  options.renman-ymd.gaming.enable = lib.mkEnableOption "Steam, GeForce NOW and Sikarugir";

  config = lib.mkIf config.renman-ymd.gaming.enable {
    homebrew = {
      taps = [ "Sikarugir-App/sikarugir" ];
      casks = [
        "nvidia-geforce-now"
        "steam"
        { name = "Sikarugir-App/sikarugir/sikarugir"; trusted = true; }
      ];
      masApps = {
        "Wuthering Waves" = 6475033368;
      };
    };
  };
}
