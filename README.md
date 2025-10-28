# curieuxjy.github.io

based on [Quarto](https://quarto.org/)

be myself

# Commit

`bash render_and_commit.sh`

```
chmod +x render_and_commit.sh
./render_and_commit.sh "chore: pre-commit before render"
# 또는
SIZE_LIMIT=100M ./render_and_commit.sh
```

- 50MB 이상 커밋 시도 시 오류 발생 방지
  - `SIZE_LIMIT` 환경변수로 제한 크기 조정 가능
- 변경된 qmd 파일만 렌더링


# TODO
- [ ] project page 정리
- [ ] ppt 오픈할 수 있는 자료들 블로그에 옮기기
- [ ] post 계획서
