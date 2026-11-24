#!/bin/bash
# 新视频.sh：第一轮「取材」，给一个新链接存原文，然后把它记进 待写稿.txt，不写笔记。
# 写稿是第二轮：切到满血号以后跑 写稿.sh。
# 会先等 重做笔记2.sh 跑完再开始；写稿.sh 在跑就不开（账号已经切走了）。进程记在 重做日志/*.pid。
# 用法：在知识库根目录运行  nohup caffeinate -i bash 新视频.sh "链接" >/dev/null 2>&1 & disown
cd "$(dirname "$0")" || exit 1
VAULT="$PWD"
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
command -v agy >/dev/null || { echo "找不到 agy"; exit 1; }
URL="$1"; [ -n "${URL}" ] || { echo "要给链接"; exit 1; }
LOGDIR="${VAULT}/重做日志"; mkdir -p "${LOGDIR}"
RESULT="${LOGDIR}/结果.txt"
QUEUE="${VAULT}/待写稿.txt"
LIMIT="${LIMIT:-55m}"; EFFORT="${EFFORT:-medium}"
FETCH_MODEL_ARGS="${FETCH_MODEL_ARGS:---model gemini-4-hydrogen-${EFFORT}}"   # 取材用 Gemini 4 Hydrogen（满血号），档位跟着 EFFORT 走；要回到账号默认模型就设 FETCH_MODEL_ARGS=" "

notify() {   # 跑完在 Mac 右上角弹通知：notify 标题 内容（没有 osascript 就跳过）
  command -v osascript >/dev/null 2>&1 || return 0
  [ "${QUIET:-0}" = 1 ] && return 0   # 夜跑时不一篇一响，只在最后通知
  osascript -e 'on run argv' -e 'display notification (item 2 of argv) with title (item 1 of argv) sound name "Glass"' -e 'end run' "$1" "$2" >/dev/null 2>&1 || true
}
running() {   # 有没有活着的同类进程：running 文件名前缀
  for f in "${LOGDIR}"/"$1"*.pid; do [ -f "$f" ] && kill -0 "$(cat "$f")" 2>/dev/null && return 0; done; return 1
}
if running 写稿; then echo "写稿.sh 在跑，等它跑完、切回取材的号再开"; exit 1; fi
while running 重做笔记2; do sleep 60; done
PIDF="${LOGDIR}/新视频-$$.pid"; echo $$ > "${PIDF}"; trap 'rm -f "${PIDF}"' EXIT

run_agy() { BOARD_ACTOR=agy agy --dangerously-skip-permissions ${FETCH_MODEL_ARGS} --effort "${EFFORT}" --print-timeout "${LIMIT}" --add-dir "${VAULT}" -p "$2" >"$1" 2>&1; }
COMMON="规矩：
- 提交时只 git add 本篇用到的文件（它的原文），不要用 git add -A 或 git add .。不推送。
- 提交后关掉所有子代理和后台任务，再写报告。
- 查子代理进度只看它写出的文件在不在、行数对不对，不读它的过程记录。"

t0="$(date +%s)"   # 按作者时间认「这次新写的提交」，别人中途 rebase 也不会把旧提交算进来
log="${LOGDIR}/$(date +%m%d-%H%M)-新视频-取材.log"
echo "=== $(date +%H:%M) 新视频取材：${URL}"
run_agy "${log}" "按 skills/video-knowledge-distill 的流程第 1 步和 references/取材.md，为这个链接取材：${URL}
用视频标题定篇名（按技能里的命名规则），原文存成 原文/<篇名>.原文.md。视频写逐字稿，画面上的字单独成行。只做取材这一步，不写笔记、不核对、不跑整理.py。完成后提交，信息写「取材：<篇名>」。最后报告篇名、原文行数和视频时长。
${COMMON}"
subj="$(git log -50 --format='%at%x09%s' | awk -F'\t' -v t="${t0}" '$1>=t {print $2}' | grep '^取材：' | head -1)"
[ -n "${subj}" ] || { echo "失败  新视频 ${URL}（取材没提交，见 ${log}）" | tee -a "${RESULT}"; notify "取材失败" "${URL}"; exit 1; }
name="${subj#取材：}"
printf '新\t%s\t%s\n' "${name}" "${URL}" >> "${QUEUE}"
echo "取材完成  新视频 ${name}（已记进 待写稿.txt）" | tee -a "${RESULT}"
notify "取材完成" "${name}"
