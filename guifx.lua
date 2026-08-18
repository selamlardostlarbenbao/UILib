local GUIFX = (function()
    local TweenService = game:GetService("TweenService")

    local attached = setmetatable({}, {__mode = "k"})

    local function playTween(scaleObject, target, duration, easingStyle)
        TweenService:Create(
            scaleObject,
            TweenInfo.new(duration, easingStyle, Enum.EasingDirection.Out),
            {Scale = target}
        ):Play()
    end

    local function ButtonFX(button, hoverScale)
        if attached[button] then
            return attached[button]
        end

        hoverScale = hoverScale or 1.05

        local scaleObject = button:FindFirstChildOfClass("UIScale")
        if not scaleObject then
            scaleObject = Instance.new("UIScale")
            scaleObject.Name = "ButtonUIScale"
            scaleObject.Parent = button
        end

        local connections = {}
        local pressed = false
        local hovering = false
        local stopped = false

        local function down()
            if pressed or not button.Active then
                return
            end
            pressed = true
            hovering = false
            playTween(scaleObject, 0.9, 0.065, Enum.EasingStyle.Exponential)
        end

        local function up()
            if not pressed then
                return
            end
            pressed = false
            playTween(scaleObject, 1, 0.25, Enum.EasingStyle.Circular)
        end

        local function mouseEnter()
            if hovering or pressed or not button.Active then
                return
            end
            hovering = true
            playTween(scaleObject, hoverScale, 0.05, Enum.EasingStyle.Circular)
        end

        local function mouseLeave()
            if not hovering then
                return
            end
            hovering = false
            if not pressed then
                playTween(scaleObject, 1, 0.035, Enum.EasingStyle.Exponential)
            end
        end

        table.insert(connections, button.InputBegan:Connect(function(inputObject)
            if inputObject.UserInputType == Enum.UserInputType.MouseButton1
                or inputObject.UserInputType == Enum.UserInputType.Touch
                or inputObject.KeyCode == Enum.KeyCode.ButtonA then
                down()
            end
        end))

        table.insert(connections, button.InputEnded:Connect(function(inputObject)
            if inputObject.UserInputType == Enum.UserInputType.MouseButton1
                or inputObject.UserInputType == Enum.UserInputType.Touch
                or inputObject.KeyCode == Enum.KeyCode.ButtonA then
                up()
            end
        end))

        table.insert(connections, button.MouseEnter:Connect(mouseEnter))
        table.insert(connections, button.MouseLeave:Connect(mouseLeave))

        local function stop()
            if stopped then
                return
            end
            stopped = true
            for _, connection in ipairs(connections) do
                connection:Disconnect()
            end
            if scaleObject.Parent then
                scaleObject.Scale = 1
            end
            attached[button] = nil
        end

        table.insert(connections, button.Destroying:Connect(stop))
        attached[button] = stop
        return stop
    end

    return {
        ButtonFX = ButtonFX,
    }
end)()

return GUIFX
