local RS      = game:GetService("RunService")
local UIS     = game:GetService("UserInputService")
local Players = game:GetService("Players")
local SG      = game:GetService("StarterGui")

local RAPI = {}

local _fs = "F".."i".."r".."e".."S".."e".."r".."v".."e".."r"
local _is = "I".."n".."v".."o".."k".."e".."S".."e".."r".."v".."e".."r"

-- Add missing RAPI.kill function
function RAPI.kill(reason)
    warn("[RAPI] Kill triggered:", reason)
    return
end

-- Add missing RAPI.log_call function
function RAPI.log_call(message, data)
    print("[RAPI Log]", message, data and tostring(data) or "")
end

function RAPI.call_remote(r, ...)
    if typeof(r) ~= "Instance" then return end
    local c = r.ClassName
    if c == "RemoteEvent"   then return r[_fs](r, ...)
    elseif c == "RemoteFunction" then return r[_is](r, ...) end
end

function RAPI.stealth_hook(r, cb)
    if typeof(r) ~= "Instance" then return end
    local fn =
        r:IsA("RemoteEvent")    and r[_fs]
     or r:IsA("RemoteFunction") and r[_is]
     or nil
    return fn and RAPI.hook_fn(fn, function(self, ...) return cb(self, ...) end)
end

function RAPI.thread(fn)               return task.spawn(fn) end
function RAPI.delay(t, fn)             return task.delay(t, fn) end
function RAPI.loop(dt, fn)             return RAPI.thread(function() while true do fn(); task.wait(dt) end end) end
function RAPI.render(fn)               return RS.RenderStepped:Connect(fn) end
function RAPI.heartbeat(fn)            return RS.Heartbeat:Connect(fn) end
function RAPI.stepped(fn)              return RS.Stepped:Connect(fn) end
function RAPI.once(sig, fn)            local c; c = sig:Connect(function(... ) c:Disconnect(); fn(...) end); return c end
function RAPI.bind_key(k, fn)          return UIS.InputBegan:Connect(function(i, g) if not g and i.KeyCode == k then fn() end end) end

-- SynX‑style run_on_thread
function RAPI.run_on_thread(fn, tid, ...)
    assert(type(fn) == "function", "run_on_thread expects a function")
    local args = {...}
    if tid ~= nil and type(tid) ~= "number" then
        table.insert(args, 1, tid)
        tid = nil
    end
    task.spawn(function(...)
        local old
        if tid and setthreadidentity and getthreadidentity then
            old = getthreadidentity(); pcall(setthreadidentity, tid)
        end
        local ok, err = pcall(fn, ...)
        if not ok then warn("[RAPI.run_on_thread] " .. tostring(err)) end
        if old then pcall(setthreadidentity, old) end
    end, table.unpack(args))
end

function RAPI.protect_gui(g)
    if syn and syn.protect_gui then syn.protect_gui(g)
    elseif gethui then g.Parent = gethui()
    else g.Parent = game.CoreGui end
    return g
end

function RAPI.new_window(name, size, pos)
    local sg = Instance.new("ScreenGui")
    sg.Name, sg.ResetOnSpawn = name, false
    RAPI.protect_gui(sg)
    local f = Instance.new("Frame", sg)
    f.Size, f.Position = size or UDim2.fromOffset(300, 200), pos or UDim2.fromOffset(60, 60)
    f.BackgroundColor3, f.BorderSizePixel = Color3.fromRGB(30, 30, 30), 0
    return sg, f
end

function RAPI.check_closure_depth(func)
	local depth = {
		upvalueCount = 0,
		constantCount = 0
	}
	if typeof(func) ~= "function" then return depth end

	local i = 1
	while true do
		local name, _ = debug.getupvalue(func, i)
		if not name then break end
		depth.upvalueCount += 1
		i += 1
	end

	local ok, constants = pcall(debug.getconstants, func)
	if ok and typeof(constants) == "table" then
		depth.constantCount = #constants
	end

	return depth
end

local function safe_enum_upvalues(func)
	local success, result = pcall(function()
		local upvalues = {}
		local i = 1
		while true do
			local name, value = debug.getupvalue(func, i)
			if not name then break end
			upvalues[i] = {
				index = i,
				name = name,
				value = value
			}
			i += 1
		end
		return upvalues
	end)
	
	if success then
		return result
	else
		warn("[RAPI.safe_enum_upvalues] Failed to enumerate upvalues:", result)
		return nil
	end
