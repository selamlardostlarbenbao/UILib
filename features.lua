return function(Library)
    if type(Library) ~= "table" then
        error("features.lua expected the necker Library table", 2)
    end
    if Library.__NeckerLinoriaFeaturePackInstalled then
        return Library
    end
    Library.__NeckerLinoriaFeaturePackInstalled = true

    local UserInputService = game:GetService("UserInputService")
    local TweenService = game:GetService("TweenService")
    local GuiService = game:GetService("GuiService")

    local BUTTON_DOWN = TweenInfo.new(0.065, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
    local BUTTON_UP = TweenInfo.new(0.25, Enum.EasingStyle.Circular, Enum.EasingDirection.Out)
    local BUTTON_HOVER = TweenInfo.new(0.05, Enum.EasingStyle.Circular, Enum.EasingDirection.Out)
    local BUTTON_LEAVE = TweenInfo.new(0.035, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)

    local function safeCall(callback, ...)
        if type(callback) ~= "function" then
            return true
        end
        local ok, result = pcall(callback, ...)
        if not ok then
            warn("Necker feature pack: " .. tostring(result))
        end
        return ok, result
    end

    local function cloneTable(source)
        local result = {}
        if type(source) == "table" then
            for key, value in pairs(source) do
                result[key] = value
            end
        end
        return result
    end

    local function copyColor(color)
        return Color3.new(color.R, color.G, color.B)
    end

    local function colorToHex(color)
        return string.format(
            "#%02X%02X%02X",
            math.clamp(math.floor(color.R * 255 + 0.5), 0, 255),
            math.clamp(math.floor(color.G * 255 + 0.5), 0, 255),
            math.clamp(math.floor(color.B * 255 + 0.5), 0, 255)
        )
    end

    local function colorToRGBText(color)
        return string.format(
            "%d, %d, %d",
            math.clamp(math.floor(color.R * 255 + 0.5), 0, 255),
            math.clamp(math.floor(color.G * 255 + 0.5), 0, 255),
            math.clamp(math.floor(color.B * 255 + 0.5), 0, 255)
        )
    end

    local function colorToTable(color)
        return {
            R = math.clamp(math.floor(color.R * 255 + 0.5), 0, 255),
            G = math.clamp(math.floor(color.G * 255 + 0.5), 0, 255),
            B = math.clamp(math.floor(color.B * 255 + 0.5), 0, 255),
        }
    end

    local function parseColor(value, fallback)
        if typeof(value) == "Color3" then
            return value
        end
        if type(value) == "table" then
            local r = tonumber(value.R or value.r or value[1])
            local g = tonumber(value.G or value.g or value[2])
            local b = tonumber(value.B or value.b or value[3])
            if r and g and b then
                if r > 1 or g > 1 or b > 1 then
                    return Color3.fromRGB(
                        math.clamp(math.floor(r + 0.5), 0, 255),
                        math.clamp(math.floor(g + 0.5), 0, 255),
                        math.clamp(math.floor(b + 0.5), 0, 255)
                    )
                end
                return Color3.new(math.clamp(r, 0, 1), math.clamp(g, 0, 1), math.clamp(b, 0, 1))
            end
        end
        if type(value) == "string" then
            local text = value:gsub("^%s+", ""):gsub("%s+$", "")
            local hex = text:gsub("#", "")
            if #hex == 6 and hex:match("^[%da-fA-F]+$") then
                local number = tonumber(hex, 16)
                if number then
                    return Color3.fromRGB(
                        math.floor(number / 65536) % 256,
                        math.floor(number / 256) % 256,
                        number % 256
                    )
                end
            end
            local r, g, b = text:match("^(%d+)%s*,%s*(%d+)%s*,%s*(%d+)$")
            if r and g and b then
                return Color3.fromRGB(
                    math.clamp(tonumber(r), 0, 255),
                    math.clamp(tonumber(g), 0, 255),
                    math.clamp(tonumber(b), 0, 255)
                )
            end
        end
        return fallback or Color3.new(1, 1, 1)
    end

    local function addFeatureConnection(window, connection)
        if not connection then
            return connection
        end
        window._FeatureConnections = window._FeatureConnections or {}
        table.insert(window._FeatureConnections, connection)
        return connection
    end

    -- Lightweight Lua-side change signal used by event-driven DependencyBox.
    -- No Heartbeat/RenderStepped polling is involved.
    local function emitControlChanged(control)
        local listeners = type(control) == "table" and control._FeatureChangeListeners or nil
        if type(listeners) ~= "table" or #listeners == 0 then
            return
        end
        local value
        if type(control.Get) == "function" then
            local ok, result = pcall(control.Get, control)
            if ok then
                value = result
            end
        end
        local snapshot = {}
        for index = 1, #listeners do
            snapshot[index] = listeners[index]
        end
        for _, callback in ipairs(snapshot) do
            safeCall(callback, value, control)
        end
    end

    local function makeControlObservable(control)
        if type(control) ~= "table" then
            return control
        end
        if control._FeatureObservable then
            return control
        end
        control._FeatureObservable = true
        control._FeatureChangeListeners = control._FeatureChangeListeners or {}

        function control:OnChanged(callback)
            assert(type(callback) == "function", "OnChanged callback must be a function")
            local listeners = self._FeatureChangeListeners
            table.insert(listeners, callback)
            local connected = true
            return {
                Disconnect = function()
                    if not connected then
                        return
                    end
                    connected = false
                    for index = #listeners, 1, -1 do
                        if listeners[index] == callback then
                            table.remove(listeners, index)
                            break
                        end
                    end
                end,
            }
        end

        local mutatorNames = {
            "Set", "Deserialize", "SetState", "SetMode", "SetTransparency", "SetAlpha",
        }
        for _, methodName in ipairs(mutatorNames) do
            local baseMethod = control[methodName]
            if type(baseMethod) == "function" then
                control[methodName] = function(selfControl, ...)
                    selfControl._FeatureSetDepth = (selfControl._FeatureSetDepth or 0) + 1
                    local results = table.pack(pcall(baseMethod, selfControl, ...))
                    selfControl._FeatureSetDepth = math.max(0, (selfControl._FeatureSetDepth or 1) - 1)
                    if not results[1] then
                        error(results[2], 0)
                    end
                    if selfControl._FeatureSetDepth == 0 then
                        emitControlChanged(selfControl)
                    end
                    return table.unpack(results, 2, results.n)
                end
            end
        end
        return control
    end

    local function makeObservedCallback(holder, callback)
        return function(...)
            local control = holder.Control
            if control and (control._FeatureSetDepth or 0) == 0 then
                emitControlChanged(control)
            end
            if type(callback) == "function" then
                return callback(...)
            end
        end
    end

    local function attachButtonFX(button, hoverScale)
        if not button or not button:IsA("GuiButton") then
            return
        end
        hoverScale = tonumber(hoverScale) or 1.05
        local scale = button:FindFirstChildOfClass("UIScale")
        if not scale then
            scale = Instance.new("UIScale")
            scale.Name = "FeatureButtonScale"
            scale.Scale = 1
            scale.Parent = button
        end
        local normalGoal = {Scale = 1}
        local downGoal = {Scale = 0.9}
        local hoverGoal = {Scale = hoverScale}
        local hovering = false
        local pressed = false

        button.MouseEnter:Connect(function()
            hovering = true
            if not pressed then
                TweenService:Create(scale, BUTTON_HOVER, hoverGoal):Play()
            end
        end)
        button.MouseLeave:Connect(function()
            hovering = false
            if not pressed then
                TweenService:Create(scale, BUTTON_LEAVE, normalGoal):Play()
            end
        end)
        button.MouseButton1Down:Connect(function()
            pressed = true
            TweenService:Create(scale, BUTTON_DOWN, downGoal):Play()
        end)
        button.MouseButton1Up:Connect(function()
            pressed = false
            TweenService:Create(scale, BUTTON_UP, hovering and hoverGoal or normalGoal):Play()
        end)
    end

    local function findButton(row)
        local toggle = row and row:FindFirstChild("Toggle")
        local button = toggle and toggle:FindFirstChild("Button")
        if button and button:IsA("GuiButton") then
            return button
        end
        if row then
            for _, descendant in ipairs(row:GetDescendants()) do
                if descendant:IsA("GuiButton") then
                    return descendant
                end
            end
        end
        return nil
    end

    local function findRowEntry(window, row)
        for _, entry in ipairs(window.Rows or {}) do
            if entry.Row == row then
                return entry
            end
        end
        return nil
    end

    local function normalizeMode(value)
        local text = string.lower(tostring(value or "Toggle"))
        if text == "always" then
            return "Always"
        elseif text == "hold" then
            return "Hold"
        end
        return "Toggle"
    end

    local function getMousePosition()
        local point = UserInputService:GetMouseLocation()
        local ok, inset = pcall(GuiService.GetGuiInset, GuiService)
        if ok and inset then
            point = point - inset
        end
        return point
    end

    ---------------------------------------------------------------------------
    -- Live theme registry. No UI colors are changed until SetTheme is called.
    ---------------------------------------------------------------------------
    local DEFAULT_THEME = {
        FontColor = Color3.new(1, 1, 1),
        MainColor = Color3.new(1, 1, 1),
        BackgroundColor = Color3.fromRGB(42, 43, 49),
        AccentColor = Color3.fromRGB(92, 239, 0),
        OutlineColor = Color3.fromRGB(42, 43, 49),
        RiskColor = Color3.fromRGB(255, 39, 125),
    }

    Library.DefaultTheme = cloneTable(DEFAULT_THEME)
    Library._FeatureWindows = Library._FeatureWindows or setmetatable({}, {__mode = "k"})
    Library._GlobalFeatureTheme = Library._GlobalFeatureTheme or {}

    local function colorBrightness(color)
        return color.R * 0.299 + color.G * 0.587 + color.B * 0.114
    end

    function Library:RegisterThemeObject(object, property, key)
        if not self.Screen then
            return nil
        end
        if typeof(object) ~= "Instance" or type(property) ~= "string" or type(key) ~= "string" then
            return nil
        end
        local ok, original = pcall(function()
            return object[property]
        end)
        if not ok or typeof(original) ~= "Color3" then
            return nil
        end
        self._FeatureThemeBindings = self._FeatureThemeBindings or {}
        self._FeatureThemeBindingIndex = self._FeatureThemeBindingIndex or setmetatable({}, {__mode = "k"})
        local objectIndex = self._FeatureThemeBindingIndex[object]
        if not objectIndex then
            objectIndex = {}
            self._FeatureThemeBindingIndex[object] = objectIndex
        end
        if objectIndex[property] then
            return objectIndex[property]
        end
        local binding = {
            Object = object,
            Property = property,
            Key = key,
            Original = original,
        }
        objectIndex[property] = binding
        table.insert(self._FeatureThemeBindings, binding)
        local override = self._FeatureThemeOverrides and self._FeatureThemeOverrides[key]
        if override then
            pcall(function()
                object[property] = override
            end)
        end
        return binding
    end

    function Library:_featureScanTheme(root)
        if not self.Screen then
            return
        end
        root = root or self.Screen
        local objects = {root}
        for _, descendant in ipairs(root:GetDescendants()) do
            table.insert(objects, descendant)
        end
        for _, object in ipairs(objects) do
            if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
                local brightness = colorBrightness(object.TextColor3)
                if brightness >= 0.72 then
                    self:RegisterThemeObject(object, "TextColor3", "FontColor")
                end
            end
            if object:IsA("UIStroke") then
                self:RegisterThemeObject(object, "Color", "OutlineColor")
            end
            if object:IsA("GuiObject") and object.BackgroundTransparency < 0.95 then
                local name = string.lower(object.Name)
                local brightness = colorBrightness(object.BackgroundColor3)
                if name:find("close", 1, true) or name:find("danger", 1, true) or name:find("delete", 1, true) then
                    self:RegisterThemeObject(object, "BackgroundColor3", "RiskColor")
                elseif name:find("progress", 1, true) or name:find("statuson", 1, true) or name:find("accent", 1, true) then
                    self:RegisterThemeObject(object, "BackgroundColor3", "AccentColor")
                elseif brightness <= 0.45 then
                    self:RegisterThemeObject(object, "BackgroundColor3", "BackgroundColor")
                elseif brightness >= 0.82 then
                    self:RegisterThemeObject(object, "BackgroundColor3", "MainColor")
                end
            end
        end
    end

    function Library:ApplyTheme()
        if not self.Screen then
            return self
        end
        self:_featureScanTheme(self.Screen)
        for _, binding in ipairs(self._FeatureThemeBindings or {}) do
            local object = binding.Object
            if object and object.Parent then
                local color = self._FeatureThemeOverrides and self._FeatureThemeOverrides[binding.Key]
                if color then
                    pcall(function()
                        object[binding.Property] = color
                    end)
                end
            end
        end
        return self
    end

    function Library:SetTheme(theme)
        if not self.Screen then
            return self:SetGlobalTheme(theme)
        end
        if type(theme) ~= "table" then
            return self
        end
        self._FeatureThemeOverrides = self._FeatureThemeOverrides or {}
        self.Theme = self.Theme or cloneTable(DEFAULT_THEME)
        for key, value in pairs(theme) do
            if DEFAULT_THEME[key] and typeof(value) == "Color3" then
                self._FeatureThemeOverrides[key] = value
                self.Theme[key] = value
            end
        end
        self:ApplyTheme()
        for _, callback in ipairs(self._FeatureThemeCallbacks or {}) do
            safeCall(callback, self:GetTheme())
        end
        return self
    end

    function Library:SetThemeColor(key, color)
        if typeof(color) ~= "Color3" then
            return self
        end
        return self:SetTheme({[tostring(key)] = color})
    end

    function Library:ResetThemeColor(key)
        if not self.Screen then
            return self
        end
        key = tostring(key)
        if self._FeatureThemeOverrides then
            self._FeatureThemeOverrides[key] = nil
        end
        if self.Theme and DEFAULT_THEME[key] then
            self.Theme[key] = DEFAULT_THEME[key]
        end
        for _, binding in ipairs(self._FeatureThemeBindings or {}) do
            if binding.Key == key and binding.Object and binding.Object.Parent then
                pcall(function()
                    binding.Object[binding.Property] = binding.Original
                end)
            end
        end
        return self
    end

    function Library:ResetTheme()
        if not self.Screen then
            Library._GlobalFeatureTheme = {}
            return self
        end
        self._FeatureThemeOverrides = {}
        self.Theme = cloneTable(DEFAULT_THEME)
        for _, binding in ipairs(self._FeatureThemeBindings or {}) do
            if binding.Object and binding.Object.Parent then
                pcall(function()
                    binding.Object[binding.Property] = binding.Original
                end)
            end
        end
        return self
    end

    function Library:GetTheme()
        local result = cloneTable(DEFAULT_THEME)
        local source = self.Screen and self.Theme or Library._GlobalFeatureTheme
        if type(source) == "table" then
            for key, value in pairs(source) do
                if DEFAULT_THEME[key] and typeof(value) == "Color3" then
                    result[key] = copyColor(value)
                end
            end
        end
        return result
    end

    function Library:OnThemeChanged(callback)
        if not self.Screen or type(callback) ~= "function" then
            return function() end
        end
        self._FeatureThemeCallbacks = self._FeatureThemeCallbacks or {}
        table.insert(self._FeatureThemeCallbacks, callback)
        local alive = true
        return function()
            if not alive then
                return
            end
            alive = false
            for index = #self._FeatureThemeCallbacks, 1, -1 do
                if self._FeatureThemeCallbacks[index] == callback then
                    table.remove(self._FeatureThemeCallbacks, index)
                    break
                end
            end
        end
    end

    function Library:SetGlobalTheme(theme)
        if self.Screen then
            return self:SetTheme(theme)
        end
        if type(theme) ~= "table" then
            return self
        end
        for key, value in pairs(theme) do
            if DEFAULT_THEME[key] and typeof(value) == "Color3" then
                Library._GlobalFeatureTheme[key] = value
            end
        end
        for window in pairs(Library._FeatureWindows) do
            if window and window.Screen and window.Screen.Parent then
                window:SetTheme(Library._GlobalFeatureTheme)
            end
        end
        return self
    end

    local BaseDecorateControlFeature = Library._decorateControl
    if type(BaseDecorateControlFeature) == "function" then
        function Library:_decorateControl(control, row, settings, controlType)
            local result = BaseDecorateControlFeature(self, control, row, settings, controlType)
            if self._FeatureThemeOverrides and next(self._FeatureThemeOverrides) ~= nil and row then
                self:_featureScanTheme(row)
            end
            return result
        end
    end

    ---------------------------------------------------------------------------
    -- AddInput / TextBox control.
    ---------------------------------------------------------------------------
    local function normalizeNumericText(text)
        text = tostring(text or "")
        local negative = text:sub(1, 1) == "-"
        local body = text:gsub("[^%d%.]", "")
        local firstDot = body:find("%.")
        if firstDot then
            body = body:sub(1, firstDot) .. body:sub(firstDot + 1):gsub("%.", "")
        end
        if negative then
            body = "-" .. body
        end
        return body
    end

    function Library:AddInput(inputSettings, legacyDefault, legacyCallback)
        local settings = type(inputSettings) == "table" and cloneTable(inputSettings) or {
            Name = tostring(inputSettings),
            Default = legacyDefault,
            Callback = legacyCallback,
        }
        settings.Name = tostring(settings.Name or "Input")
        settings.Default = settings.Default ~= nil and settings.Default or settings.CurrentValue
        if settings.Default == nil then
            settings.Default = ""
        end
        settings.Callback = settings.Callback or function() end
        settings.ChangedCallback = settings.ChangedCallback or settings.OnChanged
        settings.Numeric = settings.Numeric == true
        settings.Finished = settings.Finished == true

        local template = self.Templates and self.Templates.Selector
        assert(template, "AddInput requires the Selector template")
        local row = template:Clone()
        row.SettingName.Text = settings.Name
        local button = findButton(row)
        assert(button, "AddInput could not find the Selector button")
        local oldLabel = button:FindFirstChild("TextLabel")
        local input = Instance.new("TextBox")
        input.Name = "Input"
        input.Active = true
        input.BackgroundTransparency = 1
        input.BorderSizePixel = 0
        input.ClearTextOnFocus = settings.ClearTextOnFocus == true
        input.MultiLine = settings.MultiLine == true
        input.PlaceholderText = tostring(settings.Placeholder or settings.PlaceholderText or "")
        input.Size = UDim2.new(1, -10, 1, -6)
        input.Position = UDim2.fromOffset(5, 3)
        input.Text = tostring(settings.Default)
        input.TextEditable = settings.ReadOnly ~= true
        input.TextWrapped = false
        input.ZIndex = button.ZIndex + 3
        if oldLabel and oldLabel:IsA("TextLabel") then
            input.FontFace = oldLabel.FontFace
            input.TextColor3 = oldLabel.TextColor3
            input.TextScaled = oldLabel.TextScaled
            input.TextSize = oldLabel.TextSize
            input.TextStrokeColor3 = oldLabel.TextStrokeColor3
            input.TextStrokeTransparency = oldLabel.TextStrokeTransparency
            input.TextTransparency = oldLabel.TextTransparency
            input.TextXAlignment = oldLabel.TextXAlignment
            input.TextYAlignment = oldLabel.TextYAlignment
            oldLabel.Visible = false
        else
            input.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
            input.TextColor3 = Color3.new(1, 1, 1)
            input.TextScaled = true
            input.TextStrokeColor3 = Color3.new(0, 0, 0)
            input.TextStrokeTransparency = 0
        end
        input.Parent = button
        attachButtonFX(button)

        self:_mount(row, settings.Name, settings.Name .. " " .. tostring(settings.Placeholder or settings.PlaceholderText or ""))

        local changing = false
        local lastText = input.Text
        local function currentValue()
            if settings.Numeric then
                return tonumber(input.Text) or 0
            end
            return input.Text
        end
        local function emitChanged()
            safeCall(settings.ChangedCallback, currentValue())
            if not settings.Finished then
                safeCall(settings.Callback, currentValue())
            end
        end

        local textConnection = input:GetPropertyChangedSignal("Text"):Connect(function()
            if changing then
                return
            end
            if settings.Numeric then
                local normalized = normalizeNumericText(input.Text)
                if normalized ~= input.Text then
                    changing = true
                    input.Text = normalized
                    changing = false
                end
            end
            if input.Text ~= lastText then
                lastText = input.Text
                emitChanged()
            end
        end)
        local focusConnection = input.FocusLost:Connect(function(enterPressed)
            if settings.Finished then
                safeCall(settings.Callback, currentValue(), enterPressed)
            end
        end)

        local rawControl = {}
        function rawControl:Get()
            return currentValue()
        end
        function rawControl:Set(value, silent)
            local text = tostring(value == nil and "" or value)
            if settings.Numeric then
                text = normalizeNumericText(text)
            end
            changing = true
            input.Text = text
            lastText = text
            changing = false
            if not silent then
                emitChanged()
                if settings.Finished then
                    safeCall(settings.Callback, currentValue(), false)
                end
            end
            return currentValue()
        end
        function rawControl:Focus()
            input:CaptureFocus()
            return self
        end
        function rawControl:IsFocused()
            return input:IsFocused()
        end
        function rawControl:Destroy()
            textConnection:Disconnect()
            focusConnection:Disconnect()
            if row and row.Parent then
                row:Destroy()
            end
        end

        local control = self:_decorateControl(rawControl, row, settings, "Input")
        control.Input = input
        self:_featureScanTheme(row)
        return control
    end

    ---------------------------------------------------------------------------
    -- DependencyBox: logical group with Linoria-like SetupDependencies().
    ---------------------------------------------------------------------------
    local DEPENDENCY_METHODS = {
        "AddButton", "AddToggle", "AddSelector", "AddDropdown", "AddSlider",
        "AddKeybind", "AddProgress", "AddColorPicker", "AddInput", "AddCircularSelection",
    }

    local function dependencyMatches(control, expected)
        if type(control) ~= "table" or type(control.Get) ~= "function" then
            return false
        end
        local ok, value = pcall(control.Get, control)
        if not ok then
            return false
        end
        if type(expected) == "function" then
            local predicateOK, predicateResult = pcall(expected, value, control)
            return predicateOK and predicateResult == true
        end
        if type(expected) == "table" then
            for _, candidate in ipairs(expected) do
                if value == candidate then
                    return true
                end
            end
            return false
        end
        return value == expected
    end

    local function createDependencyBox(parent, window, settings)
        settings = type(settings) == "table" and cloneTable(settings) or {}
        local box = {
            Parent = parent,
            Window = window,
            Controls = {},
            Rows = {},
            Dependencies = {},
            Visible = true,
            _DependencyConnections = {},
            _PreviousManualVisible = setmetatable({}, {__mode = "k"}),
            _Destroyed = false,
        }
        if window then
            window._FeatureDependencyBoxes = window._FeatureDependencyBoxes or setmetatable({}, {__mode = "k"})
            window._FeatureDependencyBoxes[box] = true
        end

        function box:_call(methodName, ...)
            local method = self.Parent and self.Parent[methodName]
            assert(type(method) == "function", "DependencyBox parent does not support " .. tostring(methodName))
            local control = method(self.Parent, ...)
            if type(control) == "table" then
                table.insert(self.Controls, control)
                local row = control.Row
                if row then
                    table.insert(self.Rows, row)
                end
            end
            local dependencyVisible = self:_dependencyState()
            self:_setRowsVisible(dependencyVisible, true)
            return control
        end

        for _, methodName in ipairs(DEPENDENCY_METHODS) do
            box[methodName] = function(selfBox, ...)
                return selfBox:_call(methodName, ...)
            end
        end

        function box:AddDependencyBox(childSettings)
            return createDependencyBox(self, self.Window, childSettings)
        end

        function box:_dependencyState()
            if #self.Dependencies == 0 then
                return true
            end
            for _, dependency in ipairs(self.Dependencies) do
                local control = dependency[1] or dependency.Control
                local expected = dependency[2]
                if expected == nil then
                    expected = dependency.Value
                end
                if not dependencyMatches(control, expected) then
                    return false
                end
            end
            return true
        end

        function box:_setRowsVisible(visible, force)
            if self._Destroyed and not force then
                return
            end
            self.Visible = visible == true
            for _, row in ipairs(self.Rows) do
                if row and row.Parent then
                    local entry = findRowEntry(self.Window, row)
                    if entry then
                        if not self.Visible then
                            if self._PreviousManualVisible[row] == nil then
                                self._PreviousManualVisible[row] = entry.ManualVisible ~= false
                            end
                            entry.ManualVisible = false
                        else
                            local previous = self._PreviousManualVisible[row]
                            if previous ~= nil then
                                entry.ManualVisible = previous
                                self._PreviousManualVisible[row] = nil
                            else
                                entry.ManualVisible = true
                            end
                        end
                    else
                        row.Visible = self.Visible
                    end
                end
            end
            if self.Window and self.Window._refreshPagination then
                self.Window:_refreshPagination()
            end
        end

        function box:Refresh()
            local visible = self:_dependencyState()
            if visible ~= self.Visible then
                self:_setRowsVisible(visible)
            end
            return visible
        end

        function box:_disconnectDependencies()
            for _, connection in ipairs(self._DependencyConnections or {}) do
                pcall(function()
                    connection:Disconnect()
                end)
            end
            self._DependencyConnections = {}
        end

        function box:SetupDependencies(dependencies)
            self:_disconnectDependencies()
            self.Dependencies = type(dependencies) == "table" and dependencies or {}
            for _, dependency in ipairs(self.Dependencies) do
                local control = dependency[1] or dependency.Control
                if type(control) == "table" then
                    makeControlObservable(control)
                    if type(control.OnChanged) == "function" then
                        local connection = control:OnChanged(function()
                            if not self._Destroyed then
                                self:Refresh()
                            end
                        end)
                        table.insert(self._DependencyConnections, connection)
                    end
                end
            end
            self:Refresh()
            return self
        end

        function box:SetVisible(visible)
            self:_disconnectDependencies()
            self.Dependencies = {}
            self:_setRowsVisible(visible == true)
            return self
        end

        function box:Destroy(destroyControls)
            if self._Destroyed then
                return
            end
            if destroyControls ~= true then
                self:_setRowsVisible(true, true)
            end
            self._Destroyed = true
            self:_disconnectDependencies()
            if self.Window and self.Window._FeatureDependencyBoxes then
                self.Window._FeatureDependencyBoxes[self] = nil
            end
            if destroyControls == true then
                for _, control in ipairs(self.Controls) do
                    if type(control.Destroy) == "function" then
                        pcall(control.Destroy, control)
                    end
                end
            end
        end

        return box
    end

    function Library:AddDependencyBox(settings)
        return createDependencyBox(self, self, settings)
    end

    ---------------------------------------------------------------------------
    -- Active keybind HUD and Always / Toggle / Hold keybind modes.
    ---------------------------------------------------------------------------
    function Library:_ensureFeatureKeybindHUD()
        if self._FeatureKeybindHUD and self._FeatureKeybindHUD.Parent then
            return self._FeatureKeybindHUD
        end
        local panel = Instance.new("Frame")
        panel.Name = "KeybindHUD"
        panel.Active = true
        panel.AnchorPoint = Vector2.new(1, 0)
        panel.AutomaticSize = Enum.AutomaticSize.Y
        panel.BackgroundColor3 = Color3.fromRGB(42, 43, 49)
        panel.BackgroundTransparency = 0.08
        panel.BorderSizePixel = 0
        panel.Position = UDim2.new(1, -18, 0, 18)
        panel.Size = UDim2.fromOffset(220, 0)
        panel.Visible = false
        panel.ZIndex = 160
        panel.Parent = self.Screen

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 12)
        corner.Parent = panel
        local stroke = Instance.new("UIStroke")
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        stroke.Color = Color3.fromRGB(42, 43, 49)
        stroke.Thickness = 2
        stroke.Parent = panel
        local padding = Instance.new("UIPadding")
        padding.PaddingTop = UDim.new(0, 8)
        padding.PaddingBottom = UDim.new(0, 8)
        padding.PaddingLeft = UDim.new(0, 10)
        padding.PaddingRight = UDim.new(0, 10)
        padding.Parent = panel
        local layout = Instance.new("UIListLayout")
        layout.FillDirection = Enum.FillDirection.Vertical
        layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
        layout.Padding = UDim.new(0, 4)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Parent = panel

        local title = Instance.new("TextLabel")
        title.Name = "Title"
        title.BackgroundTransparency = 1
        title.LayoutOrder = 0
        title.Size = UDim2.new(1, 0, 0, 24)
        title.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
        title.Text = "Keybinds"
        title.TextColor3 = Color3.new(1, 1, 1)
        title.TextScaled = true
        title.TextStrokeColor3 = Color3.new(0, 0, 0)
        title.TextStrokeTransparency = 0.35
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.ZIndex = 161
        title.Parent = panel
        local titleConstraint = Instance.new("UITextSizeConstraint")
        titleConstraint.MinTextSize = 12
        titleConstraint.MaxTextSize = 18
        titleConstraint.Parent = title

        self._FeatureKeybindHUD = panel
        self._FeatureKeybindEntries = self._FeatureKeybindEntries or setmetatable({}, {__mode = "k"})
        if self._FeatureKeybindHUDVisible == nil then
            self._FeatureKeybindHUDVisible = true
        end

        local dragging = false
        local dragInput
        local startPointer
        local startPosition
        addFeatureConnection(self, panel.InputBegan:Connect(function(inputObject)
            if inputObject.UserInputType == Enum.UserInputType.MouseButton1 or inputObject.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragInput = inputObject
                startPointer = inputObject.Position
                startPosition = panel.Position
            end
        end))
        addFeatureConnection(self, UserInputService.InputChanged:Connect(function(inputObject)
            if not dragging then
                return
            end
            if inputObject.UserInputType == Enum.UserInputType.MouseMovement or inputObject == dragInput then
                local delta = inputObject.Position - startPointer
                panel.Position = UDim2.new(
                    startPosition.X.Scale,
                    startPosition.X.Offset + delta.X,
                    startPosition.Y.Scale,
                    startPosition.Y.Offset + delta.Y
                )
            end
        end))
        addFeatureConnection(self, UserInputService.InputEnded:Connect(function(inputObject)
            if inputObject.UserInputType == Enum.UserInputType.MouseButton1 or inputObject == dragInput then
                dragging = false
                dragInput = nil
            end
        end))

        self:_featureScanTheme(panel)
        return panel
    end

    function Library:_refreshFeatureKeybindHUD()
        local panel = self._FeatureKeybindHUD
        if not panel then
            return
        end
        local visibleCount = 0
        for control, data in pairs(self._FeatureKeybindEntries or {}) do
            local label = data.Label
            local active = data.Active == true
            if label and label.Parent then
                label.Visible = active and not data.NoUI
                if label.Visible then
                    visibleCount = visibleCount + 1
                    local key = type(control.Get) == "function" and tostring(control:Get()) or "Unknown"
                    label.Text = string.format("[%s] %s (%s)", key, data.Name, data.Mode)
                end
            end
        end
        panel.Visible = self._FeatureKeybindHUDVisible == true and visibleCount > 0
    end

    function Library:SetKeybindHUDVisible(visible)
        self._FeatureKeybindHUDVisible = visible == true
        self:_refreshFeatureKeybindHUD()
        return self
    end

    function Library:GetKeybindHUDVisible()
        return self._FeatureKeybindHUDVisible == true
    end

    local function registerKeybindHUD(window, control, settings, stateData)
        local panel = window:_ensureFeatureKeybindHUD()
        local label = Instance.new("TextLabel")
        label.Name = tostring(settings.Name or "Keybind")
        label.BackgroundTransparency = 1
        label.LayoutOrder = 10 + #(panel:GetChildren())
        label.Size = UDim2.new(1, 0, 0, 21)
        label.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
        label.TextColor3 = Color3.new(1, 1, 1)
        label.TextScaled = true
        label.TextStrokeColor3 = Color3.new(0, 0, 0)
        label.TextStrokeTransparency = 0.4
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.ZIndex = 161
        label.Parent = panel
        local constraint = Instance.new("UITextSizeConstraint")
        constraint.MinTextSize = 10
        constraint.MaxTextSize = 15
        constraint.Parent = label
        window._FeatureKeybindEntries[control] = {
            Label = label,
            Name = tostring(settings.Name or "Keybind"),
            Mode = stateData.Mode,
            Active = stateData.Active,
            NoUI = settings.NoUI == true,
        }
        window:_featureScanTheme(label)
        window:_refreshFeatureKeybindHUD()
        return label
    end

    local function buildKeybindModeMenu(window, control, button, stateData)
        local menu = Instance.new("Frame")
        menu.Name = "KeybindModeMenu"
        menu.BackgroundColor3 = Color3.fromRGB(42, 43, 49)
        menu.BackgroundTransparency = 0.04
        menu.BorderSizePixel = 0
        menu.Size = UDim2.fromOffset(120, 105)
        menu.Visible = false
        menu.ZIndex = 180
        menu.Parent = window.Screen
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 10)
        corner.Parent = menu
        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(42, 43, 49)
        stroke.Thickness = 2
        stroke.Parent = menu
        local padding = Instance.new("UIPadding")
        padding.PaddingTop = UDim.new(0, 6)
        padding.PaddingBottom = UDim.new(0, 6)
        padding.PaddingLeft = UDim.new(0, 6)
        padding.PaddingRight = UDim.new(0, 6)
        padding.Parent = menu
        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 4)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Parent = menu

        for index, mode in ipairs({"Always", "Toggle", "Hold"}) do
            local option = Instance.new("TextButton")
            option.Name = mode
            option.AutoButtonColor = false
            option.BackgroundColor3 = Color3.new(1, 1, 1)
            option.BackgroundTransparency = 0.08
            option.BorderSizePixel = 0
            option.LayoutOrder = index
            option.Size = UDim2.new(1, 0, 0, 27)
            option.Text = mode
            option.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
            option.TextColor3 = Color3.new(1, 1, 1)
            option.TextScaled = true
            option.TextStrokeColor3 = Color3.new(0, 0, 0)
            option.TextStrokeTransparency = 0.35
            option.ZIndex = 181
            option.Parent = menu
            local optionCorner = Instance.new("UICorner")
            optionCorner.CornerRadius = UDim.new(0, 7)
            optionCorner.Parent = option
            attachButtonFX(option, 1.03)
            option.Activated:Connect(function()
                control:SetMode(mode, false)
                menu.Visible = false
            end)
        end

        button.InputBegan:Connect(function(inputObject)
            if inputObject.UserInputType ~= Enum.UserInputType.MouseButton2 then
                return
            end
            local point = getMousePosition()
            local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
            local x = math.clamp(point.X + 6, 8, math.max(8, viewport.X - menu.Size.X.Offset - 8))
            local y = math.clamp(point.Y + 6, 8, math.max(8, viewport.Y - menu.Size.Y.Offset - 8))
            menu.Position = UDim2.fromOffset(x, y)
            menu.Visible = not menu.Visible
        end)
        window:_featureScanTheme(menu)
        return menu
    end

    local BaseAddKeybind = Library.AddKeybind
    function Library:AddKeybind(keybindSettings, legacyKey, legacyCallback)
        if type(keybindSettings) ~= "table" then
            return BaseAddKeybind(self, keybindSettings, legacyKey, legacyCallback)
        end

        local advanced = keybindSettings.Mode ~= nil
            or keybindSettings.KeybindMode ~= nil
            or keybindSettings.ShowInKeybindHUD == true
            or keybindSettings.NoUI ~= nil
        if not advanced then
            return BaseAddKeybind(self, keybindSettings, legacyKey, legacyCallback)
        end

        local settings = cloneTable(keybindSettings)
        local userCallback = settings.Callback or function() end
        local userChangedCallback = settings.ChangedCallback
        local syncHUD = function() end
        local stateData = {
            Mode = normalizeMode(settings.Mode or settings.KeybindMode or (settings.HoldToInteract and "Hold" or "Toggle")),
            Active = false,
        }
        stateData.Active = stateData.Mode == "Always" or (stateData.Mode == "Toggle" and settings.DefaultState == true)
        settings.HoldToInteract = stateData.Mode == "Hold"

        settings.Callback = function(payload)
            local previous = stateData.Active
            if stateData.Mode == "Hold" then
                stateData.Active = payload == true
            elseif stateData.Mode == "Toggle" then
                stateData.Active = not stateData.Active
            else
                stateData.Active = true
            end
            if stateData.Active ~= previous then
                safeCall(userCallback, stateData.Active)
            end
            syncHUD()
        end
        settings.ChangedCallback = function(key)
            safeCall(userChangedCallback, key)
            syncHUD()
        end

        local control = BaseAddKeybind(self, settings)
        self._FeatureAdvancedKeybindControls = self._FeatureAdvancedKeybindControls or {}
        table.insert(self._FeatureAdvancedKeybindControls, control)
        local baseSet = control.Set
        local baseDestroy = control.Destroy
        local baseGet = control.Get
        local window = self

        registerKeybindHUD(window, control, keybindSettings, stateData)

        syncHUD = function()
            local data = window._FeatureKeybindEntries and window._FeatureKeybindEntries[control]
            if data then
                data.Mode = stateData.Mode
                data.Active = stateData.Active
                window:_refreshFeatureKeybindHUD()
            end
        end

        local baseSettings = control._Settings or settings
        function control:SetMode(mode, silent)
            mode = normalizeMode(mode)
            local oldState = stateData.Active
            stateData.Mode = mode
            baseSettings.HoldToInteract = mode == "Hold"
            if mode == "Always" then
                stateData.Active = true
            elseif mode == "Hold" then
                stateData.Active = false
            else
                stateData.Active = false
            end
            syncHUD()
            if not silent and oldState ~= stateData.Active then
                safeCall(userCallback, stateData.Active)
            end
            return stateData.Mode
        end
        function control:GetMode()
            return stateData.Mode
        end
        function control:SetState(value, silent)
            if stateData.Mode == "Always" then
                stateData.Active = true
            else
                stateData.Active = value == true
            end
            syncHUD()
            if not silent then
                safeCall(userCallback, stateData.Active)
            end
            return stateData.Active
        end
        function control:GetState()
            return stateData.Active
        end
        function control:IsActive()
            return stateData.Active
        end
        function control:Set(value, silent)
            local result = baseSet(control, value, silent)
            syncHUD()
            return result
        end
        function control:Serialize()
            return {
                Key = baseGet(control),
                Mode = stateData.Mode,
                State = stateData.Mode == "Toggle" and stateData.Active or nil,
            }
        end
        function control:Deserialize(value, silent)
            if type(value) == "table" then
                if value.Key ~= nil then
                    baseSet(control, value.Key, true)
                end
                if value.Mode ~= nil then
                    control:SetMode(value.Mode, true)
                end
                if stateData.Mode == "Toggle" and value.State ~= nil then
                    stateData.Active = value.State == true
                end
                syncHUD()
                if not silent then
                    safeCall(userChangedCallback, baseGet(control))
                end
                return baseGet(control)
            end
            return control:Set(value, silent)
        end

        local button = findButton(control.Row)
        local modeMenu = button and buildKeybindModeMenu(window, control, button, stateData) or nil
        function control:Destroy()
            for index = #(window._FeatureAdvancedKeybindControls or {}), 1, -1 do
                if window._FeatureAdvancedKeybindControls[index] == control then
                    table.remove(window._FeatureAdvancedKeybindControls, index)
                    break
                end
            end
            local entry = window._FeatureKeybindEntries and window._FeatureKeybindEntries[control]
            if entry and entry.Label then
                entry.Label:Destroy()
            end
            if window._FeatureKeybindEntries then
                window._FeatureKeybindEntries[control] = nil
            end
            if modeMenu and modeMenu.Parent then
                modeMenu:Destroy()
            end
            window:_refreshFeatureKeybindHUD()
            return baseDestroy(control)
        end
        syncHUD()
        return control
    end

    ---------------------------------------------------------------------------
    -- ColorPicker transparency/alpha and right-click copy/paste context menu.
    ---------------------------------------------------------------------------
    local function writeClipboard(text)
        local writer = setclipboard or toclipboard
        if type(writer) == "function" then
            pcall(writer, tostring(text))
            return true
        end
        return false
    end

    local function readClipboard()
        local reader = getclipboard
        if type(reader) == "function" then
            local ok, value = pcall(reader)
            if ok and type(value) == "string" then
                return value
            end
        end
        return nil
    end

    local function buildColorContextMenu(window, control, getTransparency, setTransparency)
        local button = findButton(control.Row)
        if not button then
            return nil
        end
        local menu = Instance.new("Frame")
        menu.Name = "ColorContextMenu"
        menu.BackgroundColor3 = Color3.fromRGB(42, 43, 49)
        menu.BackgroundTransparency = 0.04
        menu.BorderSizePixel = 0
        menu.Size = UDim2.fromOffset(142, 142)
        menu.Visible = false
        menu.ZIndex = 190
        menu.Parent = window.Screen
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 10)
        corner.Parent = menu
        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(42, 43, 49)
        stroke.Thickness = 2
        stroke.Parent = menu
        local padding = Instance.new("UIPadding")
        padding.PaddingTop = UDim.new(0, 6)
        padding.PaddingBottom = UDim.new(0, 6)
        padding.PaddingLeft = UDim.new(0, 6)
        padding.PaddingRight = UDim.new(0, 6)
        padding.Parent = menu
        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 4)
        layout.Parent = menu

        local actions = {
            {"Copy Color", function()
                local color = control:Get()
                Library._FeatureColorClipboard = {
                    Color = colorToTable(color),
                    Transparency = getTransparency(),
                }
                writeClipboard(colorToHex(color))
            end},
            {"Paste Color", function()
                local clipboardText = readClipboard()
                local stored = Library._FeatureColorClipboard
                local fallbackColor = stored and parseColor(stored.Color, control:Get()) or control:Get()
                local color = clipboardText and parseColor(clipboardText, fallbackColor) or fallbackColor
                control:Set(color, false)
                if stored and stored.Transparency ~= nil then
                    setTransparency(stored.Transparency, false)
                end
            end},
            {"Copy HEX", function()
                local color = control:Get()
                Library._FeatureColorClipboard = {
                    Color = colorToTable(color),
                    Transparency = getTransparency(),
                }
                writeClipboard(colorToHex(color))
            end},
            {"Copy RGB", function()
                local color = control:Get()
                Library._FeatureColorClipboard = {
                    Color = colorToTable(color),
                    Transparency = getTransparency(),
                }
                writeClipboard(colorToRGBText(color))
            end},
        }

        for index, action in ipairs(actions) do
            local option = Instance.new("TextButton")
            option.Name = action[1]:gsub("%s+", "")
            option.AutoButtonColor = false
            option.BackgroundColor3 = Color3.new(1, 1, 1)
            option.BackgroundTransparency = 0.08
            option.BorderSizePixel = 0
            option.LayoutOrder = index
            option.Size = UDim2.new(1, 0, 0, 27)
            option.Text = action[1]
            option.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
            option.TextColor3 = Color3.new(1, 1, 1)
            option.TextScaled = true
            option.TextStrokeColor3 = Color3.new(0, 0, 0)
            option.TextStrokeTransparency = 0.35
            option.ZIndex = 191
            option.Parent = menu
            local optionCorner = Instance.new("UICorner")
            optionCorner.CornerRadius = UDim.new(0, 7)
            optionCorner.Parent = option
            attachButtonFX(option, 1.03)
            option.Activated:Connect(function()
                safeCall(action[2])
                menu.Visible = false
            end)
        end

        button.InputBegan:Connect(function(inputObject)
            if inputObject.UserInputType ~= Enum.UserInputType.MouseButton2 then
                return
            end
            local point = getMousePosition()
            local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
            local x = math.clamp(point.X + 6, 8, math.max(8, viewport.X - menu.Size.X.Offset - 8))
            local y = math.clamp(point.Y + 6, 8, math.max(8, viewport.Y - menu.Size.Y.Offset - 8))
            menu.Position = UDim2.fromOffset(x, y)
            menu.Visible = not menu.Visible
        end)
        window:_featureScanTheme(menu)
        return menu
    end

    local function addAlphaSlider(window, control, popup, transparency, callback)
        local connections = {}
        local alpha = 1 - transparency
        popup.Size = UDim2.fromOffset(math.max(148, popup.Size.X.Offset), math.max(354, popup.Size.Y.Offset + 44))
        local confirm = popup:FindFirstChild("Confirm")
        if confirm and confirm:IsA("GuiObject") then
            confirm.Position = UDim2.fromOffset(confirm.Position.X.Offset, confirm.Position.Y.Offset + 44)
        end

        local label = Instance.new("TextLabel")
        label.Name = "AlphaLabel"
        label.BackgroundTransparency = 1
        label.Position = UDim2.fromOffset(10, 256)
        label.Size = UDim2.fromOffset(128, 18)
        label.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
        label.TextColor3 = Color3.new(1, 1, 1)
        label.TextScaled = true
        label.TextStrokeColor3 = Color3.new(0, 0, 0)
        label.TextStrokeTransparency = 0.25
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.ZIndex = 84
        label.Parent = popup
        local labelConstraint = Instance.new("UITextSizeConstraint")
        labelConstraint.MinTextSize = 10
        labelConstraint.MaxTextSize = 14
        labelConstraint.Parent = label

        local bar = Instance.new("Frame")
        bar.Name = "AlphaBar"
        bar.Active = true
        bar.BackgroundColor3 = Color3.fromRGB(76, 76, 84)
        bar.BorderSizePixel = 0
        bar.Position = UDim2.fromOffset(10, 279)
        bar.Size = UDim2.fromOffset(128, 12)
        bar.ZIndex = 84
        bar.Parent = popup
        local barCorner = Instance.new("UICorner")
        barCorner.CornerRadius = UDim.new(1, 0)
        barCorner.Parent = bar
        local fill = Instance.new("Frame")
        fill.Name = "Fill"
        fill.BackgroundColor3 = Color3.new(1, 1, 1)
        fill.BorderSizePixel = 0
        fill.Size = UDim2.fromScale(alpha, 1)
        fill.ZIndex = 85
        fill.Parent = bar
        local fillCorner = barCorner:Clone()
        fillCorner.Parent = fill
        local knob = Instance.new("Frame")
        knob.Name = "Knob"
        knob.AnchorPoint = Vector2.new(0.5, 0.5)
        knob.BackgroundColor3 = Color3.new(1, 1, 1)
        knob.BorderSizePixel = 0
        knob.Position = UDim2.fromScale(alpha, 0.5)
        knob.Size = UDim2.fromOffset(16, 16)
        knob.ZIndex = 86
        knob.Parent = bar
        local knobCorner = Instance.new("UICorner")
        knobCorner.CornerRadius = UDim.new(1, 0)
        knobCorner.Parent = knob
        local knobStroke = Instance.new("UIStroke")
        knobStroke.Color = Color3.fromRGB(42, 43, 49)
        knobStroke.Thickness = 2
        knobStroke.Parent = knob
        local input = Instance.new("TextButton")
        input.Name = "Input"
        input.Active = true
        input.AutoButtonColor = false
        input.BackgroundTransparency = 1
        input.Size = UDim2.fromScale(1, 1)
        input.Text = ""
        input.ZIndex = 87
        input.Parent = bar

        local dragging = false
        local touchInput
        local function render()
            fill.Size = UDim2.fromScale(alpha, 1)
            knob.Position = UDim2.fromScale(alpha, 0.5)
            label.Text = string.format("Alpha: %d%%", math.floor(alpha * 100 + 0.5))
        end
        local function setAlphaFromX(x, fire)
            alpha = math.clamp((x - bar.AbsolutePosition.X) / math.max(1, bar.AbsoluteSize.X), 0, 1)
            render()
            if fire then
                safeCall(callback, 1 - alpha)
            end
        end
        table.insert(connections, addFeatureConnection(window, input.InputBegan:Connect(function(inputObject)
            if inputObject.UserInputType == Enum.UserInputType.MouseButton1 or inputObject.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                touchInput = inputObject.UserInputType == Enum.UserInputType.Touch and inputObject or nil
                setAlphaFromX(inputObject.Position.X, true)
            end
        end)))
        table.insert(connections, addFeatureConnection(window, UserInputService.InputChanged:Connect(function(inputObject)
            if not dragging then
                return
            end
            if inputObject.UserInputType == Enum.UserInputType.MouseMovement or inputObject == touchInput then
                setAlphaFromX(inputObject.Position.X, true)
            end
        end)))
        table.insert(connections, addFeatureConnection(window, UserInputService.InputEnded:Connect(function(inputObject)
            if inputObject.UserInputType == Enum.UserInputType.MouseButton1 or inputObject == touchInput then
                dragging = false
                touchInput = nil
            end
        end)))

        render()
        window:_featureScanTheme(label)
        window:_featureScanTheme(bar)
        return {
            GetAlpha = function()
                return alpha
            end,
            SetAlpha = function(value, fire)
                alpha = math.clamp(tonumber(value) or alpha, 0, 1)
                render()
                if fire then
                    safeCall(callback, 1 - alpha)
                end
                return alpha
            end,
            Connections = connections,
        }
    end

    local BaseAddColorPicker = Library.AddColorPicker
    function Library:AddColorPicker(colorSettings, legacyColor, legacyCallback)
        if type(colorSettings) ~= "table" then
            return BaseAddColorPicker(self, colorSettings, legacyColor, legacyCallback)
        end
        local requested = cloneTable(colorSettings)
        local alphaEnabled = requested.EnableAlpha == true or requested.Transparency ~= nil or requested.Alpha ~= nil
        local contextEnabled = requested.ContextMenu ~= false
        if not alphaEnabled and not contextEnabled then
            return BaseAddColorPicker(self, colorSettings, legacyColor, legacyCallback)
        end

        local transparency
        if requested.Transparency ~= nil then
            transparency = math.clamp(tonumber(requested.Transparency) or 0, 0, 1)
        elseif requested.Alpha ~= nil then
            transparency = 1 - math.clamp(tonumber(requested.Alpha) or 1, 0, 1)
        else
            transparency = 0
        end
        local userCallback = requested.Callback or function() end
        local baseSettings = cloneTable(requested)
        baseSettings.Callback = function(color)
            safeCall(userCallback, color, transparency)
        end

        local existingPopups = setmetatable({}, {__mode = "k"})
        for _, child in ipairs(self.Screen:GetChildren()) do
            if child.Name == "ColorPickerSidePanel" then
                existingPopups[child] = true
            end
        end
        local control = BaseAddColorPicker(self, baseSettings)
        local popup
        for _, child in ipairs(self.Screen:GetChildren()) do
            if child.Name == "ColorPickerSidePanel" and not existingPopups[child] then
                popup = child
                break
            end
        end

        local baseSet = control.Set
        local baseDestroy = control.Destroy
        local alphaSlider
        local function getTransparency()
            return transparency
        end
        local function setTransparency(value, silent)
            transparency = math.clamp(tonumber(value) or transparency, 0, 1)
            if alphaSlider then
                alphaSlider.SetAlpha(1 - transparency, false)
            end
            if not silent then
                safeCall(userCallback, control:Get(), transparency)
            end
            return transparency
        end

        if alphaEnabled and popup then
            alphaSlider = addAlphaSlider(self, control, popup, transparency, function(newTransparency)
                transparency = newTransparency
                safeCall(userCallback, control:Get(), transparency)
            end)
        end

        function control:GetTransparency()
            return transparency
        end
        function control:SetTransparency(value, silent)
            return setTransparency(value, silent)
        end
        function control:GetAlpha()
            return 1 - transparency
        end
        function control:SetAlpha(value, silent)
            return setTransparency(1 - math.clamp(tonumber(value) or (1 - transparency), 0, 1), silent)
        end
        function control:Set(value, silent)
            local result = baseSet(control, value, silent)
            return result
        end
        function control:Serialize()
            local data = colorToTable(control:Get())
            if alphaEnabled then
                data.Transparency = transparency
                data.Alpha = 1 - transparency
            end
            return data
        end
        function control:Deserialize(value, silent)
            if type(value) == "table" then
                local parsed = parseColor(value, control:Get())
                baseSet(control, parsed, true)
                if alphaEnabled then
                    if value.Transparency ~= nil then
                        setTransparency(value.Transparency, true)
                    elseif value.Alpha ~= nil then
                        setTransparency(1 - math.clamp(tonumber(value.Alpha) or 1, 0, 1), true)
                    end
                end
                if not silent then
                    safeCall(userCallback, control:Get(), transparency)
                end
                return control:Get()
            end
            return baseSet(control, value, silent)
        end

        local contextMenu = contextEnabled and buildColorContextMenu(self, control, getTransparency, setTransparency) or nil
        function control:Destroy()
            if alphaSlider then
                for _, connection in ipairs(alphaSlider.Connections or {}) do
                    pcall(function()
                        connection:Disconnect()
                    end)
                end
            end
            if contextMenu and contextMenu.Parent then
                contextMenu:Destroy()
            end
            return baseDestroy(control)
        end
        return control
    end

    ---------------------------------------------------------------------------
    -- Observable controls: change callbacks feed event-driven DependencyBox.
    ---------------------------------------------------------------------------
    do
        local BaseObservedAddToggle = Library.AddToggle
        function Library:AddToggle(nameOrSettings, default, callback)
            local holder = {}
            local control
            if type(nameOrSettings) == "table" then
                local settings = cloneTable(nameOrSettings)
                local userCallback = settings.Callback
                settings.Callback = makeObservedCallback(holder, userCallback)
                control = BaseObservedAddToggle(self, settings)
            else
                control = BaseObservedAddToggle(self, nameOrSettings, default, makeObservedCallback(holder, callback))
            end
            holder.Control = makeControlObservable(control)
            return holder.Control
        end

        local BaseObservedAddSelector = Library.AddSelector
        function Library:AddSelector(nameOrSettings, values, default, callback)
            local holder = {}
            local control
            if type(nameOrSettings) == "table" then
                local settings = cloneTable(nameOrSettings)
                local userCallback = settings.Callback
                settings.Callback = makeObservedCallback(holder, userCallback)
                control = BaseObservedAddSelector(self, settings)
            else
                control = BaseObservedAddSelector(self, nameOrSettings, values, default, makeObservedCallback(holder, callback))
            end
            holder.Control = makeControlObservable(control)
            return holder.Control
        end

        local BaseObservedAddDropdown = Library.AddDropdown
        function Library:AddDropdown(settingsOrName, legacyValues, legacyDefault, legacyCallback, legacyMultiple)
            local holder = {}
            local control
            if type(settingsOrName) == "table" then
                local settings = cloneTable(settingsOrName)
                local userCallback = settings.Callback
                settings.Callback = makeObservedCallback(holder, userCallback)
                control = BaseObservedAddDropdown(self, settings)
            else
                control = BaseObservedAddDropdown(self, settingsOrName, legacyValues, legacyDefault, makeObservedCallback(holder, legacyCallback), legacyMultiple)
            end
            holder.Control = makeControlObservable(control)
            return holder.Control
        end

        local BaseObservedAddSlider = Library.AddSlider
        function Library:AddSlider(nameOrSettings, minimum, maximum, default, callback, step)
            local holder = {}
            local control
            if type(nameOrSettings) == "table" then
                local settings = cloneTable(nameOrSettings)
                local userCallback = settings.Callback
                settings.Callback = makeObservedCallback(holder, userCallback)
                control = BaseObservedAddSlider(self, settings)
            else
                control = BaseObservedAddSlider(self, nameOrSettings, minimum, maximum, default, makeObservedCallback(holder, callback), step)
            end
            holder.Control = makeControlObservable(control)
            return holder.Control
        end

        local BaseObservedAddInput = Library.AddInput
        function Library:AddInput(inputSettings, legacyDefault, legacyCallback)
            local holder = {}
            local settings
            if type(inputSettings) == "table" then
                settings = cloneTable(inputSettings)
                local userChangedCallback = settings.ChangedCallback or settings.OnChanged
                settings.ChangedCallback = makeObservedCallback(holder, userChangedCallback)
                settings.OnChanged = nil
            else
                settings = {
                    Name = tostring(inputSettings),
                    Default = legacyDefault,
                    Callback = legacyCallback,
                    ChangedCallback = makeObservedCallback(holder, nil),
                }
            end
            local control = BaseObservedAddInput(self, settings)
            holder.Control = makeControlObservable(control)
            return holder.Control
        end

        local BaseObservedAddKeybind = Library.AddKeybind
        function Library:AddKeybind(keybindSettings, legacyKey, legacyCallback)
            local holder = {}
            local settings
            if type(keybindSettings) == "table" then
                settings = cloneTable(keybindSettings)
                local userCallback = settings.Callback
                local userChangedCallback = settings.ChangedCallback
                settings.Callback = makeObservedCallback(holder, userCallback)
                settings.ChangedCallback = makeObservedCallback(holder, userChangedCallback)
            else
                settings = {
                    Name = tostring(keybindSettings),
                    CurrentKey = legacyKey,
                    Callback = makeObservedCallback(holder, legacyCallback),
                    ChangedCallback = makeObservedCallback(holder, nil),
                }
            end
            local control = BaseObservedAddKeybind(self, settings)
            holder.Control = makeControlObservable(control)
            return holder.Control
        end

        local BaseObservedAddColorPicker = Library.AddColorPicker
        function Library:AddColorPicker(colorSettings, legacyColor, legacyCallback)
            local holder = {}
            local control
            if type(colorSettings) == "table" then
                local settings = cloneTable(colorSettings)
                local userCallback = settings.Callback
                settings.Callback = makeObservedCallback(holder, userCallback)
                control = BaseObservedAddColorPicker(self, settings)
            else
                control = BaseObservedAddColorPicker(self, colorSettings, legacyColor, makeObservedCallback(holder, legacyCallback))
            end
            holder.Control = makeControlObservable(control)
            return holder.Control
        end

        if type(Library.AddProgress) == "function" then
            local BaseObservedAddProgress = Library.AddProgress
            function Library:AddProgress(...)
                return makeControlObservable(BaseObservedAddProgress(self, ...))
            end
        end
    end

    ---------------------------------------------------------------------------
    -- Add the new methods to Sections, SubTabs and Tabs returned by the base UI.
    ---------------------------------------------------------------------------
    local function augmentParent(parent, window)
        if type(parent) ~= "table" or parent.__FeatureParentAugmented then
            return parent
        end
        parent.__FeatureParentAugmented = true

        if type(parent._add) == "function" then
            function parent:AddInput(...)
                return self:_add("AddInput", ...)
            end
        elseif parent.Name and parent.Window == window then
            function parent:AddInput(...)
                return self.Window:_withTab(self.Name, "AddInput", ...)
            end
        end

        function parent:AddDependencyBox(settings)
            return createDependencyBox(self, window, settings)
        end
        return parent
    end

    local BaseAddSection = Library.AddSection
    function Library:AddSection(...)
        local section = BaseAddSection(self, ...)
        return augmentParent(section, self)
    end

    local BaseAddSubTab = Library.AddSubTab
    if type(BaseAddSubTab) == "function" then
        function Library:AddSubTab(...)
            local subTab = BaseAddSubTab(self, ...)
            return augmentParent(subTab, self)
        end
    end

    local BaseCreateTab = Library.CreateTab
    function Library:CreateTab(...)
        local tab = BaseCreateTab(self, ...)
        return augmentParent(tab, self)
    end

    ---------------------------------------------------------------------------
    -- Window lifecycle: feature state, optional theme, clean teardown.
    ---------------------------------------------------------------------------
    local BaseCreateWindow = Library.CreateWindow
    function Library:CreateWindow(settings)
        local window = BaseCreateWindow(self, settings)
        window._FeatureConnections = window._FeatureConnections or {}
        window._FeatureThemeBindings = {}
        window._FeatureThemeBindingIndex = setmetatable({}, {__mode = "k"})
        window._FeatureThemeOverrides = {}
        window._FeatureThemeCallbacks = {}
        window._FeatureDependencyBoxes = setmetatable({}, {__mode = "k"})
        window.Theme = cloneTable(DEFAULT_THEME)
        Library._FeatureWindows[window] = true

        local requestedTheme = type(settings) == "table" and settings.Theme or nil
        if next(Library._GlobalFeatureTheme) ~= nil then
            window:SetTheme(Library._GlobalFeatureTheme)
        end
        if type(requestedTheme) == "table" then
            window:SetTheme(requestedTheme)
        end
        return window
    end

    local BaseDestroy = Library.Destroy
    function Library:Destroy(...)
        if self.Screen then
            local dependencyBoxes = {}
            for box in pairs(self._FeatureDependencyBoxes or {}) do
                table.insert(dependencyBoxes, box)
            end
            for _, box in ipairs(dependencyBoxes) do
                if type(box.Destroy) == "function" then
                    pcall(box.Destroy, box, false)
                end
            end
            self._FeatureDependencyBoxes = setmetatable({}, {__mode = "k"})

            local advancedKeybinds = {}
            for _, control in ipairs(self._FeatureAdvancedKeybindControls or {}) do
                table.insert(advancedKeybinds, control)
            end
            for _, control in ipairs(advancedKeybinds) do
                if type(control.Destroy) == "function" then
                    pcall(control.Destroy, control)
                end
            end
            self._FeatureAdvancedKeybindControls = {}
            for _, connection in ipairs(self._FeatureConnections or {}) do
                pcall(function()
                    connection:Disconnect()
                end)
            end
            self._FeatureConnections = {}
            Library._FeatureWindows[self] = nil
            if self._FeatureKeybindHUD and self._FeatureKeybindHUD.Parent then
                self._FeatureKeybindHUD:Destroy()
            end
        end
        return BaseDestroy(self, ...)
    end

    Library.FeaturePack = {
        AddInput = true,
        DependencyBox = true,
        DependencyBoxEventDriven = true,
        AdvancedKeybinds = true,
        ColorPickerAlphaContext = true,
        LiveTheme = true,
        Version = "1.1.0",
    }

    return Library
end
