import os
import re
import sys

def run_tests():
    index_path = 'docs/index.html'
    css_path = 'docs/assets/css/styles.css'
    
    with open(index_path, 'r', encoding='utf-8') as f:
        html = f.read()
        
    with open(css_path, 'r', encoding='utf-8') as f:
        css = f.read()

    errors = []

    # 1. CSS parses successfully / No malformed blocks
    # Basic check for stray brackets like `} width: 100%; }`
    if re.search(r'\}\s*width:\s*100%;\s*\}', css):
        errors.append("Malformed CSS block found.")

    # 2. No undefined G7 variables
    undefined = ['--jade)', '--graphite)', '--pearl)', '--pearl-dark)', '--heading-color)', '--text-color)']
    for u in undefined:
        if u in html or u in css:
            errors.append(f"Undefined variable {u} found.")

    # 3. Study at a Glance says Panel Memberships
    if 'Panel Memberships' not in html:
        errors.append("'Panel Memberships' not found in HTML.")

    # 4. No forecast complex environmental regimes claim
    if 'forecast complex environmental regimes' in html:
        errors.append("Found incorrect 'forecast complex environmental regimes' claim.")

    # 5. Check mode aware notice
    if 'id="mode-aware-methodological-notice"' not in html:
        errors.append("Mode aware notice span not found.")

    if errors:
        print("FAIL: G7.3 Visual Recovery validation failed.")
        for e in errors:
            print(f" - {e}")
        sys.exit(1)
    
    print("PASS: G7.3 Visual Recovery validation passed.")
    sys.exit(0)

if __name__ == '__main__':
    run_tests()
