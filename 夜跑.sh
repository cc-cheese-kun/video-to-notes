#!/bin/bash
# 夜跑.sh：每天 00:00 由定时任务启动，把「待提炼.md」里还没跑过的视频链接一篇一篇跑完（取材 → 写稿），
# 09:35 以后不再开新篇，正好用满两个五小时额度窗口。
# 待提炼.md：你自己或聊天助手往里加链接，一行一条、整段分享文字都行；本脚本只读不改它，免得和别人的推送打架。
# 跑完的链接记在 重做日志/已提炼.txt（本机，不进仓库），失败两次的记在 重做日志/夜跑放弃.txt。
# 手动试跑：在知识库根目录运行  bash 夜跑.sh        （STOP_AT=0935 可以改停止时间，如 STOP_AT=2359）
# 手动提炼：bash 夜跑.sh 链接1 链接2 …   只跑这几条，不拉仓库、不看停止时间；视频提炼.command 就是这么调的
cd "$(dirname "$0")" || exit 1
VAULT="$PWD"
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
LOGDIR="${VAULT}/重做日志"; mkdir -p "${LOGDIR}"
INBOX="${VAULT}/待提炼.md"
DONE="${LOGDIR}/已提炼.txt"; GAVEUP="${LOGDIR}/夜跑放弃.txt"; FAILS="${LOGDIR}/夜跑失败次数.txt"
NIGHTLOG="${LOGDIR}/夜跑-$(date +%m%d).log"
MANUAL=0; [ $# -gt 0 ] && MANUAL=1
if [ "${MANUAL}" = 1 ]; then STOP_AT="${STOP_AT:-2400}"; else STOP_AT="${STOP_AT:-0935}"; fi   # 这个时刻（HHMM）以后不开新篇
QUOTA_WAIT="${QUOTA_WAIT:-1800}"      # 额度用完时，等多少秒再试
touch "${DONE}" "${GAVEUP}" "${FAILS}"
SKIPPED=0
if [ "${MANUAL}" = 1 ]; then
  INBOX="${LOGDIR}/手动-$$.txt"; printf '%s\n' "$@" > "${INBOX}"
  SKIPPED="$(grep -cxF -f "${DONE}" "${INBOX}")"   # 已经提炼过的不重跑
fi
exec >>"${NIGHTLOG}" 2>&1

notify() {
  command -v osascript >/dev/null 2>&1 || return 0
  osascript -e 'on run argv' -e 'display notification (item 2 of argv) with title (item 1 of argv) sound name "Glass"' -e 'end run' "$1" "$2" >/dev/null 2>&1 || true
}
log() { echo "$(date '+%m-%d %H:%M') $*"; }
now() { date +%H%M; }
# 看板：夜跑自己记，署名「夜跑」；连不上看板也不影响跑（20 秒超时，失败就算了）
board_cmd() {
  if command -v board >/dev/null 2>&1; then BOARD_ACTOR="${ACTOR:-夜跑}" perl -e 'alarm 20; exec @ARGV' board "$@"
  else BOARD_ACTOR="${ACTOR:-夜跑}" perl -e 'alarm 20; exec @ARGV' python3 "${VAULT}/工具/看板服务/board.py" "$@"; fi
}
BOARD_ID=""
board_start() {   # 今晚有活才建一条任务并认领
  [ -n "${BOARD_ID}" ] && return 0
  if [ "${MANUAL}" = 1 ]; then title="手动提炼 $(date +%m-%d\ %H:%M)"; desc="视频提炼：手动点视频提炼.command"; else title="夜跑 $(date +%m-%d)"; desc="视频提炼：读 待提炼.md，00:00 跑到 ${STOP_AT}"; fi
  BOARD_ID="$(board_cmd add "${title}" "${desc}" 2>/dev/null | sed -n 's/^#\([0-9][0-9]*\).*/\1/p' | head -1)"
  if [ -n "${BOARD_ID}" ]; then board_cmd claim "${BOARD_ID}" >/dev/null 2>&1 || true; log "看板任务 #${BOARD_ID}"
  else log "看板连不上，今晚不记看板"; BOARD_ID="-"; fi
}
board_log() { [ -n "${BOARD_ID}" ] && [ "${BOARD_ID}" != "-" ] && board_cmd log "${BOARD_ID}" "$1" "${2:-}" >/dev/null 2>&1 || true; }
board_end() { [ -n "${BOARD_ID}" ] && [ "${BOARD_ID}" != "-" ] && board_cmd "$1" "${BOARD_ID}" "$2" >/dev/null 2>&1 || true; }

past_stop() { [ "$(now)" -ge "${STOP_AT}" ] && [ "$(now)" -lt 1200 ]; }   # 只认上午的停止时间，00:00 开跑时不会误判

# 同时只跑一份；视频提炼.command 和手动跑的脚本也认这个 pid
for f in "${LOGDIR}"/*.pid; do
  if [ -f "$f" ] && kill -0 "$(cat "$f")" 2>/dev/null; then log "已有任务在跑（$f），今晚不开"; exit 0; fi
done
PIDF="${LOGDIR}/夜跑.pid"; echo $$ > "${PIDF}"; trap 'rm -f "${PIDF}"' EXIT

if [ "${MANUAL}" = 1 ]; then log "=== 手动提炼开始：$# 条"; else log "=== 夜跑开始"; fi
# 拿别人推上来的新链接；本地没提交的改动先收起来再放回
if [ "${MANUAL}" = 0 ] && ! git pull --rebase --autostash -q; then
  log "git pull 失败，用本地的 待提炼.md 接着跑"; git rebase --abort >/dev/null 2>&1
fi
# 拿不到看板口令的 AI（比如云端的）把要记的事写进 重做日志/看板待补记.txt，一行一条；这里用 Mac 的口令代它记成 board note
PENDING="${LOGDIR}/看板待补记.txt"
if [ -s "${PENDING}" ]; then
  : > "${PENDING}.剩下"
  while IFS= read -r note || [ -n "${note}" ]; do
    [ -n "${note}" ] || continue
    if ACTOR=云端助手 board_cmd note "${note}" >/dev/null 2>&1; then log "补记看板：${note}"; else echo "${note}" >> "${PENDING}.剩下"; fi
  done < "${PENDING}"
  mv "${PENDING}.剩下" "${PENDING}"
fi
[ -f "${INBOX}" ] || { log "没有 待提炼.md，结束"; exit 0; }

PAT='https?://(v\.douyin\.com|www\.douyin\.com/video|b23\.tv|(www\.)?bilibili\.com/video|youtu\.be|(www\.)?youtube\.com/(watch|shorts)|xhslink\.com|(www\.)?xiaohongshu\.com/(explore|discovery))[^[:space:]，。！？」)]*'
pending() {   # 待提炼.md 里的链接，去掉已跑完的和已放弃的
  grep -oE "${PAT}" "${INBOX}" | awk '!seen[$0]++' | grep -vxF -f "${DONE}" | grep -vxF -f "${GAVEUP}"
}
new_subjects() {   # 这一篇开跑以后「新写出来」的提交标题；按作者时间算，别人中途 rebase 改了提交号也不会把旧提交算进来
  git log -50 --format='%at%x09%s' | awk -F'\t' -v t="$1" '$1>=t {print $2}'
}
fail_count() { grep -cxF "$1" "${FAILS}"; }
quota_hit() {   # 最近的 agy 日志里有没有额度用完的字样（字样以 agy 实际报错为准，待核实）
  tail -c 4000 "$(ls -t "${LOGDIR}"/*.log 2>/dev/null | grep -v '夜跑-' | head -1)" 2>/dev/null \
    | grep -qiE 'quota|exhausted|rate.?limit|429|额度|配额'
}

TONIGHT="${LOGDIR}/夜跑今晚失败.txt"; : > "${TONIGHT}"   # 今晚失败过的，今晚不再碰
todo() { pending | grep -vxF -f "${TONIGHT}"; }

ok=0; bad=0
while true; do
  if past_stop; then log "到 ${STOP_AT} 了，不开新篇"; break; fi
  url="$(todo | head -1)"
  [ -n "${url}" ] || { log "今晚能跑的都跑完了"; break; }
  board_start
  log "开始：${url}"
  t0="$(date +%s)"
  QUIET=1 bash 新视频.sh "${url}"
  if new_subjects "${t0}" | grep -q '^取材：'; then
    QUIET=1 bash 写稿.sh
  fi
  if new_subjects "${t0}" | grep -q '^重写：'; then
    echo "${url}" >> "${DONE}"; ok=$((ok+1)); log "完成：${url}"
    note="$(new_subjects "${t0}" | grep '^重写：' | head -1)"; note="${note#重写：}"
    board_log "完成：${note:-${url}}" "02-抖音/${note}.md"
  elif quota_hit; then
    board_log "额度像是用完了，等 $((QUOTA_WAIT/60)) 分钟：${url}"
    log "像是额度用完了，等 $((QUOTA_WAIT/60)) 分钟再试"; sleep "${QUOTA_WAIT}"
  else
    echo "${url}" >> "${FAILS}"; echo "${url}" >> "${TONIGHT}"; bad=$((bad+1))
    if [ "$(fail_count "${url}")" -ge 2 ]; then echo "${url}" >> "${GAVEUP}"; log "失败两次，放弃：${url}"; board_log "失败两次，放弃：${url}"
    elif [ "${MANUAL}" = 1 ]; then log "失败：${url}（要重跑就再点一次）"; board_log "失败：${url}"
    else log "失败一次，明晚再试：${url}"; board_log "失败一次，明晚再试：${url}"; fi
  fi
done
left="$(pending | grep -c .)"
log "=== 结束：完成 ${ok}，失败 ${bad}，清单还剩 ${left}"
if [ "${bad}" -gt 0 ] && [ "${ok}" -eq 0 ]; then board_end stuck "完成 0 篇，失败 ${bad} 篇，清单还剩 ${left} 条，见 重做日志/$(basename "${NIGHTLOG}")"
else board_end done "完成 ${ok} 篇，失败 ${bad} 篇，清单还剩 ${left} 条"; fi
[ "${MANUAL}" = 1 ] && rm -f "${INBOX}"
if [ "${MANUAL}" = 1 ]; then
  msg="完成 ${ok} 篇，失败 ${bad} 篇"; [ "${SKIPPED}" -gt 0 ] && msg="${msg}，${SKIPPED} 条以前提炼过、跳过了"
  notify "视频提炼结束" "${msg}"
else notify "夜跑结束" "完成 ${ok} 篇，失败 ${bad} 篇，清单还剩 ${left} 条"; fi
