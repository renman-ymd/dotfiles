{ pkgs, lib, lixpkg, config, ... }: {

  imports = [
    ../../../modules/darwin
    ../../shared-dev/system/darwin
    ../../shared-personal/system/darwin
  ];

  renman-ymd.nix.enable = true;

  nixpkgs.hostPlatform = "aarch64-darwin";

  # Pin the hostname. With HostName unset macOS derives it from the network
  # (DHCP/Bonjour), so it changes as you move between routers. GnuPG stamps
  # its lock files with hostname + pid and will only break a stale lock when
  # the recorded hostname matches the current one -- otherwise it assumes the
  # holder lives on another machine and blocks until timeout. A hostname that
  # changes across a reboot is enough to wedge the keyring permanently.
  # localHostName follows hostName; ComputerName is left alone.
  networking.hostName = "Renauds-MacBook-Air";
  networking.applicationFirewall.enable = true;

  # Homebrew — GUI apps and nixpkgs gaps
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      upgrade = true;
      # "zap" removes any cask/formula not in this list on darwin-rebuild
      cleanup = "zap";
    };
  };

  users.users."renman-ymd" = {
    name = "renman-ymd";
    home = "/Users/renman-ymd";
  };

  system.primaryUser = "renman-ymd";
  system.stateVersion = 6;
}
