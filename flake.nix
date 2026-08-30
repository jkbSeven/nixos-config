{
  description = "NixOS config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-26.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs?ref=nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    colmena = {
      url = "github:zhaofengli/colmena/stable";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    terranix = {
      url = "github:terranix/terranix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-unstable,
      home-manager,
      colmena,
      terranix,
      agenix,
      ...
    }:
    let
      system = "x86_64-linux";

      forAllSystems = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed;

      # Homelab variables and functions
      libHomelab = import ./homelab/lib;
      inventory = import ./homelab/inventory.nix;
      mkNode = libHomelab.mkNode {
        inherit inventory;
        modules = [
          ./homelab/modules
          ./hosts/vm.nix
        ];
        root = self;
      };
      # End of homelab variables and functions
    in
    {
      nixosConfigurations = {
        thinkpad6 = nixpkgs-unstable.lib.nixosSystem {
          inherit system;
          modules = [
            ./hosts/thinkpad6/configuration.nix
            home-manager.nixosModules.home-manager
            { home-manager.users.jkb = import ./home.nix; }
          ];
        };

        pc = nixpkgs-unstable.lib.nixosSystem {
          inherit system;
          modules = [
            ./hosts/pc/configuration.nix
            home-manager.nixosModules.home-manager
            { home-manager.users.jkb = import ./home.nix; }
          ];
        };

        vm-base = nixpkgs.lib.nixosSystem {
          inherit system;

          modules = [
            ./hosts/vm.nix
          ];
        };
      };

      templates = {
        C = {
          path = ./templates/C;
          description = "Baseline C env for Linux with gcc and clang";
        };
      };

      infra = {
        production = terranix.lib.terranixConfiguration {
          inherit system;
          modules = [
            ./homelab/deploy/config.nix
          ];
          extraArgs = {
            inherit (self.colmenaHive) nodes;
            inherit inventory;
          };
        };
      };

      colmenaHive = colmena.lib.makeHive (
        {
          meta = {
            nixpkgs = import nixpkgs {
              system = "x86_64-linux";
              overlays = [ ];
            };
          };
        }
        // builtins.mapAttrs mkNode inventory.nodes
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = import nixpkgs-unstable {
            inherit system;
            config.allowUnfreePredicate =
              pkg:
              builtins.elem (nixpkgs-unstable.lib.getName pkg) [
                "terraform"
              ];
          };
        in
        rec {
          default = deploy;
          deploy = pkgs.mkShellNoCC {
            packages = [
              pkgs.just
              pkgs.jq

              pkgs.colmena
              pkgs.libguestfs-with-appliance # for guestfish
              (pkgs.terraform.withPlugins (p: [
                p.bpg_proxmox
                p.ubiquiti-community_unifi
              ]))
              agenix.packages.${system}.default
            ];
          };
        }
      );

      formatter = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        pkgs.nixfmt
      );
    };
}
