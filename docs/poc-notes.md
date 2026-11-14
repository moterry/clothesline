# Proof of concept — desktop-layer strips (Task 2)

Checked by the user in the hands-on session on 2026-11-14, with the real app (`~/Applications/晾衣绳.app`).

| Check | Result |
|---|---|
| A. Four-finger spread / F11: strips visible, hover & click respond | pass |
| B. Desktop revealed: drag a screenshot into a chat app, windows come back, drop succeeds, screenshot stays on the line | pass |
| C. ⌃⌥L summons over windows; ⌃⌥L / Esc sends them back | pass |
| D. Not in Dock / ⌘Tab | pass |

Decision: dragging works straight from desktop mode, so drags do **not** auto-summon (`AppModel.summonOnDrag = false`). ⌃⌥L stays as a convenience for grabbing a screenshot without revealing the desktop.

Found in the session: dropping on Lethe did nothing — on macOS the drop's item provider cannot be read back as a file URL. Fixed by sinking the URLs recorded when our own drag starts (`AppModel.dropOnLethe`), verified end to end by `--selftest-lethe`.
