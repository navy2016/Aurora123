import os
import json
import argparse
import fnmatch
from pathlib import Path

def matches_any(filename, patterns):
    if not patterns: return False
    return any(fnmatch.fnmatch(filename, pattern) for pattern in patterns)

def analyze_repo(path, top_n=5, include_patterns=None, exclude_patterns=None, scan_todo=False):
    if not include_patterns:
        include_patterns = ['*']
    if not exclude_patterns:
        exclude_patterns = []

    metrics = {
        'total_files': 0,
        'total_size_bytes': 0,
        'extension_counts': {},
        'top_files': [],
        'todo_count': 0
    }

    all_files = []

    for root, dirs, files in os.walk(path):
        # Filter directories in-place for os.walk
        dirs[:] = [d for d in dirs if not matches_any(d, exclude_patterns)]
        
        for file in files:
            if matches_any(file, exclude_patterns):
                continue
            if not matches_any(file, include_patterns):
                continue

            file_path = Path(root) / file
            try:
                stat = file_path.stat()
                size = stat.st_size
                
                metrics['total_files'] += 1
                metrics['total_size_bytes'] += size
                
                ext = file_path.suffix.lower() or 'no_extension'
                metrics['extension_counts'][ext] = metrics['extension_counts'].get(ext, 0) + 1
                
                all_files.append({
                    'path': str(file_path.relative_to(path)),
                    'size_bytes': size
                })

                if scan_todo:
                    try:
                        # Simple check for text files/common code files
                        if ext in ['.py', '.js', '.ts', '.c', '.cpp', '.h', '.java', '.go', '.md', '.txt', '.html', '.css']:
                            with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                                content = f.read()
                                metrics['todo_count'] += content.count('TODO') + content.count('FIXME')
                    except Exception:
                        pass
                        
            except (PermissionError, FileNotFoundError):
                continue

    # Sort files by size for top_n
    all_files.sort(key=lambda x: x['size_bytes'], reverse=True)
    metrics['top_files'] = all_files[:top_n]

    return metrics

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Analyze repository metrics')
    parser.add_argument('--path', type=str, required=True, help='Target directory path')
    parser.add_argument('--top_n', type=int, default=5, help='Number of largest files to show')
    parser.add_argument('--include', nargs='*', help='Include patterns (glob)')
    parser.add_argument('--exclude', nargs='*', help='Exclude patterns (glob)')
    parser.add_argument('--scan_todo', action='store_true', help='Scan for TODO/FIXME')

    args = parser.parse_args()
    
    result = analyze_repo(
        args.path, 
        top_n=args.top_n, 
        include_patterns=args.include, 
        exclude_patterns=args.exclude, 
        scan_todo=args.scan_todo
    )
    
    print(json.dumps(result, indent=2))
