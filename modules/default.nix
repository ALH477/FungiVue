{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.fungivue;
in
{
  options = with lib; {
    fungivue = {
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
      hardware = mkOption {
        type = types.attrsOf types.anything;
        default = {};
        description = "Hardware configuration submodule";
      };
      nginx = mkOption {
        type = types.attrsOf types.anything;
        default = {};
        description = "NGINX configuration submodule";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    imports = [
      ./hardware.nix
      ./nginx.nix
    ];

    environment.systemPackages = with pkgs; [
      pkgs.python3Full
      pkgs.python3Packages.numpy
      pkgs.python3Packages.matplotlib
      pkgs.python3Packages.pyserial
    ];

    users.groups.dialout = {};

    systemd.timers.fungivue-scan = {
      description = "Periodic FungiVue scan timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "30sec";
        OnUnitActiveSec = "60sec";
      };
    };

    environment.etc."fungivue/config.json".text = builtins.toJSON {
      scanDirectory = toString cfg.scanDirectory;
      arduinoPort = cfg.arduinoPort;
      version = "1.0.0";
    };
  };
}
