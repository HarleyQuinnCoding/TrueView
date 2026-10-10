import torch, numpy as np
from transformers import AutoImageProcessor, AutoModelForImageClassification
import coremltools as ct

MODEL_ID = "Cr2do/ai-detector"  # ViT, MIT — verified by Samentha in Colab

processor = AutoImageProcessor.from_pretrained(MODEL_ID)
model = AutoModelForImageClassification.from_pretrained(MODEL_ID)
model.eval()

# Same wrapper trick: trace refuses dict outputs, CoreML wants a clean tensor.
class LogitsWrapper(torch.nn.Module):
    def __init__(self, m):
        super().__init__()
        self.m = m
    def forward(self, x):
        return self.m(x).logits

example = torch.rand(1, 3, 224, 224)
traced = torch.jit.trace(LogitsWrapper(model), example)

labels = [model.config.id2label[i] for i in range(len(model.config.id2label))]
mlmodel = ct.convert(
    traced,
    inputs=[ct.TensorType(name="image", shape=(1, 3, 224, 224), dtype=np.float32)],
    classifier_config=ct.ClassifierConfig(class_labels=labels),
    minimum_deployment_target=ct.target.iOS17,
)
mlmodel.save("TrueViewImageClassifier.mlpackage")
print("Saved TrueViewImageClassifier.mlpackage")
print("Label map:", model.config.id2label)

