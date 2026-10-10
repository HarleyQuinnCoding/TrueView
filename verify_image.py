import torch, numpy as np, coremltools as ct
from transformers import AutoImageProcessor, AutoModelForImageClassification
from PIL import Image

MODEL_ID = "Cr2do/ai-detector"
processor = AutoImageProcessor.from_pretrained(MODEL_ID)
model = AutoModelForImageClassification.from_pretrained(MODEL_ID)
model.eval()

img = Image.open("test_real.jpg").convert("RGB")  # any real photo
inputs = processor(images=img, return_tensors="pt")

with torch.no_grad():
    torch_logits = model(**inputs).logits.numpy()

# Reproduce the processor EXACTLY (from preprocessor_config.json):
# resize 224x224 BICUBIC, /255, (x - 0.5) / 0.5
arr = np.array(img.resize((224, 224), Image.BICUBIC)).astype(np.float32) / 255.0
arr = (arr - 0.5) / 0.5
arr = arr.transpose(2, 0, 1)[None, ...].astype(np.float32)

mlmodel = ct.models.MLModel("TrueViewImageClassifier.mlpackage")
pred = mlmodel.predict({"image": arr})
core_label = pred["classLabel"]  # CoreML answers in words, thanks to classifier_config

torch_idx = int(torch_logits.argmax())
torch_label = model.config.id2label[torch_idx]

print("PyTorch says:", torch_label, "| CoreML says:", core_label)
assert torch_label == core_label, "MISMATCH — do not ship this model"
print("OK — conversion matches. Ship it.")

