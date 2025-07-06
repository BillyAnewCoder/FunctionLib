local RS = game:GetService("RunService")

local FLib = {}

function FLib.create_thread(f) return task.spawn(f) end

function FLib.on_render_step(f) return RS.RenderStepped:Connect(f) end
function FLib.on_heartbeat(f)   return RS.Heartbeat:Connect(f)   end
function FLib.on_stepped(f)     return RS.Stepped:Connect(f)     end

function FLib.delay_call(t, f)  return task.delay(t, f)           end

function FLib.protect_gui(gui)
    if syn and syn.protect_gui then syn.protect_gui(gui)
    elseif gethui then gui.Parent = gethui()
    else gui.Parent = game:GetService("CoreGui") end
    return gui
end

function FLib.safe_exec(f, ...)
    local ok, res = pcall(f, ...)
    if not ok then warn(res) end
    return ok, res
end

function FLib.toggle_loop(flag, interval, f)
    task.spawn(function()
        while flag do
            f()
            task.wait(interval)
        end
    end)
end

return FLib
