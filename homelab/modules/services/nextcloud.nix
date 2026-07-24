{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.homelab.services.nextcloud;
  domain = config.homelab.settings.domain;
in
{
  options.homelab.services.nextcloud.enable = lib.mkEnableOption "Enable nextcloud service";

  config = lib.mkIf cfg.enable {

    fileSystems."/mnt/nextcloud_data" = {
      device = "nas.jkb7.dev:/mnt/main/nextcloud_data"; # FIXME: hardcoded NAS hostname
      fsType = "nfs4";
      options = [ "noatime" ];
    };

    users.users.nextcloud = {
      isSystemUser = true;
      group = "nextcloud";
      uid = config.homelab.settings.users.nextcloud.uid;
    };

    users.groups.nextcloud.gid = config.homelab.settings.users.nextcloud.gid;

    services.nextcloud = {
      enable = true;
      package = pkgs.nextcloud33;

      hostName = "drive.${domain}";
      datadir = "/mnt/nextcloud_data";

      config.adminpassFile = "/var/lib/secrets/nextcloud";
      config.dbtype = "pgsql";
      database.createLocally = true;
    };

    systemd.services.remotefs-tmpfiles = {
      description = "Ensure nextcloud config directories are created after NFS share is mounted";
      path = [ "systemd-tmpfiles" ];
      script = "systemd-tmpfiles --create --remove --exclude-prefix=/dev";
      after = [ "remote-fs.target" ];
      requires = [ "remote-fs.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = "yes";
      };
    };

    systemd.services.nextcloud-setup = {
      after = [ "remotefs-tmpfiles.service" ];
      requires = [ "remotefs-tmpfiles.service" ];
    };

    systemd.services.phpfpm-nextcloud = {
      after = [ "remotefs-tmpfiles.service" ];
      requires = [ "remotefs-tmpfiles.service" ];
    };

    homelab.proxy.virtualHosts."drive.${domain}" = {
      locations."/" = {
        proxyPass = "http://${config.homelab.settings.thisNodeFqdn}";
        proxyWebsockets = true;
        extraConfig = "proxy_pass_header Authorization;";
      };
    };

    networking.firewall.extraInputRules = ''
      ip saddr ${config.homelab.settings.proxyIp} tcp dport 80 accept
    '';
  };
}
