let
  libHomelab = import ./../lib;
  inventory = import ./../inventory.nix;
  nodes = inventory.nodes;
  roles = inventory.roles;

  admin = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAGUyXopT6n4AgbFY4E2Xgf753xESReel5p45qDYIRaV";
  admins = [ admin ];

  nixosNodes = libHomelab.filterAttrs (nodeName: nodeConfig: nodeConfig.vm != null) nodes;
  nixosNodesNames = builtins.attrNames nixosNodes;

  privateKeyPerNode = builtins.listToAttrs (
    map (nodeName: { name = "node-${nodeName}.host_ssh.age"; value = { publicKeys = admins; }; }) nixosNodesNames
  );

  publicKeyPerNode = builtins.listToAttrs (
    map (nodeName: { name = nodeName; value = (builtins.readFile (./. + "/node-${nodeName}.host_ssh.pub")); }) nixosNodesNames
  );

  publicKeyForRole = role: publicKeyPerNode."${(libHomelab.nodeFromRole role inventory).name}";
in
{
  "grafana.age".publicKeys = admins ++ [ (publicKeyForRole roles.monitoring) ];
  "cloudflare-dns.age".publicKeys = admins ++ [ (publicKeyForRole roles.proxy) ];
  "nextcloud.age".publicKeys = admins ++ [ (publicKeyForRole roles.nextcloud) ];
}
// privateKeyPerNode
