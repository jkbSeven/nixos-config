/*
`name` and `node` (config) of currently processed node (from inventory.nix) through builtins.mapAttrs
`users` and `inventory` are basically loaded from users.nix and inventory.nix
*/

{ lib }:
{ users, inventory, modules, root }:
name:
node:
let
  fqdn = "${name}.srv.${inventory.domain}";
in
{

  imports = modules ++ map (role: root + "/modules/homelab/roles/${role}.nix") node.roles;

  networking.hostName = name;

  homelab.settings = {
    inventory = inventory;
    users = users;
    domain = inventory.domain;

    thisNode = node;
    thisNodeFqdn = fqdn;
    proxyIp = lib.ipFromRole "proxy" inventory;
  };

  deployment = {
    # if targetHost = null, then colmena doesn't deploy it with `colmena apply`
    # but the node is still evaluated, which is exactly what we need
    # publisher pattern works, while not causing any deployment issues
    targetHost = if node.vm != null then fqdn else null;
    targetUser = "admin";
    tags = node.tags or [ ];
  };
}
