"""
Unified Model Inference Service
Provides easy-to-use functions for summarization and Q&A
Can be called from Flutter via platform channels or HTTP
"""
import torch
import torch.nn as nn
import json
import sys
from pathlib import Path

BASE_DIR = Path(__file__).parent.parent
FEATURES_DIR = BASE_DIR / "data" / "features"
MODELS_DIR = BASE_DIR / "results" / "models"

# Model parameters
EMBEDDING_DIM = 128
HIDDEN_DIM = 128
VOCAB_SIZE = 5002
MAX_INPUT_LEN = 200
MAX_OUTPUT_LEN = 50
MAX_QUESTION_LEN = 50
MAX_CONTEXT_LEN = 200
MAX_ANSWER_LEN = 50

# Load models once (singleton pattern)
_summarizer_model = None
_qa_model = None
_vocab = None

def load_models():
    """Load models and vocabulary (lazy loading)"""
    global _summarizer_model, _qa_model, _vocab
    
    if _vocab is None:
        with open(FEATURES_DIR / "vocabulary.json", 'r') as f:
            _vocab = json.load(f)
    
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    
    if _summarizer_model is None:
        from inference_summarizer import SummarizerModel
        _summarizer_model = SummarizerModel(VOCAB_SIZE, EMBEDDING_DIM, HIDDEN_DIM).to(device)
        _summarizer_model.load_state_dict(
            torch.load(MODELS_DIR / "summarizer_model.pth", map_location=device)
        )
        _summarizer_model.eval()
    
    if _qa_model is None:
        from inference_qa import QAModel
        _qa_model = QAModel(VOCAB_SIZE, EMBEDDING_DIM, HIDDEN_DIM).to(device)
        _qa_model.load_state_dict(
            torch.load(MODELS_DIR / "qa_model.pth", map_location=device)
        )
        _qa_model.eval()
    
    return _summarizer_model, _qa_model, _vocab

def summarize_text(text: str) -> str:
    """Summarize text using trained model"""
    try:
        from inference_summarizer import summarize, load_vocabulary
        
        word_to_idx, idx_to_word = load_vocabulary()
        model, _, _ = load_models()
        device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
        
        summary = summarize(text, model, word_to_idx, idx_to_word, device)
        return summary if summary else "Unable to generate summary."
    except Exception as e:
        return f"Error: {str(e)}"

def answer_question(question: str, context: str) -> tuple[str, float]:
    """Answer question based on context using trained model"""
    try:
        from inference_qa import answer_question as qa_answer, load_vocabulary
        
        word_to_idx, idx_to_word = load_vocabulary()
        _, model, _ = load_models()
        device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
        
        answer, confidence = qa_answer(question, context, model, word_to_idx, idx_to_word, device)
        return answer if answer else "Unable to generate answer.", confidence
    except Exception as e:
        return f"Error: {str(e)}", 0.0

# CLI interface
if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage:")
        print("  python model_inference_service.py summarize <text>")
        print("  python model_inference_service.py qa <question> <context>")
        sys.exit(1)
    
    command = sys.argv[1]
    
    if command == "summarize":
        if len(sys.argv) < 3:
            print("Error: Text required for summarization")
            sys.exit(1)
        text = ' '.join(sys.argv[2:])
        result = summarize_text(text)
        print(result)
    
    elif command == "qa":
        if len(sys.argv) < 4:
            print("Error: Question and context required")
            sys.exit(1)
        question = sys.argv[2]
        context = ' '.join(sys.argv[3:])
        answer, confidence = answer_question(question, context)
        print(f"Answer: {answer}")
        print(f"Confidence: {confidence:.2f}")
    
    else:
        print(f"Unknown command: {command}")
        sys.exit(1)

