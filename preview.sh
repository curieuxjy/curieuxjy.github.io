#!/usr/bin/env bash
set -euo pipefail

# ===== 설정 =====
PRE_MSG="${1:-pre-commit}"
SIZE_LIMIT="${SIZE_LIMIT:-50M}"   # 환경변수로 조정 가능 (예: SIZE_LIMIT=100M)

# ===== 1) 대용량 파일(> SIZE_LIMIT) 사전 검사 =====
echo "🔎 Checking for files larger than ${SIZE_LIMIT} (excluding .git) ..."
mapfile -t large_files < <(find . -path ./.git -prune -o -type f -size +"${SIZE_LIMIT}" -print)

if [ "${#large_files[@]}" -gt 0 ]; then
  echo "❌ 중단: 아래 파일(들)이 ${SIZE_LIMIT} 초과입니다."
  printf '   %s\n' "${large_files[@]}"
  echo "ℹ️  해결 방법 예시: Git LFS 사용, 파일 제외(.gitignore), 용량 축소 등"
  exit 1
fi
echo "✅ Large file check passed."

# ===== 2) 최신 커밋 기준 변경된 .qmd 목록 추출 =====
echo "🔹 최근 변경된 .qmd 파일 검색 중..."
base_ref="$(git rev-parse HEAD)"
changed="$(git diff --name-only "$base_ref" | grep '\.qmd$' || true)"

if [ -z "$changed" ]; then
  echo "ℹ️  미리보기할 .qmd 변경이 없습니다."
  exit 0
fi

echo "🔹 미리보기 대상:"
echo "$changed"

# ===== 3) 변경된 .qmd 파일에 대해 quarto preview 실행 =====
for f in $changed; do
  [ -z "$f" ] && continue
  echo "🧩 Preview 시작: $f"
  quarto preview "$f" --no-browser &
done

echo "✅ 모든 preview 서버가 실행되었습니다."
echo "🌐 브라우저에서 http://localhost:4200 접속하여 확인하세요."
echo "🛑 종료하려면 Ctrl+C 를 누르세요."
wait
