"""Poor-man's static checker for the Shadow Swap GDScript files (there is no Godot binary in the
authoring environment, so this catches the most common mistakes: bad indentation, missing
resource paths, calls to autoload/class members that do not exist, unbalanced brackets).
Run from the project root:  python3 tools/static_check.py"""
import os, re, sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
problems = []
scripts = {}
for base, dirs, files in os.walk(ROOT):
    dirs[:] = [d for d in dirs if d not in (".godot", "docs", "tools", "build")]
    for f in files:
        if f.endswith(".gd"):
            scripts[os.path.join(base, f)] = open(os.path.join(base, f), encoding="utf-8").read()

# --- 1. indentation / brackets / tabs -------------------------------------------------
for path, text in scripts.items():
    rel = os.path.relpath(path, ROOT)
    depth = 0
    for n, line in enumerate(text.split("\n"), 1):
        if line.startswith(" ") and line.strip():
            problems.append(f"{rel}:{n}: line starts with spaces (use tabs)")
        stripped = re.sub(r'"(?:[^"\\]|\\.)*"', '""', line)
        stripped = stripped.split("#")[0]
        depth += sum(stripped.count(c) for c in "([{") - sum(stripped.count(c) for c in ")]}")
    if depth != 0:
        problems.append(f"{rel}: unbalanced brackets (depth {depth})")

# --- 2. res:// paths exist ---------------------------------------------------------------
all_text = list(scripts.items())
for base, dirs, files in os.walk(ROOT):
    dirs[:] = [d for d in dirs if d not in (".godot", "docs", "tools", "build")]
    for f in files:
        if f.endswith((".tscn", "project.godot", "export_presets.cfg")) or f == "project.godot":
            all_text.append((os.path.join(base, f), open(os.path.join(base, f), encoding="utf-8").read()))
for path, text in all_text:
    for m in re.finditer(r'res://[A-Za-z0-9_./%-]+', text):
        p = m.group(0)
        if "%" in p: continue
        if not os.path.exists(os.path.join(ROOT, p[6:])):
            problems.append(f"{os.path.relpath(path, ROOT)}: missing resource {p}")

# --- 3. members of autoloads / class_names ----------------------------------------------
def members(text):
    names = set()
    for m in re.finditer(r'^(?:static\s+)?func\s+(\w+)', text, re.M): names.add(m.group(1))
    for m in re.finditer(r'^(?:@export\s+)?(?:static\s+)?var\s+(\w+)', text, re.M): names.add(m.group(1))
    for m in re.finditer(r'^const\s+(\w+)', text, re.M): names.add(m.group(1))
    for m in re.finditer(r'^signal\s+(\w+)', text, re.M): names.add(m.group(1))
    for m in re.finditer(r'^enum\s+(\w+)', text, re.M): names.add(m.group(1))
    return names

proj = open(os.path.join(ROOT, "project.godot")).read()
registry = {}
for m in re.finditer(r'^(\w+)="\*res://([^"]+)"', proj, re.M):
    registry[m.group(1)] = os.path.join(ROOT, m.group(2))
for path, text in scripts.items():
    m = re.search(r'^class_name\s+(\w+)', text, re.M)
    if m: registry[m.group(1)] = path
member_map = {name: members(scripts[path]) for name, path in registry.items()}
# built-in Node members that are legal on any script instance
for path, text in scripts.items():
    rel = os.path.relpath(path, ROOT)
    for n, line in enumerate(text.split("\n"), 1):
        code = re.sub(r'"(?:[^"\\]|\\.)*"', '""', line).split("#")[0]
        for m in re.finditer(r'\b([A-Z]\w+)\.(\w+)', code):
            owner, member = m.groups()
            if owner in member_map and member not in member_map[owner]:
                problems.append(f"{rel}:{n}: {owner}.{member} is not defined")

# --- 4. typed variable method calls inside level.gd --------------------------------------
var_types = {"hud": "GameHud", "pause_menu": "PauseMenu", "end_screen": "StageEndScreen", "player": "ShadowSwapPlayer"}
builtin_ok = {"position", "add_child", "queue_free", "is_in_group", "add_to_group", "global_position", "velocity", "visible"}
for path, text in scripts.items():
    if not path.endswith("level.gd"): continue
    for n, line in enumerate(text.split("\n"), 1):
        code = re.sub(r'"(?:[^"\\]|\\.)*"', '""', line).split("#")[0]
        for var, cls in var_types.items():
            for m in re.finditer(r'\b%s\.(\w+)' % var, code):
                if m.group(1) not in member_map[cls] and m.group(1) not in builtin_ok and m.group(1) not in ("process_mode",):
                    problems.append(f"level.gd:{n}: {var}.{m.group(1)} not found on {cls}")

# --- 5. input actions used in code exist in project.godot -------------------------------
actions = set(re.findall(r'^(\w+)=\{\n"deadzone"', proj, re.M))
for path, text in scripts.items():
    for m in re.finditer(r'(?:is_action_pressed|get_vector|is_action_just_pressed)\(([^)]*)\)', text):
        for a in re.findall(r'"(\w+)"', m.group(1)):
            if a not in actions:
                problems.append(f"{os.path.relpath(path, ROOT)}: unknown input action {a}")

print(f"checked {len(scripts)} scripts")
for p in problems: print("PROBLEM:", p)
print("OK - no problems found" if not problems else f"{len(problems)} problem(s)")
sys.exit(1 if problems else 0)
