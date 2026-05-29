"""
Master script to run entire training pipeline
Run this to execute all steps in sequence
"""
import subprocess
import sys
from pathlib import Path

BASE_DIR = Path(__file__).parent.parent
SCRIPTS_DIR = BASE_DIR / "scripts"

scripts = [
    "01_prepare_data.py",
    "02_feature_engineering.py",
    "05_create_excel.py",
    "03_train_summarizer.py",
    "04_train_qa.py",
]

# Note: Run create_csv.py first if processed_data.csv doesn't exist

def main():
    print("🚀 Starting Complete AI Training Pipeline\n")
    
    for i, script in enumerate(scripts, 1):
        print(f"\n{'='*60}")
        print(f"Step {i}/{len(scripts)}: Running {script}")
        print(f"{'='*60}\n")
        
        script_path = SCRIPTS_DIR / script
        result = subprocess.run([sys.executable, str(script_path)], cwd=BASE_DIR)
        
        if result.returncode != 0:
            print(f"\n❌ Error in {script}. Stopping pipeline.")
            sys.exit(1)
        
        print(f"\n✅ {script} completed successfully")
    
    print(f"\n{'='*60}")
    print("🎉 All steps completed! Training pipeline finished.")
    print(f"{'='*60}")
    print("\n📁 Results saved in:")
    print(f"   - Models: {BASE_DIR / 'results' / 'models'}")
    print(f"   - Charts: {BASE_DIR / 'results' / 'charts'}")
    print(f"   - Excel: {BASE_DIR / 'dataset.xlsx'}")

if __name__ == "__main__":
    main()

