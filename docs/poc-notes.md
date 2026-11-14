# Proof of concept — desktop-layer strips (Task 2)

Build: `scripts/build.sh && ./build/Clothesline` (at commit of Task 2; later replaced by the real app).

| Check | Result |
|---|---|
| A. Four-finger spread / F11: strips visible, hover & click respond | pending (needs the user) |
| B. Desktop revealed: drag image into a chat app, windows come back, drop succeeds | pending (needs the user) |
| C. ⌃⌥L summons over windows; drag into chat behind works; Esc sends back | pending (needs the user) |
| D. Not in Dock / ⌘Tab, present on every Space | pending (needs the user) |

Automated check from the agent: build OK, process stays running. `screencapture` is blocked (no Screen Recording permission for the terminal), so visual checks need the user.

Decision: pending. Until checks run, summon is kept as a convenience and drag does not auto-summon.
