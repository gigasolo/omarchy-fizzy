#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail() { echo "qml.test: $*" >&2; exit 1; }
must() { grep -q -- "$1" "$2" || fail "$3"; }
must_not() { if grep -q -- "$1" "$2"; then fail "$3"; fi; }

must_not 'bash", "-c", "printf' "$root/Service.qml" "wl-copy must not use bash -c"
must '"wl-copy", "--"' "$root/Service.qml" "copy must exec wl-copy as argv"
must 'omarchy-agent-prompt' "$root/Service.qml" "agent handoff must use omarchy-agent-prompt"
must '"which", "fizzy"' "$root/Service.qml" "refresh must probe which fizzy first"
must 'function probeCurrent' "$root/Service.qml" "killed probes must ignore stale onExited by generation"
must 'function tryRecoverWhich' "$root/Service.qml" "recovery which must wait for killed children to exit"
must 'function peekCurrent' "$root/Service.qml" "killed peeks must ignore stale onExited by generation"
must 'function tryStartPendingPeek' "$root/Service.qml" "replacement peek must wait for killed children to exit"
must_not 'function drainPendingPeek' "$root/Service.qml" "drainPendingPeek started the next card before the killed child exited"
must_not '_probeKilled' "$root/Service.qml" "a one-tick killed flag loses the race with async terminate"
must_not 'Qt.callLater' "$root/Service.qml" "callLater must not clear the kill guard before terminate finishes"
must 'id: peekWatchdog' "$root/Service.qml" "peek processes need a watchdog"
must 'id: actionWatchdog' "$root/Service.qml" "read processes need a watchdog"
must 'panelOpen' "$root/Service.qml" "peek must know whether the panel is open"
must 'peekCachePut' "$root/Service.qml" "peek cache must be bounded in Model.js"
must 'SplitParser' "$root/Service.qml" "CLI output must be bounded"
must_not 'StdioCollector' "$root/Service.qml" "StdioCollector retains unbounded CLI output"
must 'property bool panelOpen' "$root/Service.qml" "Service must expose panelOpen"
must 'service.panelOpen = opened' "$root/Panel.qml" "Panel must tell Service when it is open"
must 'running: root.opened' "$root/Panel.qml" "UI timers must not run while the panel is closed"
must 'running: root.opened && (root.needsSetup || service.awaitingProfile !== "")' "$root/Panel.qml" "setup poll must not run while the panel is closed"
must 'running: root.opened && root.rotatingPhrases' "$root/Panel.qml" "phrase timer must not run while the panel is closed"
must 'text === "m") root.markSelectedRead' "$root/Panel.qml" "m marks the peeked or selected item"
must 'text === "M") root.markAllRead' "$root/Panel.qml" "M is gated by the panel helper"
must 'text: "OLDER"' "$root/Panel.qml" "already-seen pings are Older, not Recent"
must 'function cycleStateFilter' "$root/Panel.qml" "left/right and h/l must switch New / older"
must_not 'markCardRead' "$root/Panel.qml" "tray must not call card mark-read"
must_not 'markCardRead' "$root/NotificationRow.qml" "rows must not call card mark-read"
must_not 'card mark-read' "$root/Service.qml" "Service must not run fizzy card mark-read"
must_not 'PREVIOUS' "$root/Panel.qml" "Previous label was replaced by Older"
must 'enterHandled' "$root/Panel.qml" "Enter must not also toggle peek"
must 'function togglePeek' "$root/Panel.qml" "Space peeks the selected card"
must 'function peekTarget' "$root/Panel.qml" "peek actions follow the peeked notification"
must '"--limit", String(root.maxItems)' "$root/Service.qml" "notification list must pass --limit matching maxItems"
must_not 'notification", "list", "--json"]' "$root/Service.qml" "notification list must not fetch unbounded JSON"
must 'fizzyArgs' "$root/Service.qml" "every Fizzy command must go through fizzyArgs"
must '"auth", "list"' "$root/Service.qml" "refresh must discover CLI profiles"
must_not '"auth", "switch"' "$root/Service.qml" "Service must not call fizzy auth switch"
must 'profileFilter' "$root/Panel.qml" "the tray can filter to one profile"
must 'function cycleProfileFilter' "$root/Panel.qml" "[ ] must cycle All / account"
must 'text === "\["' "$root/Panel.qml" "[ cycles profiles"
must 'text === "\]"' "$root/Panel.qml" "] cycles profiles"
must 'function jumpAccountDigit' "$root/Panel.qml" "1-9 jump accounts like workspaces"
must 'AccountsView' "$root/Panel.qml" "accounts overlay should live in AccountsView.qml"
must 'accountNameForProfile' "$root/Service.qml" "refresh must skip identity show when the account name is already known"
must_not 'parseIdentity' "$root/Service.qml" "identity JSON must be parsed once via interpretIdentity"
must 'beginAddProfile' "$root/Service.qml" "add account must launch fizzy setup --profile"
must '"auth", "logout"' "$root/Service.qml" "remove account must call fizzy auth logout"
must 'commentListLimit' "$root/Service.qml" "comment list limit must live in Model.js"
must '"--limit", String(Model.commentListLimit())' "$root/Service.qml" "comment list must pass --limit from Model"
must 'function markPeekItemRead' "$root/Service.qml" "peekItem must follow mark-read so the check hides"
must 'HelpView' "$root/Panel.qml" "shortcuts overlay should live in HelpView.qml"
must 'PeekView' "$root/Panel.qml" "card peek should live in PeekView.qml"
must 'NotificationRow' "$root/Panel.qml" "notification rows should live in NotificationRow.qml"
must_not 'FIZZY_TOKEN' "$root/Service.qml" "Service must not mention tokens"
must_not 'FIZZY_TOKEN' "$root/Panel.qml" "Panel must not mention tokens"
must_not 'FIZZY_TOKEN' "$root/AccountsView.qml" "Accounts overlay must not mention tokens"
must_not 'comment create' "$root/Service.qml" "do not add a comment composer"
must_not 'boards search' "$root/Service.qml" "do not add boards search"

