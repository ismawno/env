-- Saves the live layout to monitors.lua, activates and verifies it, else restores the old one; paths arrive via env.
local jq = os.getenv("MAD_DISPLAYS_JQ") or "jq"
local layout_file = os.getenv("MAD_DISPLAYS_FILE")
local env_dir = os.getenv("MAD_DISPLAYS_ENV")
local repo_path = os.getenv("MAD_DISPLAYS_REPO_PATH")
local panel = os.getenv("MAD_DISPLAYS_PANEL")

local header = "-- The screens this host knows, rewritten by display-layout-save. Every entry is one hl.monitor spec."

local function sh(value)
  return "'" .. (tostring(value):gsub("'", "'\\''")) .. "'"
end

-- LuaJIT's close() on a pipe reports success whatever the command did, so the status comes back in the output.
local function run(command)
  local pipe = io.popen("{ " .. command .. " ; } 2>&1; printf '\\n__rc=%d' \"$?\"")
  local output, code = pipe:read("*a"):match("^(.*)\n__rc=(%d+)%s*$")
  pipe:close()
  return code == "0", output or ""
end

local function notify(urgency, body)
  os.execute("notify-send -u " .. urgency .. " " .. sh("Display layout") .. " " .. sh(body))
end

local function write(path, text)
  local file, err = io.open(path, "w")
  if not file then return nil, err end
  file:write(text)
  return file:close()
end

-- Every failure past the write puts the old file back, so the session never keeps a layout that did not verify.
local function die(message, previous)
  if previous then
    write(layout_file, previous)
    run("home-manager switch --flake " .. sh(env_dir) .. " -b backup")
    run("hyprctl reload")
    message = message .. "; the previous layout is back"
  end
  notify("critical", message)
  io.stderr:write(message .. "\n")
  os.exit(1)
end

local function query(program)
  local ok, output = run("hyprctl monitors all -j | " .. jq .. " -r " .. sh(program))
  if not ok then die("hyprctl monitors failed: " .. output) end
  return output
end

