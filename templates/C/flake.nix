{
  description = "C development for Linux with common libs";

  inputs.nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";

  outputs =
    { self, nixpkgs, ... }@inputs:
    let
      supportedSystems = [
        "x86_64-linux"
        # "x86_64-darwin"
        # "aarch64-linux"
        # "aarch64-darwin"
      ];

      # Helper for providing system-specific attributes, credits: determinate-systems
      forEachSupportedSystem =
        f:
        inputs.nixpkgs.lib.genAttrs supportedSystems (
          system:
          f {
            inherit system;
            pkgs = inputs.nixpkgs.legacyPackages.${system};
          }
        );
    in
    {
      devShells = forEachSupportedSystem (
        { pkgs, system }:
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              gcc
              gnumake
              gdb
              clang
              valgrind
            ];
          };
        }
      );

      packages = forEachSupportedSystem (
        { pkgs, system }:
        {
          default = pkgs.stdenv.mkDerivation {
            pname = "prog";
            version = "0.1.0";
            src = ./.;

            buildInputs = [
              #pkgs.zlib
              #pkgs.openssl
              #pkgs.libcurl
            ];

            nativeBuildInputs = [
              #pkgs.pkg-config
            ];
          };

        }
      );

      formatter = forEachSupportedSystem ({ pkgs, system }: pkgs.nixfmt);
    };
}