python3 - "$root" <<'EOF'
import re, sys
from pathlib import Path
root = Path(sys.argv[1])
missing = []
for path in sorted(root.glob("*.qml")):
    src = path.read_text()
    for m in re.finditer(r"\b(Text|Label|TextEdit|StyledText)\s*\{", src):
        i, depth = m.end(), 1
        while i < len(src) and depth:
            depth += (src[i] == "{") - (src[i] == "}")
            i += 1
        block = src[m.end():i]
        if "textFormat:" not in block:
            line = src[:m.start()].count("\n") + 1
            missing.append(f"{path.name}:{line}")
if missing:
    raise SystemExit("missing textFormat: " + ", ".join(missing))

def brace_body(src, open_idx):
    depth = 0
    for i in range(open_idx, len(src)):
        if src[i] == "{":
            depth += 1
        elif src[i] == "}":
            depth -= 1
            if depth == 0:
                return src[open_idx:i + 1]
    raise SystemExit("unclosed brace")

def function_body(src, name):
    m = re.search(r"function\s+" + re.escape(name) + r"\s*\(", src)
    if not m:
        raise SystemExit("missing function " + name)
    start = src.find("{", m.end())
    return brace_body(src, start)

def on_triggered(src, timer_id):
    m = re.search(r"id:\s*" + re.escape(timer_id) + r"\b", src)
    if not m:
        raise SystemExit("missing " + timer_id)
    t = re.search(r"onTriggered:\s*\{", src[m.end():])
    if not t:
        raise SystemExit("missing onTriggered for " + timer_id)
    return brace_body(src[m.end():], t.end() - 1)

def on_exited_bodies(src):
    bodies = []
    for m in re.finditer(r"onExited:\s*function\s*\([^)]*\)\s*\{", src):
        bodies.append(brace_body(src, src.find("{", m.end() - 1)))
    return bodies

panel = (root / "Panel.qml").read_text()
service = (root / "Service.qml").read_text()
row = re.search(r"NotificationRow\s*\{", panel)
if not row:
    raise SystemExit("missing NotificationRow instantiation")
row_body = brace_body(panel, panel.find("{", row.end() - 1))
if re.search(r"\bservice\s*:\s*service\b", row_body):
    raise SystemExit("NotificationRow is a Repeater delegate; service: service self-binds to undefined")
if re.search(r"\bpointerGate\s*:\s*pointerGate\b", row_body):
    raise SystemExit("NotificationRow is a Repeater delegate; pointerGate: pointerGate self-binds to undefined")
if "root.service" not in row_body and "fizzyService" not in row_body:
    raise SystemExit("NotificationRow must bind service from the panel scope, not its own property")
