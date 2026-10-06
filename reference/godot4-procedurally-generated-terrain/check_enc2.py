import os

files_to_check = [f for f in os.listdir('.') if f.endswith('.gd')]
for f_name in files_to_check:
    with open(f_name, 'rb') as file:
        raw = file.read()
        has_bom = raw.startswith(b'\xef\xbb\xbf')
        try:
            raw.decode('utf-8')
            valid_utf8 = True
        except UnicodeDecodeError:
            valid_utf8 = False
        print(f"{f_name}: ValidUTF8={valid_utf8}, HasBOM={has_bom}")
