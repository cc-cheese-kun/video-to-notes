#!/usr/bin/env python3
"""视频笔记检查脚本：只检查、不修改。

用法：python3 check_notes.py 02-抖音
输出每篇笔记的问题；「✗」是违反规则，「?」是需要人工看一眼的可疑情况。
退出码：有 ✗ 时为 1，方便放在推送前自动跑。
"""
import glob
import os
import re
import sys

BANNED = (
    "嚼碎 讲透 硬核 颠覆性 降维 高维 底层逻辑 终极 彻底 惊天 残酷真相 认知升级 "
    "一针见血 直击本质 这意味着 总而言之 综上所述 值得注意的是 深入探讨 赋能 "
    "核心在于 让我们 一起来看看 本文 不难发现"
).split()
REQUIRED = ["类型", "平台", "标题", "作者", "链接", "依据", "建立", "标签", "原简介"]
# 这些网站不可能是「视频本身的完整版」
NOT_ORIGINAL = ["arxiv.org", "wikipedia.org", "baike.", "etymonline.com", "ctext.org",
                "zhihu.com", "doi.org", "scholar.google"]
RATIO_WARN = 3  # 文案笔记「视频讲了什么」字数超过原简介几倍时提醒


def section(body, title):
    m = re.search(rf"^## {re.escape(title)}\n(.*?)(?=^## |\Z)", body, re.S | re.M)
    return m.group(1) if m else None


def plain_len(text):
    """去掉标题、列表符号、空白后的字数。"""
    text = re.sub(r"^#+ .*$", "", text, flags=re.M)
    text = re.sub(r"[\s\-*>#`]", "", text)
    return len(text)


def check(path):
    text = open(path, encoding="utf-8").read()
    m = re.match(r"---\n(.*?)\n---\n(.*)", text, re.S)
    if not m:
        return ["✗ 没有 frontmatter"]
    fm, body = m.groups()
    bad, warn = [], []

    def field(name):
        r = re.search(rf"^{name}:[ \t]*(.*)$", fm, re.M)
        return r.group(1).strip() if r else None

    missing = [k for k in REQUIRED if field(k) is None]
    if missing:
        bad.append("缺字段：" + "、".join(missing))
    for k in ("作者", "链接"):
        if field(k) == "":
            bad.append(f"{k}留空（拿不到要写「待补」）")

    basis = field("依据") or ""
    if basis not in ("视频", "原版", "文案"):
        bad.append(f"依据取值不对：{basis or '空'}")

    intro_m = re.search(r"^原简介:\s*\|\n(.*?)(?=^\S|\Z)", fm, re.S | re.M)
    intro = intro_m.group(1).strip() if intro_m else (field("原简介") or "")
    intro_pending = intro in ("", "待补")

    told = section(body, "视频讲了什么")
    if told is None:
        told = section(body, "文章讲了什么")
    if told is None:
        bad.append("没有「视频讲了什么」或「文章讲了什么」")
    if section(body, "值得想的") is None:
        bad.append("没有「值得想的」")

    # 文案笔记：正文不能明显超出原简介
    if basis == "文案" and told is not None:
        if intro_pending:
            if "待补" not in told:
                bad.append("原简介是待补，正文却写了内容")
        else:
            ratio = plain_len(told) / max(plain_len(intro), 1)
            if ratio > RATIO_WARN:
                warn.append(f"正文是原简介的 {ratio:.1f} 倍，检查是否补了文案没有的内容")
        if section(body, "关键原话") is not None:
            bad.append("依据是文案，却有「关键原话」")

    # 原版：链接要像是视频本身
    if basis == "原版":
        link = field("原版链接") or ""
        if not link.startswith("http"):
            bad.append("依据是原版，却没有原版链接")
        elif any(d in link for d in NOT_ORIGINAL):
            bad.append(f"原版链接像参考资料，不像视频原版：{link}")
        elif re.search(r"youtube\.com/(@|channel/|c/)", link):
            bad.append(f"原版链接是频道主页，不是具体视频：{link}")
        quotes = section(body, "关键原话")
        if quotes and not re.search(r"（\d{1,2}:\d{2}(:\d{2})?）", quotes):
            warn.append("依据是原版，关键原话却没有时间戳，确认是否真的读了原版")

    # 时间戳只在真看过视频或原版时出现
    if basis == "文案" and re.search(r"（\d{1,2}:\d{2}(:\d{2})?）", body):
        bad.append("依据是文案，却出现了时间戳")

    # 背景补充的来源格式
    bg = section(body, "背景补充") or ""
    for line in bg.splitlines():
        if line.startswith("- ") and not re.search(
                r"来源：\[[^\]]+\]\(https?://[^)]+\)，\d{4}-\d{2}-\d{2}", line):
            bad.append("来源格式不对：" + line[2:28] + "…")

    used = [w for w in BANNED if w in re.sub(r"\[\[[^\]]*\]\]", "", body)]  # 链接里是别人的标题，不算
    if used:
        bad.append("禁用词：" + "、".join(used))
    bold = len(re.findall(r"\*\*[^*]+\*\*", body))
    if bold > 3:
        bad.append(f"粗体 {bold} 处（上限 3）")
    if re.search(r"[\U0001F300-\U0001FAFF]", body):
        bad.append("有 emoji")
    if re.search(r"^(无|暂无)\s*$", body, re.M):
        bad.append("空节写了「无」，应整节删掉")

    return [f"✗ {x}" for x in bad] + [f"? {x}" for x in warn]


def main():
    target = sys.argv[1] if len(sys.argv) > 1 else "02-抖音"
    if os.path.isfile(target):
        files = [target]
    else:
        files = sorted(glob.glob(os.path.join(target, "*.md")))
    failed = 0
    for f in files:
        issues = check(f)
        name = os.path.basename(f)[:-3]
        if issues:
            print(name)
            for i in issues:
                print("    " + i)
            if any(i.startswith("✗") for i in issues):
                failed += 1
        else:
            print(f"{name}  ✓")
    print(f"\n共 {len(files)} 篇，{failed} 篇有违规。")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
