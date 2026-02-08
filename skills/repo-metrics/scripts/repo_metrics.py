import os, json, argparse, fnmatch
def analyze_repo(path, top_n=5, include_patterns=None, exclude_patterns=None, scan_todo=False):
    metrics = {'total_files': 0, 'extension_counts': {}, 'top_files': [], 'todo_count': 0, 'errors': []}
    all_files = []
    todo_keywords = ['TODO', 'FIXME']
    for root, dirs, files in os.walk(path):
        if exclude_patterns:
            dirs[:] = [d for d in dirs if not any(fnmatch.fnmatch(d, p) for p in exclude_patterns)]
            files = [f for f in files if not any(fnmatch.fnmatch(f, p) for p in exclude_patterns)]
        if include_patterns:
            files = [f for f in files if any(fnmatch.fnmatch(f, p) for p in include_patterns)]
        for file in files:
            file_path = os.path.join(root, file)
            try:
                stat = os.stat(file_path)
                metrics['total_files'] += 1
                _, ext = os.path.splitext(file)
                ext = ext.lower() or 'no_ext'
                metrics['extension_counts'][ext] = metrics['extension_counts'].get(ext, 0) + 1
                all_files.append({'path': file_path, 'size': stat.st_size})
                if scan_todo:
                    try:
                        with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                            content = f.read()
                            for kw in todo_keywords: metrics['todo_count'] += content.upper().count(kw)
                    except: pass
            except Exception as e: metrics['errors'].append(f'Error processing {file_path}: {str(e)}')
    all_files.sort(key=lambda x: x['size'], reverse=True)
    metrics['top_files'] = all_files[:top_n]
    return metrics
if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--path', default='.')
    parser.add_argument('--top_n', type=int, default=5)
    parser.add_argument('--include', nargs='*')
    parser.add_argument('--exclude', nargs='*', default=['.git', '__pycache__', 'node_modules', 'venv'])
    parser.add_argument('--scan_todo', action='store_true')
    args = parser.parse_args()
    result = analyze_repo(args.path, args.top_n, args.include, args.exclude, args.scan_todo)
    print(json.dumps(result, indent=2, ensure_ascii=False))
