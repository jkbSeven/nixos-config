{
  description = "NixOS config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in
    {
      nixosConfigurations = {
        thinkpad6 = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./hosts/thinkpad6/configuration.nix
            home-manager.nixosModules.home-manager
            { home-manager.users.jkb = import ./home.nix; }
          ];
        };

        vm1 = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            hostname = "nixos-vm1";
          };

          modules = [
            ./hosts/vm.nix
          ];
        };

        vm2 = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            hostname = "nixos-vm2";
          };

          modules = [ ./hosts/vm.nix ];
        };
      };

      templates = {
        C = {
          path = ./templates/C;
          description = "Baseline C env for Linux with gcc and clang";
        };
      };

      formatter.${system} = pkgs.nixfmt;
    };
}
