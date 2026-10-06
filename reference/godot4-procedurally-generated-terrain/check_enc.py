import os
import chardet

files_to_check = [f for f in os.listdir('.') if f.endswith('.gd')]
for f in files_to_check:
    with open(f, 'rb') as file:
        raw = file.read()
        res = chardet.detect(raw)
        has_bom = raw.startswith(b'\xef\xbb\xbf')
        print(f"{f}: Encoding={res['encoding']}, HasBOM={has_bom}")
