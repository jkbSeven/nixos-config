{
  config,
  lib,
  nodes,
  ...
}:

let
  cfg = config.homelab.services.proxy;

  defaultVHostConfig = {
    forceSSL = true;
    enableACME = true;

    # https://github.com/NixOS/nixpkgs/issues/210807
    acmeRoot = null;
  };

  mergeVHosts = nodes: lib.mkMerge (
    map (n: builtins.mapAttrs (_: config: defaultVHostConfig // config) n.config.homelab.proxy.virtualHosts) (builtins.attrValues nodes)
  );
in
{
  options.homelab.services.proxy.enable = lib.mkEnableOption "Enable Nginx proxy that uses virtualHosts published by other modules";

  config = lib.mkIf cfg.enable {

    security.acme = {
      acceptTerms = true;

      defaults = {
        email = "Jacob202@pm.me";
        dnsProvider = "cloudflare";
        environmentFile = "/var/lib/secrets/cloudflare";
      };

      certs = {
        "jkb7.dev" = {
          domain = "*.jkb7.dev";
          group = "nginx";
        };
      };
    };

    services.nginx = {
      enable = true;

      recommendedTlsSettings = true;
      recommendedGzipSettings = true;
      recommendedProxySettings = true;
      recommendedOptimisation = true;

      virtualHosts = mergeVHosts nodes;
    };

    networking.firewall.allowedTCPPorts = [
      80
      443
    ];

  };
}
