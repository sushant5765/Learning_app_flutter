"""
Step 1: Prepare and clean the dataset

"""
import os                               # interacting wth operating system(paths,dir)
import re                                    # regular expression for cleaning text
import pandas as pd                    # handle csv data
from pathlib import Path               # file and folder paths

# Setup paths
BASE_DIR = Path(__file__).parent.parent
DATA_DIR = BASE_DIR / "data"
RAW_DIR = DATA_DIR / "raw"
PROCESSED_DIR = DATA_DIR / "processed"

# Create directories
RAW_DIR.mkdir(parents=True, exist_ok=True)
PROCESSED_DIR.mkdir(parents=True, exist_ok=True)

def clean_text(text):
    """Clean and normalize text"""
    # Remove extra whitespace
    text = re.sub(r'\s+', ' ', text)
    # Remove special characters but keep punctuation
    text = re.sub(r'[^\w\s.,!?;:\-()]', '', text)
    return text.strip()

def split_into_sentences(text):
    """Split text into sentences"""
    sentences = re.split(r'[.!?]+', text)
    return [s.strip() for s in sentences if len(s.strip()) > 10]

def create_summaries(text):
    """Create extractive summaries (first 2-3 sentences)"""
    sentences = split_into_sentences(text)
    if len(sentences) <= 3:
        return ' '.join(sentences)
    # Take first 2-3 sentences as summary
    summary_length = min(3, len(sentences) // 2)
    return ' '.join(sentences[:summary_length])

def generate_qa_pairs(text):
    """Generate simple Q&A pairs from text"""
    sentences = split_into_sentences(text)
    qa_pairs = []
    
    for i, sentence in enumerate(sentences[:5]):  # Limit to first 5 sentences
        # Simple question generation
        words = sentence.split()
        if len(words) > 5:
            # Create "What is X?" type questions
            key_word = words[0] if words[0][0].isupper() else words[2] if len(words) > 2 else words[0]
            question = f"What is {key_word}?"
            qa_pairs.append({
                'question': question,
                'answer': sentence,
                'context': text
            })
    
    return qa_pairs

def main():
    print("📖 Reading processed_data.csv...")
    
    # Read dataset from CSV
    csv_path = BASE_DIR / "processed_data.csv"
    if not csv_path.exists():
        print(f"❌ Error: {csv_path} not found!")
        print("   Please run: python create_csv.py first")
        return
    
    df = pd.read_csv(csv_path)
    paragraphs = df['paragraph'].astype(str).tolist()
    
    print(f"✅ Found {len(paragraphs)} paragraphs")
    
    # Process data
    summarization_data = []
    qa_data = []
    
    print("🔄 Processing paragraphs...")   # strats cleaning texts here
    for idx, para in enumerate(paragraphs):
        cleaned = clean_text(para)
        if len(cleaned) < 50:  # Skip very short paragraphs
            continue
        
        # Summarization data
        summary = create_summaries(cleaned)
        summarization_data.append({
            'id': idx,
            'original_text': cleaned,
            'summary': summary,
            'original_length': len(cleaned.split()),
            'summary_length': len(summary.split()),
            'compression_ratio': len(summary.split()) / len(cleaned.split()) if len(cleaned.split()) > 0 else 0
        })
        
        # Q&A data
        qa_pairs = generate_qa_pairs(cleaned)
        for qa in qa_pairs:
            qa_data.append({
                'id': len(qa_data),
                'document_id': idx,
                **qa                                   # form qa function take values    **QA syntax
            })
        
        if (idx + 1) % 100 == 0:
            print(f"   Processed {idx + 1}/{len(paragraphs)} paragraphs")
    
    # Save to CSV
    print("💾 Saving processed data...")
    summarization_df = pd.DataFrame(summarization_data)
    qa_df = pd.DataFrame(qa_data)
    
    summarization_df.to_csv(PROCESSED_DIR / "summarization_data.csv", index=False)
    qa_df.to_csv(PROCESSED_DIR / "qa_data.csv", index=False)
    
    print(f"✅ Saved {len(summarization_data)} summarization examples")
    print(f"✅ Saved {len(qa_data)} Q&A examples")
    print(f"📊 Summary statistics:")
    print(f"   Average original length: {summarization_df['original_length'].mean():.1f} words")
    print(f"   Average summary length: {summarization_df['summary_length'].mean():.1f} words")
    print(f"   Average compression ratio: {summarization_df['compression_ratio'].mean():.2f}")

if __name__ == "__main__":
    main()

