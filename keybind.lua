return function(Library)
    local UserInputService = game:GetService("UserInputService")
    local RunService = game:GetService("RunService")
    local TweenService = game:GetService("TweenService")

    local ControlKeys = {
        [Enum.KeyCode.LeftShift] = true,
        [Enum.KeyCode.RightShift] = true,
        [Enum.KeyCode.LeftControl] = true,
        [Enum.KeyCode.RightControl] = true,
        [Enum.KeyCode.LeftAlt] = true,
        [Enum.KeyCode.RightAlt] = true,
    }
    local AllKeys = {}
    for _, key in ipairs(Enum.KeyCode:GetEnumItems()) do
        if key ~= Enum.KeyCode.Unknown then
            AllKeys[key] = true
        end
    end
    local AssignedKeys = {}

    local NameOverrides = {
        [Enum.KeyCode.LeftShift] = "Shift",
        [Enum.KeyCode.RightShift] = "Shift",
        [Enum.KeyCode.LeftControl] = "Ctrl",
        [Enum.KeyCode.RightControl] = "Ctrl",
        [Enum.KeyCode.LeftAlt] = "Alt",
        [Enum.KeyCode.RightAlt] = "Alt",
        [Enum.KeyCode.Zero] = "0",
        [Enum.KeyCode.One] = "1",
        [Enum.KeyCode.Two] = "2",
        [Enum.KeyCode.Three] = "3",
        [Enum.KeyCode.Four] = "4",
        [Enum.KeyCode.Five] = "5",
        [Enum.KeyCode.Six] = "6",
        [Enum.KeyCode.Seven] = "7",
        [Enum.KeyCode.Eight] = "8",
        [Enum.KeyCode.Nine] = "9",
    }
    local NameAliases = {
        Shift = Enum.KeyCode.LeftShift,
        Ctrl = Enum.KeyCode.LeftControl,
        Alt = Enum.KeyCode.LeftAlt,
        ["0"] = Enum.KeyCode.Zero,
        ["1"] = Enum.KeyCode.One,
        ["2"] = Enum.KeyCode.Two,
        ["3"] = Enum.KeyCode.Three,
        ["4"] = Enum.KeyCode.Four,
        ["5"] = Enum.KeyCode.Five,
        ["6"] = Enum.KeyCode.Six,
        ["7"] = Enum.KeyCode.Seven,
        ["8"] = Enum.KeyCode.Eight,
        ["9"] = Enum.KeyCode.Nine,
    }

    local function safeCall(callback, ...)
        if type(callback) == "function" then
            local ok, err = pcall(callback, ...)
            if not ok then warn(err) end
        end
    end

    local function sortKeys(keys)
        local result = table.clone(keys)
        table.sort(result, function(a, b)
            local ac = ControlKeys[a] and 1 or 0
            local bc = ControlKeys[b] and 1 or 0
            if ac == bc then return a.Name < b.Name end
            return bc < ac
        end)
        return result
    end

    local function makeName(keys)
        local sorted = sortKeys(keys)
        if #sorted == 0 then return "<UNBOUND>" end
        local names = {}
        for i, key in ipairs(sorted) do
            names[i] = NameOverrides[key] or key.Name
        end
        return table.concat(names, "+")
    end

    local function serializeKeys(keys)
        local sorted = sortKeys(keys)
        local names = {}
        for i, key in ipairs(sorted) do
            names[i] = ControlKeys[key] and (NameOverrides[key] or key.Name) or key.Name
        end
        return table.concat(names, "+")
    end

    local function normalizeKeys(value)
        local values = {}
        if typeof(value) == "EnumItem" then
            values[1] = value
        elseif type(value) == "table" then
            values = value
        elseif type(value) == "string" then
            for name in value:gmatch("[^%+]+") do
                local clean = name:gsub("^%s+", ""):gsub("%s+$", "")
                values[#values + 1] = NameAliases[clean] or Enum.KeyCode[clean:gsub("^Enum%.KeyCode%.", "")]
            end
        end

        local result, seen = {}, {}
        local controls, standard = 0, 0
        for _, value2 in ipairs(values) do
            local key = typeof(value2) == "EnumItem" and value2 or Enum.KeyCode[tostring(value2):gsub("^Enum%.KeyCode%.", "")]
            if key and AllKeys[key] and not seen[key] then
                if ControlKeys[key] and controls < 2 then
                    controls += 1
                    seen[key] = true
                    result[#result + 1] = key
                elseif not ControlKeys[key] and standard < 1 then
                    standard += 1
                    seen[key] = true
                    result[#result + 1] = key
                end
            end
        end
        return result
    end

    local function setGradient(button, blue)
        for _, child in ipairs(button:GetChildren()) do
            if child:IsA("UIGradient") then child:Destroy() end
        end
        local gradient = Instance.new("UIGradient")
        gradient.Name = blue and "BlueGradient" or "GreyGradient"
        gradient.Color = blue and ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.new(0.34117648, 0.847058833, 1)),
            ColorSequenceKeypoint.new(1, Color3.new(0.529411793, 1, 0.97647059)),
        }) or ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.new(0.576470613, 0.58431375, 0.65882355)),
            ColorSequenceKeypoint.new(1, Color3.new(0.815686285, 0.831372559, 0.933333337)),
        })
        gradient.Rotation = -90
        gradient.Parent = button
    end

    local function shimmer(button)
        local screen = button:FindFirstAncestorOfClass("ScreenGui")
        if not screen then return function() end end

        local frame = Instance.new("Frame")
        frame.Name = "Shimmer"
        frame.Active = false
        frame.AnchorPoint = Vector2.new(0.5, 1)
        frame.BackgroundColor3 = Color3.new(1, 1, 1)
        frame.BackgroundTransparency = 0.5
        frame.BorderSizePixel = 0
        frame.ClipsDescendants = true
        frame.Position = UDim2.new(0.5, 0, 0.99, 0)
        frame.Size = UDim2.new(0.96, 0, 0.93, 0)
        frame.ZIndex = 11
        frame.Parent = button

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0.18, 0)
        corner.Parent = frame

        local gradient = Instance.new("UIGradient")
        gradient.Color = ColorSequence.new(Color3.new(1, 1, 1))
        gradient.Offset = Vector2.new(-1, 0)
        gradient.Rotation = 25
        gradient.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.375311732, 0.181249976),
            NumberSequenceKeypoint.new(0.5, 0),
            NumberSequenceKeypoint.new(0.639650881, 0.1875),
            NumberSequenceKeypoint.new(1, 1),
        })
        gradient.Parent = frame

        local stopped = false
        task.spawn(function()
            while not stopped and button.Parent do
                if screen.Enabled then
                    gradient.Offset = Vector2.new(-1, 0)
                    TweenService:Create(gradient, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
                        Offset = Vector2.new(1, 0),
                    }):Play()
                end
                task.wait(0.55)
            end
        end)

        return function()
            stopped = true
            if frame.Parent then frame:Destroy() end
        end
    end

    local function buttonFX(button, connections)
        local scale = button:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
        scale.Scale = 1
        scale.Parent = button
        local pressed = false

        connections[#connections + 1] = button.MouseEnter:Connect(function()
            if not pressed then
                TweenService:Create(scale, TweenInfo.new(0.05, Enum.EasingStyle.Circular, Enum.EasingDirection.Out), {Scale = 1.05}):Play()
            end
        end)
        connections[#connections + 1] = button.MouseLeave:Connect(function()
            if not pressed then
                TweenService:Create(scale, TweenInfo.new(0.035, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Scale = 1}):Play()
            end
        end)
        connections[#connections + 1] = button.InputBegan:Connect(function(inputObject)
            if inputObject.UserInputType == Enum.UserInputType.MouseButton1
                or inputObject.UserInputType == Enum.UserInputType.Touch
                or inputObject.KeyCode == Enum.KeyCode.ButtonA then
                pressed = true
                TweenService:Create(scale, TweenInfo.new(0.065, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Scale = 0.9}):Play()
            end
        end)
        connections[#connections + 1] = button.InputEnded:Connect(function(inputObject)
            if inputObject.UserInputType == Enum.UserInputType.MouseButton1
                or inputObject.UserInputType == Enum.UserInputType.Touch
                or inputObject.KeyCode == Enum.KeyCode.ButtonA then
                pressed = false
                TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Circular, Enum.EasingDirection.Out), {Scale = 1}):Play()
            end
        end)
    end

    function Library:AddKeybind(keybindSettings, legacyKey, legacyCallback)
        local settings = type(keybindSettings) == "table" and keybindSettings or {
            Name = tostring(keybindSettings),
            CurrentKey = legacyKey,
            Callback = legacyCallback,
        }
        settings.Name = tostring(settings.Name or "Keybind")
        settings.Callback = settings.Callback or function() end
        settings.HoldToInteract = settings.HoldToInteract == true
        settings.IgnoreProcessed = settings.IgnoreProcessed == true

        local row = self.Templates.Selector:Clone()
        row.SettingName.Text = settings.Name
        local button = row.Toggle.Button
        local label = button.TextLabel
        local currentKeys = normalizeKeys(settings.CurrentKey or settings.Default)
        local owner = {}
        local registeredSignature = ""
        local listening = false
        local holding = false
        local holdToken = 0
        local editRender
        local shimmerCleanup
        local bindingStartValue
        local bindingStartKeys
        local skipActivated = false
        local connections = {}

        button.AutoButtonColor = true
        button.BackgroundTransparency = 1
        button.BorderSizePixel = 0
        button.Image = "rbxassetid://14423621163"
        button.PressedImage = "rbxassetid://14423621349"
        button.ImageColor3 = Color3.new(1, 1, 1)
        button.ImageTransparency = 0
        button.ScaleType = Enum.ScaleType.Slice
        button.SliceCenter = Rect.new(20, 20, 80, 80)
        button.SliceScale = 1
        button.ZIndex = 2
        label.AnchorPoint = Vector2.new(0.5, 0.5)
        label.Position = UDim2.fromScale(0.5, 0.5)
        label.BackgroundTransparency = 1
        label.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
        label.Size = UDim2.new(0.85, 0, 0.6, 0)
        label.TextColor3 = Color3.new(1, 1, 1)
        label.TextScaled = true
        label.TextSize = 18
        label.TextStrokeTransparency = 1
        label.TextWrapped = true
        label.TextXAlignment = Enum.TextXAlignment.Right
        label.TextYAlignment = Enum.TextYAlignment.Center
        label.ZIndex = 6
        local stroke = label:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
        stroke.Color = Color3.new(0, 0, 0)
        stroke.Thickness = 3
        stroke.Transparency = 0
        stroke.Parent = label
        setGradient(button, false)

        self:_mount(row, settings.Name, settings.Name .. " keybind")
        buttonFX(button, connections)

        local function render(keys)
            label.Text = makeName(keys or currentKeys)
        end

        local function setRegistered(keys)
            local signature = serializeKeys(keys)
            if signature ~= "" and AssignedKeys[signature] and AssignedKeys[signature] ~= owner then
                return false
            end
            if registeredSignature ~= "" and AssignedKeys[registeredSignature] == owner then
                AssignedKeys[registeredSignature] = nil
            end
            registeredSignature = signature
            if signature ~= "" then AssignedKeys[signature] = owner end
            return true
        end

        local function fireChanged(oldValue)
            if serializeKeys(currentKeys) ~= oldValue then
                safeCall(settings.ChangedCallback, #currentKeys == 1 and currentKeys[1] or table.clone(currentKeys))
            end
        end

        local function stopListening()
            if not listening then return end
            listening = false
            if editRender then editRender:Disconnect() editRender = nil end
            if shimmerCleanup then shimmerCleanup() shimmerCleanup = nil end
            if not setRegistered(currentKeys) then
                currentKeys = bindingStartKeys or {}
            end
            setGradient(button, false)
            render()
            fireChanged(bindingStartValue or "")
            bindingStartValue = nil
            bindingStartKeys = nil
        end

        local function startListening()
            if listening then return end
            bindingStartValue = serializeKeys(currentKeys)
            bindingStartKeys = table.clone(currentKeys)
            currentKeys = {}
            listening = true
            render()
            setGradient(button, true)
            shimmerCleanup = shimmer(button)

            local captured = {}
            local capturedTimes = {}
            local rendered = false
            editRender = RunService.RenderStepped:Connect(function()
                local now = tick()
                local newest
                local added = false
                for _, info in pairs(capturedTimes) do
                    if not newest or newest < info.t then newest = info.t end
                end
                for _, inputObject in ipairs(UserInputService:GetKeysPressed()) do
                    local key = inputObject.KeyCode
                    if key ~= Enum.KeyCode.Unknown then
                        if not newest or now - newest > 0.5 then
                            table.clear(capturedTimes)
                            newest = nil
                        end
                        if not capturedTimes[key] then
                            capturedTimes[key] = {t = now}
                            newest = now
                            added = true
                        end
                    end
                end

                local list = {}
                for key, info in pairs(capturedTimes) do
                    list[#list + 1] = {key = key, t = info.t}
                end
                table.sort(list, function(a, b) return a.t > b.t end)

                local controls, standard = 0, 0
                table.clear(captured)
                for _, info in ipairs(list) do
                    if ControlKeys[info.key] and controls < 2 then
                        controls += 1
                        captured[#captured + 1] = info.key
                    elseif not ControlKeys[info.key] and standard < 1 then
                        standard += 1
                        captured[#captured + 1] = info.key
                    end
                end
                if added or not rendered then render(captured) end
                currentKeys = table.clone(captured)
                rendered = true
            end)
        end

        connections[#connections + 1] = button.Activated:Connect(function()
            if skipActivated then
                skipActivated = false
                return
            end
            if listening then stopListening() else startListening() end
        end)

        connections[#connections + 1] = UserInputService.InputBegan:Connect(function(inputObject, processed)
            if listening then
                if inputObject.KeyCode == Enum.KeyCode.Return and not processed then
                    stopListening()
                elseif inputObject.UserInputType == Enum.UserInputType.MouseButton1 then
                    skipActivated = true
                    stopListening()
                end
                return
            end
            if processed and not settings.IgnoreProcessed then return end
            if #currentKeys == 0 then return end

            local down = {}
            for _, inputObject2 in ipairs(UserInputService:GetKeysPressed()) do
                if inputObject2.KeyCode ~= Enum.KeyCode.Unknown then
                    down[inputObject2.KeyCode] = true
                end
            end
            local count = 0
            for _ in pairs(down) do count += 1 end
            if count ~= #currentKeys then return end
            for _, key in ipairs(currentKeys) do
                if not down[key] then return end
            end

            if settings.HoldToInteract then
                if holding then return end
                holding = true
                holdToken += 1
                local token = holdToken
                task.spawn(function()
                    while holding and token == holdToken do
                        safeCall(settings.Callback, true)
                        RunService.Heartbeat:Wait()
                    end
                end)
            else
                safeCall(settings.Callback, #currentKeys == 1 and currentKeys[1] or table.clone(currentKeys))
            end
        end)

        connections[#connections + 1] = UserInputService.InputEnded:Connect(function(inputObject)
            if inputObject.UserInputType == Enum.UserInputType.MouseButton1 and skipActivated then
                task.spawn(function()
                    RunService.RenderStepped:Wait()
                    skipActivated = false
                end)
            end
            if not settings.HoldToInteract or not holding then return end
            for _, key in ipairs(currentKeys) do
                if inputObject.KeyCode == key then
                    holding = false
                    holdToken += 1
                    safeCall(settings.Callback, false)
                    return
                end
            end
        end)

        local control = {
            Get = function()
                return makeName(currentKeys)
            end,
            Set = function(_, value, silent)
                if listening then stopListening() end
                local keys = normalizeKeys(value)
                if not setRegistered(keys) then return makeName(currentKeys) end
                currentKeys = keys
                render()
                if not silent then
                    safeCall(settings.ChangedCallback, #currentKeys == 1 and currentKeys[1] or table.clone(currentKeys))
                end
                return makeName(currentKeys)
            end,
            Destroy = function()
                if editRender then editRender:Disconnect() editRender = nil end
                if shimmerCleanup then shimmerCleanup() shimmerCleanup = nil end
                if registeredSignature ~= "" and AssignedKeys[registeredSignature] == owner then
                    AssignedKeys[registeredSignature] = nil
                end
                registeredSignature = ""
                holding = false
                holdToken += 1
                for _, connection in ipairs(connections) do connection:Disconnect() end
                row:Destroy()
            end,
        }

        if not setRegistered(currentKeys) then currentKeys = {} end
        render()
        return self:_decorateControl(control, row, settings, "Keybind")
    end
end
