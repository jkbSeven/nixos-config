host := `hostname`
default_switch_config := if host == "nixos-pc" { 
    "pc" 
} else if host == "nixos-thinkpad" {
    "thinkpad6"
} else {
    "unsupported"
}

env_pattern := "stg|prod"

# generate ssh key pair for a given node, for a given environment
[arg('env', long, pattern=env_pattern)]
[arg('force', long, value="1")]
[group('homelab')]
gen-ssh-key node env="stg" force="0":
    #!/bin/sh

    env_dir="./homelab/deploy/{{ env }}"
    mkdir -p $env_dir || exit 1

    key_dir="${env_dir}/keys"
    mkdir -p $key_dir || exit 1

    node="{{ node }}"

    priv_key_path="${key_dir}/node-${node}.host_ssh"
    pub_key_path="${priv_key_path}.pub"

    if [ -f "$priv_key_path" ] || [ -f "$pub_key_path" ]; then
        if [ ! {{ force }} -eq 1 ]; then
            printf 'WARNING: key for node %s already exists at %s, not overwriting\n' "$node" "$key_dir"
            exit 0
        else
            printf 'INFO: key for node %s already exists at %s, but option --force was used, so overwriting\n' "$node" "$key_dir"
            rm -f "$priv_key_path" "$pub_key_path"
        fi
    fi

    printf 'INFO: generating ssh keys for node %s\n' "$node"

    # -q for silencing unnecessary output; -t for key type;
    # -N to omit passphrase; -C to overwrite the default hostname comment
    ssh-keygen -q -t ed25519 -N "" -C "$node" -f "$priv_key_path" || exit 1

# build qcow2 image for the baseline vm
[group('homelab')]
build-vm-image output="result":
    #!/bin/sh
    printf 'INFO: building baseline vm image\n'

    # default output name is 'result'
    nix build -o "{{ output }}" .#nixosConfigurations.vm-base.config.system.build.images.qemu || exit 1

# allocate baseline vm image for a node
[arg('env', long, pattern=env_pattern)]
[arg('vm_image_path', long="vm-image-path")]
[arg('force', long, value="1")]
[group('homelab')]
allocate-vm-image node env="stg" vm_image_path="result" force="0":
    #!/bin/sh

    env_dir="./homelab/deploy/{{ env }}"
    mkdir -p $env_dir || exit 1

    images_dir="${env_dir}/images"
    mkdir -p "$images_dir" || exit 1

    node="{{ node }}"
    image_path="${images_dir}/${node}.qcow2"

    if [ -f "${image_path}" ]; then
        if [ ! {{ force }} -eq 1 ]; then
            printf 'WARNING: image for node %s already exists at %s, not overwriting\n' "$node" "$image_path"
            exit 0
        else
            printf 'INFO: image for node %s already exists at %s, but option --force was used, so overwriting\n' "$node" "$image_path"
        fi
    fi

    printf 'INFO: allocating vm image to %s\n' "$image_path"
    cp {{ vm_image_path }}/nixos*.qcow2 "$image_path" || exit 1
    chmod 0600 "$image_path" || exit 1

# inject host ssh key into node's qcow2 image
[arg('env', long, pattern=env_pattern)]
[arg('preserve_priv_key', long="preserve-private-key", value="1")]
[arg('force', long, value="1")]
[group('homelab')]
inject-ssh-key node env="stg" preserve_priv_key="0" force="0":
    #!/bin/sh

    env_dir="./homelab/deploy/{{ env }}"
    if [ ! -d "$env_dir" ]; then
        printf 'Deployment dir for env "%s" does not exist, you need to build qcow images first\n' {{ env }}
        exit 1
    fi

    node="{{ node }}"
    image_path="${env_dir}/images/${node}.qcow2"
    priv_key_path="${env_dir}/keys/node-${node}.host_ssh"
    pub_key_path="${env_dir}/keys/node-${node}.host_ssh.pub"

    if [ ! -f "$priv_key_path" ]; then
        printf 'ERROR: private key for node %s was not found on path %s\n' "$node" "$priv_key_path"
        exit 1
    fi

    printf 'INFO: injecting ssh keys for node %s\n' "$node"
    guestfish --add "$image_path" --rw --file <(sed "s#SED_PRIVATE_KEY_PATH#${priv_key_path}#" ./homelab/deploy/inject_ssh.guestfish | sed "s#SED_PUBLIC_KEY_PATH#${pub_key_path}#") || exit 1

    if [ 0 -eq "{{ preserve_priv_key }}" ]; then
        printf 'INFO: shreding private ssh key for node %s\n' "$node"
        shred -u "$priv_key_path" || exit 1
    fi

