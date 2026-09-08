{
  lib,
  libHomelab,
  inventory,
  evaluatedNodes,
  ...
}:
let
  nixosNodes = libHomelab.filterNonNixosNodes inventory.nodes;
  proxmoxEndpoint = "https://10.10.10.10:8006";
  unifiEndpoint = "https://10.10.0.1";

  nodesDNSRecords = builtins.mapAttrs (name: node:
    {
      name = "${name}.srv.${inventory.domain}";
      type = "A";
      record = node.ip;
      ttl = 0;
    }) inventory.nodes;

  proxyIP = libHomelab.ipFromRole "proxy" inventory;
  virtualHostsNames = builtins.attrNames evaluatedNodes.nodes.proxy.config.services.nginx.virtualHosts;
  proxiedDNSRecords = builtins.listToAttrs (map (vhost:
    {
      name = builtins.replaceStrings ["."] ["-"] vhost;
      value = {
        name = vhost;
        type = "A";
        record = proxyIP;
        ttl = 0;
      };
    }) virtualHostsNames);

in
{

  terraform.required_providers.proxmox = {
    source = "bpg/proxmox";
    version = "0.111.1";
  };

  variable.proxmox_api_token = {
    type = "string";
    sensitive = true;
  };

  variable.proxmox_deployer_ssh_key_path = {
    type = "string";
    default = "~/.ssh/keys/deployer";
  };

  provider.proxmox = {
    endpoint = proxmoxEndpoint;
    api_token = "\${var.proxmox_api_token}";
    insecure = true;

    ssh = {
      username = "deployer";
      private_key = "\${file(\"\${var.proxmox_deployer_ssh_key_path}\")}";
    };
  };


  resource.proxmox_virtual_environment_file.base-nixos-image = {
    content_type = "import";
    datastore_id = "local";
    node_name = "proxmox-um790";
    overwrite = true;

    source_file = {
      path = "./../../base.qcow2";
    };
  };

  resource.proxmox_virtual_environment_vm = builtins.mapAttrs (name: node:
    {
      depends_on = [ "unifi_user.${name}" ];

      inherit name;
      node_name = "proxmox-um790";
      # vm_id = ...;
      tags = [ "prod" ];

      agent = {
        enabled = true;
        wait_for_ip = {
          disabled = true;
        };
      };

      cpu = {
        cores = node.vm.cores;
        type = "x86-64-v2-AES";
      };

      disk = {
        interface = "virtio0";
        file_format = "qcow2";
        import_from = "\${proxmox_virtual_environment_file.base-nixos-image.id}";
      };

      memory.dedicated = node.vm.memory;

      network_device = [
        {
          bridge = "vmbr0";
          mac_address = node.mac;

          model = "virtio";
          firewall = false;

          enabled = true;
          disconnected = false;

          mtu = 0;
          queues = 0;
          rate_limit = 0;
          vlan_id = 0;
          trunks = "";
        }
      ];

    }) nixosNodes;

  resource.terraform_data = builtins.mapAttrs (name: _:
    {
      depends_on = [ "proxmox_virtual_environment_vm.${name}" ];
      triggers_replace = [ "\${proxmox_virtual_environment_vm.${name}.id}" ];

      provisioner.local-exec = {
        /*
          FIXME:
          Horrendous script!
          Instead of sleeping for 20s, check if the ssh pub key exists on the filesystem with `[ -f ... ]`.
          There are race conditions and ssh key may not yet be generated when the qemu agent runs `cat ...`
        */
        command = ''
          api_base="${proxmoxEndpoint}/api2/json"
          auth_header="Authorization: PVEAPIToken=''${var.proxmox_api_token}"
          vm_id="''${proxmox_virtual_environment_vm.${name}.vm_id}"
          node="proxmox-um790"
          qemu_agent_path="''$''${api_base}/nodes/''$''${node}/qemu/''$''${vm_id}/agent"

          alive=0
          for i in $(seq 1 60); do
            curl --silent --insecure --fail -H "$auth_header" -X POST "''$''${qemu_agent_path}/ping" && alive=1 && break
            sleep 1
          done

          if [ $alive -eq 0 ]; then
            printf 'VM is not responding to QEMU ping requests, cannot obtain the public ssh key\n'
            exit 1
          fi

          sleep 20
          pid=$(curl --silent --insecure -H "$auth_header" -H "Content-Type: application/json" -X POST -d '{"command": ["cat", "/etc/ssh/ssh_host_ed25519_key.pub"]}' "''$''${qemu_agent_path}/exec" | jq -r '.data.pid')

          sleep 5
          mkdir -p ../keys || exit 1
          curl --silent --insecure -H "$auth_header" -X GET "''$''${qemu_agent_path}/exec-status?pid=''$''${pid}" | jq -r '.data.["out-data"]' | cut -d ' ' -f 1,2 > ../keys/${name}.pub
        '';
      };

    }) nixosNodes;

/*
  Terraform resources for Unifi
  FIXME: move to a separate file and import here
*/

  terraform.required_providers.unifi = {
    source = "filipowm/unifi";
    version = "1.1.0";
  };

  variable.unifi_api_token = {
    type = "string";
    sensitive = true;
  };

  provider.unifi = {
    api_url = unifiEndpoint;
    api_key = "\${var.unifi_api_token}";
    allow_insecure = true;
  };

  resource.unifi_network.services = {
    name = "services";
    subnet = "10.10.10.1/24";
    vlan_id = 3919;

    # regular full access network
    # https://registry.terraform.io/providers/filipowm/unifi/latest/docs/resources/network#purpose-1
    purpose = "corporate";

    dhcp_enabled = true;
    dhcp_start = "10.10.10.6";
    dhcp_stop = "10.10.10.254";

    dhcp_v6_enabled = false;
    dhcp_v6_dns_auto = false;
    ipv6_ra_enable = true;
    ipv6_ra_valid_lifetime = 0;
  };

  resource.unifi_user = builtins.mapAttrs (name: node:
    {
      inherit name;
      mac = node.mac;
      fixed_ip = node.ip;
      network_id = "\${unifi_network.services.id}";
      allow_existing = true;

      note = "Homelab node '${name}', managed through terraform";
    }) inventory.nodes;

  resource.unifi_dns_record = nodesDNSRecords // proxiedDNSRecords;
}
