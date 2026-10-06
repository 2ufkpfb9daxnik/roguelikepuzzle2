import os

with open('main.gd', 'r', encoding='utf-8') as f:
    text = f.read()

try:
    # PowerShellがSJISで読んだものをUTF8で保存したので、
    # UTF8エンコードされたバイト列を、CP932でエンコードし直す？
    # 違う。text は、元のUTF-8バイト列をcp932でデコードした文字列。
    # それを元に戻すには、cp932でエンコードして元のバイト列を得て、それをutf-8でデコードする。
    original_bytes = text.encode('cp932')
    restored_text = original_bytes.decode('utf-8')
    
    with open('main_restored.gd', 'w', encoding='utf-8') as f:
        f.write(restored_text)
    print("Restore successful!")
except Exception as e:
    print("Restore failed:", e)
