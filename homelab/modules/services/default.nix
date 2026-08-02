{ ... }:
{
  imports = [
    ./grafana.nix
    ./victoria-metrics.nix
    ./proxy.nix
    ./nextcloud.nix
  ];
}