end

function RAPI.safe_enum_constants(func)
	local success, constants = pcall(debug.getconstants, func)
	if not success then
		warn("[RAPI.safe_enum_constants] Failed to get constants:", constants)
		return {}
	end

	local output = {}
	for i, v in ipairs(constants) do
		local typ = typeof(v)
		local entry = {
			index = i,
			type = typ,
			value = v,
			isInstance = typ == "Instance",
			isEnum = typ == "EnumItem",
			isString = typ == "string",
			isNumber = typ == "number",
			isBool = typ == "boolean",
			stringValue = typ == "Instance" and v:GetFullName() or tostring(v)
		}

		-- Optional heuristic tags
		if entry.isNumber then
			local num = v
			entry.isDamageLike = num > 0 and num <= 500
			entry.isMultiplier = num > 0 and num <= 2
			entry.isVectorMagnitude = num >= 50 and num <= 5000
		end

		table.insert(output, entry)
	end

	return output
end

function RAPI.inspect_closure(func, tag)
	local info = {
		upvalues = {},
		constants = {}
	}

	pcall(function()
		local i = 1
		while true do
			local name, val = debug.getupvalue(func, i)
			if not name then break end
			table.insert(info.upvalues, {
				index = i,
				name = name,
				type = typeof(val),
				value = typeof(val) == "Instance" and val:GetFullName() or val
			})
			i += 1
		end
	end)

	info.constants = RAPI.safe_enum_constants(func)

	local patternTiers = {
		critical = { "kick", "ban", "shutdown", "report", "crash" },
		warning = { "breakjoints", "destroy", "fireserver", "teleport" }
	}

	for _, const in ipairs(info.constants) do
		local valueStr = tostring(const.value):lower()

		for tier, patterns in pairs(patternTiers) do
			for _, pattern in ipairs(patterns) do
				if valueStr:find(pattern) then
					local msg = ("[RAPI %s] Matched: \"%s\" via \"%s\""):format(tier:upper(), valueStr, pattern)

					pcall(function()
						RAPI.log_call(msg, {
							tier = tier,
							triggeredBy = tag or "Unknown"
						})
					end)

					if tier == "critical" then
						RAPI.kill("Detected critical constant: " .. valueStr)
						return
					end
				end
			end
		end
	end

	pcall(function()
		RAPI.log_call("[Closure Inspector]" .. (tag and (" [" .. tag .. "]") or ""), {
			upvalueCount = #info.upvalues,
			constantCount = #info.constants
		})
	end)

	return info
end

-- Fixed variable declaration
local fnHooks, mtHooks = {}, {}

function RAPI.hook_fn(orig, repl)
    if fnHooks[orig] then return fnHooks[orig] end
    local h = hookfunction(orig, repl)
    fnHooks[orig] = h
    return h
end

function RAPI.hook_mt(obj, member, new)
    local mt = getrawmetatable(obj)
    if not mt then return end
    setreadonly(mt, false)
    if not mtHooks[member] then
        mtHooks[member] = mt[member]
        mt[member] = new
    end
    setreadonly(mt, true)
    return mtHooks[member]
end

function getrawfunction(class, method)
    local ok, inst = pcall(Instance.new, class)
    if ok and inst and typeof(inst[method]) == "function" then
        return inst[method]
    end
end

function RAPI.safe_hook(targetFunc, newFunc)
    local info = RAPI.check_closure_depth(targetFunc)
    if info.upvalueCount > 200 then
        warn("[RAPI.safe_hook] Too many upvalues in target function:", info.upvalueCount)
        return targetFunc
    end

    if not islclosure(targetFunc) then
        warn("[RAPI.safe_hook] Target is not a Lua closure. Aborting hook.")
        return targetFunc
    end

    return hookfunction(targetFunc, newcclosure(newFunc))
end

