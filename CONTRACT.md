# hdr-toggle — shared contract

macOS 26.6.1 (Tahoe), Apple M1, Raycast 2.x extension + a small compiled CLI.
This file is the single source of truth for every module. Do not change it
without saying so; other agents code against it.

## Why this exists

macOS has no public API to toggle HDR. The private `MonitorPanel` framework
exposes it:

```
@interface MPDisplay : NSObject
@property(readonly) int displayID;
@property(readonly, nullable) NSString *displayName;
@property(readonly) BOOL isBuiltIn;
@property(readonly) BOOL hasHDRModes;
- (BOOL)preferHDRModes;
- (void)setPreferHDRModes:(BOOL)enabled;
@end

@interface MPDisplayMgr : NSObject
@property(readonly, nullable) NSArray<MPDisplay *> *displays;
- (nullable MPDisplay *)displayWithID:(int)displayID;
@end
```

Verified on the target machine:
- reading and setting both work from a plain unsigned CLI
- no SIP changes, no entitlements, no TCC prompt, no Accessibility grant
- `setPreferHDRModes:` returns immediately; the display settles in ~0.8–1.1 s
- one process invocation costs ~84 ms, most of it dyld startup
- the display is `LG HDR 4K`, displayID 2, `hasHDRModes = true`

Link with:
```
clang -fobjc-arc -O2 -framework Foundation \
  -F/System/Library/PrivateFrameworks -framework MonitorPanel ...
```

## hdrctl — CLI contract

Built from `tools/hdrctl.m`, output `tools/hdrctl`, copied to `assets/hdrctl`.
Universal binary preferred (`-arch arm64 -arch x86_64`), ad-hoc signed.

### `hdrctl list [--json]`

Text: one display per line, tab-separated:
```
<id>\t<name>\t<builtin|external>\t<hdr|no-hdr>\t<on|off>
```

JSON (exactly this shape, no wrapper keys):
```json
[
  { "id": 2, "name": "LG HDR 4K", "builtin": false, "hdrCapable": true, "hdr": true },
  { "id": 1, "name": "Built-in Retina Display", "builtin": true, "hdrCapable": false, "hdr": false }
]
```

### `hdrctl get [selector]`

Prints exactly `on` or `off` plus a newline. Nothing else on stdout.

### `hdrctl set [selector] --value on|off|toggle [--wait <ms>]`

- Applies the preference, then polls `preferHDRModes` until it matches or
  `--wait` expires (default 2000 ms, poll every 50 ms).
- Prints the final state (`on` / `off`) on stdout, newline terminated.
- Exit 0 only if the final state matches the request.

### `hdrctl watch --rules <path>`

Long-running. See "Watcher" below.

### Selector (shared by `get` and `set`)

Exactly one of:
- `--id <n>` — CGDirectDisplayID
- `--name <s>` — case-insensitive exact match on `displayName`
- `--external` — first display with `isBuiltIn == false` and `hasHDRModes == true`

If no selector is given, behave as `--external`.

### Exit codes

| code | meaning |
|---|---|
| 0 | success |
| 1 | usage error |
| 2 | no display matched the selector |
| 3 | display matched but is not HDR-capable |
| 4 | set requested but the display did not reach the requested state |

Errors go to stderr, one line, prefixed `hdrctl: `.

## rules.json

Written by the extension, read by `hdrctl watch`.

Path: `<raycast supportPath>/rules.json`
(e.g. `~/Library/Application Support/com.raycast.macos/extensions/hdr-toggle/rules.json`)

```json
{
  "version": 1,
  "rules": [
    { "display": "LG HDR 4K", "hdr": true }
  ]
}
```

- `display` matches `MPDisplay.displayName` case-insensitively (exact first,
  then a single unambiguous substring match; ambiguity = skip + log).
- `hdr` is the desired state on connect.
- Missing/empty/malformed file: the watcher exits 0 quietly. launchd will
  restart it on the next login or throttle interval; that is acceptable.
- A display already in the desired state is a no-op (this also prevents the
  watcher from reacting to its own HDR change, which itself fires a display
  reconfiguration callback).

## Watcher

`hdrctl watch --rules <path>`:

