---
name: all-platform-video-extract
description: Universal multi-platform video extraction skill for parsing video share links/text from 1000+ sites (Douyin/TikTok, Bilibili, YouTube, Kuaishou, Xiaohongshu, Weibo, X/Twitter, etc.) to extract video titles, covers, audio, and direct download links. Uses your own logged-in browser session (Safari/Chrome cookies, read locally) for sites that return 403 to anonymous requests.
---

# All-Platform Video Extract (全平台视频解析与提取)

This skill enables the agent to extract metadata (title, author, cover, description) and direct download links from over 1,000 online video platforms.

## Core Rules & Default Behaviors
1. **Always Use Browser Cookies for Restricted Platforms**:
   - For platforms requiring fresh session authentication or active cookies (such as **Douyin/抖音**, TikTok, Bilibili, Xiaohongshu), the agent **MUST** automatically include `--cookies-from-browser safari` (or `chrome`) when running `yt-dlp` commands.
   - Example default download command:
     ```bash
     ~/Library/Python/3.9/bin/yt-dlp --cookies-from-browser safari -o "~/Downloads/%(title)s.%(ext)s" "<URL>"
     ```
2. **Use the Auto-Fallback Script**:
   - For link extraction, run `.agents/skills/all-platform-video-extract/scripts/extract.py "<URL>"`. It automatically cascades through Safari and Chrome cookies before falling back to direct requests.
