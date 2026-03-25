# hammerspoon-files

Configs for the Hammerspoon macOS window-manager and automation framework http://www.hammerspoon.org

## Install

Clone directly to `$HOME/.hammerspoon`:

```bash
git clone git@github.com:ryan-williams/hammerspoon-files.git "$HOME"/.hammerspoon
```

Alternatively, clone this repo to some other path:

```bash
git clone git@github.com:ryan-williams/hammerspoon-files.git
REPO="$PWD"/hammerspoon-files
```

and either "source" this repository's `init.lua` from the default `"$HOME"/.hammerspoon/init.lua` location (cf. [#579](https://github.com/Hammerspoon/hammerspoon/issues/579)):

```bash
mkdir -p "$HOME"/.hammerspoon
cat >>"$HOME"/.hammerspoon/init.lua  <<EOF
package.path = "$REPO/?.lua;"..package.path
require('init')
EOF
```

or use the method from [#582](https://github.com/Hammerspoon/hammerspoon/pull/582):

```bash
defaults write org.hammerspoon.Hammerspoon MJConfigFile "$REPO/init.lua"
```

## Unicode Text Expander

[`unicode.lua`](unicode.lua) provides quick insertion of unicode characters anywhere (terminals, browsers, editors). Type a trigger sequence starting with `;`, and it auto-replaces with the corresponding unicode character.

Toggle debug mode with `ctrl-shift-u` (logs keystrokes to HS console).

### Arrows

| Trigger | Output | Description |
|---------|--------|-------------|
| `;r` | → | right arrow |
| `;l` | ← | left arrow |
| `;u` | ↑ | up arrow |
| `;d` | ↓ | down arrow |
| `;lr` | ↔ | left-right arrow |
| `;R` | ⇒ | double right arrow |
| `;L` | ⇐ | double left arrow |
| `;D` | ⇔ | double left-right arrow |
| `;lR` | ⟹ | long double right arrow |
| `;lL` | ⟸ | long double left arrow |
| `;lD` | ⟺ | long left-right double arrow |
| `;ll` | ⟷ | long left-right arrow |
| `;rl` | ⇄ | right over left arrow |

### Math / Comparison

| Trigger | Output | Description |
|---------|--------|-------------|
| `;~` | ≈ | almost equal |
| `;!` | ≠ | not equal |
| `;<` | ≤ | less than or equal |
| `;>` | ≥ | greater than or equal |
| `;+` | ± | plus-minus |
| `;8` | ∞ | infinity |
| `;o` | ° | degree |
| `;m` | μ | mu |
| `;v` | √ | square root |
| `;x` | × | multiplication |
| `;/` | ÷ | division |

### Modifier Keys

| Trigger | Output | Description |
|---------|--------|-------------|
| `;cmd` | ⌘ | command |
| `;opt` | ⌥ | option |
| `;ctl` | ⌃ | control |
| `;shf` | ⇧ | shift |
| `;tab` | ⇥ | tab |
| `;ret` | ⏎ | return |
| `;bsp` | ⌫ | backspace |
| `;del` | ⌦ | delete |
| `;esc` | ⎋ | escape |

### Common Symbols

| Trigger | Output | Description |
|---------|--------|-------------|
| `;.` | … | ellipsis |
| `;-` | — | em dash |
| `;n` | – | en dash |
| `;b` | • | bullet |
| `;y` | ✓ | check mark |
| `;X` | ✗ | x mark |

### Prefix Matching

Single-char triggers (`;r`, `;~`) fire immediately. Triggers that are prefixes of longer ones (e.g. `;l` → `;lr`, `;ll`) wait 300ms — if you keep typing it matches the longer trigger, otherwise the short one fires.
