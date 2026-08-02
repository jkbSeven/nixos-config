{
  config,
  lib,
  nodes,
  ...
}:

let
  cfg = config.homelab.services.victoria-metrics;

  mergeScrapeTargets = targetLists:
    let
      allJobs = builtins.concatLists targetLists;
      byJob = builtins.groupBy (j: j.job_name) allJobs;
    in
    lib.mapAttrsToList (job_name: jobs: {
      inherit job_name;
      static_configs = [
        {
          targets = lib.flatten (builtins.concatMap (j: map(sc: sc.targets) j.static_configs) jobs);
        }
      ];
    }) byJob;
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

      prometheusConfig.scrape_configs = mergeScrapeTargets (map (node: node.config.homelab.monitoring.scrapeTargets) (lib.attrValues nodes));
    };

  };
}
