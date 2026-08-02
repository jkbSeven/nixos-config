{
  lib,
  ...
}:

{
  options.homelab.monitoring.scrapeTargets = lib.mkOption {
    type = lib.types.listOf lib.types.attrs;
    default = [ ];
    description = ''
      Rules for scraping metrics.
      Every node/service can declare custom targets.
      Targets are merged and injected into the metrics-db config.
    '';
  };
}
