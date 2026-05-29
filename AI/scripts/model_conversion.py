"""
Convert trained PyTorch models (.pth) to TensorFlow Lite (.tflite)
Steps:
1. Load PyTorch model
2. Export to ONNX
3. Convert ONNX to TensorFlow
4. Convert TensorFlow to TensorFlow Lite
"""

import torch
import torch.nn as nn
from pathlib import Path
import onnx
from onnx_tf.backend import prepare
import tensorflow as tf

# Set up directories
BASE_DIR = Path(__file__).parent.parent
RESULTS_DIR = BASE_DIR / "results"
MODELS_DIR = RESULTS_DIR / "models"
TFLITE_DIR = RESULTS_DIR / "tflite"
TFLITE_DIR.mkdir(parents=True, exist_ok=True)

# Model parameters (same as training)
EMBEDDING_DIM = 128
HIDDEN_DIM = 128
VOCAB_SIZE = 5002
MAX_INPUT_LEN = 200
MAX_OUTPUT_LEN = 50

# -------------------------
# Example Summarizer model
# -------------------------
class SummarizerModel(nn.Module):
    def __init__(self, vocab_size, embedding_dim, hidden_dim):
        super().__init__()
        self.embedding = nn.Embedding(vocab_size, embedding_dim, padding_idx=0)
        self.encoder = nn.LSTM(embedding_dim, hidden_dim, batch_first=True, bidirectional=True)
        self.decoder = nn.LSTM(embedding_dim, hidden_dim * 2, batch_first=True)
        self.output = nn.Linear(hidden_dim * 2, vocab_size)

    def forward(self, x):
        x_emb = self.embedding(x)
        enc_out, (h, c) = self.encoder(x_emb)
        dec_out, _ = self.decoder(x_emb, (torch.cat([h[-2], h[-1]], dim=1).unsqueeze(0),
                                          torch.cat([c[-2], c[-1]], dim=1).unsqueeze(0)))
        logits = self.output(dec_out)
        return logits

# -------------------------
# Example Q&A model
# -------------------------
class QAModel(nn.Module):
    def __init__(self, vocab_size, embedding_dim, hidden_dim):
        super().__init__()
        self.embedding = nn.Embedding(vocab_size, embedding_dim, padding_idx=0)
        self.question_encoder = nn.LSTM(embedding_dim, hidden_dim, batch_first=True, bidirectional=True)
        self.context_encoder = nn.LSTM(embedding_dim, hidden_dim, batch_first=True, bidirectional=True)
        self.answer_decoder = nn.LSTM(embedding_dim, hidden_dim * 2, batch_first=True)
        self.output = nn.Linear(hidden_dim * 2, vocab_size)

    def forward(self, question_seq, context_seq):
        q_emb = self.embedding(question_seq)
        _, (q_h, _) = self.question_encoder(q_emb)
        c_emb = self.embedding(context_seq)
        c_out, (c_h, _) = self.context_encoder(c_emb)
        decoder_h = torch.cat([c_h[-1], c_h[-2]], dim=1).unsqueeze(0)
        decoder_c = torch.cat([c_h[-1], c_h[-2]], dim=1).unsqueeze(0)
        dec_out, _ = self.answer_decoder(c_emb, (decoder_h, decoder_c))
        logits = self.output(dec_out)
        return logits

# -------------------------
# Conversion function
# -------------------------
def convert_pth_to_tflite(model_class, pth_file, tflite_file, input_shapes):
    """
    model_class : class of PyTorch model
    pth_file : path to .pth file
    tflite_file : output .tflite path
    input_shapes : dict of dummy input tensors {name: shape}
    """
    device = torch.device('cpu')

    # Load PyTorch model
    model = model_class(VOCAB_SIZE, EMBEDDING_DIM, HIDDEN_DIM).to(device)
    model.load_state_dict(torch.load(pth_file, map_location=device))
    model.eval()

    # Prepare dummy inputs for ONNX export
    dummy_inputs = [torch.randint(0, VOCAB_SIZE, shape) for shape in input_shapes.values()]

    # Export to ONNX
    onnx_file = str(TFLITE_DIR / (pth_file.stem + ".onnx"))
    torch.onnx.export(
        model,
        tuple(dummy_inputs) if len(dummy_inputs) > 1 else dummy_inputs[0],
        onnx_file,
        export_params=True,
        opset_version=13,
        input_names=list(input_shapes.keys()),
        output_names=['output'],
        dynamic_axes={name: {0: 'batch'} for name in input_shapes.keys()}
    )
    print(f"✅ ONNX exported: {onnx_file}")

    # Load ONNX and convert to TensorFlow
    onnx_model = onnx.load(onnx_file)
    tf_rep = prepare(onnx_model)
    tf_model_dir = str(TFLITE_DIR / (pth_file.stem + "_tf"))
    tf_rep.export_graph(tf_model_dir)
    print(f"✅ TensorFlow model saved: {tf_model_dir}")

    # Convert TensorFlow model to TFLite
    converter = tf.lite.TFLiteConverter.from_saved_model(tf_model_dir)
    tflite_model = converter.convert()
    with open(tflite_file, "wb") as f:
        f.write(tflite_model)
    print(f"✅ TFLite model saved: {tflite_file}")

# -------------------------
# Run conversion for both models
# -------------------------
convert_pth_to_tflite(
    SummarizerModel,
    MODELS_DIR / "summarizer_model.pth",
    TFLITE_DIR / "summarizer_model.tflite",
    {"input_seq": (1, MAX_INPUT_LEN)}
)

convert_pth_to_tflite(
    QAModel,
    MODELS_DIR / "qa_model.pth",
    TFLITE_DIR / "qa_model.tflite",
    {"question_seq": (1, 30), "context_seq": (1, MAX_INPUT_LEN)}
)
