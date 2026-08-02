- how to decalre fqdn for non-nix-managed nodes
- how to declare nginx vhosts / metrics targets / backup jobs for non-nix-managed nodes,
    so that they are propagated to other nodes and at the same time colmena doesn't try to deploy a nixos config
- a library function for generating fqdn, so that they can be used for `thisNodeFqdn` and also for terranix deployment to Unifi DNS
- I'm not sure if the `roles` approach is the optimal solution
- I feel like I need more stuff declared in static files (e.g. fqdns, admin user)
    and that current implementation of `mkNode` needs to be improved (the `homelab.settings` attribute set needs a redesign)
- currently lacking agenix, terranix (for proxmox, for unifi dns, for truenas shares and users)
- how to enable node exporter by default for nodes? should that go into the `mkNode` function?
    or maybe a "base" role that gets auto added for all nodes?


Get rid of `ip` in `inventory.nix`. Capture it dynamically when creating the VM through terraform and set the FQDN for given node.
