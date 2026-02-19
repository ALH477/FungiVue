{
  description = "FungiVue: NixOS for Ultrasound Mushroom Growth Imaging on SBCs";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [
            (final: prev: {
              ubootOrangePiZero2W = prev.buildUBoot {
                defconfig = "orangepi_zero2w_defconfig";
                extraMeta.platforms = [ "aarch64-linux" ];
                filesToInstall = [ "u-boot-sunxi-with-spl.bin" ];
                version = "2024.04";
                src = prev.fetchurl {
                  url = "https://ftp.denx.de/pub/u-boot/u-boot-2024.04.tar.bz2";
                  hash = "sha256-GKhT/jn6160DqQzC1Cda6u1tppc13vrDSSuAUIhD3Uo=";
                };
                nativeBuildInputs = [
                  prev.dtc
                  prev.armTrustedFirmwareTools
                  prev.bison
                  prev.flex
                  prev.which
                  prev.swig
                  prev.openssl
                  (prev.python3.withPackages (p: [
                    p.setuptools
                    p.libfdt
                    p.pyelftools
                  ]))
                ];
                BL31 = "${prev.armTrustedFirmwareAllwinner}/bl31.bin";
              };

              dwm = prev.dwm.overrideAttrs (old: {
                src = prev.fetchgit {
                  url = "https://git.suckless.org/dwm";
                  rev = "6.4";
                  hash = "sha256-uhFal7PdyxC7ppKEATw3Q6DLFTdr0qbboIgFw1c2vQg=";
                };
                postPatch = ''
                  sed -i 's/#define MODKEY Mod1Mask/#define MODKEY Mod4Mask/' config.def.h
                '';
              });

              fungivue-vue-app = prev.stdenv.mkDerivation {
                name = "fungivue-vue-app";
                src = self.inputs.fungivue-vue-src or (
                  if prev.lib.pathExists ./src/vue
                  then ./src/vue
                  else prev.fetchurl {
                    url = "https://github.com/ALH477/FungiVue/archive/refs/heads/main.tar.gz";
                    hash = "sha256-0000000000000000000000000000000000000000000000000000000000000000";
                  }
                );
                nativeBuildInputs = [ prev.nodejs prev.npm ];

                buildPhase = ''
                  export HOME=$TMPDIR
                  cd $src
                  npm install
                  npm run build
                '';

                installPhase = ''
                  mkdir -p $out
                  cp -r dist/* $out/
                '';
              };

              fungivue-imaging = prev.stdenv.mkDerivation {
                name = "fungivue-imaging";
                src = ./src/python;
                nativeBuildInputs = [ prev.python3 ];
                buildPhase = ''
                  mkdir -p $out/bin
                  cp imaging_script.py $out/bin/fungivue-imaging
                  chmod +x $out/bin/fungivue-imaging
                '';
              };
            })
          ];
        };

        fungivueModule = { config, lib, ... }: {
          options = with lib; {
            enableFungiVue = mkEnableOption "FungiVue ultrasound imaging system";
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
          };

          config = lib.mkIf config.enableFungiVue {
            imports = [ ./modules/fungivue.nix ];

            environment.systemPackages = with pkgs; [
              fungivue-imaging
              python3Full
              python3Packages.numpy
              python3Packages.matplotlib
              python3Packages.pyserial
            ];

            users.groups.dialout = {};

            services.nginx = {
              enable = true;
              virtualHosts.localhost = {
                root = "${pkgs.fungivue-vue-app}";
                locations."/scans/".alias = "${config.fungivue.scanDirectory}/";
                locations."/".extraConfig = ''
                  try_files $uri $uri/ /index.html;
                '';
              };
            };

            systemd.services.fungivue-imaging = {
              description = "FungiVue Ultrasound Imaging Service";
              wantedBy = [ "multi-user.target" ];
              serviceConfig = {
                Type = "simple";
                ExecStart = "${pkgs.fungivue-imaging}/bin/fungivue-imaging";
                Restart = "on-failure";
                RestartSec = 5;
              };
              deviceConfig = {
                Unit = "dev-serial.device";
                RequiredBy = "fungivue-imaging.service";
              };
            };
          };
        };

        dockerModule = { config, lib, ... }: {
          options = with lib; {
            enableFungiVueDocker = mkEnableOption "Docker with socket activation for FungiVue";
          };

          config = lib.mkIf config.enableFungiVueDocker {
            virtualisation.docker = {
              enable = true;
              autoPrune.enable = true;
            };
            systemd.services.docker.wantedBy = lib.mkForce [];
            systemd.sockets.docker.wantedBy = lib.mkForce [ "sockets.target" ];
          };
        };

        aiModule = { config, lib, ... }: {
          options = with lib; {
            enableFungiVueAI = mkEnableOption "Ollama AI integration for FungiVue";
          };

          config = lib.mkIf config.enableFungiVueAI {
            services.ollama = {
              enable = true;
              host = "0.0.0.0";
            };
            systemd.services.ollama.wantedBy = lib.mkForce [];
          };
        };

      in
      {
        packages = {
          fungivue-vue-app = pkgs.fungivue-vue-app;
          fungivue-imaging = pkgs.fungivue-imaging;
        };

        nixosConfigurations = {
          opi-zero2w = nixpkgs.lib.nixosSystem {
            system = "aarch64-linux";
            modules = [
              "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
              fungivueModule
              dockerModule
              aiModule
              ({ config, lib, ... }: {
                nixpkgs.pkgs = pkgs;

                boot.kernelPackages = pkgs.linuxPackages_6_12;
                boot.supportedFilesystems = lib.mkForce [ "vfat" "ext4" ];

                hardware.deviceTree.name = "allwinner/sun50i-h618-orangepi-zero2w.dtb";
                boot.loader.grub.enable = false;
                boot.loader.generic-extlinux-compatible.enable = true;
                boot.kernelParams = [ "console=ttyS0,115200" ];

                zramSwap.enable = true;
                zramSwap.algorithm = "zstd";
                zramSwap.memoryPercent = 100;

                networking.hostName = "opi-fungivue";
                services.avahi = { enable = true; nssmdns4 = true; publish = { enable = true; addresses = true; }; };

                boot.kernelModules = [ "g_ether" ];
                hardware.deviceTree.overlays = [{
                  name = "usb0-peripheral";
                  dtsText = ''
                    /dts-v1/; /plugin/;
                    / { fragment@0 { target = <&usbotg>; __overlay__ { dr_mode = "peripheral"; status = "okay"; }; }; };
                  '';
                }];
                networking.interfaces.usb0.ipv4.addresses = [{ address = "10.0.0.1"; prefixLength = 24; }];
                networking.defaultGateway = "10.0.0.2";
                networking.nameservers = [ "1.1.1.1" ];

                services.xserver = {
                  enable = true;
                  videoDrivers = [ "modesetting" ];
                  windowManager.dwm.enable = true;
                  displayManager.lightdm.enable = true;
                  displayManager.sessionCommands = ''
                    while true; do
                      xsetroot -name "$(free -h | awk '/^Mem/ { print $7 }') avail | $(date +'%H:%M')"
                      sleep 10
                    done &
                  '';
                };
                services.displayManager.autoLogin = { enable = true; user = "root"; };

                fonts.packages = with pkgs; [ pkgs.nerd-fonts.jetbrains-mono ];

                environment.systemPackages = with pkgs; [
                  alpaca
                  vscodium
                  ollama
                  neovim
                  emacs-nox
                  git
                  wget
                  btop
                  st
                  dmenu
                ];

                sdImage = {
                  compressImage = true;
                  postBuildCommands = ''
                    dd if=${pkgs.ubootOrangePiZero2W}/u-boot-sunxi-with-spl.bin of=$img bs=1024 seek=8 conv=notrunc
                  '';
                };

                services.openssh = { enable = true; settings.PermitRootLogin = "yes"; };
                users.users.root.initialPassword = "nixos";
                system.stateVersion = "25.11";

                enableFungiVue = true;
                scanDirectory = "/var/www/scans";
                arduinoPort = "/dev/ttyUSB0";
                enableFungiVueDocker = true;
                enableFungiVueAI = true;
              })
            ];
          };

          rpi-zero2w = nixpkgs.lib.nixosSystem {
            system = "aarch64-linux";
            modules = [
              "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
              fungivueModule
              dockerModule
              aiModule
              ({ config, lib, pkgs, ... }: {
                boot.kernelPackages = pkgs.linuxPackages_latest;
                boot.supportedFilesystems = lib.mkForce [ "vfat" "ext4" "f2fs" ];
                boot.loader.grub.enable = false;
                boot.loader.generic-extlinux-compatible.enable = true;

                hardware.enableRedistributableFirmware = true;
                hardware.deviceTree.enable = true;

                zramSwap.enable = true;
                zramSwap.algorithm = "zstd";
                zramSwap.memoryPercent = 100;

                networking.hostName = "rpi-fungivue";
                services.avahi = { enable = true; nssmdns4 = true; publish = { enable = true; addresses = true; }; };

                services.xserver = {
                  enable = true;
                  videoDrivers = [ "modesetting" ];
                  windowManager.dwm.enable = true;
                  displayManager.lightdm.enable = true;
                };
                services.displayManager.autoLogin = { enable = true; user = "pi"; };

                fonts.packages = with pkgs; [ pkgs.nerd-fonts.jetbrains-mono ];

                environment.systemPackages = with pkgs; [
                  vscodium
                  neovim
                  git
                  wget
                  btop
                ];

                users.users.pi = {
                  isNormalUser = true;
                  description = "FungiVue User";
                  initialPassword = "nixos";
                  extraGroups = [ "networkmanager" "wheel" "dialout" ];
                  shell = pkgs.bash;
                };

                services.openssh = { enable = true; settings.PermitRootLogin = "yes"; };
                system.stateVersion = "25.11";

                enableFungiVue = true;
                scanDirectory = "/var/www/scans";
                arduinoPort = "/dev/ttyUSB0";
                enableFungiVueDocker = true;
                enableFungiVueAI = true;
              })
            ];
          };

          fungivue-dev = nixpkgs.lib.nixosSystem {
            inherit system;
            modules = [
              fungivueModule
              dockerModule
              aiModule
              ({ config, lib, ... }: {
                boot.loader.systemd-boot.enable = true;
                boot.loader.efi.canTouchEfiVariables = true;

                boot.kernelPackages = pkgs.linuxPackages_latest;

                networking.hostName = "fungivue-dev";
                networking.networkmanager.enable = true;

                time.timeZone = "America/Los_Angeles";
                i18n.defaultLocale = "en_US.UTF-8";

                services.xserver.enable = true;
                services.xserver.displayManager.sddm.enable = true;
                services.xserver.desktopManager.cinnamon.enable = true;

                users.users.devuser = {
                  isNormalUser = true;
                  description = "FungiVue Developer";
                  extraGroups = [ "networkmanager" "wheel" "dialout" ];
                  shell = pkgs.bash;
                };

                environment.systemPackages = with pkgs; [
                  python3Full
                  brave
                  git
                  vim
                  nodejs
                  npm
                ];

                services.openssh = { enable = true; settings.PermitRootLogin = "yes"; };
                system.stateVersion = "25.11";

                enableFungiVue = true;
                enableFungiVueDocker = true;
                enableFungiVueAI = true;
              })
            ];
          };
        };
      }
    );
}
