{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.fungivue.hardware;
in
{
  options.fungivue.hardware = {
    enable = mkEnableOption "FungiVue hardware support (Arduino sensors)";
    arduinoPort = mkOption {
      type = types.str;
      default = "/dev/ttyUSB0";
      description = "Serial port for Arduino connection";
    };
    enableDocker = mkEnableOption "Docker support";
    enableAI = mkEnableOption "Ollama AI support";
  };

  config = lib.mkIf cfg.enable {
    users.groups.dialout = {};

    services.udev.rules = ''
      # Arduino Uno/Nano
      SUBSYSTEM=="usb", ATTR{idVendor}=="2341", ATTR{idProduct}=="0043", MODE="0666", GROUP="dialout"
      SUBSYSTEM=="usb", ATTR{idVendor}=="2341", ATTR{idProduct}=="0001", MODE="0666", GROUP="dialout"
      
      # Arduino Mega
      SUBSYSTEM=="usb", ATTR{idVendor}=="2341", ATTR{idProduct}=="0010", MODE="0666", GROUP="dialout"
      
      # CH340 USB-Serial (common on clones)
      SUBSYSTEM=="usb", ATTR{idVendor}=="1a86", ATTR{idProduct}=="7523", MODE="0666", GROUP="dialout"
      
      # CP2102 USB-Serial
      SUBSYSTEM=="usb", ATTR{idVendor}=="10c4", ATTR{idProduct}=="ea60", MODE="0666", GROUP="dialout"
    '';

    environment.systemPackages = with pkgs; [
      arduino
      picocom
      screen
    ];

    systemd.services.fungivue-imaging = {
      description = "FungiVue Ultrasound Imaging Service";
      wantedBy = [ "multi-user.target" ];
      after = [ "dev-serial.device" ];
      requires = [ "dev-serial.device" ];
      serviceConfig = {
        Type = "simple";
        User = "fungivue";
        Group = "dialout";
        ExecStart = "${pkgs.python3Packages.fungivue-imaging}/bin/fungivue-imaging";
        Restart = "on-failure";
        RestartSec = 10;
        UdevPackage = pkgs.systemd;
      };
    };

    users.users.fungivue = {
      isNormalUser = true;
      description = "FungiVue Imaging Service";
      group = "dialout";
      extraGroups = [ "dialout" ];
    };
  };
}
