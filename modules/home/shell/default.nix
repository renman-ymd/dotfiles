{ config, lib, pkgs, ... }:
let
  cfg = config.renman-ymd.shell;

  platform =
    if pkgs.stdenv.hostPlatform.isDarwin then {
      copy = "pbcopy";
      open = "open";
    } else throw "renman-ymd.shell: no clipboard and open commands for this platform yet";
in
{
  options.renman-ymd.shell.enable = lib.mkEnableOption "Nushell, Starship, zoxide, carapace and a bare zsh login shell";

  config = lib.mkIf cfg.enable {
    # Nushell is the only interactive shell. zsh stays as the POSIX login shell
    # (modules/darwin/shell) but must stay bare, so no program may inject
    # prompts, completions or hooks into it -- opt every shell out by default
    # and let nushell back in.
    home.shell = {
      enableShellIntegration = false;
      enableNushellIntegration = true;
    };

    home.packages = with pkgs; [
      starship-jj
    ];

    # competion for common command like docker, cargo...
    programs.carapace = {
      enable = true;
      enableNushellIntegration = true;
    };

    # Login shell only -- interactive work happens in nushell (ghostty spawns
    # it directly). Keep this to the environment that login/non-nushell
    # consumers still need; no prompt, aliases, completions or plugins.
    programs.zsh = {
      enable = true;
      enableCompletion = false;   # nothing here to complete
    };

    # nushell prompt
    programs.starship = {
      enable = true;
      enableNushellIntegration = true;
    };

    xdg.configFile = {
      "starship.toml".source = ./configs/starship.toml;
      "starship-jj/starship-jj.toml".source = ./configs/starship-jj.toml;
    };

    programs.zoxide = {
      enable = true;
      enableNushellIntegration = true;
      options = [ "--cmd" "cd" ];
    };

    # interactive only
    programs.nushell = {
      enable = true;
      loadSessionVariables = true;

      shellAliases = {
        la = "ls --all";
        ll = "ls --all --long";
      };

      # PATH goes first: other features' snippets run commands found through it.
      extraEnv = lib.mkBefore (builtins.replaceStrings
        [ "@profileDirectory@" ]
        [ config.home.profileDirectory ]
        (builtins.readFile ./env.nu));

      # After the zoxide, starship and carapace integrations Home Manager adds.
      extraConfig = lib.mkAfter (builtins.replaceStrings
        [ "@copy@" "@open@" ]
        [ platform.copy platform.open ]
        (builtins.readFile ./config.nu));
    };
  };
}
