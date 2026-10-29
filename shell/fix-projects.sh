#!/bin/bash
# Makes projects copied from Windows work on the Mac:
#   - rebuilds Python .venv folders (Windows ones don't run on macOS)
#   - reinstalls node_modules and recompiles
#   - rewrites Windows interpreter paths in .vscode/settings.json and *.code-workspace
# Usage: fix-projects            (every project in $NP_ROOT)
#        fix-projects ~/somewhere/my-project
set -uo pipefail

ROOT="${NP_ROOT:-$HOME/Documents/Projects}"
PY=$(command -v python3.13 || command -v python3)
FAILED=()
warn() { printf '\033[1;33m  ! %s\033[0m\n' "$1"; FAILED+=("$1"); }

fix_one() {
  local dir="$1" name; name=$(basename "$dir")

  # Windows paths in VS Code config -> Mac paths
  for f in "$dir"/.vscode/settings.json "$dir"/*.code-workspace; do
    [ -f "$f" ] || continue
    sed -i '' -E 's#[\/]+[.]venv[\/]+Scripts[\/]+python([.]exe)?#/.venv/bin/python#g' "$f"
  done

  # Python: pyproject.toml or a requirements.txt (top level or one folder down)
  local req; req=$(ls "$dir"/requirements.txt "$dir"/*/requirements.txt 2>/dev/null | head -1)
  if [ -f "$dir/pyproject.toml" ] || [ -n "$req" ]; then
    if [ -d "$dir/.venv" ] && ! "$dir/.venv/bin/python" -c '' 2>/dev/null; then
      rm -rf "$dir/.venv"   # Windows venv: has Scripts/ instead of bin/
    fi
    if [ ! -d "$dir/.venv" ]; then
      echo "  $name: building Python environment"
      "$PY" -m venv "$dir/.venv" || { warn "$name: venv"; return; }
      "$dir/.venv/bin/python" -m pip install -q --upgrade pip
      if [ -f "$dir/pyproject.toml" ]; then
        (cd "$dir" && .venv/bin/python - <<'EOF'
import subprocess, sys, tomllib
p = tomllib.load(open("pyproject.toml", "rb")).get("project", {})
deps = p.get("dependencies", [])
for extra in p.get("optional-dependencies", {}).values():
    deps += extra
if deps:
    subprocess.check_call([sys.executable, "-m", "pip", "install", "-q", *deps])
EOF
        ) || warn "$name: Python packages"
      else
        "$dir/.venv/bin/pip" install -q -r "$req" || warn "$name: Python packages"
      fi
    fi
  fi

  # Node: reinstall (Windows node_modules can hold Windows-only binaries) and compile
  if [ -f "$dir/package.json" ]; then
    echo "  $name: installing Node packages"
    if [ -f "$dir/package-lock.json" ]; then (cd "$dir" && npm ci --silent) || warn "$name: npm ci"
    else (cd "$dir" && npm install --silent) || warn "$name: npm install"; fi
    grep -q '"compile"' "$dir/package.json" && { (cd "$dir" && npm run compile --silent) || warn "$name: compile"; }
  fi
}

# Old Claude conversations and memories from the PC ($ROOT/_claude-archive/projects),
# refiled under the Mac folder names Claude Code looks for. Never overwrites.
import_claude_archive() {
  local arch="$ROOT/_claude-archive/projects" win lower dest
  [ -d "$arch" ] || return 0
  local home_slug proj_slug
  home_slug=$(printf '%s' "$HOME" | sed 's/[^A-Za-z0-9]/-/g')
  proj_slug=$(printf '%s' "$ROOT" | sed 's/[^A-Za-z0-9]/-/g')
  echo "  Importing old Claude conversations and memories"
  for d in "$arch"/*/; do
    win=$(basename "$d"); lower=$(printf '%s' "$win" | tr '[:upper:]' '[:lower:]')
    case "$lower" in
      c--users-meech-documents-projects*) dest="$proj_slug${win:33}" ;;  # 33 = length of that prefix
      c--users-meech) dest="$home_slug" ;;
      *) continue ;;  # Claude desktop scratch folders: kept in the archive only
    esac
    mkdir -p "$HOME/.claude/projects/$dest"
    cp -Rn "$d". "$HOME/.claude/projects/$dest/" 2>/dev/null
  done
}

if [ $# -gt 0 ]; then
  for d in "$@"; do fix_one "$(cd "$d" && pwd)"; done
else
  [ -d "$ROOT" ] || { echo "No projects folder at $ROOT (set NP_ROOT)"; exit 1; }
  echo "Fixing projects in $ROOT"
  for d in "$ROOT"/*/; do fix_one "${d%/}"; done
  import_claude_archive
fi

if [ ${#FAILED[@]} -gt 0 ]; then
  echo "Problems:"; printf '  - %s\n' "${FAILED[@]}"; exit 1
fi
echo "Projects ready."
