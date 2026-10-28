# Project helpers. Loaded from ~/.zshrc.
#   np "Basket Light"   new Claude project from _template
#   fix-projects        make projects copied from Windows run on the Mac
export NP_ROOT="$HOME/Documents/Projects"
alias fix-projects="bash $HOME/.dev-setup/shell/fix-projects.sh"

np() {
  local name="$1"
  [[ -z "$name" ]] && { echo 'Usage: np "Project Name"' >&2; return 1; }
  local slug=$(print -r -- "$name" | sed -E 's/[^A-Za-z0-9_ -]//g; s/^ +| +$//g; s/ +/-/g' | tr '[:upper:]' '[:lower:]')
  local dest="$NP_ROOT/$slug"
  [[ -e "$dest" ]] && { echo "Already exists: $dest" >&2; return 1; }
  cp -R "$NP_ROOT/_template" "$dest"
  local esc=${name//\\/\\\\}; esc=${esc//\//\\/}; esc=${esc//&/\\&}
  sed -i '' -e "s/{{PROJECT}}/$esc/g" -e "s/{{DATE}}/$(date +%Y-%m-%d)/g" "$dest/CLAUDE.md"
  command -v git >/dev/null && git -C "$dest" init -q
  code "$dest"
}
