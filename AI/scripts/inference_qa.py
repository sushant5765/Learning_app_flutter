"""
Inference script for Q&A Model
Loads trained model and answers questions
"""
import torch
import torch.nn as nn
import json
import sys
from pathlib import Path
from nltk.tokenize import word_tokenize

BASE_DIR = Path(__file__).parent.parent
FEATURES_DIR = BASE_DIR / "data" / "features"
MODELS_DIR = BASE_DIR / "results" / "models"

# Model parameters (must match training)
EMBEDDING_DIM = 128
HIDDEN_DIM = 128
VOCAB_SIZE = 5002
MAX_QUESTION_LEN = 50
MAX_CONTEXT_LEN = 200
MAX_ANSWER_LEN = 50

class QAModel(nn.Module):
    """Encoder-Decoder LSTM for Question Answering"""
    def __init__(self, vocab_size, embedding_dim, hidden_dim):
        super().__init__()
        self.embedding = nn.Embedding(vocab_size, embedding_dim, padding_idx=0)
        self.question_encoder = nn.LSTM(embedding_dim, hidden_dim, batch_first=True, bidirectional=True)
        self.context_encoder = nn.LSTM(embedding_dim, hidden_dim, batch_first=True, bidirectional=True)
        self.answer_decoder = nn.LSTM(embedding_dim, hidden_dim * 2, batch_first=True)
        self.similarity = nn.Linear(hidden_dim * 4, 1)
        self.output = nn.Linear(hidden_dim * 2, vocab_size)
    
    def forward(self, question_seq, context_seq, answer_seq=None):
        q_emb = self.embedding(question_seq)
        q_out, (q_h, q_c) = self.question_encoder(q_emb)
        q_hidden = torch.cat([q_h[-2], q_h[-1]], dim=1)
        
        c_emb = self.embedding(context_seq)
        c_out, (c_h, c_c) = self.context_encoder(c_emb)
        c_hidden = torch.cat([c_h[-2], c_h[-1]], dim=1)
        
        combined = torch.cat([q_hidden, c_hidden], dim=1)
        similarity = torch.sigmoid(self.similarity(combined))
        
        if answer_seq is not None and self.training:
            decoder_input = answer_seq[:, :-1]
            a_emb = self.embedding(decoder_input)
            decoder_h = torch.cat([c_h[-1], c_h[-2]], dim=1).unsqueeze(0)
            decoder_c = decoder_h.clone()
            decoder_hidden = (decoder_h, decoder_c)
            decoder_out, _ = self.answer_decoder(a_emb, decoder_hidden)
            answer_logits = self.output(decoder_out)
            return answer_logits, similarity
        else:
            # Inference mode
            outputs = []
            start_token = word_to_idx.get('<start>', word_to_idx.get('<PAD>', 0))
            decoder_input_tensor = torch.tensor([[start_token]] * context_seq.size(0), dtype=torch.long).to(context_seq.device)
            decoder_input_emb = self.embedding(decoder_input_tensor)
            decoder_h = torch.cat([c_h[-1], c_h[-2]], dim=1).unsqueeze(0)
            decoder_c = decoder_h.clone()
            decoder_hidden = (decoder_h, decoder_c)
            
            for _ in range(MAX_ANSWER_LEN):
                decoder_out, decoder_hidden = self.answer_decoder(decoder_input_emb, decoder_hidden)
                output = self.output(decoder_out)
                outputs.append(output)
                predicted_token = output.argmax(dim=-1)
                end_token = word_to_idx.get('<end>', word_to_idx.get('<PAD>', 0))
                if (predicted_token == end_token).all():
                    break
                decoder_input_emb = self.embedding(predicted_token)
            
            return torch.cat(outputs, dim=1) if outputs else torch.zeros(context_seq.size(0), 1, VOCAB_SIZE).to(context_seq.device), similarity

# Global variables
word_to_idx = {}
idx_to_word = {}

def load_vocabulary():
    """Load vocabulary and create reverse mapping"""
    global word_to_idx, idx_to_word
    
    with open(FEATURES_DIR / "vocabulary.json", 'r') as f:
        word_to_idx = json.load(f)
    
    idx_to_word = {v: k for k, v in word_to_idx.items()}
    return word_to_idx, idx_to_word

def text_to_sequence(text, max_len):
    """Convert text to sequence of indices"""
    words = word_tokenize(text.lower())
    sequence = [word_to_idx.get(word, word_to_idx.get('<UNK>', 1)) for word in words if word.isalnum()]
    
    if len(sequence) > max_len:
        sequence = sequence[:max_len]
    else:
        sequence = sequence + [0] * (max_len - len(sequence))
    
    return sequence

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

def answer_question(question, context, model, device='cpu'):
    """Answer question based on context"""
    model.eval()
    
    q_seq = torch.tensor([text_to_sequence(question, MAX_QUESTION_LEN)], dtype=torch.long).to(device)
    c_seq = torch.tensor([text_to_sequence(context, MAX_CONTEXT_LEN)], dtype=torch.long).to(device)
    
    with torch.no_grad():
        outputs, similarity = model(q_seq, c_seq)
        if len(outputs.shape) > 0:
            predicted = outputs.argmax(dim=-1)[0].cpu().tolist()
            answer = sequence_to_text(predicted)
            confidence = similarity[0][0].item() if similarity.numel() > 0 else 0.5
        else:
            answer = ""
            confidence = 0.0
    
    return answer if answer else "Unable to generate answer.", confidence

def main():
    if len(sys.argv) < 3:
        print("Usage: python inference_qa.py <question> <context>")
        sys.exit(1)
    
    question = sys.argv[1]
    context = ' '.join(sys.argv[2:])  # Handle context with spaces
    
    # Load vocabulary
    load_vocabulary()
    
    # Load model
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    model = QAModel(VOCAB_SIZE, EMBEDDING_DIM, HIDDEN_DIM).to(device)
    model.load_state_dict(torch.load(MODELS_DIR / "qa_model.pth", map_location=device))
    model.eval()
    
    # Generate answer
    answer, confidence = answer_question(question, context, model, device)
    print(answer)

if __name__ == "__main__":
    # Ensure NLTK data is available
    try:
        import nltk
        nltk.data.find('tokenizers/punkt')
    except LookupError:
        import nltk
        nltk.download('punkt', quiet=True)
    
    main()
