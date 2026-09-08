{
  config,
  lib,
  nodes,
  ...
}:

let
  cfg = config.homelab.services.proxy;
  domain = config.homelab.settings.domain;
  secretsDir = config.homelab.settings.secretsDir;

  defaultVHostConfig = {
    forceSSL = true;
    enableACME = true;

    # https://github.com/NixOS/nixpkgs/issues/210807
    acmeRoot = null;
  };

  discoverVHosts = nodes: map (n: builtins.mapAttrs (_: config: defaultVHostConfig // config) n.config.homelab.proxy.virtualHosts) (builtins.attrValues nodes);
  extraVHosts = lib.mapAttrsToList (name: config: { "${name}" = (defaultVHostConfig // config); } ) config.homelab.settings.inventory.extraProxyVHosts;
in
{
  options.homelab.services.proxy.enable = lib.mkEnableOption "Enable Nginx proxy that uses virtualHosts published by other modules";

  config = lib.mkIf cfg.enable {

    security.acme = {
      acceptTerms = true;

      defaults = {
        email = "Jacob202@pm.me";
        dnsProvider = "cloudflare";
        environmentFile = "${secretsDir}/cloudflare";
      };

      certs = {
        "${domain}" = {
          domain = "*.${domain}";
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

      virtualHosts = lib.mkMerge ((discoverVHosts nodes) ++ extraVHosts);
    };

    networking.firewall.allowedTCPPorts = [
      80
      443
    ];

  };
}
