{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.fungivue.nginx;
in
{
  options.fungivue.nginx = {
    enable = mkEnableOption "NGINX web server for FungiVue";
    host = mkOption {
      type = types.str;
      default = "0.0.0.0";
      description = "Listen address";
    };
    port = mkOption {
      type = types.port;
      default = 80;
      description = "Listen port";
    };
    scanDirectory = mkOption {
      type = types.path;
      default = "/var/www/scans";
      description = "Directory containing ultrasound scan images";
    };
    vueAppDirectory = mkOption {
      type = types.path;
      default = "/var/www/fungi-vue";
      description = "Directory containing Vue.js webapp";
    };
    enableAPI = mkEnableOption "Flask API backend";
  };

  config = lib.mkIf cfg.enable {
    services.nginx = {
      enable = true;
      package = pkgs.nginx;

      virtualHosts.${cfg.host} = {
        listen = [ cfg.port ];
        root = cfg.vueAppDirectory;
        
        locations = {
          "/" = {
            index = "index.html";
            extraConfig = ''
              try_files $uri $uri/ /index.html;
            '';
          };
          
          "/scans/" = {
            alias = "${cfg.scanDirectory}/";
            extraConfig = ''
              autoindex on;
              add_header Cache-Control "no-cache";
            '';
          };
          
          "/api/" = lib.mkIf cfg.enableAPI {
            proxyPass = "http://127.0.0.1:5000/";
            proxySetHeader.Host = "$host";
            proxySetHeader.X-Real-IP = "$remote_addr";
            proxySetHeader.X-Forwarded-For = "$proxy_add_x_forwarded_for";
          };
        };
      };
    };

    environment.etc."fungivue/nginx.conf".text = ''
      server {
          listen ${toString cfg.port};
          server_name localhost;

          root ${cfg.vueAppDirectory};
          index index.html;

          location / {
              try_files $uri $uri/ /index.html;
          }

          location /scans/ {
              alias ${cfg.scanDirectory}/;
              autoindex on;
          }

          ${lib.optionalString cfg.enableAPI ''
          location /api/ {
              proxy_pass http://127.0.0.1:5000/;
              proxy_set_header Host $host;
              proxy_set_header X-Real-IP $remote_addr;
          }
          ''}
      }
    '';
  };
}
