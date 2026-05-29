"""
Step 3: Train Summarization Model
LSTM-based Sequence-to-Sequence model for text summarization
"""
import torch                                # PyTorch library for tensors and neural networks
import torch.nn as nn                       # Neural network modules
import torch.optim as optim                  # Optimizers for training
import pandas as pd                          # For handling CSV data
import numpy as np                           # For numerical operations
import json                                   # For saving/loading JSON files
import matplotlib.pyplot as plt               # For plotting training curves
from pathlib import Path                     # For handling file paths
from tqdm import tqdm                        # For progress bars
import ast                                   # For converting string representation of lists to Python lists

# Define directories for data, features, results, models, and charts
BASE_DIR = Path(__file__).parent.parent
DATA_DIR = BASE_DIR / "data"
FEATURES_DIR = DATA_DIR / "features"
RESULTS_DIR = BASE_DIR / "results"
MODELS_DIR = RESULTS_DIR / "models"
CHARTS_DIR = RESULTS_DIR / "charts"

# Create directories if they do not exist

MODELS_DIR.mkdir(parents=True, exist_ok=True)
CHARTS_DIR.mkdir(parents=True, exist_ok=True)

# Model Parameters
EMBEDDING_DIM = 128
HIDDEN_DIM = 128
VOCAB_SIZE = 5002  # vocab + PAD + UNK
MAX_INPUT_LEN = 200
MAX_OUTPUT_LEN = 50
BATCH_SIZE = 16
EPOCHS = 20
LEARNING_RATE = 0.001

# creates neural network module
class SummarizerModel(nn.Module):
    """LSTM-based Seq2Seq model for summarization"""

    def __init__(self, vocab_size, embedding_dim, hidden_dim):                                         # constructor function to setup model
        super().__init__()                                                                           # parent class called pytorch requirement
        self.embedding = nn.Embedding(vocab_size, embedding_dim, padding_idx=0)                            #converts words Id into vectors
        self.encoder = nn.LSTM(embedding_dim, hidden_dim, batch_first=True, bidirectional=True)                # encoder reads input
        self.decoder = nn.LSTM(embedding_dim, hidden_dim, batch_first=True)                                  #decoder writes output
        self.output = nn.Linear(hidden_dim, vocab_size)                                                         #converts decoder vector into score word probability
        self.hidden_dim = hidden_dim                                                                                  # Store hidden dimension for later use
    
    def forward(self, input_seq, decoder_input=None):
        batch_size = input_seq.size(0)
        
        # Encode
        input_emb = self.embedding(input_seq)
        encoder_out, (hidden, cell) = self.encoder(input_emb)
        
        # Prepare decoder hidden state (combine bidirectional)
        h = hidden[-1] + hidden[-2]
        c = cell[-1] + cell[-2]
        decoder_hidden = (h.unsqueeze(0), c.unsqueeze(0))
        
        # Decode   #teacher forcing
        if decoder_input is not None and self.training:
            # Teacher forcing mode - decoder_input length determines output length
            decoder_input_emb = self.embedding(decoder_input)
            decoder_out, _ = self.decoder(decoder_input_emb, decoder_hidden)
            output = self.output(decoder_out)
            return output  # Shape: [batch, seq_len, vocab_size]
        
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
        
        return torch.cat(outputs, dim=1)

#load datasets
def load_data():
    """Load and prepare training data"""
    print("📖 Loading data...")
    
    # Load sequences csv file
    df = pd.read_csv(FEATURES_DIR / "summarization_sequences.csv")
    
    # Convert string representations to lists
    df['original_sequence'] = df['original_sequence'].apply(ast.literal_eval)
    df['summary_sequence'] = df['summary_sequence'].apply(ast.literal_eval)
    
    # Convert to tensors
    inputs = torch.tensor(df['original_sequence'].tolist(), dtype=torch.long)
    targets = torch.tensor(df['summary_sequence'].tolist(), dtype=torch.long)
    
    # Train/Val split (80/20)
    split_idx = int(len(inputs) * 0.8)
    train_inputs, val_inputs = inputs[:split_idx], inputs[split_idx:]
    train_targets, val_targets = targets[:split_idx], targets[split_idx:]
    
    return (train_inputs, train_targets), (val_inputs, val_targets)

