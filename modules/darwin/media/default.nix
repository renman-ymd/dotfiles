{ config, lib, ... }: {
  options.renman-ymd.media.enable = lib.mkEnableOption "music apps";

  config = lib.mkIf config.renman-ymd.media.enable {
    homebrew.casks = [ "deezer" ];
  };
}
