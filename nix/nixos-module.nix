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
            "tokenizer"
            "vae"
          ];
          sha256 = "sha256-OqZwaFiF3oLXURVXkwJgWCkqcQSAUZ2QWupf3emefKw=";
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
        text-encoder = pkgs.fetchurl {
          name = "Comfy-Org/Qwen-Image_ComfyUI/qwen_2.5_vl_7b_fp8_scaled.safetensors";
          url = "https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors";
          sha256 = "sha256-y1Y22FKg6mqQdasb70lsDbeu8TwCNQVx44iuqVnFwLQ=";
        };
        text-encoder-config = pkgs.fetchurl {
          name = "Qwen/Qwen-Image/text_encoder/config.json";
          url = "https://huggingface.co/Qwen/Qwen-Image/resolve/main/text_encoder/config.json";
          sha256 = "sha256-CB1BuuTHWBWv3jQLXO452ccf6+P8MUbgNmp1pF2gwEs=";
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
          User = "miniapp-factory-imagegen";
          Group = "miniapp-factory-imagegen";
          StateDirectory = "miniapp-factory-imagegen";
        };
        script =
          let
            path = "/var/lib/miniapp-factory-imagegen";
          in
          ''
            rm -rf ${path}/model
            mkdir -p ${path}/model
            ln -s ${base}/model_index.json ${path}/model/model_index.json
            ln -s ${base}/scheduler ${path}/model/scheduler
            ln -s ${base}/tokenizer ${path}/model/tokenizer
            ln -s ${base}/vae ${path}/model/vae
            mkdir -p ${path}/model/transformer
            ln -s ${transformer} ${path}/model/transformer/diffusion_pytorch_model.safetensors
            ln -s ${transformer-config} ${path}/model/transformer/config.json
            mkdir -p ${path}/model/text_encoder
            ln -s ${text-encoder} ${path}/model/text_encoder/model.safetensors
            ln -s ${text-encoder-config} ${path}/model/text_encoder/config.json
            mkdir -p ${path}/model/lora
            ln -s ${lora} ${path}/model/lora/lora.safetensors

            rm -rf ${path}/offload
            mkdir -p ${path}/offload
            ${lib.getExe miniapp-factory-imagegen}
          '';
      };
  };
}
