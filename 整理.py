#!/usr/bin/env python3
"""知识库整理脚本：更新索引和每篇笔记的导航「主题」行，并检查标签、主题、链接。

用法（在知识库根目录）：
    python3 整理.py           更新索引和导航，再检查
    python3 整理.py --check   只检查，不改文件

规矩写在 AGENTS.md。这个脚本只做机械的部分：
- 00-索引.md 里两个标记之间的内容由脚本生成，手改会被覆盖
- 每篇笔记「## 导航」下的「- 主题：」那一行由脚本按 04-主题/ 生成
- 「- 相关：」那几行由 AI 写，脚本只检查链接存在
"""
import glob
import os
import re
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
NOTE_DIRS = ["01-笔记", "02-抖音", "03-讨论", "05-视频制作"]
PRIVATE_DIR = "01-笔记"
THEME_DIR = "04-主题"
INDEX = "00-索引.md"
BEGIN = "<!-- 以下由 整理.py 生成，不要手改 -->"
END = "<!-- 生成结束 -->"
LINK = re.compile(r"\[\[([^\]]+)\]\]")

errors, warns = [], []


def read(p):
    with open(os.path.join(ROOT, p), encoding="utf-8") as f:
        return f.read()


def write(p, s):
    with open(os.path.join(ROOT, p), "w", encoding="utf-8") as f:
        f.write(s)


def target(link):
    return link.split("|")[0].split("#")[0].strip()


def split_fm(s):
    if s.startswith("---\n"):
        end = s.find("\n---", 4)
        if end != -1:
            return s[4:end], s[end + 4:]
    return "", s


def load_tag_table():
    """AGENTS.md 「## 标签表」一节里，每行「- 组名（说明）：a、b、c」。"""
    s = read("AGENTS.md")
    m = re.search(r"^## 标签表\n(.*?)(?=^## |\Z)", s, re.S | re.M)
    if not m:
        errors.append("AGENTS.md 里没有「## 标签表」")
        return {}
    groups = {}
    for line in m.group(1).splitlines():
        g = re.match(r"^-\s*([^（(：:]+)[^：:]*[：:](.+)$", line)
        if g:
            groups[g.group(1).strip()] = [t.strip() for t in g.group(2).split("、") if t.strip()]
    return groups


def load_themes():
    """返回 {主题名: (一句话说明, [(小类, [笔记名])])} 和 {笔记名: [(主题, 小类)]}。"""
    themes, where = {}, {}
    for p in sorted(glob.glob(os.path.join(ROOT, THEME_DIR, "*.md"))):
        name = os.path.basename(p)[:-3]
        _, body = split_fm(open(p, encoding="utf-8").read())
        d = re.search(r"^>\s*(.+)$", body, re.M)
        subs, cur = [], None
        for line in body.splitlines():
            h = re.match(r"^##\s+(.+)$", line)
            if h:
                cur = None if h.group(1).strip() == "还没想清楚的" else (h.group(1).strip(), [])
                if cur:
                    subs.append(cur)
                continue
            if cur and line.startswith("- "):
                for l in LINK.findall(line)[:1]:
                    n = target(l)
                    if n in cur[1]:
                        warns.append(f"{THEME_DIR}/{name}.md：「{n}」在「{cur[0]}」里列了两次")
                    cur[1].append(n)
                    where.setdefault(n, []).append((name, cur[0]))
        themes[name] = (d.group(1).strip() if d else "", subs)
    return themes, where


def load_notes():
    notes = {}
    for d in NOTE_DIRS:
        for p in sorted(glob.glob(os.path.join(ROOT, d, "**", "*.md"), recursive=True)):
            rel = os.path.relpath(p, ROOT)
            notes[os.path.basename(p)[:-3]] = rel
    return notes


def all_names():
    names = set()
    for p in glob.glob(os.path.join(ROOT, "**", "*.md"), recursive=True):
        if "node_modules" not in p:
            names.add(os.path.basename(p)[:-3])
    return names


def summary(s):
    m = re.search(r"^>\s*一句话[：:]\s*(.+)$", s, re.M)
    return m.group(1).strip() if m else ""


def tags_of(fm):
    m = re.search(r"^标签:\s*\[(.*?)\]", fm, re.M)
    if not m:
        return None
    return [t.strip().strip("'\"") for t in m.group(1).split(",") if t.strip()]


def nav_theme_line(places):
    parts = [f"[[{t}]] › {sub}" for t, sub in places]
    return "- 主题：" + "；".join(parts)


