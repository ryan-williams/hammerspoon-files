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
