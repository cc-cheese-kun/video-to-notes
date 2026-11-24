#!/usr/bin/env python3
"""
all-platform-video-extract helper script
Wraps yt-dlp to extract video metadata and download URLs.
Automatically tries browser cookies (Safari / Chrome) for high-risk platforms like Douyin.
"""
import sys
import json
import shutil
import subprocess
import os

YTDLP_BIN = shutil.which("yt-dlp") or os.path.expanduser("~/Library/Python/3.9/bin/yt-dlp")

def run_ytdlp(url, browser=None):
    cmd = [YTDLP_BIN, "--dump-json", "--no-warnings"]
    if browser:
        cmd.extend(["--cookies-from-browser", browser])
    cmd.append(url)
    
    proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    return proc.returncode, proc.stdout, proc.stderr

def extract(url, preferred_browser=None):
    # Determine candidate browsers
    # Default priority on macOS: Safari -> Chrome
    candidate_browsers = [preferred_browser] if preferred_browser else ["safari", "chrome", None]
    
    last_error = None
    for browser in candidate_browsers:
        code, stdout, stderr = run_ytdlp(url, browser)
        if code == 0 and stdout.strip():
            try:
                info = json.loads(stdout)
                return {
                    "success": True,
                    "browser_used": browser or "none",
                    "title": info.get("title"),
                    "uploader": info.get("uploader"),
                    "duration": info.get("duration"),
                    "thumbnail": info.get("thumbnail"),
                    "url": info.get("url") or (info.get("formats")[-1].get("url") if info.get("formats") else None),
                    "webpage_url": info.get("webpage_url")
                }
            except json.JSONDecodeError:
                pass
        last_error = stderr.strip() or stdout.strip()

    # If yt-dlp fails and URL is Douyin, fallback to Playwright headless scraper
    if 'douyin.com' in url or 'iesdouyin.com' in url:
        script_path = os.path.join(os.path.dirname(__file__), "extract_douyin.mjs")
        if os.path.exists(script_path):
            try:
                proc = subprocess.run(["node", script_path, url], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=35)
                if proc.returncode == 0 and proc.stdout.strip():
                    info = json.loads(proc.stdout)
                    if info.get("success"):
                        return {
                            "success": True,
                            "browser_used": "playwright-safari-cookies",
                            "title": info.get("title"),
                            "uploader": info.get("author"),
                            "url": info.get("video_url"),
                            "description": info.get("desc")
                        }
            except Exception as e:
                pass

    return {"success": False, "error": last_error}

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: extract.py <VIDEO_URL> [browser_name]")
        sys.exit(1)
    
    url = sys.argv[1]
    browser = sys.argv[2] if len(sys.argv) > 2 else None
    result = extract(url, browser)
    print(json.dumps(result, ensure_ascii=False, indent=2))
