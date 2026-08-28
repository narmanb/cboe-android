#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "src"


def read(rel):
    return (ROOT / rel).read_text(encoding="utf-8")


def write(rel, text):
    (ROOT / rel).write_text(text, encoding="utf-8")


def replace_once(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected exactly one anchor, found {count}")
    return text.replace(old, new, 1)


# 1. Port Codeberg's cArea dimension API without importing unrelated files.
area_rel = Path("src/scenario/area.hpp")
area = read(area_rel)
area = replace_once(
    area,
    "class cArea {\npublic:\n\tconst size_t max_dim;",
    "class cArea {\n\tsize_t dimension;\npublic:\n\tsize_t max_dim() const { return dimension; };",
    "cArea member",
)
area = replace_once(area, "\t\t: max_dim(dim)", "\t\t: dimension(dim)", "cArea constructor")
area = replace_once(
    area,
    "\t\treturn loc.x < max_dim && loc.y < max_dim && loc.x >= 0 && loc.y >= 0;\n\t}\n};",
    "\t\treturn loc.x < max_dim() && loc.y < max_dim() && loc.x >= 0 && loc.y >= 0;\n\t}\n\n"
    "\tstd::string loc_str(location where) {\n"
    "\t\tstd::string str = name;\n"
    "\t\tfor(info_rect_t rect : area_desc){\n"
    "\t\t\tif(!rect.empty() && rect.contains(where)){\n"
    "\t\t\t\tstr += \": \\" + rect.descr;\n"
    "\t\t\t\tbreak;\n"
    "\t\t\t}\n"
    "\t\t}\n"
    "\t\treturn str;\n"
    "\t}\n};",
    "cArea is_on_map/loc_str",
)
write(area_rel, area)

# 2. Give cCurOut the same callable max_dim API used by current Codeberg.
univ_h_rel = Path("src/universe/universe.hpp")
univ_h = read(univ_h_rel)
univ_h = replace_once(
    univ_h,
    "\tstatic const int max_dim = 96;\n\tstatic const int half_dim = max_dim / 2;\n\tarray2d<ter_num_t, max_dim, max_dim> out;\n\tarray2d<unsigned char, max_dim, max_dim> out_e;",
    "\tstatic const int outd_size = 96;\n\tstatic const int half_dim = outd_size / 2;\n\tarray2d<ter_num_t, outd_size, outd_size> out;\n\tarray2d<unsigned char, outd_size, outd_size> out_e;\n\tint max_dim() const { return outd_size; }",
    "cCurOut dimension API",
)
write(univ_h_rel, univ_h)

# 3. Convert every explicit cArea/cCurOut member access in the source tree.
# Negative lookahead makes this idempotent and leaves already-migrated Codeberg files alone.
member_re = re.compile(r"(?P<prefix>\.|->)max_dim\b(?!\s*\()")
text_suffixes = {".cpp", ".hpp", ".h", ".tpp", ".cc"}
changed = []
for path in SRC.rglob("*"):
    if not path.is_file() or path.suffix not in text_suffixes:
        continue
    rel = path.relative_to(ROOT)
    if rel == area_rel:
        continue
    text = path.read_text(encoding="utf-8")
    new = member_re.sub(lambda m: m.group("prefix") + "max_dim()", text)
    new = new.replace("cCurOut::max_dim", "cCurOut::outd_size")
    if new != text:
        path.write_text(new, encoding="utf-8")
        changed.append(str(rel))

# 4. A few member functions refer to max_dim without an object prefix.
# These are the exact legacy call sites corresponding to Codeberg's refactor.
for rel in [Path("src/scenario/outdoors.cpp"), Path("src/scenario/town_import.tpp")]:
    text = read(rel)
    new = re.sub(r"\bmax_dim\b(?!\s*\()", "max_dim()", text)
    if new != text:
        write(rel, new)
        changed.append(str(rel))

# cCurOut's own methods previously referred to its static constant unqualified.
univ_cpp_rel = Path("src/universe/universe.cpp")
univ_cpp = read(univ_cpp_rel)
for old, new in [
    ("writeArray(file, out, max_dim, max_dim);", "writeArray(file, out, max_dim(), max_dim());"),
    ("writeArray(file, out_e, max_dim, max_dim);", "writeArray(file, out_e, max_dim(), max_dim());"),
    ("readArray(file, out, max_dim, max_dim);", "readArray(file, out, max_dim(), max_dim());"),
    ("readArray(file, out_e, max_dim, max_dim);", "readArray(file, out_e, max_dim(), max_dim());"),
    ("if(x >= max_dim) return false;", "if(x >= outd_size) return false;"),
    ("if(y >= max_dim) return false;", "if(y >= outd_size) return false;"),
]:
    if old not in univ_cpp:
        raise RuntimeError(f"cCurOut implementation anchor missing: {old}")
    univ_cpp = univ_cpp.replace(old, new, 1)
write(univ_cpp_rel, univ_cpp)

# 5. Verify that no explicit member access was left in old field syntax.
remaining = []
for path in SRC.rglob("*"):
    if not path.is_file() or path.suffix not in text_suffixes:
        continue
    text = path.read_text(encoding="utf-8")
    for line_no, line in enumerate(text.splitlines(), 1):
        if member_re.search(line):
            remaining.append(f"{path.relative_to(ROOT)}:{line_no}: {line.strip()}")

if remaining:
    print("Unconverted max_dim member accesses:", file=sys.stderr)
    print("\n".join(remaining), file=sys.stderr)
    sys.exit(2)

print("Converted max_dim member API across source tree.")
print(f"Files touched by member conversion: {len(set(changed))}")