function RAPI.hook_namecall(callback)
    if RAPI.__ncHooked then return end
    RAPI.__ncHooked = true

    -- 1) use executor's hookmetamethod if present
    if hookmetamethod then
        local old
        old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
            local m  = getnamecallmethod()
            local ok, res = pcall(callback, self, m, ...)
            if ok and res ~= nil then return res end
            return old(self, ...)
        end))
        return old
    end

    -- 2) raw metatable fallback
    local mt = getrawmetatable(game)
    if not mt then
        warn("[RAPI] cannot hook __namecall: metatable locked")
        return
    end
    setreadonly(mt, false)
    local orig = rawget(mt, "__namecall") or function(self, ...) return self[getnamecallmethod()](self, ...) end
    mt.__namecall = newcclosure(function(self, ...)
        local m = getnamecallmethod()
        local ok, res = pcall(callback, self, m, ...)
        if ok and res ~= nil then return res end
        return orig(self, ...)
    end)
    setreadonly(mt, true)
    return orig
end

function RAPI.monitor_stack(limit)
    limit = limit or 150
    local depth = 0

    while debug.getinfo(depth + 1) do
        depth += 1
        if depth > limit then
            warn(("[RAPI.monitor_stack] Stack depth exceeded safe limit (%d > %d)"):format(depth, limit))
            return false
        end
    end

    return true
end

function RAPI.wrap_safe(func, limit)
    return function(...)
        if not RAPI.monitor_stack(limit) then
            return warn("[RAPI.wrap_safe] Aborted: stack overflow risk.")
        end
        return func(...)
    end
end

function RAPI.safe(f,...)             local ok,r=pcall(f,...);if not ok then warn(r)end;return ok,r end
function RAPI.retry(n,w,f,...)        for i=1,n do local ok,r=pcall(f,...);if ok then return r end;task.wait(w)end end
function RAPI.random_string(l)        local t={}for i=1,l do t[i]=string.char(math.random(97,122))end;return table.concat(t) end
function RAPI.get_player(q)           for _,p in ipairs(Players:GetPlayers())do if p.Name:lower():find(q:lower())then return p end end end

