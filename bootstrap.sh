#!/bin/bash
# Rebuilds the Windows VS Code + Claude Code setup on a new Mac.
# Run:  bash -c "$(curl -fsSL https://raw.githubusercontent.com/Sonofamitch503/dev-setup/main/bootstrap.sh)"
# Safe to re-run: every step skips or overwrites what is already there.
set -uo pipefail

REPO_URL="https://github.com/Sonofamitch503/dev-setup.git"
SETUP="$HOME/.dev-setup"
VSCODE_USER="$HOME/Library/Application Support/Code/User"
FAILED=()

step() { printf '\n\033[1;34m==> %s\033[0m\n' "$1"; }
warn() { printf '\033[1;33m  ! %s\033[0m\n' "$1"; FAILED+=("$1"); }

# 0. Apple's developer tools (git, compilers). A fresh Mac doesn't have them.
step "Apple developer tools"
if ! xcode-select -p >/dev/null 2>&1; then
  xcode-select --install 2>/dev/null
  echo "  A window popped up: click Install, then Agree. This script waits and carries on by itself."
  until xcode-select -p >/dev/null 2>&1; do sleep 10; done
  echo "  Developer tools installed."
fi

# 1. Homebrew
step "Homebrew - may ask for your Mac password"
if ! command -v brew >/dev/null && [ ! -x /opt/homebrew/bin/brew ]; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"
grep -q 'brew shellenv' "$HOME/.zprofile" 2>/dev/null ||
  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"

# 2. This setup repo
step "Setup files"
if [ -d "$SETUP/.git" ]; then git -C "$SETUP" pull -q --ff-only || warn "could not update $SETUP"
else git clone -q "$REPO_URL" "$SETUP" || { echo "Could not download $REPO_URL"; exit 1; }; fi

# 3. VS Code, git, node, python
step "VS Code and tools"
brew bundle --file="$SETUP/Brewfile" || warn "some Brewfile items failed (see above)"

# 4. Claude Code
step "Claude Code"
command -v claude >/dev/null || [ -x "$HOME/.local/bin/claude" ] ||
  curl -fsSL https://claude.ai/install.sh | bash || warn "Claude Code install failed"
grep -q '.local/bin' "$HOME/.zshrc" 2>/dev/null || echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
mkdir -p "$HOME/.claude"
[ -f "$HOME/.claude/settings.json" ] || cp "$SETUP/claude/settings.json" "$HOME/.claude/settings.json"
if [ -d "$SETUP/claude/plans" ]; then
  mkdir -p "$HOME/.claude/plans" && cp -n "$SETUP"/claude/plans/* "$HOME/.claude/plans/" 2>/dev/null
fi

# 5. Git identity
step "Git config"
git config --global user.name "Meech"
git config --global user.email "346439889+Sonofamitch503@users.noreply.github.com"
git config --global init.defaultBranch main

# 6. VS Code settings and extensions
step "VS Code settings and extensions"
mkdir -p "$VSCODE_USER"
cp "$SETUP/vscode/settings.json" "$VSCODE_USER/settings.json"
[ -f "$SETUP/vscode/keybindings.json" ] && cp "$SETUP/vscode/keybindings.json" "$VSCODE_USER/"
[ -d "$SETUP/vscode/snippets" ] && cp -R "$SETUP/vscode/snippets" "$VSCODE_USER/"
CODE=$(command -v code || echo "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code")
while read -r ext; do
  [ -n "$ext" ] && { "$CODE" --install-extension "$ext" --force >/dev/null || warn "extension $ext"; }
done < "$SETUP/vscode/extensions.txt"
"$CODE" --install-extension "$SETUP"/vscode/bones-inc-*.vsix --force >/dev/null || warn "Bones INC extension"

# 7. Shell helpers: np "Project Name", fix-projects
step "Shell helpers"
grep -q 'dev-setup/shell/np.zsh' "$HOME/.zshrc" 2>/dev/null ||
  echo 'source "$HOME/.dev-setup/shell/np.zsh"' >> "$HOME/.zshrc"

# 8. Projects copied from the PC: wait for them, then make them Mac-ready
step "Projects"
PROJECTS="$HOME/Documents/Projects"
if [ ! -d "$PROJECTS" ] || [ -z "$(ls -A "$PROJECTS" 2>/dev/null)" ]; then
  echo "Copy your Projects folder from the PC to $PROJECTS now."
  printf "Press Enter when it's there (or type s to skip and run fix-projects later): "
  read -r answer < /dev/tty || answer=s
fi
if [ -d "$PROJECTS" ] && [ -n "$(ls -A "$PROJECTS" 2>/dev/null)" ]; then
  NP_ROOT="$PROJECTS" bash "$SETUP/shell/fix-projects.sh" || warn "fix-projects had problems (see above)"
else
  echo "  Skipped. After copying, open a terminal and run: fix-projects"
fi

# 9. Done
step "Finished"
if [ ${#FAILED[@]} -gt 0 ]; then
  echo "These steps had problems (re-run the script after fixing):"
  printf '  - %s\n' "${FAILED[@]}"
fi
cat <<'EOF'

Two sign-ins left (VS Code is opening now):
  1. In VS Code, open the Claude Code panel and sign in.
  2. Open a new terminal, run `claude`, and log in. Your skills and plugins sync from your account.
EOF
open -a "Visual Studio Code" 2>/dev/null || true
