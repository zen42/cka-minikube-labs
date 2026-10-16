#!/usr/bin/env python3
"""CKA Labs TUI — optional right-pane Textual app driven by cka-tui.sh.

Exempt from the repo's bash-only rule. Never depends on the user's kubectl
context — it only shells out to `make`/tmux/verify.sh, which pin the
`cka-labs` context themselves. Never commits or mutates the repo.

Environment (set by cka-tui.sh):
  REPO_ROOT             repo root (default: parent of this script's dir)
  CKA_TUI_SHELL_PANE    tmux pane id of the left shell pane (%N); if empty,
  CKA_TUI_KILL_TARGET   session/window id to destroy on quit (optional;
                        cka-tui.sh's wrapper also cleans up on exit)
  CKA_TUI_KILL_CMD      "kill-session" or "kill-window"
  CKA_TUI_TMUX_SOCKET   private tmux socket name for tests (optional)
"""

import asyncio
import json
import os
import pathlib
import re
import subprocess

from textual import on
from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.containers import VerticalScroll
from textual.reactive import reactive
from textual.screen import ModalScreen
from textual.widgets import (
    Footer,
    Header,
    Label,
    ListItem,
    ListView,
    Log,
    Markdown,
    TabbedContent,
    TabPane,
)

REPO_ROOT = pathlib.Path(
    os.environ.get("REPO_ROOT") or pathlib.Path(__file__).resolve().parent.parent
)
LAB_DIRS = sorted(REPO_ROOT.glob("labs/[0-9][0-9]-*"))
PROGRESS_DIR = REPO_ROOT / ".progress"
STATE_FILE = REPO_ROOT / ".state" / "tui_state"

SHELL_PANE = os.environ.get("CKA_TUI_SHELL_PANE", "")
KILL_TARGET = os.environ.get("CKA_TUI_KILL_TARGET", "")
KILL_CMD = os.environ.get("CKA_TUI_KILL_CMD", "")
TMUX_SOCKET = os.environ.get("CKA_TUI_TMUX_SOCKET", "")


def _tmux(*args: str) -> None:
    cmd = ["tmux"]
    if TMUX_SOCKET:
        cmd += ["-L", TMUX_SOCKET]
    subprocess.run(cmd + list(args), capture_output=True)


def send_to_shell(cmd: str) -> None:
    if SHELL_PANE:
        _tmux("send-keys", "-t", SHELL_PANE, cmd, "Enter")


def lab_title(index: int) -> str:
    try:
        for line in (LAB_DIRS[index] / "README.md").read_text().splitlines():
            m = re.match(r"#\s*Lab\s*\d+\s*[–-]\s*(.+)", line)
            if m:
                return m.group(1).strip()
    except OSError:
        pass
    return LAB_DIRS[index].name[3:].replace("-", " ").title()


def completed_labs() -> set:
    if not PROGRESS_DIR.is_dir():
        return set()
    return {int(p.name) for p in PROGRESS_DIR.glob("[0-9][0-9]")}


def load_state() -> int:
    try:
        data = json.loads(STATE_FILE.read_text())
        return max(0, min(int(data.get("current_lab", 0)), len(LAB_DIRS) - 1))
    except Exception:
        return 0


def save_state(current_lab: int) -> None:
    try:
        STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
        STATE_FILE.write_text(json.dumps({"current_lab": current_lab}))
    except OSError:
        pass


class LabListScreen(ModalScreen):
    BINDINGS = [Binding("escape", "cancel", "Close")]

    def __init__(self, current: int, completed: set):
        super().__init__()
        self._current = current
        self._completed = completed

    def compose(self) -> ComposeResult:
        with VerticalScroll(id="lab-list-box"):
            yield ListView(
                *[
                    ListItem(
                        Label(
                            f"  {'[done]' if i in self._completed else '[----]'}"
                            f"  {i:02d}  {lab_title(i)}"
                        )
                    )
                    for i in range(len(LAB_DIRS))
                ],
                id="lab-list",
            )

    def on_mount(self) -> None:
        lv = self.query_one("#lab-list", ListView)
        lv.index = self._current
        lv.focus()

    @on(ListView.Selected)
    def on_selected(self, event: ListView.Selected) -> None:
        self.dismiss(event.index)

    def action_cancel(self) -> None:
        self.dismiss(None)


class ConfirmScreen(ModalScreen):
    BINDINGS = [
        Binding("y", "confirm", "Yes"),
        Binding("n,escape", "cancel", "No"),
    ]

    def __init__(self, msg: str, on_confirm):
        super().__init__()
        self._msg = msg
        self._on_confirm = on_confirm

    def compose(self) -> ComposeResult:
        with VerticalScroll(id="confirm-box"):
            yield Label(self._msg)
            yield Label("[y] Yes    [n/Esc] No")

    def action_confirm(self) -> None:
        self._on_confirm()
        self.dismiss()

    def action_cancel(self) -> None:
        self.dismiss()


