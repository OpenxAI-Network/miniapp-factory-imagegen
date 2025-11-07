{
  inputs = {
    xnode-manager.url = "github:Openmesh-Network/xnode-manager";
    miniapp-factory-imagegen.url = "github:OpenxAI-Network/miniapp-factory-imagegen";
    nixpkgs.follows = "miniapp-factory-imagegen/nixpkgs";
    host.url = "path:/etc/nixos";
    host-nixpkgs.follows = "host/nixpkgs";
  };

  nixConfig = {
    extra-substituters = [
      "https://nix-community.cachix.org"
      "https://cuda-maintainers.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
    ];
  };

  outputs = inputs: {
    nixosConfigurations.container = inputs.nixpkgs.lib.nixosSystem {
      specialArgs = {
        inherit inputs;
      };
      modules = [
        inputs.xnode-manager.nixosModules.container
        {
          services.xnode-container.xnode-config = {
            host-platform = ./xnode-config/host-platform;
            state-version = ./xnode-config/state-version;
            hostname = ./xnode-config/hostname;
          };
        }
        inputs.miniapp-factory-imagegen.nixosModules.default
        (
          { pkgs, ... }@args:
          let
            host-pkgs = import inputs.host-nixpkgs {
              system = pkgs.system;
              config = {
                allowUnfree = true;
              };
            };
          in
          {
            services.miniapp-factory-imagegen.enable = true;

            nixpkgs.config.allowUnfree = true;
            nixpkgs.config.cudaSupport = true;

            hardware.graphics = {
              enable = true;
              extraPackages = [
                pkgs.nvidia-vaapi-driver
              ];
            };
            hardware.nvidia.open = true;
            services.xserver.videoDrivers = [ "nvidia" ];
            hardware.nvidia.package = host-pkgs.linuxPackages.nvidiaPackages.stable;
          }
        )
      ];
    };
  };
}
