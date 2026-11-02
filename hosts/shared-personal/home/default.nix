{ lib, ... }: {
  renman-ymd.cli.full.enable = lib.mkDefault true;
  renman-ymd.docs.enable = lib.mkDefault true;
}
