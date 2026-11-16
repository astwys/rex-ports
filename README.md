# rex-ports

A [Rex](https://www.superlogical.com/rex) plugin that lists the TCP ports your Rex panes listen on and jumps to the pane you pick. It checks every session, so you can find the server on `:5173` without remembering which tab started it.

![The Go to Port picker filtered to four dev servers](screenshot.png)

## Requirements

- Rex, tested with 0.1.0-preview.19
- the `rex` CLI on your `PATH`, because fzf runs `rex do ports` to jump
- [fzf](https://github.com/junegunn/fzf)
- `lsof` and `ps`, which macOS ships with

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

Press the key, or pick "Go to Port…" in the command palette. A floating pane lists each port that a process in a Rex pane listens on, with the process name and the pane's location as `session › window › pane`. Enter jumps to the pane. Esc closes the picker.

To skip the picker, pass the port:

```sh
rex do ports port=5173
```

## How it works

`lsof` lists the listening TCP sockets and their process IDs. The plugin calls each Rex terminal's `process` method to get the PID of its shell. For each listener, it follows the parent process IDs until it reaches one of those shells. The picker leaves out listeners that reach none.

Ports that Docker or OrbStack publish belong to the VM process, not to a pane, so they never appear.

## License

MIT