# bootstrap vm images for all nodes
[arg('env', long, pattern=env_pattern)]
[group('homelab')]
bootstrap env="stg":
    #!/bin/sh

    env_dir="./homelab/deploy/{{ env }}"

    # FIXME: filter non-nixos nodes
    if ! nodes=$(nix eval --json --file "${env_dir}/inventory.nix" --apply 'builtins.attrNames' nodes | jq -r '.[]'); then
        exit 1
    fi

    just build-vm-image || exit 1

    for node in $nodes; do
        printf '=== Node %s ===\n' "$node"
        just bootstrap-node $node --env {{ env }} --no-nix-build-vm-image || exit 1
        printf '\n'
    done

# bootstrap a vm image for a given node
[arg('env', long, pattern=env_pattern)]
[arg('build_vm_image', long="no-nix-build-vm-image", value="0")]
[group('homelab')]
bootstrap-node node env="stg" build_vm_image="1":
    #!/bin/sh

    node="{{ node }}"

    if [ {{ build_vm_image }} -eq 1 ]; then
        just build-vm-image || exit 1
    fi

    just allocate-vm-image $node --env {{ env }} || exit 1
    just gen-ssh-key $node --env {{ env }} || exit 1
    just inject-ssh-key $node --env {{ env }} || exit 1

# list all declared nodes for a given environment
[arg('env', long, pattern=env_pattern)]
[group('homelab')]
ls-nodes env="stg":
    #!/bin/sh

    env_dir="./homelab/deploy/{{ env }}"

    # FIXME: filter non-nixos nodes
    if ! nodes=$(nix eval --json --file "${env_dir}/inventory.nix" --apply 'builtins.attrNames' nodes | jq -r '.[]'); then
        exit 1
    fi

    printf '%s\n' $nodes

[arg('env', long, pattern=env_pattern)]
[group('homelab')]
_build_tf_config env="stg":
    nix build -o homelab/deploy/{{ env }}/config.tf.json.tmp .#infra.{{ env }}.tf
    cp homelab/deploy/{{ env }}/config.tf.json.tmp homelab/deploy/{{ env }}/config.tf.json
    chmod 0600 homelab/deploy/{{ env }}/config.tf.json
    rm homelab/deploy/{{ env }}/config.tf.json.tmp

# run terraform commands within a given environment
[arg('env', long, pattern=env_pattern)]
[group('homelab')]
tf env="stg" +ARGS: (_build_tf_config env)
    terraform -chdir=homelab/deploy/{{ env }} {{ ARGS }}

# deploy infra changes for a given environment (colmena + tf)
[arg('env', long, pattern=env_pattern)]
[group('homelab')]
deploy env="stg": (_build_tf_config env)
    terraform -chdir=homelab/deploy/{{ env }} apply
    colmena apply -f homelab/deploy/{{ env }}/hive.nix

# switch to new nixos configuration on the current host
switch config=default_switch_config:
    #!/bin/sh
    if [ "{{ config }}" = "unsupported" ]; then
        echo "Unsupported hostname: {{ host }}. Aborting"
        exit 1
    fi
    sudo nixos-rebuild switch --flake .#{{ config }}
