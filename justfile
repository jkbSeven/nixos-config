host := `hostname`
default_switch_config := if host == "nixos-pc" { 
    "pc" 
} else if host == "nixos-thinkpad" {
    "thinkpad6"
} else {
    "unsupported"
}

# bootstrap homelab infrastructure
[group('homelab')]
bootstrap:
    @printf 'Not implemented :(\n'
    @exit 1

# deploy changes to homelab nodes
[arg('targets', long)]
[group('homelab')]
deploy targets='*' :
    colmena apply --on '{{ targets }}'

# generate ssh key pair for each homelab node for a given environment
[arg('env', long, pattern='stg|prod')]
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
            printf 'WARNING: key for node %s already exists at %s\n' "$node" "$key_path"
            continue
        fi

        # -q for silencing unnecessary output; -t for key type;
        # -N to omit passphrase; -C to overwrite the default hostname comment
        ssh-keygen -q -t ed25519 -N "" -C "Node: $node" -f $key_path || exit 1
    done


# switch to new nixos configuration on the current host
switch config=default_switch_config:
    #!/bin/sh
    if [ "{{ config }}" = "unsupported" ]; then
        echo "Unsupported hostname: {{ host }}. Aborting"
        exit 1
    fi
    sudo nixos-rebuild switch --flake .#{{ config }}
