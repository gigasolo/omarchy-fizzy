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
must 'running: root.opened && root.needsSetup' "$root/Panel.qml" "setup poll must not run while the panel is closed"
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
must '--limit", "8"' "$root/Service.qml" "comment list must pass --limit 8"
must 'HelpView' "$root/Panel.qml" "shortcuts overlay should live in HelpView.qml"
must 'PeekView' "$root/Panel.qml" "card peek should live in PeekView.qml"
must 'NotificationRow' "$root/Panel.qml" "notification rows should live in NotificationRow.qml"
must_not 'FIZZY_TOKEN' "$root/Service.qml" "Service must not mention tokens"
must_not 'FIZZY_TOKEN' "$root/Panel.qml" "Panel must not mention tokens"
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
EOF