HELP_TEXT = """\
CKA Labs TUI - keys and tmux cheat sheet

App keys (right pane):
  n / p      next / previous lab          s  start lab (make lab-NN)
  1 / 2 / 3  README / SOLUTION / OUTPUT   v  verify (streams to OUTPUT)
  L          lab list                     t  teardown (make teardown-NN)
  o          solve (asks first)           ?  this help     q  quit

Scroll the active tab:  Up/Down, PageUp/PageDown, Home/End  or  j/k, Space/b

tmux - 'Ctrl-b' means: hold Ctrl, press b, release, then the next key:
  Ctrl-b Left/Right or Ctrl-b o   switch pane      Ctrl-b d  detach (keeps running)
  Ctrl-b [ then PageUp/arrows     scroll shell pane (q exits scroll mode)

Mouse: click a pane to focus, wheel scrolls the guide and shell scrollback
(when launched inside your own tmux, needs 'set -g mouse on' in your config).
"""


class HelpScreen(ModalScreen):
    BINDINGS = [
        Binding("escape", "cancel", "Close"),
        Binding("q", "cancel", show=False),
        Binding("question_mark", "cancel", show=False),
    ]

    def compose(self) -> ComposeResult:
        with VerticalScroll(id="help-box"):
            yield Label(HELP_TEXT, markup=False)

    def action_cancel(self) -> None:
        self.dismiss()


