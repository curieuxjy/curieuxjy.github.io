#!/usr/bin/env bash
set -euo pipefail

# ===== 설정 =====
PRE_MSG="${1:-pre-commit}"
SIZE_LIMIT="${SIZE_LIMIT:-50M}"   # 환경변수로 조정 가능 (예: SIZE_LIMIT=100M)

# ===== 1) 대용량 파일(> SIZE_LIMIT) 사전 검사 =====
echo "🔎 Checking for files larger than ${SIZE_LIMIT} (excluding .git) ..."
mapfile -t large_files < <(find . -path ./.git -prune -o -type f -size +"${SIZE_LIMIT}" -print)

if [ "${#large_files[@]}" -gt 0 ]; then
  echo "❌ 커밋/푸시 중단: 아래 파일(들)이 ${SIZE_LIMIT} 초과입니다."
  printf '   %s\n' "${large_files[@]}"
  echo "ℹ️  해결 방법 예시: Git LFS 사용, 파일 제외(.gitignore), 용량 축소 등"
  exit 1
fi
echo "✅ Large file check passed."

# ===== 2) Pre-commit (있을 때만) & push =====
before_hash="$(git rev-parse HEAD)"

echo "🔹 Pre-commit: '$PRE_MSG'"
git add -A

pre_committed=0
if git diff --cached --quiet; then
  echo "ℹ️  스테이징된 변경이 없어 pre-commit을 건너뜁니다."
else
  git commit -m "$PRE_MSG"
  git push
  pre_committed=1
  echo "✅ Pre-commit & push 완료"
fi

# ===== 3) 기준점 설정 =====
base_ref="$before_hash"
if [ $pre_committed -eq 1 ]; then
  base_ref="HEAD~1"
fi

# ===== 4) 방금 커밋(또는 기준점) 대비 변경된 .qmd 목록 추출 =====
changed="$(git diff --name-only "$base_ref" HEAD | grep '\.qmd$' || true)"

if [ -z "$changed" ]; then
  echo "ℹ️  렌더링할 .qmd 변경이 없습니다."
  exit 0
fi

echo "🔹 렌더링 대상:"
echo "$changed"

# ===== 5) 변경된 .qmd 렌더링 =====
while IFS= read -r f; do
  [ -z "$f" ] && continue
  echo "🛠️  Rendering: $f"
  quarto render "$f"
done <<< "$changed"

# ===== 6) 렌더 결과 커밋 & 푸시 =====
git add -A

changed_one_line="$(echo "$changed" | tr '\n' ' ')"
commit_msg="Render: ${changed_one_line}"

if git diff --cached --quiet; then
  echo "ℹ️  렌더 후 커밋할 변경이 없습니다."
else
  git commit -m "$commit_msg"
  git push
  echo "✅ Commit & push 완료: $commit_msg"
fi


# chmod +x render_and_commit.sh
# ./render_and_commit.sh "chore: pre-commit before render"
# # 또는
# SIZE_LIMIT=100M ./render_and_commit.sh
