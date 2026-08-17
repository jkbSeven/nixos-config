{ lib }:
role: inventory:
let
  nodeSet = lib.filterAttrs (name: node: builtins.elem role node.roles) inventory.nodes;
  name = builtins.elemAt (builtins.attrNames nodeSet) 0;
in
{
  name = name;
  value = nodeSet.name;
}
