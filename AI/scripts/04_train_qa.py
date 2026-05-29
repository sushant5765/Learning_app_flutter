"""
Step 4: Train Question Answering Model
Siamese LSTM network for Q&A
"""
import torch
import torch.nn as nn
import torch.optim as optim
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from pathlib import Path
from tqdm import tqdm
import ast

BASE_DIR = Path(__file__).parent.parent
DATA_DIR = BASE_DIR / "data"
FEATURES_DIR = DATA_DIR / "features"
RESULTS_DIR = BASE_DIR / "results"
MODELS_DIR = RESULTS_DIR / "models"
CHARTS_DIR = RESULTS_DIR / "charts"

# Model Parameters
EMBEDDING_DIM = 128
HIDDEN_DIM = 128
VOCAB_SIZE = 5002
BATCH_SIZE = 16
EPOCHS = 15
LEARNING_RATE = 0.001

class QAModel(nn.Module):
    """Siamese LSTM for Question Answering"""
    def __init__(self, vocab_size, embedding_dim, hidden_dim):
        super().__init__()
        self.embedding = nn.Embedding(vocab_size, embedding_dim, padding_idx=0)
        self.question_encoder = nn.LSTM(embedding_dim, hidden_dim, batch_first=True, bidirectional=True)
        self.context_encoder = nn.LSTM(embedding_dim, hidden_dim, batch_first=True, bidirectional=True)
        self.answer_decoder = nn.LSTM(embedding_dim, hidden_dim * 2, batch_first=True)
        self.similarity = nn.Linear(hidden_dim * 4, 1)  # question + context hidden states
        self.output = nn.Linear(hidden_dim * 2, vocab_size)
    
    def forward(self, question_seq, context_seq, answer_seq=None):
        # Encode question
        q_emb = self.embedding(question_seq)
        q_out, (q_h, _) = self.question_encoder(q_emb)
        q_hidden = torch.cat([q_h[-2], q_h[-1]], dim=1)  # Combine bidirectional
        
        # Encode context
        c_emb = self.embedding(context_seq)
        c_out, (c_h, _) = self.context_encoder(c_emb)
        c_hidden = torch.cat([c_h[-2], c_h[-1]], dim=1)
        
        # Similarity score
        combined = torch.cat([q_hidden, c_hidden], dim=1)
        similarity = torch.sigmoid(self.similarity(combined))
        
        # Answer prediction - use decoder approach
        if answer_seq is not None:
            # Teacher forcing: use answer sequence for training/validation
            decoder_input = answer_seq[:, :-1]  # Remove last token
            a_emb = self.embedding(decoder_input)
            
            # Initialize decoder with context hidden state
            # c_h shape: [2, batch, hidden_dim] (bidirectional, 2 layers)
            # We need [1, batch, hidden_dim*2] for decoder
            decoder_h = torch.cat([c_h[-1], c_h[-2]], dim=1)  # [batch, hidden_dim*2]
            decoder_h = decoder_h.unsqueeze(0)  # [1, batch, hidden_dim*2]
            decoder_c = torch.cat([c_h[-1], c_h[-2]], dim=1).unsqueeze(0)  # [1, batch, hidden_dim*2]
            decoder_hidden = (decoder_h, decoder_c)
            
            # Decode - ensure we process all timesteps
            decoder_out, decoder_hidden_out = self.answer_decoder(a_emb, decoder_hidden)
            # decoder_out should be [batch, seq_len-1, hidden_dim*2]
            answer_logits = self.output(decoder_out)  # [batch, seq_len-1, vocab_size]
            return answer_logits, similarity
        else:
            # Inference: use context encoding (simplified)
            # Take mean pooling of context output
            c_pooled = c_out.mean(dim=1)  # [batch, hidden_dim*2]
            # Project to vocab (simplified - should use proper decoder)
            answer_logits = self.output(c_pooled.unsqueeze(1))  # [batch, 1, vocab]
            return answer_logits, similarity

def load_data():
    """Load Q&A data"""
    print("📖 Loading Q&A data...")
    
    df = pd.read_csv(FEATURES_DIR / "qa_sequences.csv")
    
    # Convert sequences
    df['question_sequence'] = df['question_sequence'].apply(ast.literal_eval)
    df['context_sequence'] = df['context_sequence'].apply(ast.literal_eval)
    df['answer_sequence'] = df['answer_sequence'].apply(ast.literal_eval)
    
    questions = torch.tensor(df['question_sequence'].tolist(), dtype=torch.long)
    contexts = torch.tensor(df['context_sequence'].tolist(), dtype=torch.long)
    answers = torch.tensor(df['answer_sequence'].tolist(), dtype=torch.long)
    
    # Train/Val split
    split_idx = int(len(questions) * 0.8)
    train_data = (questions[:split_idx], contexts[:split_idx], answers[:split_idx])
    val_data = (questions[split_idx:], contexts[split_idx:], answers[split_idx:])
    
    return train_data, val_data