#training for one epoch
def train_epoch(model, train_loader, criterion, optimizer, device):
    """Train for one epoch"""
    model.train() # enbale training mode
    total_loss = 0
    
    for batch_inputs, batch_targets in tqdm(train_loader, desc="Training"):
        batch_inputs = batch_inputs.to(device)
        batch_targets = batch_targets.to(device)
        
        optimizer.zero_grad()                  #optimizer defined
        
        # Forward pass - use teacher forcing
        # Prepare decoder input (shift targets by one for teacher forcing)
        # decoder_input: [batch, seq_len-1] -> output: [batch, seq_len-1, vocab]
        # decoder_target: [batch, seq_len-1] -> matches output length
        decoder_input = batch_targets[:, :-1]  # Remove last token
        decoder_target = batch_targets[:, 1:]    # Remove first token
        
        outputs = model(batch_inputs, decoder_input)
        
        # Ensure output and target lengths match
        seq_len = decoder_target.size(1)
        if outputs.size(1) != seq_len:
            outputs = outputs[:, :seq_len, :]          # Truncate if needed
        
        # Reshape for loss calculation
        outputs = outputs.contiguous().view(-1, VOCAB_SIZE)
        targets = decoder_target.contiguous().view(-1)
        
        loss = criterion(outputs, targets)                               #criteria is crossentropy loss
        loss.backward()
        torch.nn.utils.clip_grad_norm_(model.parameters(), 1.0)                       #gradient clipping
        optimizer.step()
        
        total_loss += loss.item()
    
    return total_loss / len(train_loader)

# validation function
def validate(model, val_loader, criterion, device):
    """Validate model"""
    model.eval()
    total_loss = 0
    
    with torch.no_grad():
        for batch_inputs, batch_targets in val_loader:
            batch_inputs = batch_inputs.to(device)
            batch_targets = batch_targets.to(device)
            
            decoder_input = batch_targets[:, :-1]
            decoder_target = batch_targets[:, 1:]
            
            outputs = model(batch_inputs, decoder_input)
            
            # Ensure output and target lengths match
            seq_len = decoder_target.size(1)
            if outputs.size(1) != seq_len:
                outputs = outputs[:, :seq_len, :]
            
            outputs = outputs.contiguous().view(-1, VOCAB_SIZE)
            targets = decoder_target.contiguous().view(-1)
            
            loss = criterion(outputs, targets)
            total_loss += loss.item()
    
    return total_loss / len(val_loader)

def main():
    print("🚀 Starting Summarization Model Training...")
    
    # Setup device: GPU if available ,else CPU
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    print(f"📱 Using device: {device}")
    
    # Load data trainig and validation
    (train_inputs, train_targets), (val_inputs, val_targets) = load_data()
    
    # Create data loaders
    train_dataset = torch.utils.data.TensorDataset(train_inputs, train_targets)
    val_dataset = torch.utils.data.TensorDataset(val_inputs, val_targets)
    
    train_loader = torch.utils.data.DataLoader(train_dataset, batch_size=BATCH_SIZE, shuffle=True)
    val_loader = torch.utils.data.DataLoader(val_dataset, batch_size=BATCH_SIZE)
    
    # Initialize model,loss fucntion,optimizer
    model = SummarizerModel(VOCAB_SIZE, EMBEDDING_DIM, HIDDEN_DIM).to(device)
    criterion = nn.CrossEntropyLoss(ignore_index=0)  # Ignore padding
    optimizer = optim.Adam(model.parameters(), lr=LEARNING_RATE)
    
    # Training loop
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
    torch.save(model.state_dict(), MODELS_DIR / "summarizer_model.pth")
    print(f"✅ Model saved to {MODELS_DIR / 'summarizer_model.pth'}")
    
    # Plot training curves
    plt.figure(figsize=(10, 6))
    plt.plot(train_losses, label='Training Loss')
    plt.plot(val_losses, label='Validation Loss')
    plt.xlabel('Epoch')
    plt.ylabel('Loss')
    plt.title('Summarization Model Training Progress')
    plt.legend()
    plt.grid(True)
    plt.savefig(CHARTS_DIR / "summarizer_training.png", dpi=300, bbox_inches='tight')
    print(f"📈 Training chart saved to {CHARTS_DIR / 'summarizer_training.png'}")
    
    print("\n✅ Training complete!")


#entry point
if __name__ == "__main__":
    main() # run the training

