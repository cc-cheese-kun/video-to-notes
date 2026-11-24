import { chromium } from 'playwright';
import { execSync } from 'child_process';
import path from 'path';
import { fileURLToPath } from 'url';
import fs from 'fs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const targetUrl = process.argv[2];

if (!targetUrl) {
  console.log(JSON.stringify({ success: false, error: 'No URL provided' }));
  process.exit(1);
}

async function run() {
  let cookies = [];
  try {
    const rawCookies = execSync(`python3 "${path.join(__dirname, 'get_cookies.py')}"`, { encoding: 'utf-8' });
    cookies = JSON.parse(rawCookies);
  } catch (e) {
    // continue without cookies if failed
  }

  const browser = await chromium.launch({
    headless: true,
    args: [
      '--disable-blink-features=AutomationControlled',
      '--no-sandbox'
    ]
  });

  const context = await browser.newContext({
    userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36',
    viewport: { width: 1280, height: 800 },
    locale: 'zh-CN',
    timezoneId: 'Asia/Shanghai'
  });

  if (cookies.length > 0) {
    try {
      await context.addCookies(cookies);
    } catch (e) {}
  }

  const page = await context.newPage();
  let videoSrc = null;
  let detailData = null;

  page.on('response', async (response) => {
    try {
      const u = response.url();
      if (u.includes('/aweme/v1/web/aweme/detail/')) {
        detailData = await response.json();
      }
      const ct = response.headers()['content-type'] || '';
      if ((ct.includes('video') || u.includes('.douyinvod.com') || u.includes('/video/tos/')) && !videoSrc) {
        videoSrc = u;
      }
    } catch (e) {}
  });

  try {
    await page.goto(targetUrl, { waitUntil: 'domcontentloaded', timeout: 25000 });
  } catch (e) {}

  await page.waitForTimeout(4000);

  // If still not captured, check DOM video element
  if (!videoSrc) {
    videoSrc = await page.evaluate(() => {
      const video = document.querySelector('video');
      if (video) {
        return video.currentSrc || video.src;
      }
      return null;
    });
  }

  let title = await page.title();
  let desc = '';
  let author = '';

  if (detailData && detailData.aweme_detail) {
    const item = detailData.aweme_detail;
    desc = item.desc || '';
    author = item.author?.nickname || '';
    if (item.video) {
      const v = item.video;
      const playList = (v.play_addr && v.play_addr.url_list) || [];
      const bitRates = (v.bit_rate || []).map(b => b.play_addr?.url_list?.[0]).filter(Boolean);
      videoSrc = playList[0] || bitRates[0] || videoSrc;
    }
  }

  await browser.close();

  console.log(JSON.stringify({
    success: !!videoSrc,
    title: title.replace(' - 抖音', '').trim(),
    author: author,
    desc: desc,
    video_url: videoSrc
  }, null, 2));
}

run().catch((err) => {
  console.log(JSON.stringify({ success: false, error: err.message }));
});
