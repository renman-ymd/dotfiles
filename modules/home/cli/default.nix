{ config, lib, pkgs, ... }:
let
  cfg = config.renman-ymd.cli;
in
{
  options.renman-ymd.cli = {
    enable = lib.mkEnableOption "fzf and bat";
    full.enable = lib.mkEnableOption "ripgrep, fd, eza, jq and htop";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      home.packages = with pkgs; [
        bat
        fzf
      ];

      xdg.configFile = {
        "bat/config".source = ./configs/bat/config;
        "bat/themes".source = ./configs/bat/themes;
      };

      programs.nushell = {
        shellAliases.cat = "bat --style=auto";
        extraEnv = builtins.readFile ./env.nu;
      };
    })

    (lib.mkIf (cfg.enable && cfg.full.enable) {
      home.packages = with pkgs; [
        ripgrep
        fd
        eza
        jq
        htop
      ];
    })
  ];
}
