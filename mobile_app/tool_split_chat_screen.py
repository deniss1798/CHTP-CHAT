# -*- coding: utf-8 -*-
path = r"c:\Users\User\Desktop\Messanger\mobile_app\lib\features\chats\presentation\screens\chat_detail_screen.dart"
with open(path, "r", encoding="utf-8") as f:
    lines = f.readlines()

start = None
end = None
for i, line in enumerate(lines):
    if start is None and "Future<void> _ensureSocketConnected" in line:
        start = i
    if "Widget _buildBody()" in line:
        end = i
        break

if start is None or end is None:
    raise SystemExit(f"markers not found start={start} end={end}")

logic = lines[start:end]
out = path.replace("chat_detail_screen.dart", "chat_detail_screen_logic.dart")
header = "part of 'chat_detail_screen.dart';\n\nextension _ChatDetailScreenLogic on _ChatDetailScreenState {\n"
footer = "}\n"
with open(out, "w", encoding="utf-8") as f:
    f.write(header)
    f.writelines(logic)
    f.write(footer)

new_main = lines[:start] + lines[end:]
last_imp = 0
for i, line in enumerate(new_main):
    if line.startswith("import "):
        last_imp = i
insert_at = last_imp + 1
while insert_at < len(new_main) and new_main[insert_at].strip() == "":
    insert_at += 1

inject = "library chat_detail_screen;\n\npart 'chat_detail_screen_logic.dart';\n\n"
new_main2 = new_main[:insert_at] + [inject] + new_main[insert_at:]
with open(path, "w", encoding="utf-8") as f:
    f.writelines(new_main2)

print("logic lines", len(logic), "main lines", len(new_main2))
