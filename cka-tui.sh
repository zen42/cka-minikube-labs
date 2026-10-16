#!/usr/bin/env bash
# cka-tui.sh — optional split-pane TUI: interactive $SHELL on the left,
# Textual app (scripts/tui.py) on the right. Standalone, not via make.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

lab_banner() { :; }   # top-level script: silence per-lab banner

VENV="$REPO_ROOT/.venv"
SCRIPT="$REPO_ROOT/scripts/tui.py"
REQS="$REPO_ROOT/scripts/requirements-tui.txt"
SESSION="cka-labs-tui"
HELP_SEEN="$REPO_ROOT/.state/tui_help_seen"

# CKA_TUI_TMUX_SOCKET (optional): run against a private tmux socket, for tests.
TMUX_BIN=(tmux)
if [[ -n "${CKA_TUI_TMUX_SOCKET:-}" ]]; then
    TMUX_BIN+=(-L "$CKA_TUI_TMUX_SOCKET")
fi
tmux_cmd() { "${TMUX_BIN[@]}" "$@"; }
tmux_str() { printf 'tmux'; [[ -n "${CKA_TUI_TMUX_SOCKET:-}" ]] && printf ' -L %q' "$CKA_TUI_TMUX_SOCKET"; }

ensure_venv() {
    if [[ -x "$VENV/bin/python3" ]] && "$VENV/bin/python3" -c 'import textual' 2>/dev/null; then
        return 0
    fi
    local manual="python3 -m venv .venv && .venv/bin/pip install -r scripts/requirements-tui.txt"
    info "textual not found in $VENV"
    if [[ ! -t 0 ]]; then
        die "textual is required and stdin is not a TTY — run: $manual"
    fi
    local ans
    read -r -p "Create .venv and install textual? [y/N] " ans
    [[ "$ans" =~ ^[Yy] ]] || die "textual is required — run: $manual"
    if ! python3 -m venv "$VENV"; then
        rm -rf "$VENV"
        die "venv creation failed — on Debian install: sudo apt install python3-venv"
    fi
    "$VENV/bin/pip" install --quiet -r "$REQS"
    info "textual installed in $VENV"
}

# Build the command run in the right (TUI) pane. The trailing kill makes sure
# the session/window is cleaned up even if the app crashes.
build_tui_cmd() {
    local kill_cmd="$1" kill_target="$2" shell_pane="$3" __out="$4"
    printf -v "$__out" \
        'REPO_ROOT=%q CKA_TUI_SHELL_PANE=%q CKA_TUI_KILL_TARGET=%q CKA_TUI_KILL_CMD=%q CKA_TUI_TMUX_SOCKET=%q %q %q; %s %s -t %q 2>/dev/null' \
        "$REPO_ROOT" "$shell_pane" "$kill_target" "$kill_cmd" "${CKA_TUI_TMUX_SOCKET:-}" \
        "$VENV/bin/python3" "$SCRIPT" "$(tmux_str)" "$kill_cmd" "$kill_target"
}

usage() {
    cat <<'EOF'
usage: ./cka-tui.sh [--help] [--no-help]
  --help      print the tmux/TUI cheat sheet and exit
  --no-help   skip the first-run tmux notice (or set CKA_TUI_NO_HELP=1)
EOF
}

