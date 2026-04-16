{
  description = "macOS system configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nixpkgs-for-lix.url = "github:NixOS/nixpkgs/106eb93cbb9d4e4726bf6bc367a3114f7ed6b32f";

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

    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, nixpkgs-for-lix, home-manager, zen-browser, nur, nix-index-database }: {
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
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.sharedModules = [ zen-browser.homeModules.default ];
          home-manager.users."renman-ymd" = import ./modules/home.nix;
        }
      ];
    };
  };
}
