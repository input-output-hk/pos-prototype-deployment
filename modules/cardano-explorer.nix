with import ../lib.nix;

{ config, pkgs, lib, ... }:

let
  cardanoPackages = import ../default.nix {};
  explorer-drv = cardanoPackages.nix-tools.cexes.cardano-sl-explorer.cardano-explorer;
in
{
  imports = [ ./cardano.nix ];
  global.dnsHostname   = mkForce   "cardano-explorer";

  services.cardano-node.executable = "${explorer-drv}/bin/cardano-explorer";

  networking.firewall.allowedTCPPorts = [
    80 443 # nginx
  ];
  environment.systemPackages = with pkgs; [ goaccess ];

  systemd.services.cardano-node.serviceConfig.LimitNOFILE = 4096;

  services.nginx = {
    enable = true;
    commonHttpConfig = ''
      log_format x-fwd '$remote_addr - $remote_user [$time_local] '
                       '"$request" $status $body_bytes_sent '
                       '"$http_referer" "$http_user_agent" "$http_x_forwarded_for"';
      access_log syslog:server=unix:/dev/log x-fwd;
    '';
    virtualHosts =
     let vhostDomainName = if config.global.dnsDomainname != null
                           then config.global.dnsDomainname else "iohkdev.io";
     in {
      "cardano-explorer.${vhostDomainName}" = {
        enableACME = true;
        addSSL = true;
        locations = {
          "/" = {
            root = cardanoPackages.explorerFrontend;
            # Serve static files or fallback to browser history api
            tryFiles = "$uri /index.html";
          };
          "/api/blocks/range/".extraConfig = "return 404;";
          "/api/".proxyPass = "http://127.0.0.1:8100";
          "/socket.io/" = {
            proxyPass = "http://127.0.0.1:8110";
            extraConfig = ''
              proxy_http_version 1.1;
              proxy_set_header Upgrade $http_upgrade;
              proxy_set_header Connection "upgrade";
              proxy_read_timeout 86400;
            '';
          };
        };
        # Otherwise nginx serves files with timestamps unixtime+1 from /nix/store
        extraConfig = ''
          if_modified_since off;
          add_header Last-Modified "";
          etag off;
        '';
      };
    };
    eventsConfig = ''
      worker_connections 1024;
    '';
    appendConfig = ''
      worker_processes 4;
      worker_rlimit_nofile 2048;
    '';
  };
}
