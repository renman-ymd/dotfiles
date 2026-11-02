{ lib, ... }: {
  renman-ymd.cli.full.enable = lib.mkDefault true;
  renman-ymd.docs.enable = lib.mkDefault true;
  renman-ymd.dev.toolchains.enable = lib.mkDefault true;
  renman-ymd.browser.enable = lib.mkDefault true;
  renman-ymd.keys.enable = lib.mkDefault true;
  renman-ymd.tiling.enable = lib.mkDefault true;
}
