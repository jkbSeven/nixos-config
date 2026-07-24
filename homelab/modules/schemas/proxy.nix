{
  lib,
  ...
}:

{
  options.homelab.proxy.virtualHosts = lib.mkOption {
    type = lib.types.attrsOf lib.types.attrs;
    default = { };
    description = ''
      Configuration for vHosts.
      Every HTTP service should declare a vHost within its module.
      These configs are merged and injected into the config on the proxy node.
      (colmena passes a `nodes` attribute set that lets us merge all vHost configs, otherwise this wouldn't work)
    '';
  };
}
