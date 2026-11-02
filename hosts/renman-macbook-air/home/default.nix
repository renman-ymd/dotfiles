{ pkgs, lib, ... }: {

  imports = [
    ../../../modules/home
    ../../shared-dev/home
    ../../shared-personal/home
  ];

  home.stateVersion = "25.11";

  home.sessionPath = [
    "/opt/homebrew/bin"
    "/opt/homebrew/sbin"
  ];

  home.packages = with pkgs; [
    # --- Window manager ---
    aerospace

    # --- Miscellaneous ---
    vesktop
    # discord removed: its Squirrel updater refuses updates for nix-signed
    # apps and crash-loops whenever Discord marks an update as required.
    # Use the homebrew cask if the official client is ever needed again.
    discordo
    alt-tab-macos
    maccy
    pinentry_mac
  ];

  home.file.".gnupg/gpg-agent.conf".text = ''
    pinentry-program ${pkgs.pinentry_mac}/bin/pinentry-mac
    default-cache-ttl 600
    max-cache-ttl 7200
  '';

  # Config file sourced from repo
  xdg.configFile = {
    # "lazygit/config.yml".source = ../../../configs/lazygit/config.yml;
    "aerospace/aerospace.toml".source = ../../../configs/aerospace/aerospace.toml;
  };

  # macOS TCC pins permissions (screen recording, accessibility, mic...) to an
  # app's code-signing identity. Nix-built apps are ad-hoc signed, so their
  # identity is the hash of the exact binary and every update silently revokes
  # the grants. Re-sign them with the stable self-signed "nix-selfsign"
  # certificate (login keychain) so grants survive rebuilds. Dev-ID-signed
  # apps (AltTab, Maccy) are left untouched.
  home.activation.resignAdhocApps = lib.hm.dag.entryAfter [ "copyApps" ] ''
    if /usr/bin/security find-certificate -c nix-selfsign > /dev/null 2>&1; then
      for app in "$HOME/Applications/Home Manager Apps"/*.app; do
        [ -e "$app" ] || continue
        # An embedded provisioning profile grants restricted entitlements
        # (Zen: passkeys, keychain groups) that only validate against the
        # vendor's own Developer ID. Re-signing carries the entitlements over
        # but voids the profile, so AMFI refuses the app ("No matching profile
        # found", -413) and launchd fails the spawn with POSIX errno 163.
        # Such apps are vendor-signed anyway, which is already a stable TCC
        # identity, so leave them alone.
        if [ -e "$app/Contents/embedded.provisionprofile" ]; then
          verboseEcho "resignAdhocApps: skipping $app (ships a provisioning profile)"
          continue
        fi
        # Sign anything without a certificate chain (ad-hoc, unsigned, or
        # unreadable signature); leave Developer-ID apps and previously
        # re-signed ones alone. Authority lines only appear at --verbose=2.
        if ! /usr/bin/codesign -dv --verbose=2 "$app" 2>&1 | /usr/bin/grep -q "^Authority="; then
          run /usr/bin/codesign --force --deep --preserve-metadata=entitlements \
            --sign nix-selfsign "$app" \
            || warnEcho "resignAdhocApps: failed to re-sign $app"
        fi
      done
    else
      warnEcho "resignAdhocApps: nix-selfsign certificate not found in keychain, skipping"
    fi
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
}
