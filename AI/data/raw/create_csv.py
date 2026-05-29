"""
create_csv.py
Converts raw paragraphs from passage.docx into processed_data.csv
with ID, word counts, char counts, sentences, avg word length, complexity, and topic.
"""

from docx import Document
import pandas as pd
import re
from pathlib import Path

# Paths
BASE_DIR = Path(__file__).parent.parent
DATA_DIR = BASE_DIR / "data"
RAW_DIR = DATA_DIR / "raw"
PROCESSED_DIR = DATA_DIR / "processed"

RAW_DIR.mkdir(parents=True, exist_ok=True)
PROCESSED_DIR.mkdir(parents=True, exist_ok=True)

# Load raw paragraphs from passage.docx
doc_path = RAW_DIR / "passage.docx"
doc = Document(doc_path)
paragraphs = [p.text.strip() for p in doc.paragraphs if len(p.text.strip()) > 0]

print(f"✅ Found {len(paragraphs)} paragraphs in {doc_path}")

# Function to compute paragraph features
def compute_features(para, idx):
    words = para.split()
    sentences = re.split(r'[.!?]+', para)
    sentences = [s for s in sentences if len(s.strip()) > 0]

    avg_word_len = sum(len(w) for w in words) / len(words) if words else 0
    complexity_score = len(words) / len(sentences) if sentences else 0

    # For demo purposes, assign a default category
    topic_category = "Mathematics"  # or Physics, Chemistry, etc.

    return {
        "id": idx + 1,
        "paragraph": para,
        "word_count": len(words),
        "char_count": len(para),
        "sentence_count": len(sentences),
        "avg_word_length": round(avg_word_len, 2),
        "complexity_score": round(complexity_score, 2),
        "topic_category": topic_category
    }

# Create dataset
data = [compute_features(p, i) for i, p in enumerate(paragraphs)]

# Save to CSV
csv_path = PROCESSED_DIR / "processed_data.csv"
df = pd.DataFrame(data)
df.to_csv(csv_path, index=False)

print(f"💾 Saved processed_data.csv with {len(data)} paragraphs to {csv_path}")
