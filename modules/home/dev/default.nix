{ config, lib, pkgs, ... }:
let
  cfg = config.renman-ymd.dev;
in
{
  options.renman-ymd.dev = {
    enable = lib.mkEnableOption "direnv, nix-direnv, nil and devenv";
    toolchains.enable = lib.mkEnableOption "language runtimes, build tools and language servers";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      programs.direnv = {
        enable = true;
        nix-direnv.enable = true;   # faster nix-shell
      };

      home.packages = with pkgs; [
        nil
        devenv
      ];
    })

    (lib.mkIf (cfg.enable && cfg.toolchains.enable) {
      home.packages = with pkgs; [
        # --- Language runtimes ---
        go
        rustc
        cargo
        clippy
        rustfmt
        python3
        ghc
        cabal-install
        bun
        nodejs
        zig
        jdk
        kotlin
        # odin           # installed via homebrew; nixpkgs lacks maintenance

        # --- C/C++ extras ---
        # clang/clang++ and make are already provided by Xcode CLT
        cmake
        meson
        ninja

        # --- Language servers ---
        gopls
        rust-analyzer
        pyright
        haskell-language-server
        typescript-language-server
        zls
        clang-tools
        kotlin-language-server
      ];
    })
  ];
}
