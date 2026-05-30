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
| `;+`, `;pm` | ± | plus-minus |
| `;inf` | ∞ | infinity |
| `;o`, `;deg` | ° | degree |
| `;m`, `;mu` | μ | mu |
| `;v` | √ | square root |
| `;x` | × | multiplication |
| `;/` | ÷ | division |

### Greek Letters

| Trigger | Output | Description |
|---------|--------|-------------|
| `;a` | α | alpha |
| `;bt` | β | beta (`;b` is bullet) |
| `;g` | γ | gamma |
| `;G` | Γ | capital gamma |
| `;dl` | δ | delta (`;d` is down arrow) |
| `;Dl` | Δ | capital delta (`;D` is ⇔) |
| `;e` | ε | epsilon |
| `;th` | θ | theta |
| `;Th` | Θ | capital theta |
| `;lm` | λ | lambda |
| `;mu` | μ | mu (also `;m`) |
| `;pi` | π | pi (`;p` left unbound) |
| `;PI` | Π | capital pi (product) |
| `;s` | σ | sigma |
| `;S` | Σ | capital sigma (sum) |
| `;ph` | φ | phi |
| `;Ph` | Φ | capital phi |
| `;w` | ω | omega |
| `;W` | Ω | capital omega |

### Fractions

Named to avoid clashing with `;1`/`;2`/... superscript digits.

| Trigger | Output | Description |
|---------|--------|-------------|
| `;hf` | ½ | half |
| `;tr` | ⅓ | third |
| `;tw` | ⅔ | two-thirds |
| `;qt` | ¼ | quarter |
| `;tq` | ¾ | three-quarters |

### Superscript / Subscript Digits

`;0`–`;9` and `;^0`–`;^9` both produce superscripts (the `;^N` form is available in case `;N` is overridden in the future). `;_0`–`;_9` produces subscripts.

| Trigger | Output | | Trigger | Output |
|---------|--------|-|---------|--------|
| `;0`, `;^0` | ⁰ | | `;_0` | ₀ |
| `;1`, `;^1` | ¹ | | `;_1` | ₁ |
| `;2`, `;^2` | ² | | `;_2` | ₂ |
| `;3`, `;^3` | ³ | | `;_3` | ₃ |
| `;4`, `;^4` | ⁴ | | `;_4` | ₄ |
| `;5`, `;^5` | ⁵ | | `;_5` | ₅ |
| `;6`, `;^6` | ⁶ | | `;_6` | ₆ |
| `;7`, `;^7` | ⁷ | | `;_7` | ₇ |
| `;8`, `;^8` | ⁸ | | `;_8` | ₈ |
| `;9`, `;^9` | ⁹ | | `;_9` | ₉ |

### Emoji

| Trigger | Output | Description |
|---------|--------|-------------|
| `;grin` | 😀 | grinning |
| `;grim` | 😬 | grimacing |
| `;think`, `;thnk` | 🤔 | thinking |
| `;laugh` | 😂 | laughing |

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
