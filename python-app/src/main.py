import websocket
import uuid
import json
from urllib import request
import random
import os

server_address = "127.0.0.1:8188"
client_id = str(uuid.uuid4())
prompt_text = """
{
  "3": {
    "inputs": {
      "seed": 559301131700773,
      "steps": 4,
      "cfg": 1,
      "sampler_name": "euler",
      "scheduler": "simple",
      "denoise": 1,
      "model": [
        "66",
        0
      ],
      "positive": [
        "6",
        0
      ],
      "negative": [
        "7",
        0
      ],
      "latent_image": [
        "58",
        0
      ]
    },
    "class_type": "KSampler",
    "_meta": {
      "title": "KSampler"
    }
  },
  "6": {
    "inputs": {
      "text": "A simple vector illustration of a yellow banana, curved, drawn in flat style with a white background. The banana should be centered and occupy most of the canvas.",
      "clip": [
        "38",
        0
      ]
    },
    "class_type": "CLIPTextEncode",
    "_meta": {
      "title": "CLIP Text Encode (Positive Prompt)"
    }
  },
  "7": {
    "inputs": {
      "text": "",
      "clip": [
        "38",
        0
      ]
    },
    "class_type": "CLIPTextEncode",
    "_meta": {
      "title": "CLIP Text Encode (Negative Prompt)"
    }
  },
  "8": {
    "inputs": {
      "samples": [
        "3",
        0
      ],
      "vae": [
        "39",
        0
      ]
    },
    "class_type": "VAEDecode",
    "_meta": {
      "title": "VAE Decode"
    }
  },
  "37": {
    "inputs": {
      "unet_name": "qwen_image_fp8_e4m3fn.safetensors",
      "weight_dtype": "default"
    },
    "class_type": "UNETLoader",
    "_meta": {
      "title": "Load Diffusion Model"
    }
  },
  "38": {
    "inputs": {
      "clip_name": "qwen_2.5_vl_7b_fp8_scaled.safetensors",
      "type": "qwen_image",
      "device": "default"
    },
    "class_type": "CLIPLoader",
    "_meta": {
      "title": "Load CLIP"
    }
  },
  "39": {
    "inputs": {
      "vae_name": "qwen_image_vae.safetensors"
    },
    "class_type": "VAELoader",
    "_meta": {
      "title": "Load VAE"
    }
  },
  "58": {
    "inputs": {
      "width": 512,
      "height": 512,
      "batch_size": 1
    },
    "class_type": "EmptySD3LatentImage",
    "_meta": {
      "title": "EmptySD3LatentImage"
    }
  },
  "60": {
    "inputs": {
      "filename_prefix": "ComfyUI",
      "images": [
        "8",
        0
      ]
    },
    "class_type": "SaveImage",
    "_meta": {
      "title": "Save Image"
    }
  },
  "66": {
    "inputs": {
      "shift": 3,
      "model": [
        "75",
        0
      ]
    },
    "class_type": "ModelSamplingAuraFlow",
    "_meta": {
      "title": "ModelSamplingAuraFlow"
    }
  },
  "75": {
    "inputs": {
      "lora_name": "Qwen-Image-Lightning-4steps-V2.0.safetensors",
      "strength_model": 1,
      "model": [
        "37",
        0
      ]
    },
    "class_type": "LoraLoaderModelOnly",
    "_meta": {
      "title": "LoraLoaderModelOnly"
    }
  }
}
"""


def queue_prompt(prompt):
    p = {"prompt": prompt, "client_id": client_id}
    data = json.dumps(p).encode('utf-8')
    req =  request.Request("http://{}/prompt".format(server_address), data=data)
    return json.loads(request.urlopen(req).read())

# https://github.com/comfyanonymous/ComfyUI/blob/master/script_examples/websockets_api_example_ws_images.py
def execute_prompt(ws, prompt):
    prompt_id = queue_prompt(prompt)['prompt_id']
    while True:
        out = ws.recv()
        if isinstance(out, str):
            message = json.loads(out)
            if message['type'] == 'executing':
                data = message['data']
                if data['prompt_id'] == prompt_id:
                    if data['node'] is None:
                        break #Execution is done

def main():
    ws = websocket.WebSocket()
    ws.connect(f"ws://{server_address}/ws?clientId={client_id}")

    project = "cat-factory"
    input = "a fluffy fat orange cat"
    width = 512
    height = 512
    output = "cat"

    prompt = json.loads(prompt_text)
    prompt["3"]["inputs"]["seed"] = random.randint(1, 2**64)
    prompt["6"]["inputs"]["text"] = input
    prompt["58"]["inputs"]["width"] = width
    prompt["58"]["inputs"]["height"] = height
    prefix = f"{project}-{output}"
    prompt["60"]["inputs"]["filename_prefix"] = prefix

    execute_prompt(ws, prompt)

    os.rename(f"/var/lib/comfyui/.local/share/comfyui/output/{prefix}_00001_.png", f"/var/lib/miniapp-factory-imagegen/{output}.png")
    # os.rename(f"/var/lib/comfyui/.local/share/comfyui/output/{prefix}_00001_.png", f"/var/lib/miniapp-factory-imagegen/projects/{project}/miniapp/public/{output}.png")
    # os.rename(f"/var/lib/miniapp-factory-imagegen/projects/{project}/miniapp/public/{output}.png.todo", f"/var/lib/miniapp-factory-imagegen/projects/{project}/miniapp/public/{output}.png.done")

    ws.close()


if __name__ == "__main__":
    main()