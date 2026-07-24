/*
Source of truth for all homelab nodes.

A role is a set of toggles for homelab services, e.g. "proxy" for nginx, "monitoring" for VictoriaMetrics + Grafana.
Machines are provisioned through terraform (terranix), hence the `vm` attribute set.

Future extensions:
- VPN mesh (adds `meshIp` and enables multi-cloud setups)
- Config options for moving some nodes to public cloud (cloud = { provider; instanceType; })
*/

{
  domain = "jkb7.dev";
  nodes = {

    proxy = {
      ip = "10.10.10.223";
      roles = [ "proxy" ];
      vm = {
        cores = 2;
        memory = 4096;
        disk = 16384;
      };
      tags = [ ];
    };

    monitoring = {
      ip = "10.10.10.163";
      roles = [ "monitoring" ];
      vm = {
        cores = 4;
        memory = 4096;
        disk = 65536;
      };
      tags = [ ];
    };

    drive = {
      ip = "10.10.10.77";
      roles = [ "nextcloud" ];
      vm = {
        cores = 2;
        memory = 4096;
        disk = 16384;
      };
      tags = [ ];
    };

    nas = {
      ip = "10.10.10.11";
      roles = [ ];
      vm = null; # not managed through terraform
      tags = [ ];
    };

  };
}
