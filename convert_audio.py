import torch, numpy as np
from transformers import AutoFeatureExtractor, AutoModelForAudioClassification
import coremltools as ct

MODEL_ID = "MelodyMachine/Deepfake-audio-detection"  # wav2vec2, Apache 2.0

extractor = AutoFeatureExtractor.from_pretrained(MODEL_ID)
model = AutoModelForAudioClassification.from_pretrained(MODEL_ID)
model.eval()

# Fixed shape: 16 kHz mono, exactly 4 seconds = 64,000 samples.
# Same wrapper trick as the image model: trace refuses dict outputs,
# so forward() returns just the logits tensor.
class LogitsWrapper(torch.nn.Module):
    def __init__(self, m):
        super().__init__()
        self.m = m
    def forward(self, x):
        return self.m(x).logits

example = torch.rand(1, 64000)
traced = torch.jit.trace(LogitsWrapper(model), example)

labels = [model.config.id2label[i] for i in range(len(model.config.id2label))]

mlmodel = ct.convert(
    traced,
    inputs=[ct.TensorType(name="waveform", shape=(1, 64000), dtype=np.float32)],
    classifier_config=ct.ClassifierConfig(class_labels=labels),
    minimum_deployment_target=ct.target.iOS17,
)
mlmodel.save("TrueViewAudioClassifier.mlpackage")
print("Saved TrueViewAudioClassifier.mlpackage")
print("Label map:", model.config.id2label)

