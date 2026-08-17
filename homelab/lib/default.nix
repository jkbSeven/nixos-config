let
  callLib = file: import file { inherit lib; };
  lib = {
    mkNode = callLib ./mkNode.nix;
    filterAttrs = callLib ./filterAttrs.nix;
    nodeFromRole = callLib ./nodeFromRole.nix;
  };
in
lib
