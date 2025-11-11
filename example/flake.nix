{
  inputs = {
    xnode-manager.url = "github:Openmesh-Network/xnode-manager";
    nixified-ai.url = "github:nixified-ai/flake";
    miniapp-factory-imagegen.url = "github:OpenxAI-Network/miniapp-factory-imagegen";
    nixpkgs.follows = "nixified-ai/nixpkgs";
    host.url = "path:/etc/nixos";
    host-nixpkgs.follows = "host/nixpkgs";
  };

  nixConfig = {
    extra-substituters = [
      "https://ai.cachix.org"
      "https://nix-community.cachix.org"
      "https://cuda-maintainers.cachix.org"
    ];
    extra-trusted-public-keys = [
      "ai.cachix.org-1:N9dzRK+alWwoKXQlnn0H6aUx0lU/mspIoz8hMvGvbbc="
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
        inputs.nixified-ai.nixosModules.comfyui
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

            systemd.services.comfyui.serviceConfig.DynamicUser = args.lib.mkForce false;
            systemd.services.comfyui.serviceConfig.ProtectHome = args.lib.mkForce false;
            services.comfyui.enable = true;
            services.comfyui.user = "miniapp-factory-imagegen";
            services.comfyui.models = [
              (pkgs.fetchResource {
                name = "qwen-image-Q4_K_M.gguf";
                url = "https://huggingface.co/city96/Qwen-Image-gguf/resolve/main/qwen-image-Q4_K_M.gguf";
                sha256 = "sha256-xvSRA2A7mkknUCVJ+2FckQOGz8Z1sUZjJZMLoQ0qEfQ=";
                passthru = {
                  comfyui.installPaths = [ "diffusion_models" ];
                };
              })
              (pkgs.fetchResource {
                name = "Qwen-Image-Lightning-4steps-V2.0.safetensors";
                url = "https://huggingface.co/lightx2v/Qwen-Image-Lightning/resolve/main/Qwen-Image-Lightning-4steps-V2.0.safetensors";
                sha256 = "sha256-h4xRm3WqoZxfN+9XsxKsA16Tago2sU4CJp6d/VPSwig=";
                passthru = {
                  comfyui.installPaths = [ "loras" ];
                };
              })
              (pkgs.fetchResource {
                name = "qwen_2.5_vl_7b_fp8_scaled.safetensors";
                url = "https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors";
                sha256 = "sha256-y1Y22FKg6mqQdasb70lsDbeu8TwCNQVx44iuqVnFwLQ=";
                passthru = {
                  comfyui.installPaths = [ "text_encoders" ];
                };
              })
              (pkgs.fetchResource {
                name = "qwen_image_vae.safetensors";
                url = "https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/vae/qwen_image_vae.safetensors";
                sha256 = "sha256-pwWA8CE+Z5Z+6clfBbtADo+wgwfgF6kkvzRBIj4CPR8=";
                passthru = {
                  comfyui.installPaths = [ "vae" ];
                };
              })
            ];
            services.comfyui.customNodes = [
              pkgs.comfyuiPackages.comfyui-gguf
            ];
            services.comfyui.environmentVariables = {
              "PYTORCH_CUDA_ALLOC_CONF" = "expandable_segments:True";
            };

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
