{ config, lib, ... }: {
  options.renman-ymd.shell.enable = lib.mkEnableOption "zsh as the POSIX login shell";

  config = lib.mkIf config.renman-ymd.shell.enable {
    # zsh stays as the login shell (POSIX-compliant)
    programs.zsh.enable = true;
  };
}
