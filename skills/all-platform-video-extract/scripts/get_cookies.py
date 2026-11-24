"""Print the user's own Douyin cookies from local Safari as JSON (for the Playwright
fallback). yt-dlp is often installed by Homebrew outside the default Python path,
so its site-packages folders are added first. Returns [] on any error.
The output contains login cookies: never save it into notes or a repository.

从本机 Safari 读出自己的抖音 cookie，输出 JSON（给 Playwright 兜底用）。
yt-dlp 常装在 Homebrew 的目录里，先把它的 site-packages 加进路径。出错就返回空列表。
输出含登录 cookie，不要存进笔记或仓库。
"""
import sys, json, os

def get_douyin_cookies():
    try:
        import glob
        patterns = [
            '/opt/homebrew/Cellar/yt-dlp/*/libexec/lib/python*/site-packages',
            '/usr/local/Cellar/yt-dlp/*/libexec/lib/python*/site-packages',
            os.path.expanduser('~/Library/Python/*/lib/python/site-packages'),
        ]
        for p in patterns:
            for path in sorted(glob.glob(p), reverse=True):
                if path not in sys.path:
                    sys.path.insert(0, path)
        from yt_dlp.cookies import extract_cookies_from_browser
        cj = extract_cookies_from_browser('safari')
        cookies = []
        for c in cj:
            if 'douyin.com' in c.domain:
                cookie_dict = {
                    'name': c.name,
                    'value': c.value,
                    'domain': c.domain,
                    'path': c.path or '/',
                }
                if c.expires:
                    cookie_dict['expires'] = float(c.expires)
                if c.secure:
                    cookie_dict['secure'] = True
                cookies.append(cookie_dict)
        return cookies
    except Exception as e:
        return []

if __name__ == '__main__':
    cookies = get_douyin_cookies()
    print(json.dumps(cookies))
