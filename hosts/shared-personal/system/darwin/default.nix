{ lib, ... }: {
  renman-ymd.dev.toolchains.enable = lib.mkDefault true;
  renman-ymd.mac-apps.enable = lib.mkDefault true;
}
