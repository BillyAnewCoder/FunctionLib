local RS,UIS,Players,SG=game:GetService("RunService"),game:GetService("UserInputService"),game:GetService("Players"),game:GetService("StarterGui")
local RAPI={}

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


return RAPI
