#!/usr/bin/env bash
# OhMykali uninstaller: undoes what install.sh set up. Packages stay installed.
set -euo pipefail

STAMP="$(date +%Y%m%d-%H%M%S)"
step() { printf '\n\033[1;34m==>\033[0m \033[1m%s\033[0m\n' "$*"; }
info() { printf '    %s\n' "$*"; }

[[ $EUID -ne 0 ]] || { echo "Run this as your normal user, not with sudo." >&2; exit 1; }

step "~/.zshrc"
ZSHRC="$HOME/.zshrc"
if [[ -f "$ZSHRC" ]] && grep -q 'ohmykali' "$ZSHRC"; then
    cp -a "$ZSHRC" "$ZSHRC.ohmykali-$STAMP.bak"
    # Drop the blank line install.sh added above the OhMykali block
    sed -i -E '/^$/{N;s/^\n(# OhMykali \(https)/\1/;P;D}' "$ZSHRC"
    sed -i -E \
        -e 's@^ZSH_THEME=""  #ohmykali# (ZSH_THEME=.*)$@\1@' \
        -e 's@^#ohmykali# @@' \
        -e '/^# OhMykali \(https:\/\/github.com\/rapidshyft\/OhMykali\)$/d' \
        -e '/ohmykali\/ohmykali\.zsh/d' \
        "$ZSHRC"
    info "Restored Powerlevel10k lines and removed OhMykali (backup: ~/.zshrc.ohmykali-$STAMP.bak)"
else
    info "Nothing to undo"
fi

step "Config files"
rm -rf "$HOME/.config/ohmykali"
rm -f "$HOME/.config/qterminal.org/color-schemes/Kali-Dark.colorscheme" \
      "$HOME/.config/qterminal.org/color-schemes/Kali-Light.colorscheme"
for ct in qt6ct qt5ct; do
    rm -f "$HOME/.config/$ct/colors/Kali-Dark.conf" "$HOME/.config/$ct/qss/fusion-simple-scrollbar.qss"
done
if grep -qs 'QT_QPA_PLATFORMTHEME' "$HOME/.local/share/applications/qterminal.desktop"; then
    rm -f "$HOME/.local/share/applications/qterminal.desktop"
fi
info "Removed the prompt, colour schemes and QTerminal launcher override"
info "QTerminal's own settings stay; backups are in ~/.config/qterminal.org/*.ohmykali-*.bak"

step "Ctrl+Alt+T shortcut"
MK=org.gnome.settings-daemon.plugins.media-keys
KB_PATH=/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/ohmykali-qterminal/
if command -v gsettings >/dev/null && gsettings list-schemas 2>/dev/null | grep -qx "$MK"; then
    list="$(gsettings get "$MK" custom-keybindings)"
    if [[ "$list" == *"$KB_PATH"* ]]; then
        list="${list//", '$KB_PATH'"/}"
        list="${list//"'$KB_PATH', "/}"
        list="${list//"'$KB_PATH'"/}"
        [[ "$list" == "[]" ]] && list="@as []"
        gsettings set "$MK" custom-keybindings "$list"
        gsettings reset-recursively "$MK.custom-keybinding:$KB_PATH" 2>/dev/null || true
        info "Removed"
    else
        info "Nothing to undo"
    fi
fi

step "Done"
info "Packages (qterminal, qt6ct/qt5ct, fonts-firacode, zsh plugins) are still installed."
info "Your login shell is still zsh. To change it: chsh -s /bin/bash"
