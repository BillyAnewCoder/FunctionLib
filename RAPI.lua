local RS,UIS,Players,SG = game:GetService("RunService"),game:GetService("UserInputService"),game:GetService("Players"),game:GetService("StarterGui")
local RAPI={}

-- base threading
function RAPI.thread(f)              return task.spawn(f) end
function RAPI.delay(t,f)             return task.delay(t,f) end
function RAPI.loop(dt,f)             return RAPI.thread(function() while true do f(); task.wait(dt) end end) end
function RAPI.render(f)              return RS.RenderStepped:Connect(f) end
function RAPI.heartbeat(f)           return RS.Heartbeat:Connect(f) end
function RAPI.stepped(f)             return RS.Stepped:Connect(f) end

-- events
function RAPI.once(sig,f)            local c;c=sig:Connect(function(... )c:Disconnect();f(...)end);return c end
function RAPI.bind_key(key,f)        return UIS.InputBegan:Connect(function(i,g) if not g and i.KeyCode==key then f() end end) end

-- gui
function RAPI.protect_gui(g)         if syn and syn.protect_gui then syn.protect_gui(g) elseif gethui then g.Parent=gethui() else g.Parent=game.CoreGui end return g end
function RAPI.new_window(n,s,p)      local sg=Instance.new("ScreenGui") sg.Name,sg.ResetOnSpawn=n,false RAPI.protect_gui(sg) local f=Instance.new("Frame",sg) f.Size=s or UDim2.fromOffset(300,200) f.Position=p or UDim2.fromOffset(60,60) f.BackgroundColor3=Color3.fromRGB(30,30,30) f.BorderSizePixel=0 return sg,f end

-- hooks
local fnHooks,mtHooks={},{}
function RAPI.hook_fn(o,n)           if fnHooks[o] then return fnHooks[o] end local h=hookfunction(o,n) fnHooks[o]=h return h end
function RAPI.hook_mt(obj,n,new)     local mt=getrawmetatable(obj) setreadonly(mt,false) if not mtHooks[n] then mtHooks[n]=mt[n] mt[n]=new end setreadonly(mt,true) return mtHooks[n] end

-- utils
function RAPI.safe(f,...)            local ok,r=pcall(f,...) if not ok then warn(r) end return ok,r end
function RAPI.retry(n,w,f,...)       for i=1,n do local ok,r=pcall(f,...) if ok then return r end task.wait(w) end end
function RAPI.random_string(l)       local t={} for i=1,l do t[i]=string.char(math.random(97,122)) end return table.concat(t) end
function RAPI.get_player(q)          for _,p in ipairs(Players:GetPlayers()) do if p.Name:lower():find(q:lower()) then return p end end end

-- path / remote helpers
local function split(p)              local t={} for s in p:gmatch("[^%.]+") do t[#t+1]=s end return t end
function RAPI.wait_for(p)            local cur=game for _,seg in ipairs(split(p)) do cur=cur:WaitForChild(seg) end return cur end
function RAPI.fire_remote(r,...)     return RAPI.safe(function(...) if r.ClassName=="RemoteEvent" then r:FireServer(...) else return r:InvokeServer(...) end end,...) end

-- toggleable loop
function RAPI.loop_toggle(flag,dt,f) return RAPI.thread(function() while flag() do f(); task.wait(dt) end end) end

-- notification
function RAPI.notif(t,d)             pcall(SG.SetCore,SG,"SendNotification",{Title="RAPI",Text=t,Duration=d or 3}) end

-- actor helpers (requires getactors)
local _getactors = rawget(_G,"getactors") or getactors
function RAPI.actors()               return _getactors and _getactors() or {} end
function RAPI.for_actors(f)          for _,a in ipairs(RAPI.actors()) do RAPI.thread(function() f(a) end) end end
function RAPI.actor_wait(n)          while true do for _,a in ipairs(RAPI.actors()) do if a.Name==n then return a end end task.wait() end end

return RAPI
