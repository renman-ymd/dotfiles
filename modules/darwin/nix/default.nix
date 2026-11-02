{ config, lib, lixpkg, ... }: {
  options.renman-ymd.nix.enable = lib.mkEnableOption "Lix, the nix settings and the re-signed nix-daemon";

  config = lib.mkIf config.renman-ymd.nix.enable {
    # Use Lix as the Nix implementation
    nix.package = lixpkg;

    # Garbage collection deletes store .app bundles, which macOS App Management
    # only allows for grantees. The check is attributed to nix-daemon (launchd
    # starts it, so no terminal grant applies), and the store binary is ad-hoc
    # signed, so a grant would die with every Lix update. Run the daemon from a
    # nix-selfsign-signed copy at a fixed, root-owned path instead and grant
    # App Management to /usr/local/libexec/nix-resigned/nix once.
    # Signing runs as root, so the nix-selfsign identity must also be in the
    # System keychain. Without it the copy stays ad-hoc signed (daemon works,
    # GC of .app bundles does not) and activation retries next switch.
    # The nix-daemon symlink mirrors the store layout: Lix is a multi-call
    # binary that dispatches on argv[0].
    # Side effect of the static path: Lix bumps no longer change the plist, so
    # the script restarts the daemon itself when it swaps the binary.
    launchd.daemons.nix-daemon.command =
      lib.mkForce "/usr/local/libexec/nix-resigned/nix-daemon";

    system.activationScripts.extraActivation.text = ''
      nixDaemonDir=/usr/local/libexec/nix-resigned
      srcBin="${config.nix.package}/bin/nix"
      if [ "$(cat "$nixDaemonDir/nix.src" 2>/dev/null)" != "$srcBin" ]; then
        echo "installing re-signed nix-daemon..." >&2
        mkdir -p "$nixDaemonDir"
        chown root:wheel "$nixDaemonDir"
        chmod 755 "$nixDaemonDir"
        cp -f "$srcBin" "$nixDaemonDir/nix.tmp"
        chmod 755 "$nixDaemonDir/nix.tmp"
        if /usr/bin/codesign --force --preserve-metadata=entitlements \
             --identifier nix --keychain /Library/Keychains/System.keychain \
             --sign nix-selfsign "$nixDaemonDir/nix.tmp"; then
          echo "$srcBin" > "$nixDaemonDir/nix.src.tmp"
        else
          echo "warning: nix-selfsign not usable from the System keychain;" \
            "nix-daemon stays ad-hoc signed" >&2
          rm -f "$nixDaemonDir/nix.src"
        fi
        mv -f "$nixDaemonDir/nix.tmp" "$nixDaemonDir/nix"
        ln -sfn nix "$nixDaemonDir/nix-daemon"
        if [ -e "$nixDaemonDir/nix.src.tmp" ]; then
          mv -f "$nixDaemonDir/nix.src.tmp" "$nixDaemonDir/nix.src"
        fi
        launchctl kickstart -k system/org.nixos.nix-daemon 2> /dev/null || true
      fi
    '';

    nix.settings = {
      experimental-features = [ "nix-command" "flakes" ];
      trusted-users = [ "@admin" "renman-ymd" ];

      # Lix binary cache – avoids building from source because of failing test
      extra-substituters = [ "https://cache.lix.systems" ];
      extra-trusted-public-keys = [ "cache.lix.systems:aBnZUw8zA7H35Cz2RyKFVs3H4PlGTLawyY5KRbvJR8o=" ];

      # Preserved settings from Lix installer-generated nix.conf
      always-allow-substitutes = true;
      max-jobs = "auto";
      bash-prompt-prefix = "(nix:$name) ";
      extra-nix-path = [ "nixpkgs=flake:nixpkgs" ];
    };

    # Nix-built OpenSSL falls back to the CA bundle in root's default profile,
    # which nix-darwin never updates, whenever NIX_SSL_CERT_FILE is unset.
    # envVariables is applied by launchctl setenv at switch time only and is
    # lost at logout, so the Emacs agent also sets the variable itself.
    launchd.user.envVariables.NIX_SSL_CERT_FILE = config.environment.variables.NIX_SSL_CERT_FILE;
    security.sudo.extraConfig = ''
      Defaults:root,%admin env_keep+=NIX_SSL_CERT_FILE
    '';
  };
}