class CKALabApp(App):
    TITLE = "CKA Labs"

    CSS = """
    TabbedContent { height: 1fr; }
    Markdown { padding: 0 1; }
    Log { padding: 0 1; }
    #lab-list-box, #confirm-box, #help-box {
        width: 70; height: auto; max-height: 80%;
        margin: 2 4; padding: 1 2;
        border: solid $primary; background: $surface;
    }
    """

    BINDINGS = [
        Binding("n", "next_lab", "Next"),
        Binding("p", "prev_lab", "Prev"),
        Binding("s", "start_lab", "Start"),
        Binding("v", "verify_lab", "Verify"),
        Binding("t", "teardown_lab", "Teardown"),
        Binding("o", "solve_lab", "Solve"),
        Binding("L", "show_lab_list", "Labs"),
        Binding("q", "quit_tui", "Quit"),
        Binding("question_mark", "help", "Help"),
        Binding("1", "tab('readme')", "README", show=False),
        Binding("2", "tab('solution')", "SOLUTION", show=False),
        Binding("3", "tab('output')", "OUTPUT", show=False),
        # app-level scroll keys act on the ACTIVE tab's scroll widget, so the
        # user never has to Tab-focus a specific widget first
        Binding("up", "scroll('up')", show=False),
        Binding("down", "scroll('down')", show=False),
        Binding("pageup", "scroll('pageup')", show=False),
        Binding("pagedown", "scroll('pagedown')", show=False),
        Binding("home", "scroll('home')", show=False),
        Binding("end", "scroll('end')", show=False),
        Binding("j", "scroll('down')", show=False),
        Binding("k", "scroll('up')", show=False),
        Binding("space", "scroll('pagedown')", show=False),
        Binding("b", "scroll('pageup')", show=False),
    ]

    current_lab: reactive[int] = reactive(0)

    def __init__(self) -> None:
        super().__init__()
        self._verify_task = None

    def compose(self) -> ComposeResult:
        yield Header()
        with TabbedContent(id="tabs"):
            with TabPane("README", id="readme"):
                with VerticalScroll(id="scroll-readme"):
                    yield Markdown(id="md-readme")
            with TabPane("SOLUTION", id="solution"):
                with VerticalScroll(id="scroll-solution"):
                    yield Markdown(id="md-solution")
            with TabPane("OUTPUT", id="output"):
                yield Log(id="output-log", highlight=True)
        yield Footer()

    def on_mount(self) -> None:
        self.current_lab = load_state() if LAB_DIRS else 0
        self._refresh_header()
        self.set_interval(5, self._refresh_header)
        self._focus_scroller()

    def watch_current_lab(self, new: int) -> None:
        if not LAB_DIRS:
            return
        self._load_lab(new)
        save_state(new)
        self._refresh_header()

    def _read(self, path: pathlib.Path) -> str:
        try:
            return path.read_text()
        except OSError:
            return f"*missing {path.name}*"

    def _load_lab(self, n: int) -> None:
        tip = (
            f"> **TUI shortcuts for this lab:** press `s` to run "
            f"`make lab-{n:02d}` (start), `v` to verify, `t` to tear down, "
            f"`?` for all keys. Any `make ...` command below can still be "
            f"typed in the left pane.\n\n"
        )
        self.query_one("#md-readme", Markdown).update(
            tip + self._read(LAB_DIRS[n] / "README.md")
        )
        self.query_one("#md-solution", Markdown).update(
            self._read(LAB_DIRS[n] / "SOLUTION.md")
        )
        self.query_one("#scroll-readme", VerticalScroll).scroll_to(y=0)
        self.query_one("#scroll-solution", VerticalScroll).scroll_to(y=0)
        self.query_one("#output-log", Log).scroll_to(y=0)
        self.query_one(TabbedContent).active = "readme"
        self._focus_scroller()

    def _active_scroller(self):
        active = self.query_one(TabbedContent).active
        if active == "output":
            return self.query_one("#output-log", Log)
        return self.query_one(f"#scroll-{active}", VerticalScroll)

    def _focus_scroller(self) -> None:
        try:
            self._active_scroller().focus()
        except Exception:
            pass

    @on(TabbedContent.TabActivated)
    def _on_tab_activated(self, event: TabbedContent.TabActivated) -> None:
        self._focus_scroller()

    def action_scroll(self, direction: str) -> None:
        try:
            scroller = self._active_scroller()
        except Exception:
            return
        {
            "up": scroller.scroll_up,
            "down": scroller.scroll_down,
            "pageup": scroller.scroll_page_up,
            "pagedown": scroller.scroll_page_down,
            "home": scroller.scroll_home,
            "end": scroller.scroll_end,
        }[direction]()

    def _refresh_header(self) -> None:
        if not LAB_DIRS:
            self.sub_title = "no labs found"
            return
        done = len(completed_labs())
        self.sub_title = (
            f"Lab {self.current_lab:02d} - {lab_title(self.current_lab)}"
            f" | {done}/{len(LAB_DIRS)} complete"
        )

    def action_next_lab(self) -> None:
        self.current_lab = min(self.current_lab + 1, len(LAB_DIRS) - 1)

    def action_prev_lab(self) -> None:
        self.current_lab = max(self.current_lab - 1, 0)

    def action_tab(self, pane_id: str) -> None:
        self.query_one(TabbedContent).active = pane_id

    def action_start_lab(self) -> None:
        send_to_shell(f"make lab-{self.current_lab:02d}")

    async def action_verify_lab(self) -> None:
        n = self.current_lab
        send_to_shell(f"make verify-{n:02d}")
        self.query_one(TabbedContent).active = "output"
        log = self.query_one("#output-log", Log)
        if self._verify_task is not None and not self._verify_task.done():
            self._verify_task.cancel()
        log.clear()
        log.write_line(f"--- Running verify for lab {n:02d} ---")
        self._verify_task = asyncio.create_task(self._run_verify(n, log))

    async def _run_verify(self, n: int, log: Log) -> None:
        try:
            proc = await asyncio.create_subprocess_exec(
                "bash",
                str(LAB_DIRS[n] / "verify.sh"),
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.STDOUT,
                cwd=str(REPO_ROOT),
            )
            async for line in proc.stdout:
                log.write_line(line.decode(errors="replace").rstrip())
            rc = await proc.wait()
            log.write_line(f"--- verify exited {rc} ---")
        except asyncio.CancelledError:
            log.write_line("--- verify cancelled ---")
            raise
        self._refresh_header()

    def action_teardown_lab(self) -> None:
        send_to_shell(f"make teardown-{self.current_lab:02d}")

    def action_solve_lab(self) -> None:
        self.push_screen(
            ConfirmScreen(
                f"Run reference solution for lab {self.current_lab:02d}?",
                lambda: send_to_shell(f"make solve-{self.current_lab:02d}"),
            )
        )

    def action_show_lab_list(self) -> None:
        def on_dismiss(idx) -> None:
            if idx is not None:
                self.current_lab = idx

        self.push_screen(
            LabListScreen(self.current_lab, completed_labs()),
            callback=on_dismiss,
        )

    def action_help(self) -> None:
        self.push_screen(HelpScreen())

    def action_quit_tui(self) -> None:
        # The wrapper command in cka-tui.sh also kills this target on exit;
        # doing it here too makes quit immediate (double-kill is harmless).
        if KILL_TARGET and KILL_CMD:
            _tmux(KILL_CMD, "-t", KILL_TARGET)
        self.exit()


if __name__ == "__main__":
    CKALabApp().run()
