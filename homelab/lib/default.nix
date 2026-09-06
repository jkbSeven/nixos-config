let
  callLib = file: import file { inherit lib; };
  lib = {
    mkNode = callLib ./mkNode.nix;
    filterAttrs = callLib ./filterAttrs.nix;
    nodeFromRole = callLib ./nodeFromRole.nix;
    ipFromRole = callLib ./ipFromRole.nix;
    paths = rec {
      repoRoot = ./../..;
      homelabRoot = ./..;
      deploy = ./../deploy;
      env = env: deploy + /${env};
    };
    filterNonNixosNodes = nodes: lib.filterAttrs (nodeName: nodeConfig: nodeConfig.vm != null) nodes;
    filterNixosNodes = nodes: lib.filterAttrs (nodeName: nodeConfig: nodeConfig.vm == null) nodes;
  };
in
lib
