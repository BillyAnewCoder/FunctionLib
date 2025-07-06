local RS      = game:GetService("RunService")
local UIS     = game:GetService("UserInputService")
local Players = game:GetService("Players")

local RAPI    = {}

----------------------------------------------------------------
-- threads / timing
----------------------------------------------------------------
function RAPI.thread(f)            return task.spawn(f) end
function RAPI.delay(t,f)           return task.delay(t,f) end
function RAPI.loop(dt,f)
    return RAPI.thread(function()
        while true do
            f()
            task.wait(dt)
        end
    end)
end
function RAPI.render(f)            return RS.RenderStepped:Connect(f) end
function RAPI.heartbeat(f)         return RS.Heartbeat:Connect(f) end
function RAPI.stepped(f)           return RS.Stepped:Connect(f) end

----------------------------------------------------------------
-- events
----------------------------------------------------------------
function RAPI.once(sig,f)
    local c; c = sig:Connect(function(...)
        c:Disconnect()
        f(...)
    end)
    return c
end
function RAPI.bind_key(key,f)
    return UIS.InputBegan:Connect(function(i,g)
        if not g and i.KeyCode == key then f() end
    end)
end

----------------------------------------------------------------
-- gui
----------------------------------------------------------------
function RAPI.protect_gui(g)
    if syn and syn.protect_gui then syn.protect_gui(g)
    elseif gethui then g.Parent = gethui()
    else g.Parent = game:GetService("CoreGui") end
    return g
end
function RAPI.new_window(name,size,pos)
    local sg = Instance.new("ScreenGui")
    sg.Name, sg.ResetOnSpawn = name, false
    RAPI.protect_gui(sg)
    local f = Instance.new("Frame", sg)
    f.Size, f.Position = size or UDim2.fromOffset(300,200), pos or UDim2.fromOffset(60,60)
    f.BackgroundColor3 = Color3.fromRGB(30,30,30)
    f.BorderSizePixel = 0
    return sg,f
end

----------------------------------------------------------------
-- hooks
----------------------------------------------------------------
local fnHooks, mtHooks = {}, {}
function RAPI.hook_fn(old,new)
    if fnHooks[old] then return fnHooks[old] end
    local h = hookfunction(old,new)
    fnHooks[old] = h
    return h
end
function RAPI.hook_mt(obj,name,new)
    local mt = getrawmetatable(obj)
    setreadonly(mt,false)
    if not mtHooks[name] then
        mtHooks[name] = mt[name]
        mt[name] = new
    end
    setreadonly(mt,true)
    return mtHooks[name]
end

----------------------------------------------------------------
-- utils
----------------------------------------------------------------
function RAPI.safe(f,...)
    local ok,r = pcall(f,...)
    if not ok then warn(r) end
    return ok,r
end
function RAPI.retry(n,waitTime,f,...)
    for i=1,n do
        local ok,r = pcall(f,...)
        if ok then return r end
        task.wait(waitTime)
    end
end
function RAPI.random_string(len)
    local s = {}
    for i=1,len do
        s[i] = string.char(math.random(97,122))
    end
    return table.concat(s)
end
function RAPI.get_player(name)
    for _,plr in ipairs(Players:GetPlayers()) do
        if plr.Name:lower():find(name:lower()) then return plr end
    end
end

return RAPI
