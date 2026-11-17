-- Jump to the pane whose process listens on a TCP port, across all sessions.
-- Lists them in an fzf picker in a floating pane; Enter jumps, Esc just closes.
local terminal = "com.superlogical.terminal"

local function basename(path) return path and path:match("[^/]+$") end

-- every port a Rex pane's programs listen on, across all sessions, sorted by port
local function find()
  local found = {}
  -- other sessions can't be viewed until this stream is attached to them
  rex.call("session.attach_all", { event_scope = "all" })
  for _, s in ipairs(rex.call("session.list").sessions) do
    local view = rex.session.view{ session_id = s.session_id }
    for _, w in ipairs(view and view.windows or {}) do
      for _, layer in ipairs(w.layers) do
        for _, b in ipairs(layer.blocks) do
          -- ponytail: ignores truncated replies; read the blob by id if a pane ever holds that many ports
          local r = b.creator_name == terminal
            and rex.call("block.method", { session_id = s.session_id, block_id = b.block_id, method = "ports" })
          if r and r.ports then
            local procs, seen = {}, {}
            for _, p in ipairs(r.processes or {}) do procs[p.pid] = p end
            for _, p in ipairs(r.ports) do
              -- one row per port, though IPv4 and IPv6 each report it
              if p.protocol == "tcp" and not seen[p.port] then
                seen[p.port] = true
                local proc = procs[p.pid] or {}
                found[#found + 1] = {
                  port = p.port,
                  name = basename(proc.script or proc.argv0 or proc.name) or "?",
                  pane = {
                    session_id = s.session_id, window_id = w.window_id, block_id = b.block_id,
                    where = table.concat({ s.label or "?", w.label or "?", b.label or "?" }, " › "),
                  },
                }
              end
            end
          end
        end
      end
    end
  end
  table.sort(found, function(a, b) return a.port < b.port end)
  return found
end

local function go(pane)
  rex.session.focus_block{ session_id = pane.session_id, block_id = pane.block_id }
  rex.client.queue("session.select", { session_id = pane.session_id, window_id = pane.window_id })
end

rex.action{
  name     = "ports",
  title    = "Go to Port…",
  keywords = "port server listen localhost dev",
  args     = { port = "integer?" },
  run      = function(ctx, args)
    local found = find()
    if args.port then
      for _, f in ipairs(found) do
        if f.port == args.port then return go(f.pane) end
      end
      error("nothing in a Rex pane listens on :" .. args.port, 0)
    end
    if #found == 0 then error("no Rex pane is listening on a port", 0) end

    local cmd = {
      "sh", "-c",
      'printf "%s\\n" "$@" | fzf --reverse --prompt "port> " --delimiter "\\t" --with-nth 2.. '
        .. '--bind "enter:become(rex -C ' .. ctx.client_id .. ' do ports port={1})"',
      "sh",
    }
    for _, f in ipairs(found) do
      cmd[#cmd + 1] = string.format("%d\t:%-5d  %-24s  %s", f.port, f.port, f.name, f.pane.where)
    end
    local _, err = rex.session.new_layer{
      bounds = { 0.2, 0.25, 0.6, 0.5 },
      focus  = true,
      layout = rex.layout.block{ flavor = terminal .. ".shell", options = { command = cmd } },
    }
    if err ~= nil then error(err, 0) end
  end,
}
