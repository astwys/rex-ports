-- Jump to the pane whose process listens on a TCP port, across all sessions.
-- Lists them in an fzf picker in a floating pane; Enter jumps, Esc just closes.
local terminal = "com.superlogical.terminal"

local function lines(argv)
  local r = rex.exec(argv)
  return (r and r.stdout or ""):gmatch("[^\n]+")
end

-- { {port, name, pid}, ... } for every listening TCP socket, one per pid+port
local function listeners()
  local out, seen, pid, name = {}, {}, nil, nil
  for l in lines{ "lsof", "+c0", "-nP", "-iTCP", "-sTCP:LISTEN", "-Fpcn" } do
    local tag, val = l:sub(1, 1), l:sub(2)
    if tag == "p" then pid = tonumber(val)
    elseif tag == "c" then name = val
    elseif tag == "n" then
      local port = tonumber(val:match(":(%d+)$"))
      if port and not seen[pid .. ":" .. port] then
        seen[pid .. ":" .. port] = true
        out[#out + 1] = { port = port, name = name, pid = pid }
      end
    end
  end
  return out
end

-- pid of each terminal's child process -> where that pane lives
local function panes()
  local by_pid = {}
  -- other sessions can't be viewed until this stream is attached to them
  rex.call("session.attach_all", { event_scope = "all" })
  for _, s in ipairs(rex.call("session.list").sessions) do
    local view = rex.session.view{ session_id = s.session_id }
    for _, w in ipairs(view and view.windows or {}) do
      for _, layer in ipairs(w.layers) do
        for _, b in ipairs(layer.blocks) do
          local p = b.creator_name == terminal
            and rex.call("block.method", { session_id = s.session_id, block_id = b.block_id, method = "process" })
          if p and p.child then
            by_pid[p.child.pid] = {
              session_id = s.session_id, window_id = w.window_id, block_id = b.block_id,
              where = table.concat({ s.label or "?", w.label or "?", b.label or "?" }, " › "),
            }
          end
        end
      end
    end
  end
  return by_pid
end

-- listeners that run inside a Rex pane, sorted by port
local function find()
  local parent = {}
  for l in lines{ "ps", "-axo", "pid=,ppid=" } do
    local pid, ppid = l:match("(%d+)%s+(%d+)")
    parent[tonumber(pid)] = tonumber(ppid)
  end
  local by_pid, found = panes(), {}
  for _, ls in ipairs(listeners()) do
    local pid = ls.pid
    -- Docker/OrbStack ports are owned by the VM, not a pane, so they never match
    while pid and pid > 1 and not by_pid[pid] do pid = parent[pid] end
    if by_pid[pid] then
      ls.pane = by_pid[pid]
      found[#found + 1] = ls
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
