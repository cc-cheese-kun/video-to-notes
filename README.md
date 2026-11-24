# video-to-notes

Drop a video link in the evening, wake up to a sourced, checked study note in your Obsidian vault.

晚上丢一条视频链接，早上起来知识库里就多了一篇分清来源、核对过的学习笔记。

This is a working Obsidian vault skeleton plus the scripts and agent skills that fill it. A CLI agent (built and tested with Gemini through the `agy` CLI) downloads the video, writes a verbatim transcript, writes a note that separates what the video says from outside background and from opinion, has a second agent check it line by line against the transcript, and files it into the right topic map. Douyin, Bilibili, YouTube and Xiaohongshu links work.

这是一个能直接用的 Obsidian 知识库骨架，加上往里填内容的脚本和 AI 技能。一个命令行 AI（用 Gemini 通过 `agy` 命令行搭建和测试）会把视频下载下来写逐字稿，再写一篇笔记：视频原话、查来的背景、自己的看法分开写；然后另开一个 AI 拿逐字稿逐句核对，最后把笔记挂进对应的主题地图。支持抖音、B 站、YouTube、小红书的链接。

## How it runs / 怎么跑

```
视频提炼.command     double-click on macOS: paste links, press Start / macOS 上双击：粘贴链接，点「开始」
夜跑.sh              nightly batch at 00:00 from launchd, reads 待提炼.md, stops opening new jobs at 09:35 / 每晚 00:00 由 launchd 启动，读 待提炼.md，09:35 后不再开新篇
  ├─ 新视频.sh       round 1: fetch + transcript, commit 原文/ / 第一轮：取材、逐字稿，提交到 原文/
  └─ 写稿.sh         round 2: write, cross-check, file, commit / 第二轮：写稿、核对、归档、提交
整理.py              rebuilds 00-索引.md and each note's topic line, checks tags and links / 重建 00-索引.md 和每篇笔记的主题行，检查标签和链接
check_notes.py       format checker for a note (✗ must be fixed) / 笔记格式检查，有 ✗ 就必须改
```

The nightly window (00:00–09:35) is sized to two five-hour quota windows of a subscription plan, so a night's batch never burns the next day's quota. Links that fail twice are set aside instead of retried forever. If the agent hits a quota error, the script waits and tries again.

夜跑的时间窗（00:00 到 09:35）正好用满订阅套餐的两个五小时额度窗口，夜里跑的批次不会吃掉第二天的额度。同一条链接失败两次就搁置，不会无限重试。碰到额度用完的报错，脚本会等一阵再试。

If you run [agent-board](https://github.com/cc-cheese-kun/agent-board), the night run logs itself there: one task per night, one journal line per video. Without the board it still runs, it just skips that part.

如果你部署了 [agent-board](https://github.com/cc-cheese-kun/agent-board)，夜跑会自己在上面记账：每晚一个任务，每个视频一条流水。没有看板也照样跑，只是跳过记账。

## What a note looks like / 笔记长什么样

See `skills/video-knowledge-distill/SKILL.md`. Three hard rules:

模板见 `skills/video-knowledge-distill/SKILL.md`。三条硬规矩：

1. What the source said, background looked up elsewhere (every line dated and linked), and the writer's own view live in separate sections. 原作说的、另外查来的背景（每条都带日期和链接）、写的人自己的看法，各放各的小节。
2. Write only what was actually seen. If only the caption was available, the note says so and stays short. 只写真正看到的东西。只拿到了文案，笔记就照实写明，宁可短。
3. Numbers, names, dates and quotes come only from the source or a cited lookup; anything missing is marked 待补 (to be filled), never invented. 数字、人名、日期、引语只能来自原作或注明出处的查证；缺的写「待补」，绝不编。

The full transcript is kept next to every note in `原文/`, so any claim can be rechecked later.

每篇笔记的完整原文都存在 `原文/` 里，以后任何一句话都能回头再核。

## Setup / 安装

- macOS (the `.command` and notifications use `osascript`; the core scripts are plain bash). macOS（`.command` 文件和通知用的是 `osascript`；核心脚本是普通 bash）。
- `yt-dlp`, `ffmpeg`, Python 3, Node (for the Douyin extractor), and an agent CLI. The scripts call `agy`; swap `run_agy` in `新视频.sh` / `写稿.sh` for Codex, Claude Code or another CLI. 需要 `yt-dlp`、`ffmpeg`、Python 3、Node（抖音提取器要用）和一个 AI 命令行工具。脚本调用的是 `agy`，换成 Codex、Claude Code 或别的，改 `新视频.sh`、`写稿.sh` 里的 `run_agy` 就行。
- Clone this repo as your vault (or copy the scripts, `skills/`, `AGENTS.md` and `整理.py` into an existing one). 把这个仓库直接克隆成你的知识库，或者把脚本、`skills/`、`AGENTS.md`、`整理.py` 拷进你已有的库里。
- For the nightly run, copy `launchd/video-night.plist.example` into `~/Library/LaunchAgents/` and fix the paths. 要每晚自动跑，把 `launchd/video-night.plist.example` 拷到 `~/Library/LaunchAgents/`，改好路径。

## Notes / 说明

- The extractor reads cookies from your own browser, locally, so it can fetch what you could watch yourself. Nothing is sent anywhere else. Use it for personal study and respect each platform's terms. 提取器在本机读你自己浏览器的 cookies，所以只能拿到你本人能看到的视频，不会发到别处。仅供个人学习使用，请遵守各平台的条款。
- Folder names follow the original Chinese vault (`02-抖音` holds notes from every platform). 文件夹名沿用原来那个中文知识库（`02-抖音` 里其实放着所有平台的笔记）。

## License

MIT
