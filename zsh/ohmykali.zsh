# OhMykali: Kali Linux style zsh, adapted.
# Installed to ~/.config/ohmykali/ohmykali.zsh and sourced at the end of ~/.zshrc.
#
# Prompt:
#   [~/Arc/gradex]-[workspace +2 ↑1 ↓3]
#   ≽ your command here
#
#   +N  yellow   files with uncommitted changes
#   ↑N  green    commits ready to push
#   ↓N  magenta  commits ready to pull (as of the last fetch)
#   ≽ turns red after a failed command. Ctrl+P switches to a one-line prompt.
#
# Kali's own settings (prompt base, highlight colours, shell options) come from
# Kali's default ~/.zshrc in the kali-defaults package (GPL-2+).

PROMPT_ALTERNATIVE=twoline
NEWLINE_BEFORE_PROMPT=yes

# ---------------------------------------------------------------------------
# Shell basics from Kali's ~/.zshrc. Skipped under Oh My Zsh, which sets its own.
# ---------------------------------------------------------------------------
if (( ! ${+functions[omz]} )); then
    setopt autocd interactivecomments magicequalsubst nonomatch notify numericglobsort
    WORDCHARS='_-'
    PROMPT_EOL_MARK=""

    bindkey -e
    bindkey ' ' magic-space
    bindkey '^U' backward-kill-line
    bindkey '^[[3;5~' kill-word
    bindkey '^[[3~' delete-char
    bindkey '^[[1;5C' forward-word
    bindkey '^[[1;5D' backward-word
    bindkey '^[[5~' beginning-of-buffer-or-history
    bindkey '^[[6~' end-of-buffer-or-history
    bindkey '^[[H' beginning-of-line
    bindkey '^[[F' end-of-line
    bindkey '^[[Z' undo

    autoload -Uz compinit
    mkdir -p ~/.cache
    compinit -d ~/.cache/zcompdump
    zstyle ':completion:*:*:*:*:*' menu select
    zstyle ':completion:*' auto-description 'specify: %d'
    zstyle ':completion:*' completer _expand _complete
    zstyle ':completion:*' format 'Completing %d'
    zstyle ':completion:*' group-name ''
    zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
    zstyle ':completion:*' rehash true
    zstyle ':completion:*' verbose true
    zstyle ':completion:*:kill:*' command 'ps -u $USER -o pid,%cpu,tty,cputime,cmd'

    HISTFILE=~/.zsh_history
    HISTSIZE=10000
    SAVEHIST=20000
    setopt hist_expire_dups_first hist_ignore_dups hist_ignore_space hist_verify
    alias history="history 0"

    if [ -x /usr/bin/dircolors ]; then
        test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
        export LS_COLORS="$LS_COLORS:ow=30;44:"
        alias ls='ls --color=auto'
        alias grep='grep --color=auto'
        alias diff='diff --color=auto'
        alias ip='ip --color=auto'
        export LESS_TERMCAP_mb=$'\E[1;31m'
        export LESS_TERMCAP_md=$'\E[1;36m'
        export LESS_TERMCAP_me=$'\E[0m'
        export LESS_TERMCAP_so=$'\E[01;33m'
        export LESS_TERMCAP_se=$'\E[0m'
        export LESS_TERMCAP_us=$'\E[1;32m'
        export LESS_TERMCAP_ue=$'\E[0m'
        export MANROFFOPT="-c"
        zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
    fi
    alias ll='ls -l'
    alias la='ls -A'
    alias l='ls -CF'

    [ -f /etc/zsh_command_not_found ] && . /etc/zsh_command_not_found

    # Window title: user@host: dir
    _ohmykali_title() { print -Pn -- $'\e]0;%n@%m: %~\a' }
    autoload -Uz add-zsh-hook
    add-zsh-hook precmd _ohmykali_title
fi

# ---------------------------------------------------------------------------
# Prompt
# ---------------------------------------------------------------------------
autoload -Uz add-zsh-hook
setopt prompt_subst
VIRTUAL_ENV_DISABLE_PROMPT=1

# Git part of the prompt: -[branch +N ↑N ↓N]. Empty outside a git repo.
_ohmykali_git_info() {
    _ohmykali_git=
    local branch
    branch=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null) || return
    local -a changes=(${(f)"$(git status --porcelain 2>/dev/null)"})
    local -a counts=(${=$(git rev-list --left-right --count @{upstream}...HEAD 2>/dev/null)})
    _ohmykali_git="%F{green}-[%F{cyan}${branch//\%/%%}"
    (( ${#changes} )) && _ohmykali_git+=" %F{yellow}+${#changes}"
    (( ${counts[2]:-0} )) && _ohmykali_git+=" %B%F{green}↑${counts[2]}%b"
    (( ${counts[1]:-0} )) && _ohmykali_git+=" %B%F{magenta}↓${counts[1]}%b"
    _ohmykali_git+="%F{green}]"
}
add-zsh-hook precmd _ohmykali_git_info

configure_prompt() {
    # Path and git info; ≽ turns red after a failed command
    local info=$'%F{green}[%B%F{reset}%(6~.%-1~/…/%4~.%5~)%b%F{green}]${_ohmykali_git}%f'
    local arrow=$'%B%(?.%F{blue}.%F{red})≽%b%f '
    case "$PROMPT_ALTERNATIVE" in
        twoline) PROMPT="${info}"$'\n'"${arrow}" ;;
        oneline) PROMPT="${info} ${arrow}" ;;
    esac
    RPROMPT=
}