def train_epoch(model, train_loader, criterion, optimizer, device):
    """Train for one epoch"""
    model.train()
    total_loss = 0
    
    for q, c, a in tqdm(train_loader, desc="Training"):
        q, c, a = q.to(device), c.to(device), a.to(device)
        
        optimizer.zero_grad()
        
        # Forward pass with teacher forcing
        answer_logits, similarity = model(q, c, a)
        
        # Prepare targets (shift by 1 for teacher forcing)
        answer_targets = a[:, 1:]  # Remove first token
        
        # Ensure lengths match
        seq_len = answer_targets.size(1)
        if answer_logits.size(1) != seq_len:
            answer_logits = answer_logits[:, :seq_len, :]
        
        # Answer prediction loss
        answer_logits = answer_logits.contiguous().view(-1, VOCAB_SIZE)
        answer_targets = answer_targets.contiguous().view(-1)
        
        loss = criterion(answer_logits, answer_targets)
        
        loss.backward()
        torch.nn.utils.clip_grad_norm_(model.parameters(), 1.0)
        optimizer.step()
        
        total_loss += loss.item()
    
    return total_loss / len(train_loader)

def validate(model, val_loader, criterion, device):
    """Validate model"""
    model.eval()
    total_loss = 0
    
    with torch.no_grad():
        for q, c, a in val_loader:
            q, c, a = q.to(device), c.to(device), a.to(device)
            
            # Forward pass with teacher forcing for validation
            answer_logits, similarity = model(q, c, a)
            
            # Prepare targets
            answer_targets = a[:, 1:]
            
            # Ensure lengths match - answer_logits should be [batch, seq_len-1, vocab]
            # answer_targets should be [batch, seq_len-1]
            seq_len = answer_targets.size(1)
            if answer_logits.dim() == 2:
                # If somehow we got [batch, vocab] instead of [batch, seq, vocab]
                answer_logits = answer_logits.unsqueeze(1).expand(-1, seq_len, -1)
            elif answer_logits.size(1) != seq_len:
                answer_logits = answer_logits[:, :seq_len, :]
            
            answer_logits = answer_logits.contiguous().view(-1, VOCAB_SIZE)
            answer_targets = answer_targets.contiguous().view(-1)
            
            loss = criterion(answer_logits, answer_targets)
            
            total_loss += loss.item()
    
    return total_loss / len(val_loader)

def main():
    print("🚀 Starting Q&A Model Training...")
    
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    print(f"📱 Using device: {device}")
    
    # Load data
    (train_q, train_c, train_a), (val_q, val_c, val_a) = load_data()
    
    train_dataset = torch.utils.data.TensorDataset(train_q, train_c, train_a)
    val_dataset = torch.utils.data.TensorDataset(val_q, val_c, val_a)
    
    train_loader = torch.utils.data.DataLoader(train_dataset, batch_size=BATCH_SIZE, shuffle=True)
    val_loader = torch.utils.data.DataLoader(val_dataset, batch_size=BATCH_SIZE)
    
    # Initialize model
    model = QAModel(VOCAB_SIZE, EMBEDDING_DIM, HIDDEN_DIM).to(device)
    criterion = nn.CrossEntropyLoss(ignore_index=0)
    optimizer = optim.Adam(model.parameters(), lr=LEARNING_RATE)
    
    # Training
    train_losses = []
    val_losses = []
    
    print(f"\n📊 Training for {EPOCHS} epochs...")
    for epoch in range(EPOCHS):
        train_loss = train_epoch(model, train_loader, criterion, optimizer, device)
        val_loss = validate(model, val_loader, criterion, device)
        
        train_losses.append(train_loss)
        val_losses.append(val_loss)
        
        print(f"Epoch {epoch+1}/{EPOCHS} - Train Loss: {train_loss:.4f}, Val Loss: {val_loss:.4f}")
    
    # Save model
    torch.save(model.state_dict(), MODELS_DIR / "qa_model.pth")
    print(f"✅ Model saved to {MODELS_DIR / 'qa_model.pth'}")
    
    # Plot
    plt.figure(figsize=(10, 6))
    plt.plot(train_losses, label='Training Loss')
    plt.plot(val_losses, label='Validation Loss')
    plt.xlabel('Epoch')
    plt.ylabel('Loss')
    plt.title('Q&A Model Training Progress')
    plt.legend()
    plt.grid(True)
    plt.savefig(CHARTS_DIR / "qa_training.png", dpi=300, bbox_inches='tight')
    print(f"📈 Training chart saved to {CHARTS_DIR / 'qa_training.png'}")
    
    print("\n✅ Training complete!")

if __name__ == "__main__":
    main()

