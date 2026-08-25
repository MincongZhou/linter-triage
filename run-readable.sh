#!/bin/bash
# 可读版运行器：调用原 zlint/run-all.sh，把全部输出落盘，并把其中压扁的 JSON 美化。
#
# 用法:
#   bash run-readable.sh "/c/.../zlint.exe"
#
# 产出:
#   zlint-readable.log          原始完整输出（含说明文字）
#   zlint-readable.pretty.log   JSON 已格式化、更易读的版本
#
# JSON 美化优先用 jq；若没有 jq，则自动探测 python / py 来美化。

set -u
T="${1:-zlint}"
ROOT="$(cd "$(dirname "$0")" && pwd)"
RAW="$ROOT/zlint-readable.log"
PRETTY="$ROOT/zlint-readable.pretty.log"

# 探测可用的 JSON 美化器：返回 "jq" / "python" / "py" / "" 
find_formatter() {
  if command -v jq >/dev/null 2>&1; then echo "jq"; return; fi
  if command -v python >/dev/null 2>&1; then echo "python"; return; fi
  if command -v py >/dev/null 2>&1; then echo "py"; return; fi
  # 常见安装路径兜底
  for p in \
    "$LOCALAPPDATA/Programs/Python/Python311/python.exe" \
    "$LOCALAPPDATA/Programs/Python/Python310/python.exe" \
    "C:/Python311/python.exe" "C:/Python310/python.exe"; do
    if [ -x "$p" ]; then echo "$p"; return; fi
  done
  echo ""
}

FMT="$(find_formatter)"

echo "运行 zlint 全部复现，输出写入:"
echo "  $RAW"
echo "  $PRETTY"
echo "JSON 美化工具: ${FMT:-无（将保留原样）}"
echo

# 1) 原样跑，tee 到原始日志
bash "$ROOT/zlint/run-all.sh" "$T" | tee "$RAW"

# 2) 后处理：美化以 { 开头且含 "result" 的 JSON 行
: > "$PRETTY"
while IFS= read -r line; do
  if [[ "$line" == \{*result* ]]; then
    case "$FMT" in
      jq)      printf '%s\n' "$line" | jq . 2>/dev/null >> "$PRETTY" && printf '\n' >> "$PRETTY" || printf '%s\n' "$line" >> "$PRETTY" ;;
      python|py)
                printf '%s\n' "$line" | "$FMT" -c "import sys,json;print(json.dumps(json.load(sys.stdin),indent=2,ensure_ascii=False))" 2>/dev/null >> "$PRETTY" && printf '\n' >> "$PRETTY" || printf '%s\n' "$line" >> "$PRETTY" ;;
      *)       printf '%s\n' "$line" >> "$PRETTY" ;;
    esac
  else
    printf '%s\n' "$line" >> "$PRETTY"
  fi
done < "$RAW"

echo
echo "已生成:"
echo "  $RAW    (原始)"
echo "  $PRETTY (美化)"
echo "完成。"
