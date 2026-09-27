import os
import struct
from playwright.sync_api import sync_playwright

# Master SVG definition: Deep jade background, warm pearl 'AQ' letters, champagne accent dot
SVG_CONTENT = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
  <defs>
    <linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#193D30"/>
      <stop offset="100%" stop-color="#14261D"/>
    </linearGradient>
  </defs>
  <rect width="64" height="64" rx="13" fill="url(#bg)"/>
  <rect x="2" y="2" width="60" height="60" rx="11" fill="none" stroke="#285F49" stroke-width="1.8"/>
  <text x="29" y="44" 
        font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif" 
        font-size="34" 
        font-weight="900" 
        fill="#FCFBF8" 
        text-anchor="middle" 
        letter-spacing="-1.5">AQ</text>
  <circle cx="51.5" cy="18.5" r="4" fill="#B38A52"/>
</svg>'''

def make_ico(png_data_list):
    """
    Constructs an ICO binary containing PNG images.
    ICO format:
    ICONDIR:
      idReserved (2 bytes) = 0
      idType (2 bytes) = 1 (icon)
      idCount (2 bytes) = number of images
    ICONDIRENTRY (16 bytes per image):
      bWidth (1 byte): 0 for 256
      bHeight (1 byte): 0 for 256
      bColorCount (1 byte): 0
      bReserved (1 byte): 0
      wPlanes (2 bytes): 1
      wBitCount (2 bytes): 32
      dwBytesInRes (4 bytes): size of PNG data
      dwImageOffset (4 bytes): offset of PNG data from start of file
    Followed by raw PNG data chunks.
    """
    count = len(png_data_list)
    header = struct.pack('<HHH', 0, 1, count)
    
    offset = 6 + 16 * count
    dir_entries = []
    image_data = b''
    
    for width, height, data in png_data_list:
        w_byte = width if width < 256 else 0
        h_byte = height if height < 256 else 0
        size = len(data)
        entry = struct.pack('<BBBBHHII', w_byte, h_byte, 0, 0, 1, 32, size, offset)
        dir_entries.append(entry)
        image_data += data
        offset += size
        
    return header + b''.join(dir_entries) + image_data

def main():
    docs_dir = os.path.abspath('docs')
    svg_path = os.path.join(docs_dir, 'favicon.svg')
    img_svg_path = os.path.join(docs_dir, 'assets', 'images', 'favicon.svg')
    os.makedirs(os.path.dirname(img_svg_path), exist_ok=True)
    
    with open(svg_path, 'w', encoding='utf-8') as f:
        f.write(SVG_CONTENT)
    with open(img_svg_path, 'w', encoding='utf-8') as f:
        f.write(SVG_CONTENT)
    print(f"Saved SVG to {svg_path}")
    
    with sync_playwright() as p:
        browser = p.chromium.launch()
        page = browser.new_page()
        
        # Load SVG into page
        page.set_content(f'''
        <!DOCTYPE html>
        <html>
        <head>
          <style>
            body {{ margin: 0; padding: 0; background: transparent; overflow: hidden; }}
            svg {{ display: block; width: 100vw; height: 100vh; }}
          </style>
        </head>
        <body>
          {SVG_CONTENT}
        </body>
        </html>
        ''')
        
        sizes = [
            (16, 16, os.path.join(docs_dir, 'favicon-16x16.png')),
            (32, 32, os.path.join(docs_dir, 'favicon-32x32.png')),
            (48, 48, os.path.join(docs_dir, 'favicon-48x48.png')),
            (180, 180, os.path.join(docs_dir, 'apple-touch-icon.png'))
        ]
        
        png_data_for_ico = []
        
        for w, h, out_path in sizes:
            page.set_viewport_size({"width": w, "height": h})
            data = page.screenshot(type="png", omit_background=True)
            with open(out_path, 'wb') as f:
                f.write(data)
            print(f"Generated {out_path} ({w}x{h}, {len(data)} bytes)")
            if w <= 48:
                png_data_for_ico.append((w, h, data))
                
        # Generate multi-res favicon.ico
        ico_path = os.path.join(docs_dir, 'favicon.ico')
        ico_bytes = make_ico(png_data_for_ico)
        with open(ico_path, 'wb') as f:
            f.write(ico_bytes)
        print(f"Generated {ico_path} ({len(ico_bytes)} bytes)")
        
        browser.close()

if __name__ == '__main__':
    main()
