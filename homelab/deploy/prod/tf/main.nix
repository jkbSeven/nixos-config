{
  lib,
  libHomelab,
  inventory,
  nodes,
  ...
}:
let
  nixosNodes = libHomelab.filterAttrs (nodeName: nodeConfig: nodeConfig.vm != null) inventory.nodes;
  proxmoxEndpoint = "https://10.10.10.10:8006";
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
}
