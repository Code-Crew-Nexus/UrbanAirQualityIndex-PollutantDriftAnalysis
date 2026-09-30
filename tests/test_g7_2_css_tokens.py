import re
import os
import sys

def run_test():
    docs_dir = os.path.join(os.path.dirname(__file__), '..', 'docs')
    css_path = os.path.join(docs_dir, 'assets', 'css', 'styles.css')
    html_path = os.path.join(docs_dir, 'index.html')
    
    with open(css_path, 'r', encoding='utf-8') as f:
        css_content = f.read()
        
    with open(html_path, 'r', encoding='utf-8') as f:
        html_content = f.read()
        
    # Extract defined tokens in :root
    # Find block of :root { ... }
    root_match = re.search(r':root\s*\{([^}]*)\}', css_content)
    defined_tokens = set()
    if root_match:
        defined_tokens = set(re.findall(r'(--[\w-]+)\s*:', root_match.group(1)))
        
    print(f"Defined tokens: {len(defined_tokens)}")
    
    # Extract all var(--token) usages
    usages = re.findall(r'var\((--[\w-]+)\)', css_content + html_content)
    used_tokens = set(usages)
    
    undefined = used_tokens - defined_tokens
    
    # Exceptions that might be dynamically set or scoped
    exceptions = {'--header-height', '--card-accent'}
    undefined = undefined - exceptions
    
    if undefined:
        print("ERROR: Undefined CSS custom properties found:")
        for token in sorted(undefined):
            print(f"  {token}")
        sys.exit(1)
    else:
        print("PASS: All CSS custom properties are defined.")
        sys.exit(0)

if __name__ == '__main__':
    run_test()
