# rex-ports

A [Rex](https://www.superlogical.com/rex) plugin that lists the TCP ports your Rex panes listen on and jumps to the pane you pick. It checks every session, so you can find the server on `:5173` without remembering which tab started it.

![The Go to Port picker filtered to four dev servers](screenshot.png)

## Requirements

- Rex server 0.1.0-preview.21 or later, for command palette prompts (`rex.ui`). The terminal `ports` method arrived in preview.20.

## Install

Clone the repo into your Rex config folder:

```sh
git clone https://github.com/astwys/rex-ports ~/.config/rex/rex-ports
```

Load it from `~/.config/rex/init.lua` and bind a key to the `ports` action:

```lua
require("rex-ports")
rex.bind("ctrl+a>o", "ports")
```

Then run `rex config reload`.

## Usage

Press the key, or pick "Go to Port…" in the command palette. The palette lists each port that a process in a Rex pane listens on, with the pane's location as `session › window › pane` and the process name. Return jumps to the pane. Esc closes the list.

To skip the picker, pass the port:

```sh
rex do ports port=5173
```

## How it works

The plugin calls each Rex terminal's `ports` method, which lists the TCP ports its programs listen on and the process that holds each one. A port bound on both IPv4 and IPv6 shows once.

Ports that Docker or OrbStack publish belong to the VM process, not to a pane, so they never appear.

## License

MIT
