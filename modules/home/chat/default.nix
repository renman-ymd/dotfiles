{ config, lib, pkgs, ... }: {
  options.renman-ymd.chat.enable = lib.mkEnableOption "chat clients";

  config = lib.mkIf config.renman-ymd.chat.enable {
    home.packages = with pkgs; [
      vesktop
      # discord removed: its Squirrel updater refuses updates for nix-signed
      # apps and crash-loops whenever Discord marks an update as required.
      # Use the homebrew cask if the official client is ever needed again.
      discordo
    ];
  };
}
