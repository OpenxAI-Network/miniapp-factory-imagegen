import getopt
import sys
from diffusers import DiffusionPipeline, FlowMatchEulerDiscreteScheduler
import torch 
import math

# https://huggingface.co/docs/diffusers/main/api/pipelines/qwenimage#lora-for-faster-inference
def main():
    try:
        opts, args = getopt.getopt(sys.argv[1:], "x", ["diffusion=", "lora="])
    except getopt.GetoptError as err:
        print(err)
        sys.exit(2)

    diffusion_path = "/var/lib/miniapp-factory-imagegen/Qwen-Image"
    lora_path = "/var/lib/miniapp-factory-imagegen/Qwen-Image-Lightning-4steps-V2.0.safetensors"

    for o, a in opts:
        if o == "--diffusion":
            diffusion_path = a
        elif o == "--lora":
            lora_path = a
        else:
            assert False, "unhandled option"

    if torch.cuda.is_available():
        torch_dtype = torch.bfloat16
        device = "cuda"
    else:
        torch_dtype = torch.float32
        device = "cpu"

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
    pipe = DiffusionPipeline.from_pretrained(diffusion_path, scheduler=scheduler, torch_dtype=torch_dtype).enable_vae_tiling().enable_model_cpu_offload().to(device)
    pipe.load_lora_weights(
        lora_path
    )

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
    image.save("/var/lib/miniapp-factory-imagegen/output.png")

if __name__ == "__main__":
    main()