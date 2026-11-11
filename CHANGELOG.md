# HDR Toggle Changelog

## [Dynamic Subtitle] - 2026-11-11

- Toggle HDR now shows the next action and current state in its subtitle
  (`Disable HDR — LG HDR 4K`), refreshed after each toggle and every minute
- Background-refresh runs are guarded so they only update the label, never the display

## [Initial Version] - 2026-11-11

- `hdrctl` CLI: list displays, read HDR state, set/toggle HDR, watch display reconfiguration
- Toggle HDR command with preference-aware display targeting
- HDR Displays menu-bar command with live state
- HDR on Connect view with per-display rules and an opt-in launchd watcher
