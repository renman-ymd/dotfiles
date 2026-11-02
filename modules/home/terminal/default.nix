{ config, lib, pkgs, ... }: {
  options.renman-ymd.terminal.enable = lib.mkEnableOption "Ghostty, which starts nu directly";

  config = lib.mkIf config.renman-ymd.terminal.enable {
    programs.ghostty = {
      enable = true;
      package = null; # system package
      settings = {
        theme = "Catppuccin Macchiato";
        font-family = "JetBrainsMono Nerd Font";
        command = "${pkgs.nushell}/bin/nu";
        shell-integration-features = true; # enable all
        macos-option-as-alt = "left";
        macos-window-buttons = "hidden";
        macos-titlebar-style = "tabs";
      };
    };
  };
}
