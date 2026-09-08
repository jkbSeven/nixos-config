/*
`name` and `node` (config) of currently processed node (from inventory.nix) through builtins.mapAttrs
``inventory` is loaded from inventory.nix
*/

{ lib }:
{ inventory, modules, root }:
name:
node:
let
  fqdn = "${name}.srv.${inventory.domain}";
in
{

  imports = modules ++ map (role: root + "/homelab/modules/roles/${role}.nix") node.roles;

  networking.hostName = name;

  homelab.settings = {
    inventory = inventory;
    users = inventory.users;
    domain = inventory.domain;

    secretsDir = "/var/lib/secrets";

    thisNode = node;
    thisNodeFqdn = fqdn;
    proxyIp = lib.ipFromRole "proxy" inventory;
  };

  services.prometheus.exporters.node = {
    enable = true;
    openFirewall = true;
    port = 9100;
  };

  homelab.monitoring.scrapeTargets = [
    {
      job_name = "node";
      static_configs = [{
        targets = [ "${fqdn}:9100" ];
      }];
    }
  ];

  deployment = {
    # if targetHost = null, then colmena doesn't deploy it with `colmena apply`
    # but the node is still evaluated, which is exactly what we need
    # publisher pattern works, while not causing any deployment issues
    targetHost = if node.vm != null then fqdn else null;
    targetUser = "admin";
    tags = node.tags or [ ];
  };
}
