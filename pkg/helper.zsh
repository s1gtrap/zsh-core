#!/usr/bin/env ksh
# -*- coding: utf-8 -*-

if ! core::exists axel; then core::install axel; fi
if ! core::exists rg; then core::install ripgrep; fi
if ! core::exists fzf; then core::install fzf; fi
if ! core::exists jq; then core::install jq; fi
if ! core::exists bat; then core::install bat; fi
if ! core::exists ghead; then core::install coreutils; fi
if ! core::exists ag; then core::install the_silver_searcher; fi

function cat {
    bat ${@}
}

# fkill [FUZZY PATTERN] - List process the selected process for kill
#   - Bypass fuzzy finder if there's only one match (--select-1)
#   - Exit if there's no match (--exit-0)
function fkill {
    # Kill process
    local pid
    pid="$(ps -ef | sed 1d | fzf -m | awk '{print $2}')"

    if [ -n "${pid}" ]; then
        echo "${pid}" | xargs kill "-${1:-9}"
    fi
}

# fa [FUZZY PATTERN] - Open the path to open
#   - Bypass fuzzy finder if there's only one match (--select-1)
#   - Exit if there's no match (--exit-0)
function fa {
    # fa <dir> - Search dirs and cd to them -
    local dir
    dir=$(fd --type d --hidden --follow --exclude .git | fzf +m | awk -F: '{print $1}' ) \
        && cd "${dir}" || return
}

# fah [FUZZY PATTERN] - Open the files hidden
#   - Bypass fuzzy finder if there's only one match (--select-1)
#   - Exit if there's no match (--exit-0)
function fah {
    # fah <dir> - Search dirs and cd to them (included hidden dirs)
    local dir
    dir=$(find "${1:-.}" -type d 2> /dev/null | fzf +m) && cd "${dir}" || return
}

# fcs [FUZZY PATTERN] - Search commits hash
#   - Bypass fuzzy finder if there's only one match (--select-1)
#   - Exit if there's no match (--exit-0)
function fcs {
    local commits commit
    commits=$(git log --color=always --pretty=oneline --abbrev-commit --reverse) && \
    commit=$(echo "${commits}" | fzf --tac +s +m -e --ansi) && \
    echo -n $(echo -n "${commit}" \
                     | awk '{print $(1)}' \
                     | perl -pe 'chomp' \
                     | sed 's/\"//g' \
                     | ghead -c -1 \
                     | pbcopy)
}

# fenv [FUZZY PATTERN] - Open the selected var env value
#   - Bypass fuzzy finder if there's only one match (--select-1)
#   - Exit if there's no match (--exit-0)
function fenv {
    # Search env variables
    local out
    out=$(env | fzf)
    echo -n "$(echo -n "${out}" | cut -d= -f2 | ghead -c -1 | pbcopy)"
}

# falias [FUZZY PATTERN] - Search alias with fzf
#   - Bypass fuzzy finder if there's only one match (--select-1)
#   - Exit if there's no match (--exit-0)
function falias {
    # Search alias by key or values
    local out
    out=$(alias | fzf)
    echo -n "$(echo -n "${out}" | cut -d= -f2 | ghead -c -1 | pbcopy)"
}


# fo [FUZZY PATTERN] - Open the selected file with the default editor
#
#   - Bypass fuzzy finder if there's only one match (--select-1)
#   - Exit if there's no match (--exit-0)
function fo {
    local file
    file=$(fd --type f --hidden --follow --exclude .git | fzf | awk -F: '{print $1}')
    if [ -n "${file}" ]; then
        ${EDITOR} "${file}"
    fi
}

# fgb [FUZZY PATTERN] - Checkout specified branch
# Include remote branches, sorted by most recent commit and limited to 30
function fgb {
    local branches branch
    branches=$(git for-each-ref --count=30 --sort=-committerdate refs/heads/ --format="%(refname:short)") &&
        branch=$(echo "${branches}" |
                     fzf-tmux -d $(( 2 + $(wc -l <<< "${branches}") )) +m) &&
        git checkout $(echo "${branch}" | sed "s/.* //" | sed "s#remotes/[^/]*/##")
}

# ftm [SESSION_NAME | FUZZY PATTERN] - create new tmux session, or switch to existing one.
# Running `tm` will let you fuzzy-find a session mame
# Passing an argument to `ftm` will switch to that session if it exists or create it otherwise
function ftm {
    [[ -n "${TMUX}" ]] && change="switch-client" || change="attach-session"
    if [ -n "${1}" ]; then
        tmux "${change}" -t "${1}" 2>/dev/null \
            || (tmux new-session -d -s "${1}" && tmux "${change}" -t "${1}"); return
    fi

    session=$(tmux list-sessions -F "#{session_name}" 2>/dev/null | fzf --exit-0) && tmux ${change} -t "${session}" || echo "No sessions found."
}

# ftmk [SESSION_NAME | FUZZY PATTERN] - delete tmux session
# Running `tm` will let you fuzzy-find a session mame to delete
# Passing an argument to `ftm` will delete that session if it exists
function ftmk {
    if [ -n "${1}" ]; then
        tmux kill-session -t "${1}"; return
    fi
    session=$(tmux list-sessions -F "#{session_name}" 2>/dev/null \
        | fzf --exit-0) && tmux kill-session -t "${session}" || echo "No session found to delete."
}

# fgr fuzzy grep via rg and open in vim with line number
function fgr {
    local file line
    read -r file line <<<$(rg --no-heading --line-number "$@" | fzf -0 -1 | awk -F: '{print $1, $2}')
    if [ -n "${file}" ]; then
        ${EDITOR} "+/${line}" "${file}"
    fi
}

# fag fuzzy grep via ag and open in vim with line number
function fag {
    local file line
    read -r file line <<<$(ag --no-heading --line-number "$@" | fzf -0 -1 | awk -F: '{print $1, $2}')
    if [ -n "${file}" ]; then
        ${EDITOR} "+/${line}" "${file}"
    fi
}

# agr - Replace value by new value using silver search
function agr {
    ag --hidden --ignore=.git -0 -l "${1}" \
        | AGR_FROM="${1}" AGR_TO="${2}" xargs -0 perl -pi -e 's/$ENV{AGR_FROM}/$ENV{AGR_TO}/g';
}

# copy pub key to buffer
function pubkey {
    more "${HOME}"/.ssh/id_rsa.pub | perl -pe 'chomp'  | pbcopy && message_info '==> Public key copied to pasteboard.'
}

# download - Implement axel to settings chunk 20
function download {
    if ! type -p axel > /dev/null; then axel::install; fi
    local filename
    filename="${1}"
    axel -n 20 -av "${filename}"
}

# ip - show ip of internet
function ip {
    dig +short myip.opendns.com @resolver1.opendns.com
}

# localip - show ip of internet
function localip {
    ipconfig getifaddr en0
}

if core::exists fd; then
    # Apply the command to CTRL-T as well
    export FZF_CTRL_T_COMMAND="fd --type f --hidden --follow --exclude .git"
fi

function net {
    # check connection
    ping 8.8.8.8 | grep -E --only-match --color=never '[0-9\.]+ ms'
}
