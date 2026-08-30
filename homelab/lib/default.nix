let
  callLib = file: import file { inherit lib; };
  lib = {
    mkNode = callLib ./mkNode.nix;
    filterAttrs = callLib ./filterAttrs.nix;
    nodeFromRole = callLib ./nodeFromRole.nix;
    paths = rec {
      repoRoot = ./../..;
      homelabRoot = ./..;
      deploy = ./../deploy;
      env = env: deploy + /${env};
    };
  };
in
lib