- Applies rules once at startup, after a 2 s delay (covers login/RunAtLoad).
- Registers `CGDisplayRegisterReconfigurationCallback`.
- On callbacks containing `kCGDisplayAddFlag` or `kCGDisplayEnabledFlag`,
  debounce 1200 ms, then re-read `MPDisplayMgr` and apply matching rules.
- Ignore all other flags. Never call `CGDisplaySetDisplayMode`.
- Block forever on `CFRunLoopRun()`. SIGTERM exits 0.
- Log one line per applied rule to stderr:
  `hdrctl: watch: "LG HDR 4K" -> on`
- Never daemonize; launchd owns the lifecycle.
- Reload `rules.json` on every apply (do not cache across events), so edits
  take effect without restarting the agent.

## LaunchAgent

- Label: `com.hdrtoggle.watch`
- Plist: `~/Library/LaunchAgents/com.hdrtoggle.watch.plist`
- ProgramArguments: `<supportPath>/hdrctl`, `watch`, `--rules`, `<supportPath>/rules.json`
- `RunAtLoad` true, `KeepAlive` true, `ThrottleInterval` 10
- `ProcessType` Background
- `StandardOutPath` and `StandardErrorPath`: `<supportPath>/watcher.log`
- Install: `launchctl bootout gui/<uid> <plist>` (ignore failure), write plist,
  `launchctl bootstrap gui/<uid> <plist>`
- Uninstall: `launchctl bootout gui/<uid> <plist>`, delete plist
- `<uid>` is `process.getuid()`

## Extension modules

| file | owner | responsibility |
|---|---|---|
| `src/lib/hdrctl.ts` | agent B | locate/copy the binary, `list()`, `get()`, `set()` |
| `src/toggle-hdr.ts` | agent B | no-view command |
| `src/lib/agent.ts` | agent C | rules read/write, agent install/remove/status |
| `src/menu-bar.tsx` | agent C | MenuBarExtra |
| `src/hdr-on-connect.tsx` | agent C | view command, per-display rules |

### Binary resolution (`src/lib/hdrctl.ts`)

Raycast gives `environment.assetsPath`. On every call:

1. Source: `path.join(environment.assetsPath, "hdrctl")`.
2. If missing, throw a clear error naming `make` (this is a dev checkout).
3. Destination: `path.join(environment.supportPath, "hdrctl")`.
4. If destination is missing or its sha256 differs from the source, copy and
   `chmod 0o755`.
5. `execFile(destination, args, { timeout: 15000 })`.

Never shell out to a string command; no `exec`, no shell interpolation.

### Exact exports of `src/lib/hdrctl.ts` (agent B owns, agent C imports)

```ts
export type Display = {
  id: number;
  name: string;
  builtin: boolean;
  hdrCapable: boolean;
  hdr: boolean;
};

export type Selector = { id: number } | { name: string } | { external: true };

export class HdrctlError extends Error {
  readonly code: number; // exit code from hdrctl, 1–4
}

/** Copies assets/hdrctl into supportPath when missing or changed, returns path. */
export async function ensureBinary(): Promise<string>;

/** Absolute path to the executable copy in supportPath. Calls ensureBinary first. */
export async function binaryPath(): Promise<string>;

export async function listDisplays(): Promise<Display[]>;

export async function getState(selector?: Selector): Promise<"on" | "off">;

export async function setState(
  selector: Selector | undefined,
  value: "on" | "off" | "toggle",
): Promise<"on" | "off">;

/** Preference-aware: named display if configured, otherwise { external: true }. */
export function targetSelector(): Selector | undefined;

/** Resolves the target to a connected Display, or throws HdrctlError. */
export async function resolveTarget(): Promise<Display>;
```

`targetSelector()` reads `getPreferenceValues<{ displayName?: string }>()` and
returns `{ name }` when non-empty after trimming, otherwise `undefined`
(meaning `--external`).

### Target display

`getPreferenceValues().displayName`, trimmed. Empty means `--external`.
An explicitly named display that is not connected resolves to exit 2, which
the command surfaces as "Display not found" rather than silently falling back.

## Coding rules

- TypeScript strict, no `any` without a comment saying why.
- No new npm dependencies beyond `@raycast/api` and `@raycast/utils`.
- Objective-C: ARC, no third-party headers, no hardcoded display IDs/names.
- Every user-visible failure gets a title and a message that says what to do.
- Do not touch files owned by another agent.
