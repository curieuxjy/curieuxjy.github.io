changed=$(git diff --name-only HEAD~1 HEAD | grep '\.qmd$')
for f in $changed; do
  quarto render "$f"
done
