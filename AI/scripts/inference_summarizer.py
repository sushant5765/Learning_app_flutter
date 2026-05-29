"""
Inference script for Summarization Model
Loads trained model and generates summaries
"""
import torch
import torch.nn as nn
import json
import sys
import re
from pathlib import Path
from nltk.tokenize import word_tokenize

BASE_DIR = Path(__file__).parent.parent
FEATURES_DIR = BASE_DIR / "data" / "features"
MODELS_DIR = BASE_DIR / "results" / "models"

# Model parameters (must match training)
EMBEDDING_DIM = 128
HIDDEN_DIM = 128
VOCAB_SIZE = 5002
MAX_INPUT_LEN = 200
MAX_OUTPUT_LEN = 50

class SummarizerModel(nn.Module):
    """LSTM-based Seq2Seq model for summarization"""
    def __init__(self, vocab_size, embedding_dim, hidden_dim):
        super().__init__()
        self.embedding = nn.Embedding(vocab_size, embedding_dim, padding_idx=0)
        self.encoder = nn.LSTM(embedding_dim, hidden_dim, batch_first=True, bidirectional=True)
        self.decoder = nn.LSTM(embedding_dim, hidden_dim, batch_first=True)
        self.output = nn.Linear(hidden_dim, vocab_size)
        self.hidden_dim = hidden_dim
    
    def forward(self, input_seq, decoder_input=None):
        batch_size = input_seq.size(0)
        input_emb = self.embedding(input_seq)
        encoder_out, (hidden, cell) = self.encoder(input_emb)
        # Combine bidirectional outputs by adding (not concatenating)
        h = hidden[-1] + hidden[-2]
        c = cell[-1] + cell[-2]
        decoder_hidden = (h.unsqueeze(0), c.unsqueeze(0))
        
        if decoder_input is not None and self.training:
            decoder_input_emb = self.embedding(decoder_input)
            decoder_out, _ = self.decoder(decoder_input_emb, decoder_hidden)
            output = self.output(decoder_out)
            return output
        
        # Inference mode
        outputs = []
        decoder_input_tensor = torch.zeros(batch_size, 1, dtype=torch.long).to(input_seq.device)
        decoder_input_emb = self.embedding(decoder_input_tensor)
        
        for _ in range(MAX_OUTPUT_LEN):
            decoder_out, decoder_hidden = self.decoder(decoder_input_emb, decoder_hidden)
            output = self.output(decoder_out)
            outputs.append(output)
            # Use predicted token
            predicted = output.argmax(dim=-1)
            decoder_input_emb = self.embedding(predicted)
        
        return torch.cat(outputs, dim=1) if outputs else torch.zeros(batch_size, 1, VOCAB_SIZE).to(input_seq.device)

# Global variables (will be set by load_vocabulary)
word_to_idx = {}
idx_to_word = {}

def load_vocabulary():
    """Load vocabulary and create reverse mapping"""
    global word_to_idx, idx_to_word
    
    with open(FEATURES_DIR / "vocabulary.json", 'r') as f:
        word_to_idx = json.load(f)
    
    # Create reverse mapping
    idx_to_word = {v: k for k, v in word_to_idx.items()}
    
    return word_to_idx, idx_to_word

def text_to_sequence(text, max_len=MAX_INPUT_LEN):
    """Convert text to sequence of indices"""
    words = word_tokenize(text.lower())
    sequence = [word_to_idx.get(word, word_to_idx.get('<UNK>', 1)) for word in words if word.isalnum()]
    
    if len(sequence) > max_len:
        sequence = sequence[:max_len]
    else:
        sequence = sequence + [0] * (max_len - len(sequence))
    
    return sequence


#sequence to text conversion
def sequence_to_text(sequence):
    """Convert sequence of indices to text"""
    words = []
    for idx in sequence:
        if idx == 0:  # PAD token
            continue
        word = idx_to_word.get(idx, '')
        if word and word not in ['<PAD>', '<UNK>', '<start>', '<end>']:
            words.append(word)
    return ' '.join(words).strip()

def summarize(text, model, device='cpu'):
    """Generate summary for given text"""
    model.eval()
    
    input_seq = torch.tensor([text_to_sequence(text)], dtype=torch.long).to(device)
    
    with torch.no_grad():
        outputs = model(input_seq)
        if len(outputs) == 0:
            return "Unable to generate summary."
        predicted = outputs.argmax(dim=-1)[0].cpu().tolist()
        summary = sequence_to_text(predicted)
    
    return summary if summary else "Unable to generate summary."

def main():
    if len(sys.argv) < 2:
        print("Usage: python inference_summarizer.py <text_to_summarize>")
        sys.exit(1)
    
    text = sys.argv[1]
    
    # Load vocabulary
    load_vocabulary()
    
    # Load model
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    model = SummarizerModel(VOCAB_SIZE, EMBEDDING_DIM, HIDDEN_DIM).to(device)
    model.load_state_dict(torch.load(MODELS_DIR / "summarizer_model.pth", map_location=device))
    model.eval()
    
    # Generate summary
    summary = summarize(text, model, device)
    print(summary)

if __name__ == "__main__":
    # Ensure NLTK data is available
    try:
        import nltk
        nltk.data.find('tokenizers/punkt')
    except LookupError:
        import nltk
        nltk.download('punkt', quiet=True)
    
    main()
