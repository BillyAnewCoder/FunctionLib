-- force actors to run on the main thread (safer for hooks)
if setfflag then
    pcall(setfflag, "DebugRunParallelLuaOnMainThread", "true")
end

local RS      = game:GetService("RunService")
local UIS     = game:GetService("UserInputService")
local Players = game:GetService("Players")
local SG      = game:GetService("StarterGui")

local RAPI    = {}

function RAPI.thread(f)               return task.spawn(f) end
function RAPI.delay(t,f)              return task.delay(t,f) end
function RAPI.loop(dt,f)              return RAPI.thread(function()while true do f();task.wait(dt)end end) end
function RAPI.render(f)               return RS.RenderStepped:Connect(f) end
function RAPI.heartbeat(f)            return RS.Heartbeat:Connect(f) end
function RAPI.stepped(f)              return RS.Stepped:Connect(f) end

function RAPI.once(s,f)               local c;c=s:Connect(function(... )c:Disconnect();f(...)end);return c end
function RAPI.bind_key(k,f)           return UIS.InputBegan:Connect(function(i,g)if not g and i.KeyCode==k then f()end end) end

function RAPI.protect_gui(g)          if syn and syn.protect_gui then syn.protect_gui(g)elseif gethui then g.Parent=gethui()else g.Parent=game.CoreGui end;return g end
function RAPI.new_window(n,s,p)       local sg=Instance.new("ScreenGui")sg.Name,sg.ResetOnSpawn=n,false;RAPI.protect_gui(sg);local f=Instance.new("Frame",sg)f.Size=s or UDim2.fromOffset(300,200)f.Position=p or UDim2.fromOffset(60,60)f.BackgroundColor3=Color3.fromRGB(30,30,30)f.BorderSizePixel=0;return sg,f end

local fnHooks,mtHooks={}
function RAPI.hook_fn(o,n)            if fnHooks[o] then return fnHooks[o] end;local h=hookfunction(o,n)fnHooks[o]=h;return h end
function RAPI.hook_mt(obj,n,new)      local mt=getrawmetatable(obj)setreadonly(mt,false)if not mtHooks[n] then mtHooks[n]=mt[n]mt[n]=new end;setreadonly(mt,true);return mtHooks[n] end

function RAPI.safe(f,...)             local ok,r=pcall(f,...);if not ok then warn(r)end;return ok,r end
function RAPI.retry(n,w,f,...)        for i=1,n do local ok,r=pcall(f,...);if ok then return r end;task.wait(w)end end
function RAPI.random_string(l)        local t={}for i=1,l do t[i]=string.char(math.random(97,122))end;return table.concat(t) end
function RAPI.get_player(q)           for _,p in ipairs(Players:GetPlayers())do if p.Name:lower():find(q:lower())then return p end end end

