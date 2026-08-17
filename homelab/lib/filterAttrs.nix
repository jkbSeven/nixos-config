/*
  Stolen from nixpkgs lib: https://noogle.dev/f/lib/filterAttrs/#implementation
*/
{ lib }:
pred: set: removeAttrs set (builtins.filter (name: !pred name set.${name}) (builtins.attrNames set))
