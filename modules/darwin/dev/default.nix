{ config, lib, ... }:
let
  cfg = config.renman-ymd.dev;
in
{
  options.renman-ymd.dev = {
    enable = lib.mkEnableOption "the system side of the dev tools";
    toolchains.enable = lib.mkEnableOption "toolchains installed through Homebrew";
  };

  config = lib.mkIf (cfg.enable && cfg.toolchains.enable) {
    homebrew.brews = [
      "odin"
      "odinfmt"
      "ols"
    ];
  };
}
