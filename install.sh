#!/usr/bin/env bash
# OhMykali installer: Kali Linux style terminal for Debian/Ubuntu (built for GNOME).
# Safe to run again; it only changes what isn't already set up.
#
#   ./install.sh                  install everything
#   ./install.sh --skip-packages  skip apt (configs only)
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
SKIP_PACKAGES=0

for arg in "$@"; do
    case "$arg" in
        --skip-packages) SKIP_PACKAGES=1 ;;
        -h|--help) sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "Unknown option: $arg" >&2; exit 1 ;;
    esac
done

step() { printf '\n\033[1;34m==>\033[0m \033[1m%s\033[0m\n' "$*"; }
info() { printf '    %s\n' "$*"; }
warn() { printf '    \033[1;33m!\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31mError:\033[0m %s\n' "$*" >&2; exit 1; }

# Set key=value inside [section] of an ini file, adding the section or key if missing.
ini_set() {
    local file="$1" section="$2" key="$3" value="$4"
    touch "$file"
    awk -v s="[$section]" -v k="$key" -v v="$value" '
        BEGIN { insec = 0; done = 0 }
        /^\[/ { if (insec && !done) { print k "=" v; done = 1 } insec = ($0 == s) }
        insec && index($0, k "=") == 1 { if (!done) { print k "=" v; done = 1 } next }
        { print }
        END { if (!done) { if (!insec) print "\n" s; print k "=" v } }
    ' "$file" > "$file.ohmykali-tmp" && mv "$file.ohmykali-tmp" "$file"
}

[[ $EUID -ne 0 ]] || die "Run this as your normal user, not with sudo. It asks for your password when it needs it."
command -v apt-get >/dev/null || die "This installer supports Debian and Ubuntu (apt) only."

# ---------------------------------------------------------------------------
step "Packages"
# QTerminal on Debian 13+ / newer Ubuntu is Qt6 (themed with qt6ct); older releases are Qt5 (qt5ct).
if [[ $SKIP_PACKAGES -eq 0 ]]; then
    if apt-cache depends qterminal 2>/dev/null | grep -q 'libqt6'; then QTCT=qt6ct; else QTCT=qt5ct; fi
    PKGS=(zsh git qterminal "$QTCT" fonts-firacode zsh-syntax-highlighting zsh-autosuggestions)
    info "Installing: ${PKGS[*]}"
    sudo apt-get update -qq
    sudo apt-get install -y "${PKGS[@]}"
else
    if command -v qt6ct >/dev/null; then QTCT=qt6ct; elif command -v qt5ct >/dev/null; then QTCT=qt5ct; else QTCT=qt6ct; fi
    info "Skipped (--skip-packages)"
fi
command -v zsh >/dev/null || die "zsh isn't installed. Run without --skip-packages."

# ---------------------------------------------------------------------------
step "Zsh prompt and highlighting"
install -Dm644 "$REPO/zsh/ohmykali.zsh" "$HOME/.config/ohmykali/ohmykali.zsh"
info "Installed ~/.config/ohmykali/ohmykali.zsh"

ZSHRC="$HOME/.zshrc"
SOURCE_LINE='[[ -f ~/.config/ohmykali/ohmykali.zsh ]] && source ~/.config/ohmykali/ohmykali.zsh'
if [[ ! -f "$ZSHRC" ]]; then
    printf '# ~/.zshrc\n\n# OhMykali (https://github.com/rapidshyft/OhMykali)\n%s\n' "$SOURCE_LINE" > "$ZSHRC"
    info "Created ~/.zshrc"
else
    tmp="$(mktemp)"
    # Turn off Powerlevel10k. Lines are tagged "#ohmykali#" so uninstall.sh can restore them.
    sed -E \
        -e '/^if \[\[ -r .*p10k-instant-prompt/,/^fi$/ s/^/#ohmykali# /' \
        -e 's@^ZSH_THEME="(powerlevel10k/[^"]*)"@ZSH_THEME=""  #ohmykali# ZSH_THEME="\1"@' \
        -e 's@^(\[\[ ! -f ~/\.p10k\.zsh \]\] [|][|] source ~/\.p10k\.zsh)@#ohmykali# \1@' \
        "$ZSHRC" > "$tmp"
    if ! grep -qF 'ohmykali/ohmykali.zsh' "$tmp"; then
        printf '\n# OhMykali (https://github.com/rapidshyft/OhMykali)\n%s\n' "$SOURCE_LINE" >> "$tmp"
    fi
    if cmp -s "$tmp" "$ZSHRC"; then
        rm -f "$tmp"
        info "~/.zshrc already set up"
    else
        cp -a "$ZSHRC" "$ZSHRC.ohmykali-$STAMP.bak"
        cat "$tmp" > "$ZSHRC" && rm -f "$tmp"
        info "Updated ~/.zshrc (backup: ~/.zshrc.ohmykali-$STAMP.bak)"
        grep -q '#ohmykali# ZSH_THEME\|#ohmykali# \[\[ ! -f ~/.p10k' "$ZSHRC" && info "Powerlevel10k turned off (still installed)"
    fi
fi

# ---------------------------------------------------------------------------
step "QTerminal"
pgrep -x qterminal >/dev/null && warn "QTerminal is running. Close all its windows after this finishes, or it may overwrite these settings when it exits."
QT_DIR="$HOME/.config/qterminal.org"
mkdir -p "$QT_DIR/color-schemes"
install -m644 "$REPO"/qterminal/color-schemes/*.colorscheme "$QT_DIR/color-schemes/"
[[ -f "$QT_DIR/qterminal.ini" ]] && cp -a "$QT_DIR/qterminal.ini" "$QT_DIR/qterminal.ini.ohmykali-$STAMP.bak"
# Apply the [General] and [Shortcuts] keys from our qterminal.ini, keeping your other settings
section=""
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    if [[ "$line" =~ ^\[(.*)\]$ ]]; then section="${BASH_REMATCH[1]}"; continue; fi
    [[ "$section" == "General" || "$section" == "Shortcuts" ]] || continue
    ini_set "$QT_DIR/qterminal.ini" "$section" "${line%%=*}" "${line#*=}"
done < "$REPO/qterminal/qterminal.ini"
info "Kali-Dark colours, Fira Code, split shortcuts (Ctrl+Shift+R / Ctrl+Shift+D / Ctrl+Shift+E)"

# ---------------------------------------------------------------------------
step "Dark menus and title bar ($QTCT)"
CT_DIR="$HOME/.config/$QTCT"
install -Dm644 "$REPO/qtct/colors/Kali-Dark.conf" "$CT_DIR/colors/Kali-Dark.conf"
install -Dm644 "$REPO/qtct/qss/fusion-simple-scrollbar.qss" "$CT_DIR/qss/fusion-simple-scrollbar.qss"
CT_CONF="$CT_DIR/$QTCT.conf"
ini_set "$CT_CONF" Appearance custom_palette true
ini_set "$CT_CONF" Appearance color_scheme_path "$CT_DIR/colors/Kali-Dark.conf"
ini_set "$CT_CONF" Appearance style Fusion
ini_set "$CT_CONF" Appearance standard_dialogs default
ini_set "$CT_CONF" Interface stylesheets "$CT_DIR/qss/fusion-simple-scrollbar.qss"
ini_set "$CT_CONF" Fonts fixed '"Fira Code,10,-1,5,500,0,0,0,0,0,0,0,0,0,0,1"'
info "Kali Qt theme in ~/.config/$QTCT (used by QTerminal only)"

LAUNCH="env QT_QPA_PLATFORMTHEME=$QTCT qterminal"
if [[ -f /usr/share/applications/qterminal.desktop ]]; then
    mkdir -p "$HOME/.local/share/applications"
    sed -E "s#^Exec=qterminal#Exec=$LAUNCH#" /usr/share/applications/qterminal.desktop \
        > "$HOME/.local/share/applications/qterminal.desktop"
    info "App menu entry starts QTerminal with the Kali theme"
fi

# ---------------------------------------------------------------------------
step "Ctrl+Alt+T shortcut"
MK=org.gnome.settings-daemon.plugins.media-keys
if command -v gsettings >/dev/null && gsettings list-schemas 2>/dev/null | grep -qx "$MK"; then
    KB_PATH=/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/ohmykali-qterminal/
    KB="$MK.custom-keybinding:$KB_PATH"
    gsettings set "$KB" name 'QTerminal (OhMykali)'
    gsettings set "$KB" command "$LAUNCH"
    gsettings set "$KB" binding '<Control><Alt>t'
    list="$(gsettings get "$MK" custom-keybindings)"
    if [[ "$list" != *"$KB_PATH"* ]]; then
        if [[ "$list" == "@as []" || "$list" == "[]" ]]; then
            list="['$KB_PATH']"
        else
            list="${list%]}, '$KB_PATH']"
        fi
        gsettings set "$MK" custom-keybindings "$list"
    fi
    info "Ctrl+Alt+T opens QTerminal"
else
    info "Skipped (not GNOME)"
fi

# ---------------------------------------------------------------------------
step "Default shell"
if [[ "$(getent passwd "$USER" | cut -d: -f7)" == */zsh ]]; then
    info "Already zsh"
else
    info "Switching your login shell to zsh (asks for your password)"
    chsh -s "$(command -v zsh)" || warn "Couldn't change the shell. Run: chsh -s $(command -v zsh)"
fi

step "Done"
info "Open QTerminal with Ctrl+Alt+T, or run 'exec zsh' in an open terminal."
info "If your login shell just changed, log out and back in once."
