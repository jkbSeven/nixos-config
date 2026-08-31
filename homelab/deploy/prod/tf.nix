{
  lib,
  libHomelab,
  inventory,
  nodes,
  ...
}:
let
  nixosNodes = libHomelab.filterAttrs (nodeName: nodeConfig: nodeConfig.vm != null) inventory.nodes;
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

  provider.proxmox = {
    endpoint = "https://10.10.10.10:8006/";
    api_token = "\${var.proxmox_api_token}";
    insecure = true;

    ssh = {
      username = "deployer";
      private_key = "\${file(\"~/.ssh/keys/deployer\")}";
    };

    tmp_dir = "./tmp";
  };

  resource.proxmox_virtual_environment_file = builtins.mapAttrs (name: node:
    {
      content_type = "import";
      datastore_id = "local";
      node_name = "proxmox-um790";

      source_file = {
        path = "./images/${name}.qcow2";
      };
    }) nixosNodes;

  resource.proxmox_virtual_environment_vm = builtins.mapAttrs (name: node:
    {
      inherit name;
      node_name = "proxmox-um790";
      # vm_id = ...;
      tags = [ "prod" ];

      agent.enabled = true;

      cpu = {
        cores = node.vm.cores;
        type = "x86-64-v2-AES";
      };

      disk = {
        interface = "virtio0";
        file_format = "qcow2";
        import_from = "\${proxmox_virtual_environment_file.${name}.id}";
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

      started = false;


    }) nixosNodes;
}
