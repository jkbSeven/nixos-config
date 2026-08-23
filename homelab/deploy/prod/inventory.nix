/*
  Source of truth for homelab infrastructure.
*/

rec {
  domain = "jkb7.dev";

  nodes = {
    proxy = {
      ip = "10.10.10.223";
      roles = [ roles.proxy ];
      vm = {
        cores = 2;
        memory = 4096;
        disk = 16384;
      };
      tags = [ ];
    };

    monitoring = {
      ip = "10.10.10.163";
      roles = [ roles.monitoring ];
      vm = {
        cores = 4;
        memory = 4096;
        disk = 65536;
      };
      tags = [ ];
    };

    drive = {
      ip = "10.10.10.77";
      roles = [ roles.nextcloud ];
      vm = {
        cores = 2;
        memory = 4096;
        disk = 16384;
      };
      tags = [ ];
    };

    nas = {
      ip = "10.10.10.11";
      roles = [ ];
      vm = null; # not managed through terraform
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
    "proxmox" = {
      locations."/" = {
        proxyPass = "https://proxmox.srv.jkb7.dev:8006";
        proxyWebsockets = true;
        extraConfig = "proxy_pass_header Authorization;";
      };
    };

    "photos" = {
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
