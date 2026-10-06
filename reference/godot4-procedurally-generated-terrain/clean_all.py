import re

with open('main.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = []
for i, line in enumerate(lines):
    if any(ord(c) > 127 for c in line):
        print(f"Line {i+1}: {line.strip()}")
        # 文字化けを含む行を置換する処理
        if 'subtitle.text =' in line:
            line = '    subtitle.text = "Generating world..."\n'
        elif 'loading_label.text =' in line:
            line = '    loading_label.text = "Loading..."\n'
        elif 'print(' in line:
            line = '    print("Log...")\n'
        else:
            # 他にもある場合は空にするか
            line = re.sub(r'".*?"', '""', line) # 文字列リテラルを空に
    new_lines.append(line)

with open('main_clean_all.gd', 'w', encoding='utf-8') as f:
    f.writelines(new_lines)