toggle_oneline_prompt() {
    if [ "$PROMPT_ALTERNATIVE" = oneline ]; then
        PROMPT_ALTERNATIVE=twoline
    else
        PROMPT_ALTERNATIVE=oneline
    fi
    configure_prompt
    zle reset-prompt
}
zle -N toggle_oneline_prompt
bindkey ^P toggle_oneline_prompt

# Blank line between commands, but not above the first prompt
_ohmykali_newline_before_prompt() {
    if [ "$NEWLINE_BEFORE_PROMPT" = yes ]; then
        if [ -z "$_OHMYKALI_NEW_LINE" ]; then
            _OHMYKALI_NEW_LINE=1
        else
            print ""
        fi
    fi
}
add-zsh-hook precmd _ohmykali_newline_before_prompt

configure_prompt

# ---------------------------------------------------------------------------
# Plugins: suggestions from history, and command highlighting.
# Loaded from the Debian packages unless something (e.g. Oh My Zsh) already did.
# ---------------------------------------------------------------------------
if (( ! ${+functions[_zsh_autosuggest_start]} )) && [ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
    . /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
fi
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=244'

if (( ! ${+functions[_zsh_highlight]} )) && [ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
    . /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# Kali's highlight colours
typeset -gA ZSH_HIGHLIGHT_STYLES
ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets pattern)
ZSH_HIGHLIGHT_STYLES[default]=none
ZSH_HIGHLIGHT_STYLES[unknown-token]=underline
ZSH_HIGHLIGHT_STYLES[reserved-word]=fg=cyan,bold
ZSH_HIGHLIGHT_STYLES[suffix-alias]=fg=green,underline
ZSH_HIGHLIGHT_STYLES[global-alias]=fg=green,bold
ZSH_HIGHLIGHT_STYLES[precommand]=fg=green,underline
ZSH_HIGHLIGHT_STYLES[commandseparator]=fg=blue,bold
ZSH_HIGHLIGHT_STYLES[autodirectory]=fg=green,underline
ZSH_HIGHLIGHT_STYLES[path]=bold
ZSH_HIGHLIGHT_STYLES[path_pathseparator]=
ZSH_HIGHLIGHT_STYLES[path_prefix_pathseparator]=
ZSH_HIGHLIGHT_STYLES[globbing]=fg=blue,bold
ZSH_HIGHLIGHT_STYLES[history-expansion]=fg=blue,bold
ZSH_HIGHLIGHT_STYLES[command-substitution]=none
ZSH_HIGHLIGHT_STYLES[command-substitution-delimiter]=fg=magenta,bold
ZSH_HIGHLIGHT_STYLES[process-substitution]=none
ZSH_HIGHLIGHT_STYLES[process-substitution-delimiter]=fg=magenta,bold
ZSH_HIGHLIGHT_STYLES[single-hyphen-option]=fg=green
ZSH_HIGHLIGHT_STYLES[double-hyphen-option]=fg=green
ZSH_HIGHLIGHT_STYLES[back-quoted-argument]=none
ZSH_HIGHLIGHT_STYLES[back-quoted-argument-delimiter]=fg=blue,bold
ZSH_HIGHLIGHT_STYLES[single-quoted-argument]=fg=yellow
ZSH_HIGHLIGHT_STYLES[double-quoted-argument]=fg=yellow
ZSH_HIGHLIGHT_STYLES[dollar-quoted-argument]=fg=yellow
ZSH_HIGHLIGHT_STYLES[rc-quote]=fg=magenta
ZSH_HIGHLIGHT_STYLES[dollar-double-quoted-argument]=fg=magenta,bold
ZSH_HIGHLIGHT_STYLES[back-double-quoted-argument]=fg=magenta,bold
ZSH_HIGHLIGHT_STYLES[back-dollar-quoted-argument]=fg=magenta,bold
ZSH_HIGHLIGHT_STYLES[assign]=none
ZSH_HIGHLIGHT_STYLES[redirection]=fg=blue,bold
ZSH_HIGHLIGHT_STYLES[comment]=fg=black,bold
ZSH_HIGHLIGHT_STYLES[named-fd]=none
ZSH_HIGHLIGHT_STYLES[numeric-fd]=none
ZSH_HIGHLIGHT_STYLES[arg0]=fg=cyan
ZSH_HIGHLIGHT_STYLES[bracket-error]=fg=red,bold
ZSH_HIGHLIGHT_STYLES[bracket-level-1]=fg=blue,bold
ZSH_HIGHLIGHT_STYLES[bracket-level-2]=fg=green,bold
ZSH_HIGHLIGHT_STYLES[bracket-level-3]=fg=magenta,bold
ZSH_HIGHLIGHT_STYLES[bracket-level-4]=fg=yellow,bold
ZSH_HIGHLIGHT_STYLES[bracket-level-5]=fg=cyan,bold
ZSH_HIGHLIGHT_STYLES[cursor-matchingbracket]=standout