for name in ("togglePeek", "loadPeek", "beginPeek", "closePeek"):
    src = panel if name == "togglePeek" else service
    body = function_body(src, name)
    if re.search(r"\bmarkRead\b", body) or re.search(r"\bopenNotification\b", body):
        raise SystemExit(name + " must not mark a notification read")
for name in ("markSelectedRead", "markAllRead", "activateSelection", "togglePeek", "copySelected", "sendSelectedToAgent", "cycleProfileFilter"):
    body = function_body(panel, name)
    if "overlayOpen" not in body and not ("showingHelp" in body and "showingAccounts" in body):
        raise SystemExit(name + " must ignore keys while an overlay is open")
jump = function_body(panel, "jumpAccountDigit")
if "showingHelp" not in jump:
    raise SystemExit("jumpAccountDigit must ignore keys while help is open")
if "overlayOpen" in jump:
    raise SystemExit("jumpAccountDigit must still work in the accounts overlay")

watchdog = on_triggered(service, "peekWatchdog")
stopped = watchdog.find("stopProcess")
gen = watchdog.find("beginPeekGen")
abandoned = watchdog.find("_peekAbandoned = true")
if gen < 0 or stopped < 0 or gen > stopped:
    raise SystemExit("peekWatchdog must bump peek gen before stopProcess")
if abandoned < 0 or abandoned > stopped:
    raise SystemExit("peekWatchdog must set _peekAbandoned before stopProcess")
if "_pendingPeekItem = null" not in watchdog:
    raise SystemExit("peekWatchdog must drop the pending peek before stopProcess")
if "loadPeek" in watchdog:
    raise SystemExit("peekWatchdog must not loadPeek before the killed child has exited")
if watchdog.find("tryStartPendingPeek") < 0 or watchdog.find("tryStartPendingPeek") < watchdog.find("failedPeek"):
    raise SystemExit("peekWatchdog must tryStartPendingPeek only after failing the hung card")

begin = function_body(service, "beginPeek")
if begin.find("peekWatchdog.stop()") < 0:
    raise SystemExit("beginPeek cache-hit / no-card must stop peekWatchdog")
if "beginPeekGen" not in begin:
    raise SystemExit("beginPeek must bump peek gen so a late child cannot write this card")
load = function_body(service, "loadPeek")
if "peekWatchdog.restart()" not in load:
    raise SystemExit("loadPeek must restart peekWatchdog when deferring")
if "peekWait" not in load:
    raise SystemExit("loadPeek must wait for peekLive / running children")
pending = function_body(service, "tryStartPendingPeek")
if "peekWait" not in pending:
    raise SystemExit("tryStartPendingPeek must wait for killed children like tryRecoverWhich")

if "markPeekItemRead" not in function_body(service, "setReadOptimistically"):
    raise SystemExit("setReadOptimistically must update peekItem via markPeekItemRead")
if "markPeekItemRead" not in function_body(service, "markAllRead"):
    raise SystemExit("markAllRead must update peekItem via markPeekItemRead")
if "_peekUnreadBeforeAll" not in function_body(service, "markAllRead"):
    raise SystemExit("markAllRead must snapshot peek unread before read-all")
if "readPending" not in function_body(service, "markRead"):
    raise SystemExit("markRead must dedupe via readPending")
refresh = function_body(service, "finishRefresh")
if "syncPeekItemFromNotifications" not in refresh:
    raise SystemExit("finishRefresh must copy unread state onto peekItem")
sync = function_body(service, "syncPeekItemFromNotifications")
if "unread !== true" not in sync:
    raise SystemExit("syncPeekItemFromNotifications must not unhide the peek check after a successful mark-read")
finish = function_body(service, "finishRead")
if "restoreNotification" not in finish:
    raise SystemExit("finishRead must restore peekItem on a failed notification read")
if "markPeekItemRead" not in finish:
    raise SystemExit("finishRead success must keep peekItem read so a concurrent refresh cannot unhide the check")
if "_peekUnreadBeforeAll" not in finish:
    raise SystemExit("failed read-all must restore the peeked row's prior unread state")

start_next = function_body(service, "startNextProfile")
known = re.search(r"accountNameForProfile\(\s*profiles\b", start_next)
if not known:
    raise SystemExit("startNextProfile must skip identity show using committed profiles")
