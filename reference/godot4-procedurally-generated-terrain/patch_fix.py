import re

with open('main.gd', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. デバッグログとカウンタの削除
content = re.sub(r'\s*set_meta\("under_(path|wall|other)_count",.*?\)', '', content)
content = re.sub(r'\s*if not has_meta\("under_update_count"\):.*?print\(log_str\)\n', '\n', content, flags=re.DOTALL)
content = re.sub(r'\s*img\.fill\(Color\(1, 0, 1, 1\)\) # デバッグ用マゼンタ塗りつぶし', '', content)

# 2. テスト用の強引な position, size, z_index, modulate 上書きの削除
content = re.sub(r'\s*minimap_container_under\.size = Vector2\(400, 400\).*?minimap_container_under\.modulate = Color\(1, 1, 1, 1\)\n', '\n', content, flags=re.DOTALL)

# 3. set_anchors_and_offsets_preset の削除（画面外へ飛ぶ原因）
content = content.replace("minimap_container_under.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 20)\n", "")

with open('main.gd', 'w', encoding='utf-8') as f:
    f.write(content)
