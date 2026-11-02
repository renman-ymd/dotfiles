{ lib, ... }: {
  renman-ymd.shell.enable = lib.mkDefault true;
  renman-ymd.editor.enable = lib.mkDefault true;
  renman-ymd.vcs.enable = lib.mkDefault true;
  renman-ymd.cli.enable = lib.mkDefault true;
  renman-ymd.dev.enable = lib.mkDefault true;
}
