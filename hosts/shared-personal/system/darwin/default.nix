{ lib, ... }: {
  renman-ymd.dev.toolchains.enable = lib.mkDefault true;
  renman-ymd.mac-apps.enable = lib.mkDefault true;
  renman-ymd.gaming.enable = lib.mkDefault true;
  renman-ymd.media.enable = lib.mkDefault true;
}
