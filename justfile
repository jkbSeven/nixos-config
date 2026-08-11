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

# switch to new nixos configuration on the current host
switch config=default_switch_config:
    #!/bin/sh
    if [ "{{ config }}" = "unsupported" ]; then
        echo "Unsupported hostname: {{ host }}. Aborting"
        exit 1
    fi
    sudo nixos-rebuild switch --flake .#{{ config }}
