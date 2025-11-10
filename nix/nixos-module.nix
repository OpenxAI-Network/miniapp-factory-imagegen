{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.miniapp-factory-imagegen;
  miniapp-factory-imagegen = pkgs.callPackage ./package.nix { };
in
{
  options = {
    services.miniapp-factory-imagegen = {
      enable = lib.mkEnableOption "Enable the python app";
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.miniapp-factory-imagegen = { };
    users.users.miniapp-factory-imagegen = {
      isSystemUser = true;
      group = "miniapp-factory-imagegen";
    };

    systemd.services.miniapp-factory-imagegen =
      let
        base = pkgs.fetchgit {
          name = "Qwen/Qwen-Image";
          url = "https://huggingface.co/Qwen/Qwen-Image";
          branchName = "main";
          fetchLFS = true;
          sparseCheckout = [
            "scheduler"
            "text_encoder"
            "tokenizer"
            "vae"
          ];
          sha256 = "sha256-ueHakFFWvKgQsZrJz/eJF682QQ8IR7tZOkOGbGMmKuE=";
        };
        transformer = pkgs.fetchurl {
          name = "Comfy-Org/Qwen-Image_ComfyUI/qwen_image_fp8_e4m3fn.safetensors";
          url = "https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/diffusion_models/qwen_image_fp8_e4m3fn.safetensors";
          sha256 = "sha256-mHY6EncB62+1kJb3dCyzqn1k7VELn06ILYNR+BduPOM=";
        };
        transformer-config = pkgs.fetchurl {
          name = "Qwen/Qwen-Image/transformer/config.json";
          url = "https://huggingface.co/Qwen/Qwen-Image/resolve/main/transformer/config.json";
          sha256 = "sha256-G9HvI/FZtOs8iU6uzCrCuata0xyhv47MCw9xCB8HMLU=";
        };
        lora = pkgs.fetchurl {
          name = "lightx2v/Qwen-Image-Lightning/Qwen-Image-Lightning-4steps-V2.0.safetensors";
          url = "https://huggingface.co/lightx2v/Qwen-Image-Lightning/resolve/main/Qwen-Image-Lightning-4steps-V2.0.safetensors";
          sha256 = "sha256-h4xRm3WqoZxfN+9XsxKsA16Tago2sU4CJp6d/VPSwig=";
        };
      in
      {
        description = "Image generation server for Miniapp Factory";
        environment = {
          PYTHONUNBUFFERED = "1";
        };
        serviceConfig = {
          ExecStart = "${lib.getExe miniapp-factory-imagegen} --base=${base} --transformer=${transformer} --transformerconfig=${transformer-config} --lora=${lora}";
          User = "miniapp-factory-imagegen";
          Group = "miniapp-factory-imagegen";
          StateDirectory = "miniapp-factory-imagegen";
        };
      };
  };
}
