import re

try:
    with open('main.gd', 'r', encoding='utf-8') as f:
        content = f.read()
        print("Successfully read main.gd with utf-8.")
except Exception as e:
    print("Error reading:", e)
