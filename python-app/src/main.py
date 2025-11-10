import getopt
import sys
from diffusers import DiffusionPipeline, FlowMatchEulerDiscreteScheduler, QwenImageTransformer2DModel
import torch 
import math
from mmgp import offload, profile_type

# https://huggingface.co/docs/diffusers/main/api/pipelines/qwenimage#lora-for-faster-inference
def main():
    try:
        opts, args = getopt.getopt(sys.argv[1:], "x", ["base=", "transformer=", "transformerconfig=", "lora="])
    except getopt.GetoptError as err:
        print(err)
        sys.exit(2)

    base_path = "/var/lib/miniapp-factory-imagegen/Qwen/Qwen-Image"
    transformer_path = "/var/lib/miniapp-factory-imagegen/qwen_image_fp8_e4m3fn.safetensors"
    transformer_config_path = "/var/lib/miniapp-factory-imagegen/transformer/config.json"
    lora_path = "/var/lib/miniapp-factory-imagegen/Qwen-Image-Lightning-4steps-V2.0.safetensors"

    for o, a in opts:
        if o == "--base":
            base_path = a
        elif o == "--transformer":
            transformer_path = a
        elif o == "--transformerconfig":
            transformer_config_path = a
        elif o == "--lora":
            lora_path = a
        else:
            assert False, "unhandled option"

    if torch.cuda.is_available():
        torch_dtype = torch.bfloat16
        device = "cuda"
        print(f"Found device: {torch.cuda.get_device_name()} (VRAM: {torch.cuda.get_device_properties(0).total_memory / 1024**3:.1f}GB)")
    else:
        torch_dtype = torch.float32
        device = "cpu"

    print(f"Running on {device}")

    scheduler_config = {
        "base_image_seq_len": 256,
        "base_shift": math.log(3),  # We use shift=3 in distillation
        "invert_sigmas": False,
        "max_image_seq_len": 8192,
        "max_shift": math.log(3),  # We use shift=3 in distillation
        "num_train_timesteps": 1000,
        "shift": 1.0,
        "shift_terminal": None,  # set shift_terminal to None
        "stochastic_sampling": False,
        "time_shift_type": "exponential",
        "use_beta_sigmas": False,
        "use_dynamic_shifting": True,
        "use_exponential_sigmas": False,
        "use_karras_sigmas": False,
    }
    scheduler = FlowMatchEulerDiscreteScheduler.from_config(scheduler_config)

    transformer = QwenImageTransformer2DModel.from_single_file(
        transformer_path,
        config = transformer_config_path,
        torch_dtype=torch_dtype,
        use_safetensors=True,
        local_files_only=True
    )
    print("Finished loading transformer")

    pipe = DiffusionPipeline.from_pretrained(
        base_path,
        scheduler=scheduler,
        transformer=transformer,
        torch_dtype=torch_dtype,
        use_safetensors=True,
        local_files_only=True
    ).enable_vae_tiling().enable_attention_slicing().enable_model_cpu_offload()
    print("Finished loading pipeline")

    pipe.load_lora_weights(
        lora_path
    )
    print("Finished loading lora")
        
    offload.profile({"transformer": pipe.transformer, "vae": pipe.vae}, profile_type.LowRAM_LowVRAM)
    print("Finished mmgp optimization")

    prompt = "a tiny astronaut hatching from an egg on the moon, Ultra HD, 4K, cinematic composition."
    negative_prompt = " "
    image = pipe(
        prompt=prompt,
        negative_prompt=negative_prompt,
        width=512,
        height=512,
        num_inference_steps=4,
        true_cfg_scale=1.0,
        generator=torch.manual_seed(0),
    ).images[0]
    image.save("output.png")

if __name__ == "__main__":
    main()