local function fields(line)
  local out = {}
  for field in (line .. "\t"):gmatch("([^\t]*)\t") do
    out[#out + 1] = field
  end
  return out
end

-- Hyprland reports 120.00100 for a 120Hz mode and prints 2880x1800@120.00Hz in availableModes; both land on "120".
local function refresh(hz)
  return (string.format("%.2f", hz):gsub("0+$", ""):gsub("%.$", ""))
end

local function number(value)
  if value == math.floor(value) then return string.format("%d", value) end
  return (string.format("%.4f", value):gsub("0+$", ""))
end

local function integral(size, scale)
  local logical = size / scale
  return math.abs(logical - math.floor(logical + 0.5)) < 0.001
end

local function load_entries(path)
  local chunk, err = loadfile(path)
  if not chunk then return nil, err end
  local ok, value = pcall(setfenv(chunk, {}))
  if ok then return value end
  return nil, value
end

local function shape_error(entries)
  if type(entries) ~= "table" or #entries == 0 then return "the file does not return a non-empty list" end
  for index, entry in ipairs(entries) do
    if type(entry.output) ~= "string" or entry.output == "" then return "entry " .. index .. " has no output" end
    local where = "entry " .. index .. " (" .. entry.output .. ")"
    if type(entry.mode) ~= "string" or not entry.mode:match("^%d+x%d+@[%d%.]+$") then
      return where .. " has no WxH@R mode"
    end
    if type(entry.position) ~= "string" or not entry.position:match("^%-?%d+x%-?%d+$") then
      return where .. " has no XxY position"
    end
    if type(entry.scale) ~= "number" or entry.scale <= 0 then return where .. " has no scale" end
    if entry.transform ~= nil and type(entry.transform) ~= "number" then
      return where .. " has a non-numeric transform"
    end
  end
end

local function serialise(entries)
  table.sort(entries, function(a, b)
    if (a.output == panel) ~= (b.output == panel) then return a.output == panel end
    return a.output < b.output
  end)
  local lines = { header, "return {" }
  for _, entry in ipairs(entries) do
    lines[#lines + 1] = string.format(
      "  { output = %q, mode = %q, position = %q, scale = %s, transform = %s },",
      entry.output,
      entry.mode,
      entry.position,
      number(entry.scale),
      number(entry.transform or 0)
    )
  end
  lines[#lines + 1] = "}"
  return table.concat(lines, "\n") .. "\n"
end

local function live()
  local modes = {}
  for line in query(".[] | .name as $n | (.availableModes // [])[] | [$n, .] | @tsv"):gmatch("[^\n]+") do
    local row = fields(line)
    local width, height, hz = row[2]:match("^(%d+)x(%d+)@([%d%.]+)Hz$")
    if width then
      modes[row[1]] = modes[row[1]] or {}
      modes[row[1]][width .. "x" .. height .. "@" .. refresh(tonumber(hz))] = true
    end
  end

  local program =
    ".[] | [.name,.description,.width,.height,.refreshRate,.x,.y,.scale,.transform,(.disabled|tostring)] | @tsv"
  local monitors = {}
  for line in query(program):gmatch("[^\n]+") do
    local row = fields(line)
    local monitor = { name = row[1], description = row[2], disabled = row[10] == "true", modes = modes[row[1]] or {} }
    for column, key in ipairs({ "width", "height", "rate", "x", "y", "scale", "transform" }) do
      monitor[key] = tonumber(row[column + 2])
    end
    monitors[#monitors + 1] = monitor
  end
  return monitors
end

-- The external is keyed by description so it comes back on any port; the panel by its own name, which never moves.
local function key_of(monitor)
  if monitor.name == panel then return monitor.name end
  return "desc:" .. monitor.description
end

local function entry_of(monitor)
  local size = monitor.width .. "x" .. monitor.height
  local straight = size .. "@" .. refresh(monitor.rate)
  local turned = monitor.height .. "x" .. monitor.width .. "@" .. refresh(monitor.rate)
  local mode = (monitor.modes[straight] and straight) or (monitor.modes[turned] and turned)
  if not mode then die(monitor.name .. " is running " .. straight .. ", which is not one of the modes it reports") end
  if not integral(monitor.width, monitor.scale) or not integral(monitor.height, monitor.scale) then
    local scale = number(monitor.scale)
    die(monitor.name .. " is at scale " .. scale .. ", which does not divide " .. size .. " into whole logical pixels")
  end
  return {
    output = key_of(monitor),
    mode = mode,
    position = string.format("%dx%d", monitor.x, monitor.y),
    scale = monitor.scale,
    transform = monitor.transform,
  }
end

local function overlap(a, b)
  return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end

local function check_layout(monitors)
  local boxes = {}
  for _, monitor in ipairs(monitors) do
    local w, h = monitor.width / monitor.scale, monitor.height / monitor.scale
    if monitor.transform % 2 == 1 then
      w, h = h, w
    end
    local box = { name = monitor.name, x = monitor.x, y = monitor.y, w = w, h = h }
    for _, other in ipairs(boxes) do
      if overlap(box, other) then
        die(box.name .. " and " .. other.name .. " overlap; move one of them apart before saving")
      end
    end
    boxes[#boxes + 1] = box
  end
end

local function describe(entry)
  return entry.mode .. " at " .. entry.position .. " scale " .. number(entry.scale)
end

if not (layout_file and env_dir and repo_path and panel) then
  die("display-layout-save was built without a layout file to write")
end

if not run("git -C " .. sh(env_dir) .. " ls-files --error-unmatch -- " .. sh(repo_path)) then
  die(repo_path .. " is not tracked by git, so the flake would not see it")
end

local handle = io.open(layout_file, "r")
if not handle then die("cannot read " .. layout_file) end
local previous = handle:read("*a")
handle:close()

local existing, load_error = load_entries(layout_file)
if not existing then die(repo_path .. " does not load as Lua: " .. tostring(load_error)) end

local enabled = {}
for _, monitor in ipairs(live()) do
  if not monitor.disabled then enabled[#enabled + 1] = monitor end
end
if #enabled == 0 then die("Hyprland reports no enabled monitor") end
check_layout(enabled)

-- A screen that is not attached right now keeps the entry it already had; the lid closed keeps the panel's.
local by_key = {}
for _, entry in ipairs(existing) do
  by_key[entry.output] = entry
end
for _, monitor in ipairs(enabled) do
  local entry = entry_of(monitor)
  by_key[entry.output] = entry
end

local merged = {}
for _, entry in pairs(by_key) do
  merged[#merged + 1] = entry
end

local text = serialise(merged)
if text == previous then
  notify("low", "already saved: the live layout is what " .. repo_path .. " says")
  os.exit(0)
end

local temporary = layout_file .. ".new"
local written, write_error = write(temporary, text)
if not written then die("cannot write " .. temporary .. ": " .. tostring(write_error)) end

local function abandon(message)
  os.remove(temporary)
  die(message)
end

local reloaded, reload_error = load_entries(temporary)
if not reloaded then abandon("the file just written does not load as Lua: " .. tostring(reload_error)) end
local bad_shape = shape_error(reloaded)
if bad_shape then abandon("the file just written is malformed: " .. bad_shape) end
local renamed, rename_error = os.rename(temporary, layout_file)
if not renamed then abandon("cannot replace " .. layout_file .. ": " .. tostring(rename_error)) end

local switched, switch_output = run("home-manager switch --flake " .. sh(env_dir) .. " -b backup")
if not switched then die("home-manager switch failed: " .. switch_output:match("([^\n]*)\n*$"), previous) end

local reloaded_ok, reload_output = run("hyprctl reload")
if not reloaded_ok then die("hyprctl reload failed: " .. reload_output, previous) end
os.execute("sleep 1")

-- A clean tree prints nothing at all here, not "no errors".
local _, errors = run("hyprctl configerrors")
local trimmed = errors:match("^%s*(.-)%s*$")
if trimmed ~= "" and not trimmed:match("^[Nn]o errors") then die("hyprctl configerrors: " .. trimmed, previous) end

local saved = {}
for _, entry in ipairs(reloaded) do
  saved[entry.output] = entry
end
for _, monitor in ipairs(live()) do
  if not monitor.disabled then
    local entry, now = saved[key_of(monitor)], entry_of(monitor)
    if not entry then die(monitor.name .. " came back without an entry of its own", previous) end
    if entry.mode ~= now.mode or entry.position ~= now.position or entry.scale ~= now.scale then
      die(monitor.name .. " came back as " .. describe(now) .. ", not " .. describe(entry), previous)
    end
  end
end

notify("normal", "saved to " .. repo_path .. "; review the diff and commit it")
