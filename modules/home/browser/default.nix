{ config, lib, pkgs, ... }: {
  options.renman-ymd.browser.enable = lib.mkEnableOption "the Zen browser";

  config = lib.mkIf config.renman-ymd.browser.enable {
    # Zen Browser does not currently support macOS managed preferences
    # so the `policies` option has no effect on Darwin.
    programs.zen-browser = {
      enable = true;
      darwinDefaultsId = "app.zen-browser.zen";
      profiles = {
        default = {
          id = 0;
          isDefault = true;
          extensions.packages = with pkgs.nur.repos.rycee.firefox-addons; [
            ublock-origin
            sponsorblock
            bitwarden
          ];
          settings = {
            "toolkit.telemetry.enabled" = false;
            "app.shield.optoutstudies.enabled" = false;
            "browser.sessionstore.resume_from_crash" = false;
          };
        };
      };
    };
  };
}