local function split(p)               local t={}for s in p:gmatch("[^%.]+")do t[#t+1]=s end return t end
function RAPI.wait_for(p)             local cur=game;for _,seg in ipairs(split(p))do cur=cur:WaitForChild(seg)end;return cur end
function RAPI.fire_remote(r, ...)
    return RAPI.safe(function(...)
        return RAPI.call_remote(r, ...)
    end, ...)
end

function RAPI.loop_toggle(flag,dt,f)  return RAPI.thread(function()while flag()do f();task.wait(dt)end end) end
function RAPI.notif(t,d)              pcall(SG.SetCore,SG,"SendNotification",{Title="RAPI",Text=t,Duration=d or 3}) end

local _getactors = rawget(_G, "getactors") or getactors

function RAPI.actors()                return _getactors and _getactors() or {} end
function RAPI.for_actors(f)           for _, a in ipairs(RAPI.actors()) do RAPI.thread(function() f(a) end) end end
function RAPI.actor_wait(n)           while true do for _, a in ipairs(RAPI.actors()) do if a.Name == n then return a end end task.wait() end end
function RAPI.run_on_actor(n, f)      local a = workspace:FindFirstChild(n) or Instance.new("Actor", workspace) a.Name = n return RAPI.thread(function() f(a) end) end

function RAPI.bind_actor(name, on_init, on_remove)
    local function bind(a)
        if a:GetAttribute("__RAPI_BOUND") then return end
        a:SetAttribute("__RAPI_BOUND", true)
        RAPI.thread(function() on_init(a) end)
        a.Destroying:Connect(function()
            if on_remove then pcall(on_remove, a) end
            RAPI.thread(function() bind(RAPI.actor_wait(name)) end)
        end)
    end
    local a = workspace:FindFirstChild(name)
    if not a then a = Instance.new("Actor") a.Name = name a.Parent = workspace end
    bind(a)
end

function RAPI.actor_clear(n)
    local a = workspace:FindFirstChild(n)
    if a and a:IsA("Actor") then for _, c in ipairs(a:GetChildren()) do c:Destroy() end end
end

function RAPI.actor_draw_box(n, s, c)
    local a = workspace:FindFirstChild(n) or Instance.new("Actor", workspace)
    a.Name = n
    local p = Instance.new("Part")
    p.Anchored = true
    p.CanCollide = false
    p.Size = s or Vector3.new(4, 4, 4)
    p.Color = c or Color3.fromRGB(0, 170, 255)
    p.CFrame = workspace.CurrentCamera.CFrame + Vector3.new(0, 5, 0)
    p.Parent = a
    return p
end

function RAPI.actor_context(n)
    local a = workspace:FindFirstChild(n) or Instance.new("Actor", workspace)
    a.Name = n
    return setmetatable({actor = a}, {
        __index = function(_, k)
            local fn = RAPI[k]
            if type(fn) == "function" then
                return function(_, ...) return fn(...) end
            end
        end
    })
end

function RAPI.actor_remote_hook(n, r, cb)
    local a = workspace:FindFirstChild(n)
    if not a then return end
    for _, e in ipairs(a:GetDescendants()) do
        if e:IsA("RemoteEvent") and e.Name == r then
            return RAPI.stealth_hook(e, cb)
        end
    end
end

function RAPI.actor_debug(n, cfg)
    cfg = cfg or {}
    local a = workspace:FindFirstChild(n) or Instance.new("Actor", workspace)
    a.Name = n
    if cfg.draw then RAPI.actor_draw_box(n, cfg.size, cfg.color) end
    if cfg.heartbeat_log then RAPI.heartbeat(function() print("[HB]", n) end) end
    if cfg.render_log then RAPI.render(function() print("[RD]", n) end) end
    if cfg.on_tick then RAPI.loop(cfg.interval or 1, function() cfg.on_tick(a) end) end
    return a
end

do
    local M = {add = {}, rem = {}}
    RAPI.ActorMgr = M
    local function bind(a)
        if a:GetAttribute("__RAPI_TRACKED") then return end
        a:SetAttribute("__RAPI_TRACKED", true)
        for _, cb in ipairs(M.add) do pcall(cb, a) end
        a.Destroying:Connect(function()
            for _, cb in ipairs(M.rem) do pcall(cb, a) end
            RAPI.thread(function() bind(RAPI.actor_wait(a.Name)) end)
        end)
    end
    function M.on_added(cb)   table.insert(M.add, cb) end
    function M.on_removed(cb) table.insert(M.rem, cb) end
    for _, a in ipairs(workspace:GetChildren()) do if a:IsA("Actor") then bind(a) end end
    workspace.ChildAdded:Connect(function(o) if o:IsA("Actor") then bind(o) end end)
end

-- REST-like command registry
local commandRegistry = {}

function RAPI.register(name, fn)
    assert(type(name) == "string", "Command name must be a string")
    assert(type(fn) == "function", "Command must be a function")
    commandRegistry[name] = fn
end

function RAPI.call(name, ...)
    local fn = commandRegistry[name]
    if not fn then
        warn("[RAPI] No command registered with name:", name)
        return
    end
    local ok, result = pcall(fn, ...)
    if not ok then
        warn("[RAPI] Error in command '"..name.."':", result)
    end
    return result
end

function RAPI.list()
    local keys = {}
    for k in pairs(commandRegistry) do
        table.insert(keys, k)
    end
    return keys
end

-- Hook .Kick to block forced disconnects
function RAPI.anti_kick()
    local lp = Players.LocalPlayer
    if lp and lp.Kick then
        RAPI.hook_fn(lp.Kick, function(self, ...)
            warn("[RAPI] Kick attempt blocked:", ...)
            return
        end)
    end
end

-- Patch error prompt (StarterGui:SetCore)
function RAPI.block_errors()
    RAPI.hook_fn(SG.SetCore, function(self, core, ...)
        if core == "SendNotification" or core == "ChatMakeSystemMessage" then
            return self(self, core, ...)
        end
        warn("[RAPI] Blocked SetCore call:", core)
    end)
end

-- Neutralize specific suspicious signals (e.g., ErrorPrompt, RemoteEvents)
function RAPI.block_remotes(names)
    local matched = {}
    for _, obj in ipairs(getgc(true)) do
        if typeof(obj) == "Instance"
            and (obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction")) then

            for _, target in ipairs(names) do
                if obj.Name:lower():find(target:lower()) then
                    -- stealth‑hook: hides FireServer / InvokeServer strings
                    RAPI.stealth_hook(obj, function()
                        warn("[RAPI] Blocked remote:", obj.Name)
                        return nil   -- swallow call / return nothing
                    end)
                    table.insert(matched, obj.Name)
                end
            end
        end
    end
    return matched
end

-- Universal crash guard (protects calls)
function RAPI.guard(fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok then
            warn("[RAPI] Guarded error:", err)
        end
    end
end

-- Fake HumanoidRootPart position (for anti-tp detection)
function RAPI.fake_position(offset)
    local lp = Players.LocalPlayer
    local char = lp.Character or lp.CharacterAdded:Wait()
    local hrp = char:WaitForChild("HumanoidRootPart")
    local fake = Instance.new("Part")
    fake.Name = "FakeHRP"
    fake.Size = Vector3.new(2,2,1)
    fake.Anchored = true
    fake.Transparency = 1
    fake.CanCollide = false
    fake.Parent = workspace

    RAPI.render(function()
        fake.CFrame = hrp.CFrame * CFrame.new(offset or Vector3.new(0, 30, 0))
    end)

    return fake
end

-- Patch known client loggers (usually used to report tools, movement, or remotes)
function RAPI.block_loggers()
    for _, func in ipairs(getgc(true)) do
        if typeof(func) == "function" and islclosure(func) then
            local info = debug.getinfo(func)
            if info.name and info.name:lower():find("log") then
                RAPI.hook_fn(func, function(...) return end)
                warn("[RAPI] Logger neutralized:", info.name)
            end
        end
    end
end

-- Fake key/mouse input for checks like "did player click" or "was input sent"
function RAPI.fake_input(key, delay)
    delay = delay or 0.2
    task.spawn(function()
        local input = Instance.new("BindableEvent")
        input.Name = "FakeInput"
        input.Parent = workspace
        firetouchinterest(input, Players.LocalPlayer.Character, 0)
        wait(delay)
        firetouchinterest(input, Players.LocalPlayer.Character, 1)
        input:Destroy()
    end)
end

-- Auto rejoin after kick
function RAPI.reconnect_after_kick()
    RAPI.anti_kick()
    game:GetService("GuiService").ErrorMessageChanged:Connect(function(msg)
        warn("[RAPI] Kick message:", msg)
        RAPI.notif("Rejoining...", 3)
        task.wait(2)
        local tp = game:GetService("TeleportService")
        local pid = game.PlaceId
        local uid = game.JobId
        tp:TeleportToPlaceInstance(pid, uid, Players.LocalPlayer)
    end)
end

-- auto‑block anti‑cheat remotes
local _acDefault = {"kick", "ban", "report", "cheat", "ac", "security"}
local _acBlocked = {}

function RAPI.auto_block_ac(patterns)
    patterns = patterns or _acDefault

    local function matches(name)
        name = name:lower()
        for _, p in ipairs(patterns) do
            if name:find(p) then return true end
        end
    end

    local function hook(remote)
        if _acBlocked[remote] then return end
        _acBlocked[remote] = true
        RAPI.stealth_hook(remote, function()
            warn("[RAPI] Blocked AC remote:", remote.Name)
            return nil
        end)
    end

    for _, d in ipairs(game:GetDescendants()) do
        if (d:IsA("RemoteEvent") or d:IsA("RemoteFunction")) and matches(d.Name) then
            hook(d)
        end
    end

    game.DescendantAdded:Connect(function(d)
        if (d:IsA("RemoteEvent") or d:IsA("RemoteFunction")) and matches(d.Name) then
            hook(d)
        end
    end)

    return _acBlocked
end

do
    local _logFilter = {}
    local _callLog = {}

    --- Tag + capture a remote call
    function RAPI.log_call(tag, remote, method, args)
        local remoteName = remote and remote.Name or "UnknownRemote"

        table.insert(_callLog, {
            tag = tag,
            remote = remote,
            method = method,
            args = args,
            time = os.clock()
        })

        if _logFilter[tag] ~= false then
            print(string.format("[RAPI:Log] [%s] %s -> %s", tag, method or "UnknownMethod", remoteName))
        end
    end

    --- Set filter per tag (false = suppress)
    function RAPI.set_log_filter(tag, value)
        _logFilter[tag] = value
    end

    --- Dump all calls
    function RAPI.dump_calls()
        return _callLog
    end
end

-- Add missing helper functions for the debug utilities
local function tableToString(tbl)
    if type(tbl) ~= "table" then return tostring(tbl) end
    local result = "{"
    for i, v in ipairs(tbl) do
        if i > 1 then result = result .. ", " end
        result = result .. tostring(v)
    end
    return result .. "}"
end

local function tableToHexString(tbl)
    if type(tbl) ~= "table" then return tostring(tbl) end
    local result = "{"
    for i, v in ipairs(tbl) do
        if i > 1 then result = result .. ", " end
        if type(v) == "string" then
            local hex = ""
            for j = 1, #v do
                hex = hex .. string.format("%02X", string.byte(v, j))
            end
            result = result .. "0x" .. hex
        else
            result = result .. tostring(v)
        end
    end
    return result .. "}"
end

-- Initialize debug utilities if not present
if not _G.DebugUtilities then
    _G.DebugUtilities = {
        log = function(tag, message)
            print("[" .. tag .. "]", message)
        end,
        ignoredRemotes = {},
        blockedRemotes = {}
    }
end

local function buildActionItems(instance, meta, contentLabel)
    local items = {
        {
            text = "Copy Path",
            action = function()
                local path = instance and instance:GetFullName() or "N/A"
                if setclipboard then
                    setclipboard(path)
                    _G.DebugUtilities.log("Copied", "Path copied to clipboard: " .. path)
                else
                    _G.DebugUtilities.log("Error", "setclipboard not available")
                    print("Path:", path)
                end
            end
        },
        {
            text = "Copy Instance",
            action = function()
                if instance then
                    local instanceCode = "game:GetService(\"" .. instance.Parent.ClassName .. "\"):WaitForChild(\"" .. instance.Name .. "\")"
                    if setclipboard then
                        setclipboard(instanceCode)
                        _G.DebugUtilities.log("Copied", "Instance reference copied to clipboard")
                    else
                        print("Instance Reference:", instanceCode)
                    end
                end
            end
        }
    }
    return items
end

function RAPI.spoof_velocity(v)
    v = v or Vector3.zero
    return RAPI.heartbeat(function()
        local c = Players.LocalPlayer.Character
        local hrp = c and c:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.AssemblyLinearVelocity = v
            pcall(function() hrp.Velocity = v end)
        end
    end)
end

local _pingHook
function RAPI.spoof_ping(ms)
    if _pingHook then return end
    local s = game:GetService("Stats"):WaitForChild("Network"):WaitForChild("ServerStatsItem")
    for _,itm in ipairs(s:GetChildren()) do
        if itm.Name:lower():find("ping") and itm.GetValue then
            _pingHook = RAPI.hook_fn(itm.GetValue,function() return ms end)
            break
        end
    end
end

function RAPI.keys(tbl)
    local out = {}
    for k in pairs(tbl) do
        table.insert(out, k)
    end
    return out
end

do
    local _velSpoof   = false
    local _velVector  = Vector3.zero
    local _velHook

    local function ensureHook()
        if _velHook then return end
        _velHook = RAPI.heartbeat(function()
            if not _velSpoof then return end
            local c   = Players.LocalPlayer.Character
            local hrp = c and c:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.AssemblyLinearVelocity = _velVector
                pcall(function() hrp.Velocity = _velVector end)
            end
        end)
    end

    function RAPI.toggle_velocity_spoof(key, vec)
        key = key or Enum.KeyCode.V
        if vec then _velVector = vec end
        ensureHook()

        local flagKey = "__RAPI_VELKEY_" .. key.Value
        if not _G[flagKey] then
            _G[flagKey] = true
            RAPI.bind_key(key, function()
                _velSpoof = not _velSpoof
                RAPI.notif("Velocity spoof: " .. tostring(_velSpoof), 2)
            end)
        end
    end

    function RAPI.set_velocity_vector(vec)
        _velVector = vec
        RAPI.notif("Velocity spoof vector set to: " .. tostring(vec), 2)
    end
end

do
    local _fly  = false              
    local _spd  = 2                    
    local _loop = nil                 
    local _keyBinds = {              
        up     = false,
        down   = false,
        fwd    = false,
        back   = false,
        left   = false,
        right  = false
    }


    function RAPI.fly_control(speed, toggleKey)
        _spd       = speed     or 2
        toggleKey  = toggleKey or Enum.KeyCode.F

        local Players   = game:GetService("Players")
        local UIS       = game:GetService("UserInputService")
        local LocalPlayer = Players.LocalPlayer

        UIS.InputBegan:Connect(function(i, g)
            if g then return end
            local k = i.KeyCode
            if k == Enum.KeyCode.Space       then _keyBinds.up     = true end
            if k == Enum.KeyCode.LeftControl then _keyBinds.down   = true end
            if k == Enum.KeyCode.W           then _keyBinds.fwd    = true end
            if k == Enum.KeyCode.S           then _keyBinds.back   = true end
            if k == Enum.KeyCode.A           then _keyBinds.left   = true end
            if k == Enum.KeyCode.D           then _keyBinds.right  = true end
        end)
        UIS.InputEnded:Connect(function(i)
            local k = i.KeyCode
            if k == Enum.KeyCode.Space       then _keyBinds.up     = false end
            if k == Enum.KeyCode.LeftControl then _keyBinds.down   = false end
            if k == Enum.KeyCode.W           then _keyBinds.fwd    = false end
            if k == Enum.KeyCode.S           then _keyBinds.back   = false end
            if k == Enum.KeyCode.A           then _keyBinds.left   = false end
            if k == Enum.KeyCode.D           then _keyBinds.right  = false end
        end)

        -- toggle key (bind once per KeyCode)
        local flag = "__RAPI_FLY_TOGGLE_" .. toggleKey.Value
        if not _G[flag] then
            _G[flag] = true
            RAPI.bind_key(toggleKey, function()
                _fly = not _fly
                RAPI.notif("Fly control: " .. tostring(_fly), 2)
            end)
        end

        -- Movement loop (create only once)
        if not _loop then
            _loop = RAPI.heartbeat(function(dt)
                if not _fly then return end

                local char = LocalPlayer.Character
                local hrp  = char and char:FindFirstChild("HumanoidRootPart")
                local hum  = char and char:FindFirstChildWhichIsA("Humanoid")
                if not hrp then return end

                local cf   = hrp.CFrame
                local dir  = Vector3.zero

                if _keyBinds.up    then dir += Vector3.new(0,  1, 0) end
                if _keyBinds.down  then dir += Vector3.new(0, -1, 0) end
                if _keyBinds.fwd   then dir += cf.LookVector       end
                if _keyBinds.back  then dir -= cf.LookVector       end
                if _keyBinds.left  then dir -= cf.RightVector      end
                if _keyBinds.right then dir += cf.RightVector      end

                if dir.Magnitude > 0 then
                    hrp.CFrame = cf + dir.Unit * _spd
                end

                if hum then
                    pcall(function()
                        hum:ChangeState(Enum.HumanoidStateType.Running)
                    end)
                end
            end)
        end
    end
end

do
    local _on      = false
    local _step    = 0.4        
    local _bindKey = Enum.KeyCode.Z
    local _conn

    function RAPI.speed_bypass(step, key)
        _step    = step or _step
        _bindKey = key  or _bindKey

        -- toggle key (bind once)
        local flag = "__RAPI_SPEED_" .. _bindKey.Value
        if not _G[flag] then
            _G[flag] = true
            RAPI.bind_key(_bindKey, function()
                _on = not _on
                RAPI.notif("Speed‑bypass: " .. tostring(_on), 2)
                print("[RAPI] speed‑bypass", _on and "ON" or "OFF")
            end)
        end

        if _conn then return end
        _conn = RAPI.render(function(dt)
            if not _on then return end
            local lp   = game:GetService("Players").LocalPlayer
            local char = lp.Character
            local hrp  = char and char:FindFirstChild("HumanoidRootPart")
            local hum  = char and char:FindFirstChildOfClass("Humanoid")
            if not hrp or not hum then return end

            -- keep official WalkSpeed legit
            hum.WalkSpeed = 16

            -- direction = camera facing on XZ
            local moveDir = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
            if moveDir.Magnitude > 0 then
                hrp.CFrame = hrp.CFrame + moveDir.Unit * _step
            end
        end)
    end
end

do
    local _on      = false
    local _bindKey = Enum.KeyCode.L
    local _maid    = nil

    local function startBypass()
        if _maid then return end
        _maid = RAPI.heartbeat(function()
            -- 1) Nuke Movement & Jump modifiers every frame
            local knit     = getrenv()._G and getrenv()._G.KnitClient or nil
            if knit and knit.Controllers then
                local sprint = knit.Controllers.SprintController
                local jump   = knit.Controllers.JumpHeightController
                if sprint then pcall(function() sprint:getMovementStatusModifier():clear() end) end
                if jump   then pcall(function() jump:getJumpModifier():clear()           end) end
            end
        end)

        for _, fn in ipairs(getgc(true)) do
            if typeof(fn) == "table" and rawget(fn, "SendToServer") and rawget(fn, "Name") == "GroundHit" then
                if not rawget(fn, "__RAPI_PATCHED") then
                    rawset(fn, "__RAPI_PATCHED", true)
                    RAPI.hook_fn(fn.SendToServer, function() end)
                end
            end
        end

        RAPI.loop(3, function()
            local lp = game:GetService("Players").LocalPlayer
            local char = lp.Character
            if not char then return end
            char:SetAttribute("StunnedUntilTime", -1)
            char:SetAttribute("SnaredUntilTime",  -1)
            char:SetAttribute("Locked",           0)
        end)

        print("[RAPI] Stun & fall‑damage bypass ON")
        RAPI.notif("No‑stun / No‑fall ON", 2)
    end

    local function stopBypass()
        if _maid then
            _maid:Disconnect()
            _maid = nil
        end
        print("[RAPI] Stun & fall‑damage bypass OFF")
        RAPI.notif("No‑stun / No‑fall OFF", 2)
    end

    -- public toggle
    function RAPI.no_stun_no_fall(key)
        if key then _bindKey = key end
        local flag = "__RAPI_NOSTUN_".._bindKey.Value
        if not _G[flag] then
            _G[flag] = true
            RAPI.bind_key(_bindKey, function()
                _on = not _on
                if _on then startBypass() else stopBypass() end
            end)
        end
        _on = true
        startBypass()
    end
end

do
    local _god         = false
    local _hookedHum   = {}
    local _maintainHB  = nil

    local function maintainHealth(h)
        if _maintainHB then return end
        _maintainHB = RAPI.heartbeat(function()
            if _god and h and h.Parent and h.Parent:IsDescendantOf(workspace) then
                h.MaxHealth = math.huge
                h.Health    = math.huge
            end
        end)
    end

    local function patchHumanoid(h)
        if _hookedHum[h] then return end
        _hookedHum[h] = true

        h.MaxHealth = math.huge
        h.Health = math.huge

        -- Block TakeDamage()
        RAPI.hook_fn(h.TakeDamage, function() end)

        -- Block BreakJoints() from model
        local model = h:FindFirstAncestorWhichIsA("Model")
        if model and typeof(model.BreakJoints) == "function" then
            RAPI.hook_fn(model.BreakJoints, function() end)
        end

        -- Prevent fall damage logic
        h.StateChanged:Connect(function(_, new)
            if _god and new == Enum.HumanoidStateType.Freefall then
                h:SetStateEnabled(Enum.HumanoidStateType.Landed, false)
                task.delay(0.15, function()
                    if h then
                        h:SetStateEnabled(Enum.HumanoidStateType.Landed, true)
                    end
                end)
            end
        end)

        -- Handle lava / killpart touch
        local root = h.Parent and h.Parent:FindFirstChild("HumanoidRootPart")
        if root and not root:FindFirstChild("__RAPI_KILLBLOCK") then
            local tag = Instance.new("BoolValue")
            tag.Name = "__RAPI_KILLBLOCK"
            tag.Parent = root

            root.Touched:Connect(function(part)
                if not _god then return end
                local name = (part.Name or ""):lower()
                if name:find("lava") or name:find("kill") or name:find("damage") then
                    h.Health = math.huge
                    h.MaxHealth = math.huge
                end
            end)
        end

        maintainHealth(h)
    end

    local function onCharacter(char)
        local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid")
        if hum then patchHumanoid(hum) end
    end

    --- Toggle invincibility
    --- @param key Enum.KeyCode|nil
    function RAPI.god_mode(key)
        key = key or Enum.KeyCode.K
        local plr = game:GetService("Players").LocalPlayer

        if plr.Character then onCharacter(plr.Character) end
        plr.CharacterAdded:Connect(onCharacter)

        local flag = "__RAPI_GOD_TOGGLE_" .. key.Value
        if not _G[flag] then
            _G[flag] = true
            RAPI.bind_key(key, function()
                _god = not _god
                RAPI.notif("God-mode: " .. tostring(_god), 2)
            end)
        end

        _god = true
        RAPI.notif("God-mode: true", 2)
    end
end

function RAPI.init()
    -- optional startup stuff here
    RAPI.log_call("RAPI initialized.")
end

-- Optional: initialize parallel execution flag (must be last!)
if setfflag then
    pcall(setfflag, "DebugRunParallelLuaOnMainThread", "true")
end

_G.RAPI = RAPI
return RAPI
