#!/usr/bin/env bash
set -euo pipefail

PRE_MSG="${1:-pre-commit}"

# 현재 HEAD 기록 (프리커밋이 없을 때 비교 기준으로 사용)
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

# 비교 기준 설정
# - 프리커밋이 생겼다면 HEAD~1..HEAD 범위를 사용
# - 아니면 before_hash..HEAD (사실상 동일 HEAD..HEAD)로 안전 처리
base_ref="$before_hash"
if [ $pre_committed -eq 1 ]; then
  base_ref="HEAD~1"
fi

# 방금 커밋(또는 기준점) 대비 변경된 .qmd 목록 추출
#  - pre-commit이 있었다면 그 커밋에 포함된 .qmd들을 타겟팅하게 됨
#  - 없었다면 빈 목록일 수 있음
changed="$(git diff --name-only "$base_ref" HEAD | grep '\.qmd$' || true)"

if [ -z "$changed" ]; then
  echo "ℹ️  렌더링할 .qmd 변경이 없습니다."
  exit 0
fi

echo "🔹 렌더링 대상:"
echo "$changed"

# 변경된 .qmd 파일 렌더링
# (quarto output은 repo 정책에 따라 docs/ 등을 포함할 수 있으므로 이후에 전체 add)
while IFS= read -r f; do
  [ -z "$f" ] && continue
  echo "🛠️  Rendering: $f"
  quarto render "$f"
done <<< "$changed"

# 렌더 결과 및 관련 산출물 포함하여 전부 추가
git add -A

# 커밋 메시지에 업데이트된 .qmd 파일명을 포함
# 한 줄로 정리
changed_one_line="$(echo "$changed" | tr '\n' ' ')"
commit_msg="Render updated QMD files: ${changed_one_line}"

# 변경이 실제로 있으면 커밋 & 푸시
if git diff --cached --quiet; then
  echo "ℹ️  렌더 후 커밋할 변경이 없습니다."
else
  git commit -m "$commit_msg"
  git push
  echo "✅ Commit & push 완료: $commit_msg"
fi
