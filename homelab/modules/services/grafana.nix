{
  config,
  lib,
  ...
}:

let
  cfg = config.homelab.services.grafana;
  domain = config.homelab.settings.domain;
in
{
  options.homelab.services.grafana = {
    enable = lib.mkEnableOption "Enable Grafana that interacts with VictoriaMetrics";

    secret = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/secrets/grafana";
    };

    port = lib.mkOption {
      type = lib.types.int;
      default = 3000;
    };
  };

  config = lib.mkIf cfg.enable {
    services.grafana = {
      enable = true;

      provision = {
        enable = true;
        datasources.settings.datasources = [
        {
          name = "Control Plane";
          type = "prometheus";

          # FIXME: currently assumes Victoria Metrics is on the same host
          url = "http://localhost:${toString config.homelab.services.victoria-metrics.port}";

          isDefault = true;
          editable = false;
        }
        ];
      };

      settings = {
        analytics.reporting_enable = false;
        security.secret_key = cfg.secret;

        server = {
          http_addr = "0.0.0.0";
          http_port = cfg.port;
          domain = domain;
        };

      };
    };

    homelab.proxy.virtualHosts."grafana.${domain}" = {
      locations."/" = {
        proxyPass = "http://${config.homelab.settings.thisNodeFqdn}:${builtins.toString cfg.port}";
        proxyWebsockets = true;
        extraConfig = "proxy_pass_header Authorization;";
      };
    };

    networking.firewall.extraInputRules = "ip saddr ${config.homelab.settings.proxyIp} tcp dport ${cfg.port} accept";
  };
}
