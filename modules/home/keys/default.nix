{ config, lib, pkgs, ... }: {
  options.renman-ymd.keys.enable = lib.mkEnableOption "gpg, its agent configuration, pinentry and the ssh configuration";

  config = lib.mkIf config.renman-ymd.keys.enable {
    home.packages = with pkgs; [
      pinentry_mac
    ];

    home.file.".gnupg/gpg-agent.conf".text = ''
      pinentry-program ${pkgs.pinentry_mac}/bin/pinentry-mac
      default-cache-ttl 600
      max-cache-ttl 7200
    '';

    # Private keys not in repo.
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
      settings = {
        "*" = {
          AddKeysToAgent = "yes";
          UseKeychain = "yes";
        };
        "github.com" = {
          User = "git";
          IdentityFile = "~/.ssh/id_ed25519";
        };
      };
    };

    # Private keyring not in repo
    # HM services.gpg-agent is systemd only
    programs.gpg = {
      enable = true;
      settings.default-key = "CB49EE78601E1E1B";
    };
  };
}
