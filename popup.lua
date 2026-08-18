return function(Library)
    if type(Library) ~= "table" then
        error("popup.lua expected the necker Library table", 2)
    end
    if Library.__NeckerPopupInstalled then
        return Library
    end
    Library.__NeckerPopupInstalled = true

    local TweenService = game:GetService("TweenService")
    local RunService = game:GetService("RunService")

    local BUTTON_IMAGE = "rbxassetid://14423621163"
    local SHADOW_IMAGE = "rbxassetid://14001321443"
    local PANEL_PATTERN = "rbxassetid://13581793331"
    local ERROR_ICON = "rbxassetid://14693511016"
    local WARN_ICON = "rbxassetid://12292293450"
    local WARN_SHADOW = "rbxassetid://13873482240"
    local CIRCLE_LEFT = "rbxassetid://8897745728"
    local CIRCLE_RIGHT = "rbxassetid://8897746094"

    local GREEN = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(92, 239, 0)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(163, 253, 28)),
    })
    local RED = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 2, 61)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 39, 125)),
    })
    local BLUE = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(87, 216, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(135, 255, 249)),
    })
    local GREY = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(98, 98, 98)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(151, 151, 151)),
    })

    local BUTTON_DOWN = TweenInfo.new(0.065, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
    local BUTTON_UP = TweenInfo.new(0.25, Enum.EasingStyle.Circular, Enum.EasingDirection.Out)
    local BUTTON_HOVER = TweenInfo.new(0.05, Enum.EasingStyle.Circular, Enum.EasingDirection.Out)
    local BUTTON_LEAVE = TweenInfo.new(0.035, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
    local WARN_IN = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

    local function cloneTable(source)
        local result = {}
        if type(source) == "table" then
            for key, value in pairs(source) do
                result[key] = value
            end
        end
        return result
    end

    local function safeCall(callback, ...)
        if type(callback) ~= "function" then
            return
        end
        local ok, message = pcall(callback, ...)
        if not ok then
            warn("Popup: " .. tostring(message))
        end
    end

    local function corner(parent, radius)
        local object = Instance.new("UICorner")
        object.CornerRadius = UDim.new(0, radius or 12)
        object.Parent = parent
        return object
    end

    local function stroke(parent, thickness, color, transparency)
        local object = Instance.new("UIStroke")
        object.Color = color or Color3.new(0, 0, 0)
        object.Thickness = thickness or 2
        object.Transparency = transparency or 0
        object.LineJoinMode = Enum.LineJoinMode.Round
        object.Parent = parent
        return object
    end

    local function textLabel(parent, name, text, zindex)
        local label = Instance.new("TextLabel")
        label.Name = name
        label.BackgroundTransparency = 1
        label.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular)
        label.Text = tostring(text or "")
        label.TextColor3 = Color3.fromRGB(42, 43, 49)
        label.TextScaled = true
        label.TextWrapped = true
        label.ZIndex = zindex or 1003
        label.Parent = parent
        return label
    end

    local function attachButtonFX(button)
        local scale = button:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
        scale.Name = "ButtonUIScale"
        scale.Parent = button
        local pressed = false
        local hovering = false

        local function Down()
            if pressed then
                return
            end
            pressed = true
            hovering = false
            TweenService:Create(scale, BUTTON_DOWN, {Scale = 0.9}):Play()
        end

        local function Up()
            if not pressed then
                return
            end
            pressed = false
            TweenService:Create(scale, BUTTON_UP, {Scale = 1}):Play()
        end

        local function MouseEnter()
            if hovering then
                return
            end
            hovering = true
            if pressed then
                return
            end
            TweenService:Create(scale, BUTTON_HOVER, {Scale = 1.05}):Play()
        end

        local function MouseLeave()
            if not hovering then
                return
            end
            hovering = false
            if pressed then
                return
            end
            TweenService:Create(scale, BUTTON_LEAVE, {Scale = 1}):Play()
        end

        button.InputBegan:Connect(function(input)
            if not button.Active then
                return
            end
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch or input.KeyCode == Enum.KeyCode.ButtonA then
                Down()
            end
        end)
        button.InputEnded:Connect(function(input)
            if not button.Active then
                return
            end
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch or input.KeyCode == Enum.KeyCode.ButtonA then
                Up()
            end
        end)
        button.MouseEnter:Connect(MouseEnter)
        button.MouseLeave:Connect(MouseLeave)
    end

    local function makeButton(parent, name, caption, position, gradientColor, zindex)
        local button = Instance.new("ImageButton")
        button.Name = name
        button.AnchorPoint = Vector2.new(0.5, 0.5)
        button.AutoButtonColor = false
        button.BackgroundTransparency = 1
        button.Image = BUTTON_IMAGE
        button.Position = position
        button.Size = UDim2.new(0.4464, 0, 0.15, 25)
        button.ZIndex = zindex or 1006
        button.Parent = parent

        local gradient = Instance.new("UIGradient")
        gradient.Name = name .. " gradient"
        gradient.Color = gradientColor
        gradient.Parent = button

        local label = textLabel(button, "TextLabel", caption, button.ZIndex)
        label.AnchorPoint = Vector2.new(0.5, 0.5)
        label.Position = UDim2.fromScale(0.5, 0.5)
        label.Size = UDim2.fromScale(0.9, 0.6)
        label.TextColor3 = Color3.new(1, 1, 1)
        stroke(label, 2.2, Color3.new(0, 0, 0), 0)

        attachButtonFX(button)
        return button, gradient
    end

    local function setCircularProgress(frame, progress)
        progress = math.clamp(tonumber(progress) or 0, 0.0001, 1)
        local leftGradient = frame.Left:FindFirstChildOfClass("UIGradient")
        local rightGradient = frame.Right:FindFirstChildOfClass("UIGradient")
        rightGradient.Rotation = math.clamp(progress * 2, 0, 1) * 180
        leftGradient.Rotation = math.clamp((progress - 0.5) * 2, 0, 1) * 180 + 180
        rightGradient.Enabled = progress < 0.5
        leftGradient.Enabled = progress < 1
    end

    local function makeCircularBar(parent)
        local bar = Instance.new("Frame")
        bar.Name = "CircularBar"
        bar.AnchorPoint = Vector2.new(0.5, 0.5)
        bar.BackgroundTransparency = 1
        bar.Position = UDim2.fromScale(0.03, 0.12)
        bar.Size = UDim2.fromScale(0.35, 0.35)
        bar.Visible = false
        bar.ZIndex = 1110
        bar.Parent = parent

        local aspect = Instance.new("UIAspectRatioConstraint")
        aspect.AspectRatio = 1
        aspect.Parent = bar

        for _, data in ipairs({{"Left", CIRCLE_LEFT}, {"Right", CIRCLE_RIGHT}}) do
            local image = Instance.new("ImageLabel")
            image.Name = data[1]
            image.AnchorPoint = Vector2.new(0.5, 0.5)
            image.BackgroundTransparency = 1
            image.Image = data[2]
            image.ImageColor3 = Color3.new(0, 0, 0)
            image.Position = UDim2.fromScale(0.5, 0.5)
            image.Size = UDim2.fromScale(1, 1)
            image.ZIndex = 1110
            image.Parent = bar

            local gradient = Instance.new("UIGradient")
            gradient.Rotation = 180
            gradient.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0),
                NumberSequenceKeypoint.new(0.499, 0),
                NumberSequenceKeypoint.new(0.5, 1),
                NumberSequenceKeypoint.new(1, 1),
            })
            gradient.Parent = image
        end

        setCircularProgress(bar, 1)
        return bar
    end

    local function getWarnHost(window)
        if window._PopupWarnHost and window._PopupWarnHost.Parent then
            return window._PopupWarnHost
        end
        local host = Instance.new("Frame")
        host.Name = "PopupWarnings"
        host.AnchorPoint = Vector2.new(0.5, 1)
        host.BackgroundTransparency = 1
        host.Position = UDim2.new(0.5, 0, 0.8, -40)
        host.Size = UDim2.new(0.5, 25, 0, 180)
        host.ZIndex = 980
        host.Parent = window.Screen

        local list = Instance.new("UIListLayout")
        list.FillDirection = Enum.FillDirection.Vertical
        list.HorizontalAlignment = Enum.HorizontalAlignment.Center
        list.VerticalAlignment = Enum.VerticalAlignment.Bottom
        list.Padding = UDim.new(0, 4)
        list.SortOrder = Enum.SortOrder.LayoutOrder
        list.Parent = host

        window._PopupWarnHost = host
        return host
    end

    local function makeWarning(host, settings)
        local group = Instance.new("CanvasGroup")
        group.Name = "Warn"
        group.BackgroundTransparency = 1
        group.Size = UDim2.new(1, 0, 0, 42)
        group.ZIndex = 981

        local shadow = Instance.new("ImageLabel")
        shadow.Name = "Shadow"
        shadow.AnchorPoint = Vector2.new(0.5, 0)
        shadow.BackgroundTransparency = 1
        shadow.Image = WARN_SHADOW
        shadow.ImageColor3 = Color3.new(0, 0, 0)
        shadow.ImageTransparency = 0.65
        shadow.Position = UDim2.new(0.5, 0, 0.15, 0)
        shadow.Size = UDim2.new(0.4, 0, 1, 0)
        shadow.ZIndex = 981
        shadow.Parent = group

        local frame = Instance.new("Frame")
        frame.Name = "Frame"
        frame.AnchorPoint = Vector2.new(0.5, 0)
        frame.BackgroundTransparency = 1
        frame.Position = UDim2.fromScale(0.5, 0)
        frame.Size = UDim2.fromScale(1, 1)
        frame.ZIndex = 982
        frame.Parent = group

        local list = Instance.new("UIListLayout")
        list.FillDirection = Enum.FillDirection.Horizontal
        list.HorizontalAlignment = Enum.HorizontalAlignment.Center
        list.VerticalAlignment = Enum.VerticalAlignment.Center
        list.Padding = UDim.new(0, 4)
        list.SortOrder = Enum.SortOrder.LayoutOrder
        list.Parent = frame

        local icon = Instance.new("ImageLabel")
        icon.Name = "Icon"
        icon.BackgroundTransparency = 1
        icon.Image = tostring(settings.Icon or WARN_ICON)
        icon.ImageColor3 = settings.IconColor or Color3.fromRGB(23, 43, 57)
        icon.LayoutOrder = 1
        icon.Size = UDim2.fromOffset(38, 38)
        icon.ZIndex = 982
        icon.Parent = frame
        local iconAspect = Instance.new("UIAspectRatioConstraint")
        iconAspect.AspectRatio = 1
        iconAspect.Parent = icon

        local label = textLabel(frame, "TextLabel", settings.Desc or "Something not good! Uh oh!", 982)
        label.AutomaticSize = Enum.AutomaticSize.X
        label.LayoutOrder = 2
        label.RichText = true
        label.Size = UDim2.new(0, 0, 1, 0)
        label.TextColor3 = settings.Color or Color3.fromRGB(255, 101, 101)
        label.TextStrokeColor3 = Color3.fromRGB(23, 43, 57)
        label.TextStrokeTransparency = 0
        label.TextWrapped = false

        local scale = Instance.new("UIScale")
        scale.Scale = 1.35
        scale.Parent = group
        local fade = Instance.new("UIGradient")
        fade.Rotation = 45
        fade.Transparency = NumberSequence.new(0)
        fade.Parent = group

        group.Parent = host
        TweenService:Create(scale, WARN_IN, {Scale = 1}):Play()
        return group, fade
    end

    local function fadeWarning(entry)
        if entry.Fading or not entry.Frame or not entry.Frame.Parent then
            return
        end
        entry.Fading = true
        task.spawn(function()
            local started = os.clock()
            repeat
                if not entry.Frame or not entry.Frame.Parent then
                    break
                end
                local alpha = math.clamp((os.clock() - started) / 0.35, 0, 1)
                local sineInOut = TweenService:GetValue(alpha, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
                local sineOut = TweenService:GetValue(alpha, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
                entry.Gradient.Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, sineInOut),
                    NumberSequenceKeypoint.new(math.clamp(1 - alpha * 0.99, 0, 1), sineOut),
                    NumberSequenceKeypoint.new(1, sineOut),
                })
                RunService.RenderStepped:Wait()
            until os.clock() - started >= 0.35
            if entry.Frame and entry.Frame.Parent then
                entry.Frame:Destroy()
            end
            entry.Dead = true
        end)
    end

    local function startWarningWorker(window)
        if window._PopupWarnWorker then
            return
        end
        window._PopupWarnWorker = true
        task.spawn(function()
            local lastPush = 0
            while window.Screen and window.Screen.Parent do
                local queue = window._PopupWarnQueue or {}
                local active = window._PopupWarnActive or {}
                window._PopupWarnQueue = queue
                window._PopupWarnActive = active
                local now = os.clock()

                for index = #active, 1, -1 do
                    local entry = active[index]
                    if entry.Dead or not entry.Frame or not entry.Frame.Parent then
                        table.remove(active, index)
                    elseif not entry.Fading and (now - entry.Created >= entry.Time or (#queue > 0 and now - entry.Created >= 1.25)) then
                        fadeWarning(entry)
                    end
                end

                if #active < 3 and #queue > 0 and now - lastPush >= 0.1 then
                    lastPush = now
                    local request = table.remove(queue, 1)
                    local frame, gradient = makeWarning(getWarnHost(window), request.Settings)
                    local entry = {
                        Frame = frame,
                        Gradient = gradient,
                        Created = os.clock(),
                        Time = math.max(0.1, tonumber(request.Settings.Time) or 4),
                    }
                    request.Entry = entry
                    table.insert(active, entry)
                end

                if #queue == 0 and #active == 0 then
                    window._PopupWarnWorker = nil
                    return
                end
                task.wait(0.05)
            end
            window._PopupWarnWorker = nil
        end)
    end

    function Library:ErrorPopup(settings)
        if not self.Screen then
            return
        end
        settings = type(settings) == "table" and cloneTable(settings) or {Desc = tostring(settings or "Something not good! Uh oh!")}
        settings.Desc = tostring(settings.Desc or settings.Message or "Something not good! Uh oh!")
        self._PopupWarnQueue = self._PopupWarnQueue or {}
        self._PopupWarnActive = self._PopupWarnActive or {}
        if #self._PopupWarnQueue >= 20 then
            return
        end
        local request = {Settings = settings}
        table.insert(self._PopupWarnQueue, request)
        startWarningWorker(self)

        local handle = {}
        function handle:Dismiss()
            local entry = request.Entry
            if entry then
                fadeWarning(entry)
                return true
            end
            local index = table.find(self._Queue or {}, request)
            if index then
                table.remove(self._Queue, index)
                return true
            end
            return false
        end
        handle._Queue = self._PopupWarnQueue
        return handle
    end

    local function makeModal(window, settings, mode)
        local overlay = Instance.new("Frame")
        overlay.Name = "PopupMessage"
        overlay.Active = true
        overlay.BackgroundTransparency = 1
        overlay.Size = UDim2.fromScale(1, 1)
        overlay.ZIndex = 1000
        overlay.Parent = window.Screen

        local panel = Instance.new("Frame")
        panel.Name = "Frame"
        panel.AnchorPoint = Vector2.new(0.5, 0.5)
        panel.BackgroundColor3 = Color3.new(1, 1, 1)
        panel.BorderSizePixel = 0
        panel.Position = UDim2.fromScale(0.5, 0.5)
        panel.Size = UDim2.fromOffset(520, 416)
        panel.ZIndex = 1001
        panel.Parent = overlay
        corner(panel, 16)
        stroke(panel, 6, Color3.fromRGB(42, 43, 49), 0)

        local shadow = Instance.new("ImageLabel")
        shadow.Name = "shadow"
        shadow.AnchorPoint = Vector2.new(0.5, 0.5)
        shadow.BackgroundTransparency = 1
        shadow.Image = SHADOW_IMAGE
        shadow.ImageColor3 = Color3.new(0, 0, 0)
        shadow.ImageTransparency = 0.75
        shadow.Position = UDim2.fromScale(0.5, 0.5)
        shadow.Size = UDim2.new(1, 35, 1, 35)
        shadow.ZIndex = 1000
        shadow.Parent = panel

        local background = Instance.new("ImageLabel")
        background.Name = "background"
        background.AnchorPoint = Vector2.new(0, 1)
        background.BackgroundTransparency = 1
        background.Image = PANEL_PATTERN
        background.ImageColor3 = Color3.fromRGB(20, 58, 67)
        background.ImageTransparency = 0.95
        background.Position = UDim2.fromScale(0, 1)
        background.Size = UDim2.fromScale(1, 1)
        background.ZIndex = 1002
        background.Parent = panel
        corner(background, 16)

        local contents = Instance.new("Frame")
        contents.Name = "Contents"
        contents.BackgroundColor3 = Color3.new(1, 1, 1)
        contents.BorderSizePixel = 0
        contents.Size = UDim2.fromScale(1, 1)
        contents.ZIndex = 1001
        contents.Parent = panel
        corner(contents, 16)

        local top = Instance.new("Frame")
        top.Name = "Top"
        top.BackgroundColor3 = Color3.new(1, 1, 1)
        top.BorderSizePixel = 0
        top.Size = UDim2.fromScale(1, 0.15)
        top.ZIndex = 1002
        top.Parent = panel
        corner(top, 16)
        local topGradient = Instance.new("UIGradient")
        topGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(55, 195, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(94, 239, 255)),
        })
        topGradient.Parent = top

        local title = textLabel(top, "Title", settings.Title or (settings.Error and "Oops!" or "Hey!"), 1003)
        title.AnchorPoint = Vector2.new(0.5, 0.5)
        title.Position = UDim2.fromScale(0.5, 0.5)
        title.Size = UDim2.fromScale(0.9, 0.675)
        title.TextColor3 = Color3.new(1, 1, 1)
        stroke(title, 2.9, Color3.new(0, 0, 0), 0)

        local desc = textLabel(contents, "Desc", settings.Desc or settings.Message or "", 1007)
        desc.AnchorPoint = Vector2.new(0.5, 0)
        desc.Position = UDim2.fromScale(0.5, 0.165)
        desc.Size = UDim2.fromScale(0.9, 0.55)
        desc.TextColor3 = Color3.fromRGB(42, 43, 49)

        local iconSource = settings.Icon or (settings.Error and ERROR_ICON or nil)
        if iconSource then
            desc.Size = UDim2.fromScale(0.85, 0.25)
            local icon = Instance.new("ImageLabel")
            icon.Name = "CustomIcon"
            icon.AnchorPoint = Vector2.new(0.5, 0)
            icon.BackgroundTransparency = 1
            icon.Image = tostring(iconSource)
            icon.ImageColor3 = settings.IconColor or Color3.new(1, 1, 1)
            icon.Position = UDim2.fromScale(0.5, 0.44)
            icon.ScaleType = Enum.ScaleType.Fit
            icon.Size = UDim2.fromScale(0.8, 0.235)
            icon.ZIndex = 1008
            icon.Parent = contents
        end

        local close
        if mode ~= "choice" or settings.CloseButton == true then
            close = makeButton(panel, "Close", "X", UDim2.fromScale(0.991, 0), RED, 1050)
            close.Size = UDim2.new(0, 45, 0, 45)
        end

        local buttons = {}
        if mode == "message" then
            buttons.Ok = makeButton(contents, "Ok", settings.OkText or "Ok!", UDim2.fromScale(0.5, 0.8641), GREEN)
        elseif mode == "confirm" then
            buttons.Yes, buttons.YesGradient = makeButton(contents, "Yes", settings.YesText or "Yes!", UDim2.fromScale(0.25, 0.8641), GREEN)
            buttons.No = makeButton(contents, "No", settings.NoText or "No", UDim2.fromScale(0.75, 0.8641), RED)
            if settings.TimedLock and tonumber(settings.TimedLock) and tonumber(settings.TimedLock) > 0 then
                buttons.Bar = makeCircularBar(buttons.Yes)
            end
        else
            local options = type(settings.Options) == "table" and settings.Options or {"Option 1", "Option 2"}
            buttons.Option1 = makeButton(contents, "Option1", tostring(options[1] or "Option 1"), UDim2.fromScale(0.25, 0.8641), BLUE)
            buttons.Option2 = makeButton(contents, "Option2", tostring(options[2] or "Option 2"), UDim2.fromScale(0.75, 0.8641), BLUE)
        end

        return overlay, buttons, close
    end

    local function showModal(window, settings, mode)
        if not window.Screen or window._PopupModalOpen then
            return nil
        end
        window._PopupModalOpen = true
        settings = type(settings) == "table" and cloneTable(settings) or {Desc = tostring(settings or "")}
        settings.Desc = tostring(settings.Desc or settings.Message or "")

        local overlay, buttons, close = makeModal(window, settings, mode)
        local done = Instance.new("BindableEvent")
        local result
        local finished = false
        local connections = {}
        local started = os.clock()

        local function finish(value)
            if finished then
                return
            end
            finished = true
            result = value
            safeCall(settings.Callback, value)
            done:Fire()
        end

        if close then
            table.insert(connections, close.Activated:Connect(function()
                finish(mode == "confirm" and false or nil)
            end))
        end
        if buttons.Ok then
            table.insert(connections, buttons.Ok.Activated:Connect(function()
                finish(nil)
            end))
        end
        if buttons.No then
            table.insert(connections, buttons.No.Activated:Connect(function()
                finish(false)
            end))
        end
        if buttons.Yes then
            table.insert(connections, buttons.Yes.Activated:Connect(function()
                local lock = tonumber(settings.TimedLock) or 0
                if os.clock() - started >= lock then
                    finish(true)
                end
            end))
        end
        if buttons.Option1 then
            table.insert(connections, buttons.Option1.Activated:Connect(function()
                finish(1)
            end))
            table.insert(connections, buttons.Option2.Activated:Connect(function()
                finish(2)
            end))
        end
        table.insert(connections, overlay.AncestryChanged:Connect(function(_, parent)
            if parent == nil then
                finish(mode == "confirm" and false or nil)
            end
        end))

        if buttons.Bar then
            buttons.Bar.Visible = true
            buttons.YesGradient.Color = GREY
            task.spawn(function()
                local duration = tonumber(settings.TimedLock) or 0
                while not finished and overlay.Parent do
                    local elapsed = os.clock() - started
                    setCircularProgress(buttons.Bar, 1 - math.clamp(elapsed, 0, duration) / duration)
                    if elapsed >= duration then
                        break
                    end
                    RunService.RenderStepped:Wait()
                end
                if buttons.Bar and buttons.Bar.Parent then
                    buttons.Bar.Visible = false
                end
                if buttons.YesGradient and buttons.YesGradient.Parent then
                    buttons.YesGradient.Color = GREEN
                end
            end)
        end

        done.Event:Wait()
        for _, connection in ipairs(connections) do
            connection:Disconnect()
        end
        if overlay.Parent then
            overlay:Destroy()
        end
        done:Destroy()
        window._PopupModalOpen = nil
        return result
    end

    function Library:MessagePopup(settings)
        return showModal(self, settings, "message")
    end

    function Library:ConfirmPopup(settings)
        return showModal(self, settings, "confirm")
    end

    function Library:ChoicePopup(settings)
        return showModal(self, settings, "choice")
    end

    local function augmentParent(parent, window)
        if type(parent) ~= "table" or parent.__PopupParentAugmented then
            return parent
        end
        parent.__PopupParentAugmented = true
        function parent:ErrorPopup(...)
            return window:ErrorPopup(...)
        end
        function parent:MessagePopup(...)
            return window:MessagePopup(...)
        end
        function parent:ConfirmPopup(...)
            return window:ConfirmPopup(...)
        end
        function parent:ChoicePopup(...)
            return window:ChoicePopup(...)
        end
        return parent
    end

    local BaseAddSection = Library.AddSection
    function Library:AddSection(...)
        return augmentParent(BaseAddSection(self, ...), self)
    end

    local BaseAddSubTab = Library.AddSubTab
    if type(BaseAddSubTab) == "function" then
        function Library:AddSubTab(...)
            return augmentParent(BaseAddSubTab(self, ...), self)
        end
    end

    local BaseCreateTab = Library.CreateTab
    function Library:CreateTab(...)
        return augmentParent(BaseCreateTab(self, ...), self)
    end

    Library.FeaturePack = Library.FeaturePack or {}
    Library.FeaturePack.Popup = true
    return Library
end
