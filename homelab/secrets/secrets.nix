let
  inventory = import ./../inventory.nix;
  roles = inventory.roles;

  admin = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAGUyXopT6n4AgbFY4E2Xgf753xESReel5p45qDYIRaV";
  admins = [ admin ];

  privateKeyPerRole = builtins.listToAttrs (
    map (roleName: { name = "role-${roleName}.host_ssh.age"; value = { publicKeys = admins; }; }) (builtins.attrNames roles)
  );

  publicKeyPerRole = builtins.listToAttrs (
    map (roleName: { name = roleName; value = (builtins.readFile (./. + "/role-${roleName}.host_ssh.pub")); }) (builtins.attrNames roles)
  );
in
{
  "grafana.age".publicKeys = admins ++ [ publicKeyPerRole.monitoring ];
  "cloudflare-dns.age".publicKeys = admins ++ [ publicKeyPerRole.proxy ];
  "nextcloud.age".publicKeys = admins ++ [ publicKeyPerRole.nextcloud ];
}
// privateKeyPerRole
