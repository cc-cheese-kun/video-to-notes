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