def update_nav(s, line):
    """把「## 导航」下的「- 主题：」行换成 line；没有导航就在末尾加。"""
    m = re.search(r"^## 导航\n(.*?)(?=^## |\Z)", s, re.S | re.M)
    if not m:
        return s.rstrip("\n") + f"\n\n## 导航\n{line}\n", True
    block = m.group(1)
    if re.search(r"^- 主题：.*$", block, re.M):
        new_block = re.sub(r"^- 主题：.*$", line, block, count=1, flags=re.M)
    else:
        new_block = line + "\n" + block
    if new_block == block:
        return s, False
    return s[:m.start(1)] + new_block + s[m.end(1):], True


def main():
    check_only = "--check" in sys.argv
    groups = load_tag_table()
    allowed = {t for ts in groups.values() for t in ts}
    form = set(groups.get("形式", []))
    private_tag = groups.get("私人", ["私人"])[0] if groups.get("私人") else "私人"
    themes, where = load_themes()
    notes = load_notes()
    names = all_names()
    changed = []

    for n in where:
        if n not in notes:
            errors.append(f"主题地图链到了不存在的笔记：{n}")

    for n, rel in notes.items():
        s = read(rel)
        fm, body = split_fm(s)
        private = rel.startswith(PRIVATE_DIR)
        tags = tags_of(fm)
        if tags is None:
            errors.append(f"{rel}：没有「标签: [...]」")
            tags = []
        bad = [t for t in tags if t not in allowed]
        if bad:
            errors.append(f"{rel}：标签不在标签表里：{'、'.join(bad)}")
        if private:
            if tags != [private_tag]:
                warns.append(f"{rel}：私人笔记的标签应该只有「{private_tag}」")
            continue
        if len(tags) > 3:
            warns.append(f"{rel}：标签超过 3 个")
        if len([t for t in tags if t in form]) != 1:
            errors.append(f"{rel}：「形式」组的标签要正好一个（{'、'.join(sorted(form))}）")
        places = where.get(n, [])
        if not places:
            errors.append(f"{rel}：没有挂到任何主题地图上")
            continue
        new_s, did = update_nav(s, nav_theme_line(places))
        nav = re.search(r"^## 导航\n(.*?)(?=^## |\Z)", new_s, re.S | re.M)
        if nav and not re.search(r"^- 相关：", nav.group(1), re.M):
            warns.append(f"{rel}：导航里还没有「- 相关：」")
        if did and not check_only:
            write(rel, new_s)
            changed.append(rel)

    # 死链
    scan = list(notes.values()) + [os.path.relpath(p, ROOT) for p in glob.glob(os.path.join(ROOT, THEME_DIR, "*.md"))]
    for rel in scan + [INDEX]:
        for l in LINK.findall(read(rel)):
            t = target(l)
            if t and t not in names:
                errors.append(f"{rel}：链接指向不存在的笔记「{t}」")

    # 索引
    idx = read(INDEX)
    if BEGIN in idx and END in idx:
        out = ["## 按主题找"]
        for t, (desc, subs) in themes.items():
            cnt = len({x for _, ns in subs for x in ns})
            out.append(f"- [[{t}]] — {desc}（{cnt}）")
        for d in NOTE_DIRS:
            items = [(n, rel) for n, rel in notes.items() if rel.startswith(d + os.sep) or rel.startswith(d + "/")]
            out.append(f"\n## {d}（{len(items)}）")
            for n, rel in items:
                sm = summary(read(rel))
                if not sm and n in where:
                    sm = ""
                out.append(f"- [[{n}]]" + (f" — {sm}" if sm else ""))
        gen = BEGIN + "\n" + "\n".join(out) + "\n" + END
        new_idx = idx[:idx.index(BEGIN)] + gen + idx[idx.index(END) + len(END):]
        if new_idx != idx and not check_only:
            write(INDEX, new_idx)
            changed.append(INDEX)
        elif new_idx != idx:
            warns.append("00-索引.md 和笔记不同步，去掉 --check 跑一次")
    else:
        errors.append("00-索引.md 里找不到生成标记，没法更新")

    for c in changed:
        print("更新：", c)
    for w in warns:
        print("提醒：", w)
    for e in errors:
        print("问题：", e)
    print(f"\n笔记 {len(notes)} 篇，主题 {len(themes)} 个；问题 {len(errors)} 条，提醒 {len(warns)} 条。")
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
