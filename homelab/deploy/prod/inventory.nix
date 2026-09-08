/*
  Source of truth for homelab infrastructure.
*/

let
  baseProxmoxMAC = "bc:24:11:10";
  baseIP = "10.10.10";
in
rec {
  domain = "jkb7.dev";

  nodes = {
    proxy = {
      ip = "${baseIP}.15";
      mac = "${baseProxmoxMAC}:00:01";
      roles = [ roles.proxy ];
      vm = {
        cores = 2;
        memory = 4096;
        disk = 16384;
      };
      tags = [ ];
    };

    monitoring = {
      ip = "${baseIP}.13";
      mac = "${baseProxmoxMAC}:00:02";
      roles = [ roles.monitoring ];
      vm = {
        cores = 4;
        memory = 4096;
        disk = 65536;
      };
      tags = [ ];
    };

    drive = {
      ip = "${baseIP}.14";
      mac = "${baseProxmoxMAC}:00:03";
      roles = [ roles.nextcloud ];
      vm = {
        cores = 2;
        memory = 4096;
        disk = 16384;
      };
      tags = [ ];
    };

    nas = {
      ip = "${baseIP}.11";
      mac = "c8:ff:bf:03:7c:fc";
      roles = [ ];
      vm = null;
      tags = [ ];
    };

  };

  users = {
    nextcloud = {
      uid = 4000;
      gid = 4000;
    };
  };

  roles = builtins.listToAttrs (
    map (roleName: { name = roleName; value = roleName; }) ["proxy" "monitoring" "nextcloud"]
  );

  extraProxyVHosts = {
    "proxmox.${domain}" = {
      locations."/" = {
        proxyPass = "https://proxmox.srv.jkb7.dev:8006";
        proxyWebsockets = true;
        extraConfig = "proxy_pass_header Authorization;";
      };
    };

    "photos.${domain}" = {
      /*
      Added to mitigate ambiguous errors when uploading big files:
          client_max_body_size 4G;
          proxy_request_buffering off;
          proxy_read_timeout 3600s;
          proxy_send_timeout 3600s;
      */
      locations."/" = {
        proxyPass = "http://immich.srv.jkb7.dev:30041";
        proxyWebsockets = true;
        extraConfig = ''
          client_max_body_size 4G;
          proxy_request_buffering off;
          proxy_read_timeout 3600s;
          proxy_send_timeout 3600s;
          proxy_pass_header Authorization;
        '';
      };
    };
  };
}
