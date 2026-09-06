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
      linuxSystem = "x86_64-linux";
      forAllSystems = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed;

      libHomelab = import ./homelab/lib;
    in
    {
      nixosConfigurations = {
        thinkpad6 = nixpkgs-unstable.lib.nixosSystem {
          system = linuxSystem;
          modules = [
            ./hosts/thinkpad6/configuration.nix
            home-manager.nixosModules.home-manager
            { home-manager.users.jkb = import ./home.nix; }
          ];
        };

        pc = nixpkgs-unstable.lib.nixosSystem {
          system = linuxSystem;
          modules = [
            ./hosts/pc/configuration.nix
            home-manager.nixosModules.home-manager
            { home-manager.users.jkb = import ./home.nix; }
          ];
        };

        vm-base = nixpkgs.lib.nixosSystem {
          system = linuxSystem;

          modules = [
            ./hosts/vm.nix
          ];
        };
      };

      /*
        Unfortunately it's not possible to point colmena to a different flake output,
        hence the workaround with `hive.nix` files in each deploy env (e.g. homelab/deploy/prod/hive.nix)

        `colmena` must be a plain attr set here, because that's what `colmena --config /path/to/hive.nix` requires
        Using `colmena.lib.makeHive` in this setup results in an instant error
        However, the terranix configuration needs the evaluated hive to harvest some configuration options
        and it's ok to pass an evaluated hive there like that, no CLI involved
      */
      infra = {
        prod =
        let
          inventory = import ./homelab/deploy/prod/inventory.nix;
          mkNode = libHomelab.mkNode {
            inherit inventory;
            modules = [
              ./hosts/vm.nix
              ./homelab/modules
              agenix.nixosModules.default
            ];
            root = self;
          };
        in
        {
          colmena = {
            meta = {
              nixpkgs = import nixpkgs {
                system = linuxSystem;
                overlays = [ ];
              };
            };
          }
          // builtins.mapAttrs mkNode inventory.nodes;

          tf = terranix.lib.terranixConfiguration {
            system = linuxSystem;
            modules = [
              ./homelab/deploy/prod/tf/main.nix
            ];
            extraArgs = {
              inventory = import ./homelab/deploy/prod/inventory.nix;
              nodes = colmena.lib.makeHive self.infra.prod.colmena;
              inherit libHomelab;
            };
          };
        };
      };

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

      templates = {
        C = {
          path = ./templates/C;
          description = "Baseline C env for Linux with gcc and clang";
        };
      };

      formatter = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        pkgs.nixfmt
      );
    };
}