list_at = start_next.find("startNotificationList")
ident_at = start_next.find("startIdentity")
if list_at < 0 or list_at < known.start():
    raise SystemExit("startNextProfile must list notifications after a known account name")
if ident_at < 0 or ident_at < known.start():
    raise SystemExit("startNextProfile must consult known account names before identity show")
if "return" not in start_next[known.start():ident_at]:
    raise SystemExit("startNextProfile must return before identity show on the known-name path")
if list_at > ident_at:
    raise SystemExit("startNextProfile must list notifications on the known-name path before identity show")

apply_ident = function_body(service, "applyProfileIdentity")
if "parseIdentity" in apply_ident:
    raise SystemExit("applyProfileIdentity must not parse identity JSON a second time")
if not re.search(r"interpretIdentity\([^)]*accountId", apply_ident):
    raise SystemExit("applyProfileIdentity must pass the profile account id into interpretIdentity")

if not re.search(
    r"property var accountRows:\s*showingAccounts\s*\?\s*Model\.accountSwitcherRows\s*\([^)]*\)\s*:\s*Model\.emptyList\s*\(\s*\)",
    panel,
    re.S,
):
    raise SystemExit("accountRows must build switcher rows only while the overlay is open")

help_bind = re.search(r"property var shortcutHelp:\s*\{", panel)
if not help_bind:
    raise SystemExit("missing shortcutHelp")
help_body = brace_body(panel, help_bind.end() - 1)
if help_body.find("emptyList") < 0 or help_body.find("showingHelp") < 0:
    raise SystemExit("shortcutHelp must use a stable empty model while help is closed")
if "Move" in help_body and help_body.find("emptyList") > help_body.find("Move"):
    raise SystemExit("shortcutHelp must return a stable empty model before building rows")
if "filterNotifications" in help_body:
    raise SystemExit("shortcutHelp must not re-filter notifications to count unread")
empty_at = help_body.find("emptyList")
after_empty = help_body[empty_at:]
if not re.search(r"unreadCount\([^)]*profileFilter", after_empty):
    raise SystemExit("shortcutHelp must count unread for the selected profile")

accounts = (root / "AccountsView.qml").read_text()
rep = re.search(r"Repeater\s*\{", accounts)
if not rep:
    raise SystemExit("missing AccountsView Repeater")
rep_body = brace_body(accounts, accounts.find("{", rep.end() - 1))
model = re.search(r"\bmodel:\s*(.+)", rep_body)
if not model:
    raise SystemExit("AccountsView Repeater missing model")
expr = model.group(1)
if "[]" in expr:
    raise SystemExit("AccountsView Repeater must not use [] as a model")
if not re.search(r"(?:addingAccount|confirmingRemove)[^:\n]*\?[^:\n]*emptyList", expr):
    raise SystemExit("AccountsView Repeater add/remove path must use Model.emptyList()")

props = [
    ("_authOutput", "stdout"),
    ("_authError", "stderr"),
    ("_logoutOutput", "stdout"),
    ("_logoutError", "stderr"),
    ("_identityOutput", "stdout"),
    ("_identityError", "stderr"),
    ("_listOutput", "stdout"),
    ("_listError", "stderr"),
    ("_readOutput", "stdout"),
    ("_readError", "stderr"),
    ("_cardShowOutput", "stdout"),
    ("_cardShowError", "stderr"),
    ("_commentOutput", "stdout"),
    ("_commentError", "stderr"),
]
seen = set()
for body in on_exited_bodies(service):
    if "parseCard" in body or "parseComments" in body or "cachePeek" in body:
        if "peekCurrent" not in body:
            raise SystemExit("peek onExited must ignore stale children via peekCurrent")
        gate = body.find("peekCurrent")
        for name in ("parseCard", "parseComments", "cachePeek"):
            at = body.find(name)
            if at >= 0 and gate > at:
                raise SystemExit("peek onExited must check peekCurrent before " + name)
    for prop, var in props:
        needle = "var %s = root.%s" % (var, prop)
        if needle not in body:
            continue
        seen.add(prop)
        clear = 'root.%s = ""' % prop
        if body.find(clear) < 0 or body.find(needle) > body.find(clear):
            raise SystemExit(prop + " must be snapshotted before it is cleared")
missing = [prop for prop, _ in props if prop not in seen]
if missing:
    raise SystemExit("missing consume-and-clear for " + ", ".join(missing))
EOF
