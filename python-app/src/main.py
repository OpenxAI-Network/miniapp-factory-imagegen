from diffusers import DiffusionPipeline, FlowMatchEulerDiscreteScheduler, QwenImageTransformer2DModel
import torch 
import math

# https://huggingface.co/docs/diffusers/main/api/pipelines/qwenimage#lora-for-faster-inference
def main():
    if torch.cuda.is_available():
        print(f"Found device: {torch.cuda.get_device_name()} (VRAM: {torch.cuda.get_device_properties(0).total_memory / 1024**3:.1f}GB)")

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

    # transformer = QwenImageTransformer2DModel.from_pretrained(
    #     "/var/lib/miniapp-factory-imagegen/model",
    #     subfolder="transformer",
    #     torch_dtype=torch.float8_e4m3fn,
    #     local_files_only=True,
    #     low_cpu_mem_usage=True,
    #     device_map="balanced",
    #     offload_folder="/var/lib/miniapp-factory-imagegen/offload"
    # )
    # print("Finished loading transformer")
    # transformer.enable_layerwise_casting(storage_dtype=torch.float8_e4m3fn, compute_dtype=torch.bfloat16)

    pipe = DiffusionPipeline.from_pretrained(
        "/var/lib/miniapp-factory-imagegen/model",
        scheduler=scheduler,
        # transformer=transformer,
        torch_dtype={"transformer": torch.float8_e4m3fn, "default": torch.bfloat16},
        local_files_only=True,
        low_cpu_mem_usage=True,
        device_map="balanced",
        offload_folder="/var/lib/miniapp-factory-imagegen/offload"
    )
    print("Finished loading pipeline")

    pipe.enable_vae_tiling()
    pipe.enable_attention_slicing()
    pipe.enable_xformers_memory_efficient_attention()
    print("Finished optimizing pipeline")

    pipe.load_lora_weights(
        "/var/lib/miniapp-factory-imagegen/model/lora/lora.safetensors"
    )
    print("Finished loading lora")

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