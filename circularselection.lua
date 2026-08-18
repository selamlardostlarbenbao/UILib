return function(Library)
    if type(Library) ~= "table" then
        error("circularselection.lua expected the necker Library table", 2)
    end
    if Library.__NeckerCircularSelectionInstalled then
        return Library
    end
    Library.__NeckerCircularSelectionInstalled = true

    local UserInputService = game:GetService("UserInputService")
    local TweenService = game:GetService("TweenService")
    local RunService = game:GetService("RunService")

    local SELECT_IMAGES = {
        Normal = {"rbxassetid://13744994506", "rbxassetid://13745368416"},
        Huge = {"rbxassetid://15276476580", "rbxassetid://15276518483"},
    }
    local SELECT_TWEEN = TweenInfo.new(0.2, Enum.EasingStyle.Circular, Enum.EasingDirection.Out)
    local DIAL_OPEN_TWEEN = TweenInfo.new(0.15, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
    local DIAL_CLOSE_TWEEN = TweenInfo.new(0.2, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
    local DIAL_COLOR = Color3.fromRGB(113, 255, 62)
    local DIAL_WARNING = Color3.fromRGB(255, 233, 65)
    local DIAL_DISABLED = Color3.fromRGB(85, 85, 85)

    local function copyTable(source)
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
            warn("CircularSelection: " .. tostring(message))
        end
    end

    local function roundIncrement(value, increment)
        local remainder = value % increment
        if increment / 2 <= remainder then
            return value + increment - remainder
        end
        return value - remainder
    end

    local function newSelectOverlay(parent, huge)
        local overlay = Instance.new("ImageLabel")
        overlay.Name = "Select"
        overlay.AnchorPoint = Vector2.new(0.5, 0.5)
        overlay.BackgroundTransparency = 1
        overlay.BorderSizePixel = 1
        overlay.Image = SELECT_IMAGES[huge and "Huge" or "Normal"][1]
        overlay.ImageColor3 = Color3.new(0, 0, 0)
        overlay.Position = UDim2.fromScale(0.5, 0.5)
        overlay.Size = UDim2.fromScale(1, 1)
        overlay.Visible = false
        overlay.ZIndex = 50
        overlay.Parent = parent
        return overlay
    end

    local function setCircularProgress(frame, progress)
        progress = math.clamp(progress, 0.0001, 1)
        local left = frame:FindFirstChild("Left")
        local right = frame:FindFirstChild("Right")
        local leftGradient = left and left:FindFirstChildOfClass("UIGradient")
        local rightGradient = right and right:FindFirstChildOfClass("UIGradient")
        if not leftGradient or not rightGradient then
            return
        end
        rightGradient.Rotation = math.clamp(progress * 2, 0, 1) * 180
        leftGradient.Rotation = math.clamp((progress - 0.5) * 2, 0, 1) * 180 + 180
        rightGradient.Enabled = progress < 0.5
        leftGradient.Enabled = progress < 1
    end

    local function newDial(parent)
        local dial = Instance.new("Frame")
        dial.Name = "Dial"
        dial.AnchorPoint = Vector2.new(0.5, 0.5)
        dial.BackgroundTransparency = 1
        dial.Position = UDim2.fromScale(0.5, 0.5)
        dial.Size = UDim2.new(0.8, 0, 0.35, 0)
        dial.ZIndex = 2000
        dial.Parent = parent

        for _, side in ipairs({
            {"Left", "rbxassetid://8897745728"},
            {"Right", "rbxassetid://8897746094"},
        }) do
            local image = Instance.new("ImageLabel")
            image.Name = side[1]
            image.AnchorPoint = Vector2.new(0.5, 0.5)
            image.BackgroundTransparency = 1
            image.Image = side[2]
            image.ImageColor3 = DIAL_COLOR
            image.Position = UDim2.fromScale(0.5, 0.5)
            image.ScaleType = Enum.ScaleType.Fit
            image.Size = UDim2.fromScale(1, 1)
            image.ZIndex = 2000
            image.Parent = dial

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

        local background = Instance.new("Frame")
        background.Name = "background"
        background.AnchorPoint = Vector2.new(0.5, 0.5)
        background.BackgroundColor3 = Color3.new(0, 0, 0)
        background.BorderSizePixel = 1
        background.Position = UDim2.fromScale(0.5, 0.5)
        background.Size = UDim2.new(1.1, 2, 1.1, 2)
        background.ZIndex = 1900
        background.Parent = dial

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(1, 0)
        corner.Parent = background

        local quantity = Instance.new("TextLabel")
        quantity.Name = "Quantity"
        quantity.AnchorPoint = Vector2.new(0.5, 0.5)
        quantity.BackgroundTransparency = 1
        quantity.FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold)
        quantity.Position = UDim2.fromScale(0.5, 0.5)
        quantity.Size = UDim2.new(1, 0, 0.7, 0)
        quantity.Text = "0"
        quantity.TextColor3 = Color3.new(1, 1, 1)
        quantity.TextScaled = true
        quantity.TextWrapped = true
        quantity.ZIndex = 2000
        quantity.Parent = dial

        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.new(0, 0, 0)
        stroke.LineJoinMode = Enum.LineJoinMode.Round
        stroke.Thickness = 2.5
        stroke.Parent = quantity

        local aspect = Instance.new("UIAspectRatioConstraint")
        aspect.AspectRatio = 1
        aspect.Parent = dial

        local deadzone = Instance.new("Frame")
        deadzone.Name = "Deadzone"
        deadzone.AnchorPoint = Vector2.new(0.5, 0.5)
        deadzone.BackgroundColor3 = Color3.fromRGB(255, 66, 91)
        deadzone.BackgroundTransparency = 1
        deadzone.BorderSizePixel = 0
        deadzone.Position = UDim2.fromScale(0.5, 0.1)
        deadzone.Size = UDim2.fromScale(0.1, 0.2)
        deadzone.ZIndex = 2100
        deadzone.Parent = dial

        local zero = Instance.new("TextLabel")
        zero.Name = "zero"
        zero.AnchorPoint = Vector2.new(0.5, 1)
        zero.BackgroundTransparency = 1
        zero.FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Heavy)
        zero.Position = UDim2.fromScale(0.5, -0.15)
        zero.Size = UDim2.fromScale(2, 1.3)
        zero.Text = "0"
        zero.TextColor3 = deadzone.BackgroundColor3
        zero.TextScaled = true
        zero.TextTransparency = 1
        zero.TextWrapped = true
        zero.ZIndex = 2100
        zero.Parent = deadzone

        setCircularProgress(dial, 1)
        return dial
    end

    local function attachDial(parent, maximum, increment, initial, changed)
        local dial = newDial(parent)
        local quantity = math.clamp(tonumber(initial) or maximum, 0, maximum)
        local tracking = false
        local connection

        local function update()
            local stepped = increment > 1
            local validStep = not stepped or quantity % increment == 0 or quantity > 100
            local enough = quantity >= increment
            dial.Quantity.Text = tostring(quantity)
            dial.Quantity.TextColor3 = quantity > 0 and (validStep and Color3.new(1, 1, 1) or Color3.fromRGB(181, 181, 181)) or Color3.fromRGB(255, 205, 205)
            local color = validStep and DIAL_COLOR or (enough and DIAL_WARNING or DIAL_DISABLED)
            dial.Left.ImageColor3 = color
            dial.Right.ImageColor3 = color
            setCircularProgress(dial, math.clamp(quantity / maximum, 0.001, 0.999))
            safeCall(changed, quantity)
        end

        local function stopTracking()
            if not tracking then
                return quantity
            end
            tracking = false
            if connection then
                connection:Disconnect()
                connection = nil
            end
            TweenService:Create(dial, DIAL_CLOSE_TWEEN, {Size = UDim2.new(0.35, 0, 1, 0)}):Play()
            TweenService:Create(dial.Deadzone, DIAL_CLOSE_TWEEN, {BackgroundTransparency = 1}):Play()
            TweenService:Create(dial.Deadzone.zero, DIAL_CLOSE_TWEEN, {TextTransparency = 1}):Play()
            return quantity
        end

        local function startTracking()
            if tracking then
                return
            end
            tracking = true
            TweenService:Create(dial, DIAL_OPEN_TWEEN, {Size = UDim2.new(0.75, 0, 1, 0)}):Play()
            TweenService:Create(dial.Deadzone, DIAL_OPEN_TWEEN, {BackgroundTransparency = 0}):Play()
            TweenService:Create(dial.Deadzone.zero, DIAL_OPEN_TWEEN, {TextTransparency = 0}):Play()
            local lastAlpha = quantity / maximum
            connection = RunService.RenderStepped:Connect(function()
                if not dial.Parent then
                    return
                end
                local mouse = UserInputService:GetMouseLocation()
                local center = dial.AbsolutePosition + dial.AbsoluteSize / 2
                local offset = mouse - center
                local angle = (math.deg(math.atan2(offset.Y, offset.X)) + 90) % 360
                local alpha = (angle <= 6 or angle >= 354) and 0 or (angle - 6) / 348

                if (alpha >= 1 or alpha <= 0.25) and lastAlpha > 0.75 then
                    alpha = 1
                elseif (alpha <= 0 or alpha >= 0.75) and lastAlpha < 0.25 then
                    alpha = 0
                else
                    lastAlpha = alpha
                end

                if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                    alpha = 1
                    lastAlpha = 1
                end

                local nextQuantity
                if maximum >= 100000 then
                    nextQuantity = math.round(math.floor(maximum * alpha / 100 + 0.5) * 100)
                elseif maximum >= 10000 then
                    nextQuantity = math.round(math.floor(maximum * alpha / 25 + 0.5) * 25)
                elseif maximum >= 1000 then
                    nextQuantity = math.round(math.floor(maximum * alpha / 5 + 0.5) * 5)
                else
                    nextQuantity = math.round(maximum * alpha)
                end
                if increment * 5 <= maximum then
                    nextQuantity = roundIncrement(nextQuantity, increment)
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
                    nextQuantity = 1
                end
                nextQuantity = math.clamp(nextQuantity, 0, maximum)
                if nextQuantity ~= quantity then
                    quantity = nextQuantity
                    update()
                end
            end)
        end

        local function set(value)
            quantity = math.clamp(tonumber(value) or 0, 0, maximum)
            update()
        end

        local function destroy()
            stopTracking()
            if dial.Parent then
                dial:Destroy()
            end
        end

        update()
        return dial, startTracking, stopTracking, set, destroy
    end

    local function normalizeItem(value, index)
        if type(value) ~= "table" then
            return {
                Name = tostring(value),
                Value = value,
                Key = value,
                Max = 1,
                Increment = 1,
                Index = index,
            }
        end
        local item = copyTable(value)
        item.Name = tostring(item.Name or item.Text or item.Value or item.Key or index)
        item.Value = item.Value ~= nil and item.Value or item.Name
        item.Key = item.Key ~= nil and item.Key or item.Value
        item.Icon = item.Icon or item.Image
        item.Max = math.max(1, tonumber(item.Max or item.Amount or item.Quantity) or 1)
        item.Increment = math.max(1, tonumber(item.Increment or item.Step) or 1)
        item.Index = index
        return item
    end

    function Library:AddCircularSelection(selectionSettings)
        local settings = type(selectionSettings) == "table" and copyTable(selectionSettings) or {Name = tostring(selectionSettings)}
        settings.Name = tostring(settings.Name or "Circular Selection")
        settings.Items = settings.Items or settings.Options or {}
        settings.Callback = settings.Callback or function() end
        settings.ItemCallback = settings.ItemCallback or settings.OnItemChanged
        settings.Columns = math.max(1, math.floor(tonumber(settings.Columns) or 4))
        settings.ItemHeight = math.max(48, tonumber(settings.ItemHeight) or 68)
        settings.Multiple = settings.Multiple ~= false and settings.Multi ~= false
        settings.MaxSelected = tonumber(settings.MaxSelected)

        local items = {}
        for index, value in ipairs(settings.Items) do
            items[index] = normalizeItem(value, index)
        end

        local rows = math.max(1, math.ceil(#items / settings.Columns))
        local rowHeight = 34 + rows * settings.ItemHeight + math.max(0, rows - 1) * 6 + 8
        local row = self.Templates.Selector:Clone()
        local aspect = row:FindFirstChildOfClass("UIAspectRatioConstraint")
        if aspect then
            aspect:Destroy()
        end
        row.ClipsDescendants = false
        row.Size = UDim2.new(1, 0, 0, rowHeight)
        row.SettingName.AnchorPoint = Vector2.zero
        row.SettingName.Position = UDim2.fromOffset(4, 0)
        row.SettingName.Size = UDim2.new(1, -8, 0, 28)
        row.SettingName.Text = settings.Name
        row.Toggle.Visible = false

        local holder = Instance.new("Frame")
        holder.Name = "CircularSelection"
        holder.BackgroundTransparency = 1
        holder.Position = UDim2.fromOffset(4, 34)
        holder.Size = UDim2.new(1, -8, 1, -38)
        holder.Parent = row

        local grid = Instance.new("UIGridLayout")
        grid.CellPadding = UDim2.fromOffset(6, 6)
        grid.CellSize = UDim2.new(1 / settings.Columns, -6, 0, settings.ItemHeight)
        grid.FillDirectionMaxCells = settings.Columns
        grid.SortOrder = Enum.SortOrder.LayoutOrder
        grid.Parent = holder

        self:_mount(row, settings.Name, settings.Name)

        local selection = {}
        local controls = {}
        local tooltipDisconnects = {}
        local listeners = {}
        local destroyed = false

        local function selectedCount()
            local count = 0
            for _, quantity in pairs(selection) do
                if quantity > 0 then
                    count += 1
                end
            end
            return count
        end

        local function emit(item, oldQuantity)
            if destroyed then
                return
            end
            local snapshot = copyTable(selection)
            safeCall(settings.Callback, snapshot)
            if item then
                safeCall(settings.ItemCallback, item.Key, selection[item.Key] or 0, oldQuantity or 0, item)
            end
            for _, callback in ipairs(listeners) do
                safeCall(callback, snapshot)
            end
        end

        local function setAppearance(entry, selected)
            local wasSelected = entry.Selected
            entry.Selected = selected
            entry.Overlay.Visible = selected
            if not selected then
                entry.Overlay:SetAttribute("Showing", false)
                entry.FlashToken += 1
                entry.Overlay.Size = UDim2.fromScale(1, 1)
                return
            end
            if wasSelected and entry.Overlay:GetAttribute("Showing") then
                return
            end
            entry.Overlay:SetAttribute("Showing", true)
            entry.FlashToken += 1
            entry.Overlay.Size = UDim2.fromScale(1.2, 1.2)
            TweenService:Create(entry.Overlay, SELECT_TWEEN, {Size = UDim2.fromScale(1, 1)}):Play()
            local token = entry.FlashToken
            task.spawn(function()
                local images = SELECT_IMAGES[entry.Item.Huge and "Huge" or "Normal"]
                while entry.Selected and entry.Overlay.Parent and entry.FlashToken == token do
                    entry.Overlay.Image = os.clock() % 1 > 0.5 and images[1] or images[2]
                    task.wait(0.1)
                end
            end)
        end

        local function setQuantity(entry, quantity, silent)
            quantity = math.clamp(math.floor(tonumber(quantity) or 0), 0, entry.Item.Max)
            local oldQuantity = selection[entry.Item.Key] or 0
            if quantity > 0 and oldQuantity <= 0 then
                if not settings.Multiple then
                    for key, other in pairs(controls) do
                        if other ~= entry and (selection[key] or 0) > 0 then
                            selection[key] = nil
                            if other.DialDestroy then
                                other.DialDestroy()
                                other.DialDestroy = nil
                            end
                            setAppearance(other, false)
                            other.Quantity.Text = other.Item.Max > 1 and ("x" .. tostring(other.Item.Max)) or ""
                        end
                    end
                elseif settings.MaxSelected and selectedCount() >= settings.MaxSelected then
                    return false
                end
            end

            if quantity <= 0 then
                selection[entry.Item.Key] = nil
                if entry.DialDestroy and not entry.DialTracking then
                    entry.DialDestroy()
                    entry.DialDestroy = nil
                end
                setAppearance(entry, false)
            else
                selection[entry.Item.Key] = quantity
                setAppearance(entry, true)
            end
            entry.Quantity.Text = entry.Item.Max > 1 and ("x" .. tostring(quantity > 0 and quantity or entry.Item.Max)) or ""
            if not silent and oldQuantity ~= quantity then
                emit(entry.Item, oldQuantity)
            end
            return true
        end

        local function ensureDial(entry, startTracking)
            if entry.Item.Max <= 1 then
                return
            end
            if not entry.DialDestroy then
                local dial, start, stop, set, destroy = attachDial(entry.Button, entry.Item.Max, entry.Item.Increment, selection[entry.Item.Key] or entry.Item.Max, function(quantity)
                    setQuantity(entry, quantity, false)
                end)
                entry.Dial = dial
                entry.DialStart = function()
                    entry.DialTracking = true
                    start()
                end
                entry.DialStop = function()
                    local quantity = stop()
                    entry.DialTracking = false
                    return quantity
                end
                entry.DialSet = set
                entry.DialDestroy = function()
                    entry.DialTracking = false
                    destroy()
                end
            end
            if startTracking and entry.DialStart then
                entry.DialStart()
            end
        end

        for _, item in ipairs(items) do
            local button = self.Templates.Selector.Toggle.Button:Clone()
            button.Name = item.Name
            button.Active = item.Selectable ~= false and item.Disabled ~= true
            button.AutoButtonColor = false
            button.AnchorPoint = Vector2.zero
            button.LayoutOrder = item.Index
            button.Size = UDim2.fromScale(1, 1)
            local buttonAspect = button:FindFirstChildOfClass("UIAspectRatioConstraint")
            if buttonAspect then
                buttonAspect:Destroy()
            end
            button.Parent = holder

            local label = button:FindFirstChild("TextLabel")
            if label then
                label.AnchorPoint = Vector2.new(0.5, 1)
                label.Position = UDim2.fromScale(0.5, 0.97)
                label.Size = UDim2.new(0.92, 0, 0.28, 0)
                label.Text = item.Name
                label.ZIndex = 12
            end

            local icon = Instance.new("ImageLabel")
            icon.Name = "Icon"
            icon.AnchorPoint = Vector2.new(0.5, 0.5)
            icon.BackgroundTransparency = 1
            icon.Image = tostring(item.Icon or "")
            icon.Position = UDim2.fromScale(0.5, 0.42)
            icon.ScaleType = Enum.ScaleType.Fit
            icon.Size = item.Icon and UDim2.fromScale(0.64, 0.64) or UDim2.fromScale(0, 0)
            icon.ZIndex = 11
            icon.Parent = button

            local quantity = Instance.new("TextLabel")
            quantity.Name = "Quantity"
            quantity.AnchorPoint = Vector2.new(1, 0)
            quantity.BackgroundTransparency = 1
            quantity.FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold)
            quantity.Position = UDim2.new(1, -5, 0, 3)
            quantity.Size = UDim2.fromScale(0.44, 0.28)
            quantity.Text = item.Max > 1 and ("x" .. tostring(item.Max)) or ""
            quantity.TextColor3 = Color3.new(1, 1, 1)
            quantity.TextScaled = true
            quantity.TextXAlignment = Enum.TextXAlignment.Right
            quantity.ZIndex = 12
            quantity.Parent = button

            local quantityStroke = Instance.new("UIStroke")
            quantityStroke.Color = Color3.new(0, 0, 0)
            quantityStroke.Thickness = 1.5
            quantityStroke.Parent = quantity

            local overlay = newSelectOverlay(button, item.Huge == true)
            local entry = {
                Item = item,
                Button = button,
                Overlay = overlay,
                Quantity = quantity,
                Selected = false,
                FlashToken = 0,
            }
            controls[item.Key] = entry

            if type(self.AttachItemTooltip) == "function" and item.Tooltip ~= false then
                table.insert(tooltipDisconnects, self:AttachItemTooltip(button, item.Tooltip or item.Name))
            end

            if item.Max > 1 then
                button.MouseButton1Down:Connect(function()
                    if not button.Active then
                        return
                    end
                    entry.PressedSelected = entry.Selected
                    entry.PressTime = os.clock()
                    if not entry.Selected and not setQuantity(entry, entry.Item.Max, false) then
                        return
                    end
                    ensureDial(entry, true)
                end)
                button.MouseButton1Up:Connect(function()
                    local quickDeselect = entry.PressedSelected and entry.Selected and entry.PressTime and os.clock() - entry.PressTime <= 0.15
                    local value = entry.DialStop and entry.DialStop() or (selection[entry.Item.Key] or 0)
                    if quickDeselect or value <= 0 then
                        setQuantity(entry, 0, false)
                    end
                    entry.PressedSelected = nil
                    entry.PressTime = nil
                end)
            else
                button.Activated:Connect(function()
                    if button.Active then
                        setQuantity(entry, entry.Selected and 0 or 1, false)
                    end
                end)
            end
        end

        local rawControl = {}
        function rawControl:Get()
            return copyTable(selection)
        end
        function rawControl:Set(value, silent)
            value = type(value) == "table" and value or {}
            for key, entry in pairs(controls) do
                local quantity = tonumber(value[key]) or 0
                setQuantity(entry, quantity, true)
                if quantity > 0 and entry.Item.Max > 1 then
                    ensureDial(entry, false)
                    if entry.DialSet then
                        entry.DialSet(quantity)
                    end
                end
            end
            if not silent then
                emit()
            end
            return self:Get()
        end
        function rawControl:SetItem(key, quantity, silent)
            local entry = controls[key]
            if not entry then
                return false
            end
            local ok = setQuantity(entry, quantity, silent)
            if ok and tonumber(quantity) and tonumber(quantity) > 0 and entry.Item.Max > 1 then
                ensureDial(entry, false)
                if entry.DialSet then
                    entry.DialSet(quantity)
                end
            end
            return ok
        end
        function rawControl:Clear(silent)
            return self:Set({}, silent)
        end
        function rawControl:OnChanged(callback)
            assert(type(callback) == "function", "CircularSelection OnChanged callback must be a function")
            table.insert(listeners, callback)
            local connected = true
            return {
                Disconnect = function()
                    if not connected then
                        return
                    end
                    connected = false
                    local index = table.find(listeners, callback)
                    if index then
                        table.remove(listeners, index)
                    end
                end,
            }
        end
        function rawControl:Destroy()
            destroyed = true
            for _, disconnect in ipairs(tooltipDisconnects) do
                pcall(disconnect)
            end
            for _, entry in pairs(controls) do
                entry.FlashToken += 1
                if entry.DialDestroy then
                    entry.DialDestroy()
                end
            end
            if row.Parent then
                row:Destroy()
            end
        end

        local control = type(self._decorateControl) == "function" and self:_decorateControl(rawControl, row, settings, "CircularSelection") or rawControl
        control.Items = controls
        control.Container = holder

        if settings.Default then
            control:Set(settings.Default, true)
        end
        if type(self._featureScanTheme) == "function" then
            self:_featureScanTheme(row)
        end
        return control
    end

    local function augmentParent(parent, window)
        if type(parent) ~= "table" or parent.__CircularSelectionParentAugmented then
            return parent
        end
        parent.__CircularSelectionParentAugmented = true
        if type(parent._add) == "function" then
            function parent:AddCircularSelection(...)
                return self:_add("AddCircularSelection", ...)
            end
        elseif parent.Name and parent.Window == window then
            function parent:AddCircularSelection(...)
                return self.Window:_withTab(self.Name, "AddCircularSelection", ...)
            end
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
    Library.FeaturePack.CircularSelection = true
    return Library
end