# Printed before entering tmux so first-time users know how to get around.
print_tui_help() {
    cat <<'EOF'
CKA Labs TUI - quick orientation

  Layout:   left pane = your shell (repo root), right pane = lab guide
            (README / SOLUTION / OUTPUT tabs).
  Switch:   Ctrl-b then Left/Right arrow (or Ctrl-b o). With the mouse,
            just click a pane.
  Scroll:   left shell: Ctrl-b [ then PageUp/arrows, q to exit scroll mode
            (or the mouse wheel). right guide: click it, then Up/Down/
            PageUp/PageDown or j/k/Space/b - or press ? for help.
  Detach:   Ctrl-b d leaves everything running (re-run ./cka-tui.sh for a
            fresh session; your place is kept in .state/tui_state).
  Quit:     press q in the right pane.

  'Ctrl-b' means: hold Ctrl, press b, release, then press the next key.
  (Mouse pane-switching only works inside your own tmux if you have
  'set -g mouse on' - this TUI enables it on its own session.)
EOF
}

maybe_show_help() {
    [[ "${NO_HELP:-0}" == 1 || "${CKA_TUI_NO_HELP:-0}" == 1 ]] && return 0
    [[ -f "$HELP_SEEN" ]] && return 0
    [[ -t 0 && -t 1 ]] || return 0   # skip when not interactive (tests, pipes)
    print_tui_help
    echo
    local ans
    read -r -p "Press Enter to continue (or type n + Enter to not show this again) " ans
    if [[ "$ans" =~ ^[Nn] ]]; then
        mkdir -p "$REPO_ROOT/.state"
        : > "$HELP_SEEN"
    fi
}

main() {
    local arg
    for arg in "$@"; do
        case "$arg" in
            --no-help) NO_HELP=1 ;;
            --help) usage; echo; print_tui_help; exit 0 ;;
            -h) usage; exit 0 ;;
            *) usage >&2; die "unknown option: $arg" ;;
        esac
    done

    # root would use root's ~/.minikube and kubeconfig (a different cluster
    # view) and leave root-owned files in .venv/ and .state/.
    if (( EUID == 0 )) && [[ "${CKA_TUI_ALLOW_ROOT:-0}" != 1 ]]; then
        die "refusing to run as root — run as your normal user (the labs, \
.venv/ and .state/ belong to that user). Override: CKA_TUI_ALLOW_ROOT=1"
    fi

    require_command tmux "sudo apt install tmux"
    require_command python3
    ensure_venv
    maybe_show_help

    if [[ -n "${TMUX:-}" ]]; then
        # Already inside tmux: add a window to the current session, kill only
        # that window on quit — never the user's session.
        local win_id shell_pane tui_cmd
        win_id="$(tmux_cmd new-window -P -F '#{window_id}' -n cka-tui -c "$REPO_ROOT" \
                  -t "$(tmux_cmd display-message -p '#{session_id}')")"
        shell_pane="$(tmux_cmd display-message -p -t "$win_id" '#{pane_id}')"
        build_tui_cmd kill-window "$win_id" "$shell_pane" tui_cmd
        tmux_cmd split-window -h -l '45%' -t "$win_id" -c "$REPO_ROOT" "$tui_cmd"
        tmux_cmd select-pane -t "$shell_pane"
    else
        # Outside tmux: fresh detached session, then attach. A stale
        # cka-labs-tui session is ours — kill it first.
        if tmux_cmd has-session -t "$SESSION" 2>/dev/null; then
            tmux_cmd kill-session -t "$SESSION"
        fi
        local cols lines sess_id shell_pane tui_cmd
        cols="$(tput cols 2>/dev/null || echo 220)"
        lines="$(tput lines 2>/dev/null || echo 50)"
        sess_id="$(tmux_cmd new-session -d -P -F '#{session_id}' -s "$SESSION" \
                   -x "$cols" -y "$lines" -c "$REPO_ROOT" "${SHELL:-/bin/bash}")"
        # mouse on for OUR session only (never in the nested-tmux path)
        tmux_cmd set-option -t "$sess_id" mouse on
        shell_pane="$(tmux_cmd display-message -p -t "$sess_id" '#{pane_id}')"
        build_tui_cmd kill-session "$sess_id" "$shell_pane" tui_cmd
        tmux_cmd split-window -h -l '45%' -t "$sess_id" -c "$REPO_ROOT" "$tui_cmd"
        tmux_cmd select-pane -t "$shell_pane"
        tmux_cmd attach-session -t "$SESSION"
    fi
}

main "$@"
