"""
Step 2: Feature Engineering
Extract features from text for model training
"""
import pandas as pd               # handle dataframes
import numpy as np               # numeric operations
from pathlib import Path           # path file path
import re                         # regular expression for text cleaning
from collections import Counter             # counting words for vocabulary
import nltk                                 # tool for tokenizing
from nltk.corpus import stopwords
from nltk.tokenize import word_tokenize, sent_tokenize

# Download NLTK data (first time only)
try:
    nltk.data.find('tokenizers/punkt_tab')
except LookupError:
    nltk.download('punkt_tab', quiet=True)
try:
    nltk.data.find('tokenizers/punkt')
except LookupError:
    nltk.download('punkt', quiet=True)
try:
    nltk.data.find('corpora/stopwords')
except LookupError:
    nltk.download('stopwords', quiet=True)

BASE_DIR = Path(__file__).parent.parent
DATA_DIR = BASE_DIR / "data"
PROCESSED_DIR = DATA_DIR / "processed"
FEATURES_DIR = DATA_DIR / "features"

FEATURES_DIR.mkdir(parents=True, exist_ok=True)

def extract_text_features(text):
    """Extract basic text features"""
    words = word_tokenize(text.lower())
    sentences = sent_tokenize(text)
    
    # Remove stopwords for analysis
    stop_words = set(stopwords.words('english'))
    content_words = [w for w in words if w.isalnum() and w not in stop_words]
    
    features = {
        'word_count': len(words),
        'sentence_count': len(sentences),
        'avg_sentence_length': len(words) / len(sentences) if len(sentences) > 0 else 0,
        'avg_word_length': np.mean([len(w) for w in words]) if words else 0,
        'unique_word_ratio': len(set(words)) / len(words) if words else 0,
        'content_word_ratio': len(content_words) / len(words) if words else 0,
        'punctuation_count': len(re.findall(r'[.,!?;:]', text)),
        'capital_letter_ratio': sum(1 for c in text if c.isupper()) / len(text) if text else 0,
    }
    
    return features

def build_vocabulary(texts, max_vocab_size=5000):
    """Build vocabulary from texts"""
    word_counts = Counter()
    
    for text in texts:
        words = word_tokenize(text.lower())
        word_counts.update([w for w in words if w.isalnum()])                       #counts how often word occurs
    
    # Get most common words
    vocab = {word: idx + 2 for idx, (word, _) in enumerate(word_counts.most_common(max_vocab_size))}
    vocab['<PAD>'] = 0
    vocab['<UNK>'] = 1
    
    return vocab

def text_to_sequence(text, vocab, max_length=200):
    """Convert text to sequence of word indices"""
    words = word_tokenize(text.lower())
    sequence = [vocab.get(w, vocab['<UNK>']) for w in words if w.isalnum()]
    
    # Pad or truncate
    if len(sequence) > max_length:
        sequence = sequence[:max_length]
    else:
        sequence = sequence + [vocab['<PAD>']] * (max_length - len(sequence))
    
    return sequence

def main():
    print("🔧 Starting Feature Engineering...")
    
    # Load processed data
    print("📖 Loading processed data...")
    summarization_df = pd.read_csv(PROCESSED_DIR / "summarization_data.csv")
    qa_df = pd.read_csv(PROCESSED_DIR / "qa_data.csv")
    
    # Extract features for summarization
    print("🔍 Extracting text features for summarization...")
    summarization_features = []
    for _, row in summarization_df.iterrows():
        orig_features = extract_text_features(row['original_text'])
        summ_features = extract_text_features(row['summary'])
        
        combined = {
            'id': row['id'],
            **{f'orig_{k}': v for k, v in orig_features.items()},
            **{f'summ_{k}': v for k, v in summ_features.items()},
        }
        summarization_features.append(combined)
    
    summarization_features_df = pd.DataFrame(summarization_features)
    
    # Extract features for Q&A
    print("🔍 Extracting text features for Q&A...")
    qa_features = []
    for _, row in qa_df.iterrows():
        question_features = extract_text_features(row['question'])
        answer_features = extract_text_features(row['answer'])
        context_features = extract_text_features(row['context'])
        
        combined = {
            'id': row['id'],
            **{f'question_{k}': v for k, v in question_features.items()},
            **{f'answer_{k}': v for k, v in answer_features.items()},
            **{f'context_{k}': v for k, v in context_features.items()},
        }
        qa_features.append(combined)
    
    qa_features_df = pd.DataFrame(qa_features)
    
    # Build vocabularies
    print("📚 Building vocabularies...")
    all_texts = list(summarization_df['original_text']) + list(summarization_df['summary'])
    vocab = build_vocabulary(all_texts)
    
    # Convert texts to sequences
    print("🔄 Converting texts to sequences...")
    summarization_df['original_sequence'] = summarization_df['original_text'].apply(
        lambda x: text_to_sequence(x, vocab, max_length=200)
    )
    summarization_df['summary_sequence'] = summarization_df['summary'].apply(
        lambda x: text_to_sequence(x, vocab, max_length=50)
    )
    
    qa_df['question_sequence'] = qa_df['question'].apply(
        lambda x: text_to_sequence(x, vocab, max_length=30)
    )
    qa_df['answer_sequence'] = qa_df['answer'].apply(
        lambda x: text_to_sequence(x, vocab, max_length=50)
    )
    qa_df['context_sequence'] = qa_df['context'].apply(
        lambda x: text_to_sequence(x, vocab, max_length=200)
    )
    
    # Save features
    print("💾 Saving features...")
    summarization_features_df.to_csv(FEATURES_DIR / "summarization_features.csv", index=False)
    qa_features_df.to_csv(FEATURES_DIR / "qa_features.csv", index=False)
    
    # Save vocab
    import json
    with open(FEATURES_DIR / "vocabulary.json", 'w') as f:
        json.dump(vocab, f)
    
    # Save sequences
    summarization_df[['id', 'original_sequence', 'summary_sequence']].to_csv(
        FEATURES_DIR / "summarization_sequences.csv", index=False
    )
    qa_df[['id', 'question_sequence', 'answer_sequence', 'context_sequence']].to_csv(
        FEATURES_DIR / "qa_sequences.csv", index=False
    )
    
    print(f"✅ Feature engineering complete!")
    print(f"   Vocabulary size: {len(vocab)}")
    print(f"   Summarization features: {len(summarization_features_df)}")
    print(f"   Q&A features: {len(qa_features_df)}")

if __name__ == "__main__":
    main()

