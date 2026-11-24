#!/bin/bash
# One double-click runs the whole video-to-notes pipeline (macOS).
# Copy a video link in the app, double-click this file: the dialog is pre-filled from
# the clipboard. Copy the next link and press 加一条 (add one) to append it; press
# 开始 (start) when done. Video links (Douyin, Bilibili, YouTube, Xiaohongshu) are
# extracted and handed to 夜跑.sh, which fetches then writes each one, logs to the
# board, and notifies once at the end. The window can be closed; keep the lid open.
#
# 视频提炼.command：双击一次就跑完整个视频提炼。
# 用法：先在抖音复制一条链接，点这个文件；框里已经填好。还有下一条就去抖音复制，回来点「加一条」；都加完点「开始」。
#       它从里面挑出视频链接（抖音、B 站、YouTube、小红书），交给 夜跑.sh 一篇篇取材（Hydrogen）→ 写稿（Neon），
#       记看板，全部跑完弹一次通知。窗口可以直接关，任务在后台跑；Mac 别合盖。
cd "$(dirname "$0")" || exit 1
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

notify() {
  osascript -e 'on run argv' -e 'display notification (item 2 of argv) with title (item 1 of argv) sound name "Glass"' -e 'end run' "$1" "$2" >/dev/null 2>&1 || true
}

# Dialog loop: the clipboard holds one link at a time, so 加一条 appends the newly copied text.
# 弹框收集链接。剪贴板一次只装一条，所以框里有「加一条」：
# 去抖音复制下一条，回来点「加一条」，它把新复制的内容接到后面；都加完点「开始」。
PAT='https?://(v\.douyin\.com|www\.douyin\.com/video|b23\.tv|(www\.)?bilibili\.com/video|youtu\.be|(www\.)?youtube\.com/(watch|shorts)|xhslink\.com|(www\.)?xiaohongshu\.com/(explore|discovery))[^[:space:]，。！？」]*'
count_links() { printf '%s\n' "$1" | grep -oE "$PAT" | awk '!seen[$0]++' | grep -c .; }
TEXT="$(pbpaste)"
while true; do
  n="$(count_links "$TEXT")"
  out="$(osascript -e 'on run argv' -e 'set r to display dialog (item 2 of argv) default answer (item 1 of argv) buttons {"取消", "加一条", "开始"} default button "开始" cancel button "取消" with title "视频提炼"' -e 'return (button returned of r) & linefeed & (text returned of r)' -e 'end run' "$TEXT" "已收集 ${n} 条视频链接。
还要加：去抖音「分享 → 复制链接」，回来点「加一条」。
都加完了点「开始」。" 2>/dev/null)" || { echo "取消了"; exit 0; }
  btn="${out%%$'\n'*}"; TEXT="${out#*$'\n'}"
  if [ "$btn" = "加一条" ]; then TEXT="${TEXT}
$(pbpaste)"; else break; fi
done

# Keep only video-site links (not e.g. icon credits in a description); drop duplicates.
# 只认视频站的链接，简介里的 flaticon 之类不算；重复的只留一条
URLS=()
while IFS= read -r u; do [ -n "$u" ] && URLS+=("$u"); done < <(
  printf '%s\n' "$TEXT" | grep -oE "$PAT" | awk '!seen[$0]++'
)

if [ "${#URLS[@]}" -eq 0 ]; then
  echo "没找到视频链接。先在 App 里点「分享 → 复制链接」，再双击我。"
  notify "视频提炼没开始" "没找到视频链接"
  exit 1
fi

# Don't start if a run is already going: two runs would fight over git.
# 已经有一轮在跑就不再开，免得两轮抢 git
for f in 重做日志/*.pid; do
  if [ -f "$f" ] && kill -0 "$(cat "$f")" 2>/dev/null; then
    echo "上一轮还在跑（${f}），等它跑完再双击。"
    notify "视频提炼没开始" "上一轮还在跑，等它跑完再来"
    exit 1
  fi
done

echo "找到 ${#URLS[@]} 个链接："; printf '  %s\n' "${URLS[@]}"
nohup caffeinate -i bash 夜跑.sh "${URLS[@]}" >/dev/null 2>&1 &   # same pipeline as the nightly run. 跟夜跑同一套：一篇篇取材→写稿，记看板，最后通知
disown
notify "视频提炼开始" "共 ${#URLS[@]} 条，一篇篇跑完再通知；进度记在看板上"
echo "已经在后台跑了，这个窗口可以关。"
