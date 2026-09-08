host := `hostname`
default_switch_config := if host == "nixos-pc" { 
    "pc" 
} else if host == "nixos-thinkpad" {
    "thinkpad6"
} else {
    "unsupported"
}

env_pattern := "stg|prod"
default_env := "stg"

# build qcow2 image for the baseline vm
[arg('output', long)]
[arg('copy_to_deploy_dir', long="no-copy", value="0")]
[group('homelab')]
build-vm-image output="result" copy_to_deploy_dir="1":
    nix build -o "{{ output }}" .#nixosConfigurations.vm-base.config.system.build.images.qemu
    @if [ {{ copy_to_deploy_dir }} -eq 1 ]; then \
        cp {{ output }}/nixos*.qcow2 homelab/deploy/base.qcow2; \
        chmod 0600 homelab/deploy/base.qcow2; \
    fi

# list all declared nodes for a given environment
[arg('env', long, pattern=env_pattern)]
[group('homelab')]
ls-nodes env=default_env:
    #!/bin/sh

    env_dir="./homelab/deploy/{{ env }}"

    # FIXME: filter non-nixos nodes
    if ! nodes=$(nix eval --json --file "${env_dir}/inventory.nix" --apply 'builtins.attrNames' nodes | jq -r '.[]'); then
        exit 1
    fi

    printf '%s\n' $nodes

[arg('env', long, pattern=env_pattern)]
[group('homelab')]
_build_tf_config env=default_env:
    #!/bin/sh
    tf_path="homelab/deploy/{{ env }}/tf"

    nix build -o ${tf_path}/config.tf.json.tmp .#infra.{{ env }}.tf || exit 1
    cp ${tf_path}/config.tf.json.tmp ${tf_path}/config.tf.json || exit 1
    chmod 0600 ${tf_path}/config.tf.json || exit 1
    rm ${tf_path}/config.tf.json.tmp || exit 1

# run terraform commands within a given environment
[arg('env', long, pattern=env_pattern)]
[group('homelab')]
tf env=default_env +ARGS: (_build_tf_config env)
    terraform -chdir=homelab/deploy/{{ env }}/tf {{ ARGS }}

# deploy infra changes for a given environment (colmena + tf)
[arg('env', long, pattern=env_pattern)]
[group('homelab')]
deploy env=default_env: (_build_tf_config env)
    terraform -chdir=homelab/deploy/{{ env }}/tf apply
    colmena apply -f homelab/deploy/{{ env }}/hive.nix

# switch to new nixos configuration on the current host
switch config=default_switch_config:
    #!/bin/sh

    if [ "{{ config }}" = "unsupported" ]; then
        echo "Unsupported hostname: {{ host }}. Aborting"
        exit 1
    fi
    sudo nixos-rebuild switch --flake .#{{ config }}
