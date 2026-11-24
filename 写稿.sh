#!/bin/bash
# 写稿.sh：第二轮「写稿」。先切到满血号，再照 待写稿.txt 逐篇写稿、核对、整理、提交。
# 写成一篇就从 待写稿.txt 里删掉那一行；失败的留着，下次接着跑。
# 用法：在知识库根目录运行  nohup caffeinate -i bash 写稿.sh >/dev/null 2>&1 & disown
# 待写稿.txt 每行：类型<TAB>篇名<TAB>链接或笔记路径。类型「新」= 新链接写新笔记，「重写」= 重写已有笔记。
cd "$(dirname "$0")" || exit 1
VAULT="$PWD"
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
command -v agy >/dev/null || { echo "找不到 agy"; exit 1; }
LOGDIR="${VAULT}/重做日志"; mkdir -p "${LOGDIR}"
RESULT="${LOGDIR}/结果.txt"
QUEUE="${VAULT}/待写稿.txt"
LIMIT="${LIMIT:-55m}"; EFFORT="${EFFORT:-medium}"
WRITE_MODEL_ARGS="${WRITE_MODEL_ARGS:---model gemini-4-neon-${EFFORT}}"   # 写稿用 Gemini 4 Neon（满血号），档位跟着 EFFORT 走：low/medium/high/xhigh；要换模型就在外面设 WRITE_MODEL_ARGS

[ -s "${QUEUE}" ] || { echo "待写稿.txt 是空的，没东西要写"; exit 0; }
notify() {   # 跑完在 Mac 右上角弹通知：notify 标题 内容（没有 osascript 就跳过）
  command -v osascript >/dev/null 2>&1 || return 0
  [ "${QUIET:-0}" = 1 ] && return 0   # 夜跑时不一篇一响，只在最后通知
  osascript -e 'on run argv' -e 'display notification (item 2 of argv) with title (item 1 of argv) sound name "Glass"' -e 'end run' "$1" "$2" >/dev/null 2>&1 || true
}
running() {   # 有没有活着的同类进程：running 文件名前缀
  for f in "${LOGDIR}"/"$1"*.pid; do [ -f "$f" ] && kill -0 "$(cat "$f")" 2>/dev/null && return 0; done; return 1
}
if running 新视频 || running 重做笔记2; then echo "取材还在跑，等它跑完、切号以后再开"; exit 1; fi
if running 写稿; then echo "写稿.sh 已经在跑"; exit 1; fi
PIDF="${LOGDIR}/写稿.pid"; echo $$ > "${PIDF}"; trap 'rm -f "${PIDF}"' EXIT

has_commit() { git log --format=%s | grep -Fxq "$1"; }
done_line() {   # 从清单删掉这一行
  grep -vxF "$1" "${QUEUE}" > "${QUEUE}.tmp"; mv "${QUEUE}.tmp" "${QUEUE}"
}
run_agy() { BOARD_ACTOR=agy agy --dangerously-skip-permissions ${WRITE_MODEL_ARGS} --effort "${EFFORT}" --print-timeout "${LIMIT}" --add-dir "${VAULT}" -p "$2" >"$1" 2>&1 < /dev/null; }
COMMON="规矩：
- 提交时只 git add 本篇用到的文件（笔记、它的原文、00-索引、改过的 04-主题 地图），不要用 git add -A 或 git add .。不推送。
- 提交后关掉所有子代理和后台任务，再写报告。
- 查子代理进度只看它写出的文件在不在、行数对不对，不读它的过程记录。"

cp "${QUEUE}" "${QUEUE}.本轮"   # 照本轮开始时的清单跑
ok=0; bad=0
while IFS= read -r line || [ -n "$line" ]; do
  [ -n "$line" ] || continue
  kind="$(printf '%s' "$line" | cut -f1)"
  name="$(printf '%s' "$line" | cut -f2)"
  target="$(printf '%s' "$line" | cut -f3)"
  raw="原文/${name}.原文.md"
  if has_commit "重写：${name}"; then echo "已写过，划掉：${name}"; done_line "$line"; continue; fi
  [ -f "${raw}" ] || { echo "失败  ${name}（找不到 ${raw}）" | tee -a "${RESULT}"; continue; }

  log="${LOGDIR}/$(date +%m%d-%H%M)-${name}-写稿.log"
  echo "=== $(date +%H:%M) 写稿：${name}"
  case "$kind" in
    新) run_agy "${log}" "用 skills/video-knowledge-distill 技能给 ${target} 写笔记。原文已经在 ${raw}，不要重新下载，也不要改原文，从第 2 步写稿开始，按技能放进对应文件夹。
1. 写稿前、改稿前，各重读一次 SKILL.md 的「三条底线」。
2. 核对必须另开子代理。
3. 写完按 AGENTS.md「每次整理完」做，跑 python3 整理.py，问题必须是 0。
4. 提交，信息写「重写：${name}」。
5. 最后用三五行报告：核对查出几处、改了几处、哪一步没跑成。
${COMMON}" ;;
    重写) run_agy "${log}" "用 skills/video-knowledge-distill 技能重写 ${target}。原文已经在 ${raw}，不要重新下载，也不要改原文，从第 2 步写稿开始。
1. 从头写，不在旧稿上改；旧笔记的「延伸问答」整节和导航里的「- 相关：」行原样保留。
2. 写稿前、改稿前，各重读一次 SKILL.md 的「三条底线」。
3. 核对必须另开子代理。
4. 写完按 AGENTS.md「每次整理完」做，跑 python3 整理.py，问题必须是 0。
5. 提交，信息写「重写：${name}」。
6. 最后用三五行报告：核对查出几处、改了几处、哪一步没跑成。
${COMMON}" ;;
    *) echo "看不懂这一行，跳过：${line}" | tee -a "${RESULT}"; continue ;;
  esac
  if has_commit "重写：${name}"; then
    echo "成功  ${name}" | tee -a "${RESULT}"; done_line "$line"; ok=$((ok+1))
  else
    echo "失败  ${name}（写稿没提交，见 ${log}）" | tee -a "${RESULT}"; bad=$((bad+1))
  fi
done < "${QUEUE}.本轮"
mv "${QUEUE}.本轮" "${LOGDIR}/上一轮待写稿.txt"
echo "写稿跑完，结果在 ${RESULT}；没写成的还在 待写稿.txt"
if [ "${bad}" -gt 0 ]; then notify "写稿有失败" "成功 ${ok} 篇，失败 ${bad} 篇，见 重做日志/结果.txt"; else notify "写稿完成" "成功 ${ok} 篇"; fi
