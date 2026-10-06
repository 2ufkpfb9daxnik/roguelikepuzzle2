import re

with open('main.gd', 'r', encoding='utf-8') as f:
    text = f.read()

# 全角文字（文字化け含む）を含むコメントを削除、または英語に置き換える。
# ASCII以外の文字を含む行末コメントを削除する。
lines = text.split('\n')
new_lines = []
for line in lines:
    if '#' in line:
        parts = line.split('#', 1)
        code_part = parts[0]
        comment_part = parts[1]
        # コメント部分に非ASCII文字が含まれているかチェック
        if any(ord(c) > 127 for c in comment_part):
            line = code_part.rstrip() # 非ASCIIコメントは削除
    new_lines.append(line)

with open('main_clean.gd', 'w', encoding='utf-8') as f:
    f.write('\n'.join(new_lines))

print("Cleaned comments.")
