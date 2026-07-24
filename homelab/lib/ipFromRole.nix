{ lib }:
role: inventory:
(
  builtins.head (
    builtins.filter (
      node: builtins.elem role node.roles
    ) (builtins.attrValues inventory.nodes)
  )
).ip
