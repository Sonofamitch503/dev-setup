#!/bin/bash
# Prints what the Mac setup did and didn't do. Changes nothing.
# Run: bash -c "$(curl -fsSL https://raw.githubusercontent.com/Sonofamitch503/dev-setup/main/doctor.sh)"
for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do [ -x "$b" ] && eval "$("$b" shellenv)"; done
export PATH="$HOME/.local/bin:$PATH"
ok() { printf '  [ok]   %s\n' "$1"; }
no() { printf '  [MISSING] %s\n' "$1"; }
chk() { if eval "$2" >/dev/null 2>&1; then ok "$1"; else no "$1"; fi; }
VS="$HOME/Library/Application Support/Code/User"
P="$HOME/Documents/Projects"
CODE=$(command -v code || echo "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code")

echo "== Mac: $(uname -m), macOS $(sw_vers -productVersion), user $(whoami)"
echo "== Tools"
chk "Apple developer tools" "xcode-select -p"
for t in brew git node python3.13 claude; do chk "$t ($(command -v $t))" "command -v $t"; done
chk "VS Code app" "[ -d '/Applications/Visual Studio Code.app' ]"
chk "code command" "[ -x \"\$CODE\" ]"
echo "  .zprofile brew line: $(grep 'brew shellenv' ~/.zprofile 2>/dev/null || echo none)"
echo "== Setup repo"
chk "~/.dev-setup downloaded" "[ -f ~/.dev-setup/bootstrap.sh ]"
[ -d ~/.dev-setup/.git ] && echo "  version: $(git -C ~/.dev-setup log -1 --format='%h %s')"
chk "np / fix-projects in ~/.zshrc" "grep -q dev-setup/shell/np.zsh ~/.zshrc"
echo "== VS Code"
chk "settings.json copied" "grep -q bonesInc '$VS/settings.json'"
echo "  extensions installed:"; "$CODE" --list-extensions --show-versions 2>/dev/null | sed 's/^/    /'
echo "== Claude"
chk "~/.claude/settings.json" "[ -f ~/.claude/settings.json ]"
chk "logged in (~/.claude.json)" "[ -f ~/.claude.json ]"
echo "  conversation folders in ~/.claude/projects:"
ls ~/.claude/projects 2>/dev/null | sed 's/^/    /' || echo "    none"
echo "== Projects ($P)"
if [ -d "$P" ]; then ls "$P" | sed 's/^/    /'; else no "Projects folder"; fi
chk "_claude-archive copied" "[ -d '$P/_claude-archive/projects' ]"
for d in "chromalocal" "First Coding Project"; do [ -d "$P/$d" ] && chk "$d: Mac .venv" "'$P/$d/.venv/bin/python' -c ''"; done
[ -d "$P/Bones INC" ] && chk "Bones INC: node_modules" "[ -d '$P/Bones INC/node_modules' ]"
