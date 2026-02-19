{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.fungivue;
in
{
  options.fungivue = {
    enable = mkEnableOption "FungiVue ultrasound imaging system";
    scanDirectory = mkOption {
      type = types.path;
      default = "/var/www/scans";
      description = "Directory to store ultrasound scan images";
    };
    arduinoPort = mkOption {
      type = types.str;
      default = "/dev/ttyUSB0";
      description = "Serial port for Arduino connection";
    };
    enableVueApp = mkEnableOption "Vue.js webapp dashboard";
    enablePythonScripts = mkEnableOption "Python imaging scripts";
    enableNGINX = mkEnableOption "NGINX web server";
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.scanDirectory != null;
        message = "FungiVue scanDirectory must be set";
      }
    ];

    environment.etc."fungivue/config.json".text = builtins.toJSON {
      scanDirectory = cfg.scanDirectory;
      arduinoPort = cfg.arduinoPort;
      version = "1.0.0";
    };

    users.groups.dialout = {};

    systemd.timers.fungivue-imaging = {
      description = "Timer for FungiVue imaging service";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "1min";
        OnUnitActiveSec = "60s";
        Persistent = true;
      };
    };
  };
}
