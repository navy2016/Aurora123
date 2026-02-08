import os, json, argparse, fnmatch
def analyze_repo(path, top_n=10, include=None, exclude=None, scan_todo=False):
    stats = {'total_files': 0, 'extension_distribution': {}, 'top_largest_files': [], 'todo_fixme_count': 0 if scan_todo else None}
    file_list = []
    exclude_patterns = (exclude or []) + ['.git/*', '.git']
    for root, dirs, files in os.walk(path):
        dirs[:] = [d for d in dirs if not any(fnmatch.fnmatch(os.path.join(root, d), os.path.join(path, p)) for p in exclude_patterns)]
        for file in files:
            full_path = os.path.join(root, file); rel_path = os.path.relpath(full_path, path)
            if include and not any(fnmatch.fnmatch(rel_path, p) for p in include): continue
            if any(fnmatch.fnmatch(rel_path, p) for p in exclude_patterns): continue
            stats['total_files'] += 1; ext = os.path.splitext(file)[1].lower() or 'no_extension'
            stats['extension_distribution'][ext] = stats['extension_distribution'].get(ext, 0) + 1
            try:
                size = os.path.getsize(full_path); file_list.append({'path': rel_path, 'size_bytes': size})
            except: continue
            if scan_todo:
                try:
                    with open(full_path, 'r', encoding='utf-8', errors='ignore') as f:
                        c = f.read(); stats['todo_fixme_count'] += c.count('TODO') + c.count('FIXME')
                except: pass
    file_list.sort(key=lambda x: x['size_bytes'], reverse=True); stats['top_largest_files'] = file_list[:top_n]
    return stats
if __name__ == '__main__':
    parser = argparse.ArgumentParser(); parser.add_argument('path'); parser.add_argument('--top_n', type=int, default=10)
    parser.add_argument('--include', nargs='+'); parser.add_argument('--exclude', nargs='+'); parser.add_argument('--scan_todo', action='store_true')
    args = parser.parse_args(); print(json.dumps(analyze_repo(args.path, args.top_n, args.include, args.exclude, args.scan_todo), indent=2))