local function split(p)               local t={}for s in p:gmatch("[^%.]+")do t[#t+1]=s end return t end
function RAPI.wait_for(p)             local cur=game;for _,seg in ipairs(split(p))do cur=cur:WaitForChild(seg)end;return cur end
function RAPI.fire_remote(r,...)      return RAPI.safe(function(... )if r.ClassName=="RemoteEvent"then r:FireServer(...)else return r:InvokeServer(...)end end,...) end

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
            return RAPI.hook_fn(e.FireServer, function(self, ...) return cb(self, ...) end)
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

-- ██▌ Anti-Cheat Utilities ▌██ --

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
        if typeof(obj) == "Instance" and obj:IsA("RemoteEvent") then
            for _, target in ipairs(names) do
                if obj.Name:lower():find(target:lower()) then
                    local orig = obj.FireServer
                    RAPI.hook_fn(orig, function(self, ...)
                        warn("[RAPI] Blocked remote:", self.Name)
                        return
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

-- ██▌ Advanced Anti-Cheat Tools ▌██ --

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

----------------------------------------------------------------
--  RAPI – anti‑cheat extras (paste below the previous section)
----------------------------------------------------------------

-- auto‑block anti‑cheat remotes
local _acDefault = {"kick","ban","report","cheat","ac","security"}
local _acBlocked = {}
function RAPI.auto_block_ac(patterns)
    patterns = patterns or _acDefault
    local function m(n)
        n = n:lower()
        for _,p in ipairs(patterns) do
            if n:find(p) then return true end
        end
    end
    local function hook(r)
        if _acBlocked[r] then return end
        _acBlocked[r] = true
        if r:IsA("RemoteEvent") then
            RAPI.hook_fn(r.FireServer,function() end)
        else
            RAPI.hook_fn(r.InvokeServer,function() return nil end)
        end
    end
    for _,d in ipairs(game:GetDescendants()) do
        if (d:IsA("RemoteEvent") or d:IsA("RemoteFunction")) and m(d.Name) then hook(d) end
    end
    game.DescendantAdded:Connect(function(d)
        if (d:IsA("RemoteEvent") or d:IsA("RemoteFunction")) and m(d.Name) then hook(d) end
    end)
    return _acBlocked
end

-- spoof linear velocity each heartbeat
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

-- spoof ping value returned to local checks
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

    --- Toggle spoofing on/off with keybind
    --- @param key Enum.KeyCode | nil
    --- @param vec Vector3       | nil
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

    --- Set the spoofed velocity at runtime
    --- @param vec Vector3
    function RAPI.set_velocity_vector(vec)
        _velVector = vec
        RAPI.notif("Velocity spoof vector set to: " .. tostring(vec), 2)
    end
end

----------------------------------------------------------------
--  RAPI.fly_control  –  free‑flight with full key control
--      • default toggle key  =  F
--      • default speed       =  2 studs / heartbeat
--      • keys:
--          W / S = forward / back   (relative to camera)
--          A / D = strafe
--          Space = up
--          LeftCtrl = down
----------------------------------------------------------------
do
    local _fly  = false                 -- on/off flag
    local _spd  = 2                     -- studs per heartbeat
    local _loop = nil                   -- Heartbeat connection
    local _keyBinds = {                 -- state table for inputs
        up     = false,
        down   = false,
        fwd    = false,
        back   = false,
        left   = false,
        right  = false
    }

    -- Main public entry
    --- @param speed     number        movement speed (studs per frame)
    --- @param toggleKey Enum.KeyCode  key to start/stop flight
    function RAPI.fly_control(speed, toggleKey)
        _spd       = speed     or 2
        toggleKey  = toggleKey or Enum.KeyCode.F

        local Players   = game:GetService("Players")
        local UIS       = game:GetService("UserInputService")
        local LocalPlayer = Players.LocalPlayer

        -- ╭───────────────── input listeners ─────────────────╮
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
        -- ╰─────────────────────────────────────────────────────╯

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

                -- keep humanoid in a “normal” state so the server
                -- doesn’t try to ragdoll or auto‑reset
                if hum then
                    pcall(function()
                        hum:ChangeState(Enum.HumanoidStateType.Running)
                    end)
                end
            end)
        end
    end
end
----------------------------------------------------------------
--  End of fly_control module
----------------------------------------------------------------
----------------------------------------------------------------
--  RAPI.god_mode  – true invincibility toggle
--      • Blocks TakeDamage / BreakJoints
--      • Sets MaxHealth + Health = ∞ every frame
--      • Re‑applies on respawn
----------------------------------------------------------------
do
    local _god      = false
    local _hooked   = {}
    local _stopLoop = nil

    local function patchHumanoid(h)
        if _hooked[h] then return end
        _hooked[h] = true

        -- infinite health baseline
        h.MaxHealth = math.huge
        h.Health    = math.huge

        -- swallow TakeDamage
        RAPI.hook_fn(h.TakeDamage, function() end)
        -- swallow BreakJoints (instant‑kill)
        RAPI.hook_fn(h.BreakJoints, function() end)

        -- if something still manages to change it, reset next heartbeat
        if not _stopLoop then
            _stopLoop = RAPI.heartbeat(function()
                if not _god then return end
                local char = h.Parent
                if char and char:IsDescendantOf(workspace) then
                    h.MaxHealth = math.huge
                    h.Health    = math.huge
                end
            end)
        end
    end

    local function setup(char)
        local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5)
        if hum then patchHumanoid(hum) end
    end

    --- Toggle true invincibility
    --- @param key Enum.KeyCode | nil
    function RAPI.god_mode(key)
        key = key or Enum.KeyCode.K
        local ply = game:GetService("Players").LocalPlayer

        -- initial apply
        if ply.Character then setup(ply.Character) end
        ply.CharacterAdded:Connect(setup)

        -- toggle key (bind once)
        local flag = "__RAPI_GOD_" .. key.Value
        if not _G[flag] then
            _G[flag] = true
            RAPI.bind_key(key, function()
                _god = not _god
                RAPI.notif("God‑mode: " .. tostring(_god), 2)
            end)
        end

        -- start active
        _god = true
        RAPI.notif("God‑mode: true", 2)
    end
end
----------------------------------------------------------------
if not RAPI.god_mode then
    local _god, _hooked, _stopLoop = false, {}, nil
    local function patchHumanoid(h)
        if _hooked[h] then return end
        _hooked[h] = true
        h.MaxHealth = math.huge
        h.Health = math.huge
        RAPI.hook_fn(h.TakeDamage, function() end)
        RAPI.hook_fn(h.BreakJoints, function() end)
        if not _stopLoop then
            _stopLoop = RAPI.heartbeat(function()
                if not _god then return end
                local char = h.Parent
                if char and char:IsDescendantOf(workspace) then
                    h.MaxHealth = math.huge
                    h.Health = math.huge
                end
            end)
        end
    end
    local function setup(char)
        local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5)
        if hum then patchHumanoid(hum) end
    end
    function RAPI.god_mode(key)
        key = key or Enum.KeyCode.K
        local ply = game:GetService("Players").LocalPlayer
        if ply.Character then setup(ply.Character) end
        ply.CharacterAdded:Connect(setup)
        local flag = "__RAPI_GOD_" .. key.Value
        if not _G[flag] then
            _G[flag] = true
            RAPI.bind_key(key, function()
                _god = not _god
                RAPI.notif("God‑mode: " .. tostring(_god), 2)
            end)
        end
        _god = true
        RAPI.notif("God‑mode: true", 2)
    end
end


return RAPI
