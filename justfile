host := `hostname`
default_switch_config := if host == "nixos-pc" { 
    "pc" 
} else if host == "nixos-thinkpad" {
    "thinkpad6"
} else {
    "unsupported"
}

env_pattern := "stg|prod"

# generate ssh key pair for each homelab node for a given environment
[arg('env', long, pattern=env_pattern)]
[group('homelab')]
gen-keys env="stg":
    #!/bin/sh

    env_dir="./homelab/deploy/{{ env }}"
    mkdir -p $env_dir || exit 1

    # FIXME: filter non-nixos nodes
    if ! nodes=$(nix eval --json --file "${env_dir}/inventory.nix" --apply 'builtins.attrNames' nodes | jq -r '.[]'); then
        exit 1
    fi

    key_dir="${env_dir}/keys"
    mkdir -p $key_dir || exit 1

    for node in $nodes; do
        key_path="${key_dir}/node-${node}.host_ssh"

        if [ -f $key_path ]; then
            printf 'WARNING: key for node %s already exists at %s, not overwriting\n' "$node" "$key_path"
            continue
        fi

        # -q for silencing unnecessary output; -t for key type;
        # -N to omit passphrase; -C to overwrite the default hostname comment
        ssh-keygen -q -t ed25519 -N "" -C "Node: $node" -f $key_path || exit 1
    done

# bulid qcow2 images for homelab nodes
[arg('env', long, pattern=env_pattern)]
[group('homelab')]
build-images env="stg":
    #!/bin/sh

    printf 'INFO: building baseline vm image\n'

    # default output name is 'result'
    nix build .#nixosConfigurations.vm-base.config.system.build.images.qemu || exit 1

    env_dir="./homelab/deploy/{{ env }}"
    mkdir -p $env_dir || exit 1

    # FIXME: filter non-nixos nodes
    if ! nodes=$(nix eval --json --file "${env_dir}/inventory.nix" --apply 'builtins.attrNames' nodes | jq -r '.[]'); then
        exit 1
    fi

    images_dir="${env_dir}/images"
    mkdir -p "$images_dir" || exit 1

    for node in $nodes; do
        image_path="${images_dir}/${node}.qcow2"

        if [ -f "${image_path}" ]; then
            printf 'WARNING: image for node %s already exists at %s, not overwriting\n' "$node" "$image_path"
            continue
        fi

        printf 'INFO: copying baseline image to %s\n' "$image_path"
        cp result/nixos*.qcow2 "$image_path" || exit 1
        chmod 0600 "$image_path" || exti 1
    done

# inject host ssh key into each node's qcow2 image
[arg('env', long, pattern=env_pattern)]
[arg('preserve_priv_keys', long="preserve-private-keys", value="1")]
[group('homelab')]
inject-ssh-keys env="stg" preserve_priv_keys="0":
    #!/bin/sh

    env_dir="./homelab/deploy/{{ env }}"
    if [ ! -d "$env_dir" ]; then
        printf 'Deployment dir for env "%s" does not exist, you need to build qcow images first\n' {{ env }}
        exit 1
    fi

    # FIXME: filter non-nixos nodes
    if ! nodes=$(nix eval --json --file "${env_dir}/inventory.nix" --apply 'builtins.attrNames' nodes | jq -r '.[]'); then
        exit 1
    fi

    for node in $nodes; do
        image_path="${env_dir}/images/${node}.qcow2"
        priv_key_path="${env_dir}/keys/node-${node}.host_ssh"
        pub_key_path="${env_dir}/keys/node-${node}.host_ssh.pub"

        printf 'INFO: injecting ssh keys for node %s\n' "$node"
        guestfish --add "$image_path" --rw --file <(sed "s#SED_PRIVATE_KEY_PATH#${priv_key_path}#" ./homelab/deploy/inject_ssh.guestfish | sed "s#SED_PUBLIC_KEY_PATH#${pub_key_path}#") || exit 1

        if [ 0 -eq "{{ preserve_priv_keys }}" ]; then
            printf 'INFO: shreding private ssh key for node %s\n' "$node"
            shred -u "$priv_key_path" || exit 1
        fi
    done

# bootstrap homelab infrastructure
[arg('env', long, pattern=env_pattern)]
[group('homelab')]
bootstrap env="stg": (build-images env) (gen-keys env) (inject-ssh-keys env)

# switch to new nixos configuration on the current host
switch config=default_switch_config:
    #!/bin/sh
    if [ "{{ config }}" = "unsupported" ]; then
        echo "Unsupported hostname: {{ host }}. Aborting"
        exit 1
    fi
    sudo nixos-rebuild switch --flake .#{{ config }}
