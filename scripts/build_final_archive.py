import os
import shutil
import zipfile
import hashlib
from datetime import datetime, timezone

def create_archive():
    build_dir = 'release_artifacts/build'
    if os.path.exists(build_dir):
        shutil.rmtree(build_dir)
    os.makedirs(build_dir)
    
    # 1. Define inclusion list
    includes = [
        'README.md',
        'config',
        'R',
        'scripts',
        'tests',
        '.github/workflows',
        'docs',
        'data/live/metadata',
        'data/live/processed',
        'data/metadata',
        'models',
    ]

    # Exclusions
    excludes = ['.git', '.Renviron', '__pycache__', 'release_artifacts', '.pytest_cache']

    def should_include(path):
        for ex in excludes:
            if ex in path:
                return False
        if path.endswith('.zip') or path.endswith('.mp4'):
            return False
        return True

    # 2. Copy files
    for item in includes:
        if not os.path.exists(item):
            continue
        if os.path.isfile(item):
            if should_include(item):
                shutil.copy2(item, os.path.join(build_dir, item))
        else:
            dest = os.path.join(build_dir, item)
            os.makedirs(os.path.dirname(dest), exist_ok=True)
            shutil.copytree(item, dest, ignore=shutil.ignore_patterns(*excludes, '*.zip', '*.mp4'))

    # 3. Create Manifest and Hash
    manifest_rows = ["path,size_bytes,sha256,category"]
    for root, _, files in os.walk(build_dir):
        for f in files:
            filepath = os.path.join(root, f)
            rel_path = os.path.relpath(filepath, build_dir)
            size = os.path.getsize(filepath)
            
            with open(filepath, 'rb') as file:
                file_hash = hashlib.sha256(file.read()).hexdigest()
            
            category = rel_path.split(os.sep)[0] if os.sep in rel_path else "root"
            manifest_rows.append(f"{rel_path},{size},{file_hash},{category}")

    with open(os.path.join(build_dir, 'ARCHIVE_MANIFEST.csv'), 'w', encoding='utf-8') as f:
        f.write('\n'.join(manifest_rows) + '\n')

    # 4. Create Archive Info
    main_sha = os.popen('git rev-parse HEAD').read().strip()
    file_count = len(manifest_rows) - 1
    info_content = f"""# Final Faculty Review Archive v0.8.3

- **Main SHA:** {main_sha}
- **Scientific Freeze:** v0.6-svm-freeze
- **Website Release:** v0.8.3-faculty-visual-recovery
- **Stable Multi-Page Snapshot:** stable-multipage-2026-09-30
- **Creation Time:** {datetime.now(timezone.utc).isoformat()}
- **File Count:** {file_count}

## Included Categories
{', '.join(includes)}

## Excluded Categories
{', '.join(excludes)}, raw payloads, credentials, .zip, .mp4
"""
    with open(os.path.join(build_dir, 'ARCHIVE_INFO.md'), 'w', encoding='utf-8') as f:
        f.write(info_content)
        
    # FREEZE_MAP.md
    with open(os.path.join(build_dir, 'FREEZE_MAP.md'), 'w', encoding='utf-8') as f:
        f.write("# Freeze Map\n\nScientific models and data are frozen at v0.6-svm-freeze.\n")

    # 5. Zip it up
    zip_path = 'release_artifacts/review_archive_v0.8.3_final_faculty.zip'
    with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
        for root, _, files in os.walk(build_dir):
            for f in files:
                filepath = os.path.join(root, f)
                arcname = os.path.relpath(filepath, build_dir)
                zipf.write(filepath, arcname)

    # 6. Calculate Zip Hash
    with open(zip_path, 'rb') as file:
        zip_hash = hashlib.sha256(file.read()).hexdigest()
    
    with open(zip_path + '.sha256', 'w', encoding='utf-8') as f:
        f.write(zip_hash + '\n')
        
    print(f"Archive created: {zip_path}")
    print(f"Size: {os.path.getsize(zip_path)} bytes")
    print(f"Hash: {zip_hash}")
    print(f"File Count: {file_count}")

if __name__ == '__main__':
    create_archive()
