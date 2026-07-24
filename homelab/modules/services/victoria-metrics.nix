{
  config,
  lib,
  nodes,
  ...
}:

let
  cfg = config.homelab.services.victoria-metrics;
in
{
  options.homelab.services.victoria-metrics = {
    enable = lib.mkEnableOption "Enable VictoriaMetrics";

    port = lib.mkOption {
      type = lib.types.int;
      default = 8428;
    };

  };

  config = lib.mkIf cfg.enable {

    services.victoriametrics = {
      enable = true;
      retentionPeriod = "3";  # months

      # FIXME: currently assumes grafana is running on the same node (as part of the `monitoring` role)
      listenAddress = "127.0.0.1:${builtins.toString cfg.port}";

      prometheusConfig.scrape_configs = lib.mkMerge (
        map (node: node.config.homelab.monitoring.scrapeTargets) (lib.attrValues nodes)
      );
    };

  };
}
