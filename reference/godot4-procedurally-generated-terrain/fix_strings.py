import re

with open('main.gd', 'r', encoding='utf-8') as f:
    text = f.read()

# 異常に長い文字列（文字化け含む）を探して置換する
# "..." の中身を空にする
text = re.sub(r'subtitle\.text\s*=\s*".*?"', 'subtitle.text = "Loading..."', text, flags=re.DOTALL)
text = re.sub(r'loading_label\.text\s*=\s*".*?"', 'loading_label.text = "Generating world..."', text, flags=re.DOTALL)

with open('main.gd', 'w', encoding='utf-8') as f:
    f.write(text)

print("Fixed giant mojibake strings.")
