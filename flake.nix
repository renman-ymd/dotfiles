{
  description = "macOS system configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nixpkgs-for-lix.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Single-system list: restrict bun2nix (transitive input of hunk) to
    # aarch64-darwin only. Otherwise its flake-parts/treefmt perSystem
    # evaluates x86_64-darwin, which nixpkgs 26.11 no longer supports.
    nix-systems-darwin.url = "github:nix-systems/aarch64-darwin";

    hunk = {
      url = "github:modem-dev/hunk";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.bun2nix.inputs.systems.follows = "nix-systems-darwin";
    };

    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self,
                     nix-darwin,
                     nixpkgs,
                     nixpkgs-for-lix,
                     home-manager,
                     zen-browser,
                     hunk,
                     nur,
                     nix-index-database,
                     nix-systems-darwin }: {
    darwinConfigurations."Renauds-MacBook-Air" = nix-darwin.lib.darwinSystem {
      specialArgs = {
        lixpkg = nixpkgs-for-lix.legacyPackages."aarch64-darwin".lix;
      };
      modules = [
        ./modules/darwin.nix
        nix-index-database.darwinModules.nix-index
        { programs.nix-index-database.comma.enable = true; }
        home-manager.darwinModules.home-manager
        {
          nixpkgs.overlays = [ nur.overlays.default ];
          nixpkgs.config.allowUnfree = true;
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "backup-nix-home-manager";
          home-manager.sharedModules = [
            zen-browser.homeModules.default
            hunk.homeManagerModules.default
          ];
          home-manager.users."renman-ymd" = import ./modules/home.nix;
        }
      ];
    };
  };
}
