import os
import re
import subprocess

def remove_comments(text):
    def replacer(match):
        s = match.group(0)
        if s.startswith('/'):
            return "" # replace comment with empty string
        else:
            return s # return string literal
    
    # Regex to capture strings (double/single quotes) or comments
    # Handles escaped quotes within strings
    pattern = re.compile(
        r'//.*?$|/\*.*?\*/|\'(?:\\.|[^\\\'])*\'|"(?:\\.|[^\\"])*"',
        re.DOTALL | re.MULTILINE
    )
    return re.sub(pattern, replacer, text)

def process_file(file_path):
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # 1. Remove comments
        cleaned_content = remove_comments(content)
        
        # 2. Remove blank lines
        lines = [line for line in cleaned_content.split('\n') if line.strip()]
        final_content = '\n'.join(lines)
        
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(final_content)
            
        print(f"Processed: {file_path}")
    except Exception as e:
        print(f"Error processing {file_path}: {e}")

def main():
    target_dir = os.path.join(os.getcwd(), 'lib')
    if not os.path.exists(target_dir):
        print("Directory 'lib' not found.")
        return

    print("Step 1: Removing comments and blank lines...")
    for root, dirs, files in os.walk(target_dir):
        for file in files:
            if file.endswith('.dart'):
                process_file(os.path.join(root, file))

    print("\nStep 2: Running dart format...")
    try:
        subprocess.run(['dart', 'format', '.'], check=True)
        print("Formatting complete.")
    except FileNotFoundError:
        print("Error: 'dart' command not found. Please ensure Dart SDK is in your PATH.")
    except subprocess.CalledProcessError as e:
        print(f"Formatting failed with error: {e}")

if __name__ == '__main__':
    main()
