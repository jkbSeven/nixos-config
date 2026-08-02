let
  callLib = file: import file { inherit lib; };
  lib = {
    mkNode = callLib ./mkNode.nix;
    ipFromRole = callLib ./ipFromRole.nix;
  };
in
lib
