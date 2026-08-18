return function(UIFactory, GUIFX)
local Library = (function(UIFactory, GUIFX)
    local UserInputService = game:GetService("UserInputService")
    local TweenService = game:GetService("TweenService")
    local HttpService = game:GetService("HttpService")
    local Players = game:GetService("Players")
    local SoundService = game:GetService("SoundService")
    local CoreGui = game:GetService("CoreGui")
    local StarterGui = game:GetService("StarterGui")

    local INVENTORY_SELECT_IMAGE = "rbxassetid://13744994506"
    local INVENTORY_TAB_ICONS = {
        "rbxassetid://15057347827",
        "rbxassetid://15057347941",
        "rbxassetid://15057347575",
        "rbxassetid://15057348192",
        "rbxassetid://15057348077",
        "rbxassetid://15057348341",
        "rbxassetid://16481507988",
        "rbxassetid://15057348474",
    }

    local Gradients = UIFactory.BuildGradients()

    local Library = {}
    Library.__index = Library

    local function clearGradient(object)
        for _, child in ipairs(object:GetChildren()) do
            if child:IsA("UIGradient") then
                child:Destroy()
            end
        end
    end

    local SECTION_GRADIENT_ALIASES = {
        green = "GreenGradient",
        blue = "BlueGradient",
        grey = "GreyGradient",
        gray = "GreyGradient",
        red = "RedGradient",
        lightgrey = "LightGreyGradient",
        lightgray = "LightGreyGradient",
        yellow = "YellowGradient",
        paleyellow = "PaleYellowGradient",
        purple = "PalePurpleGradient",
        palepurple = "PalePurpleGradient",
        lightgreen = "LightGreenGradient",
        evolved = "EvolvedGradient",
        gold = "GoldGradient",
        rainbow = "RainbowGradient",
        hidden = "HiddenGradient",
        shadow = "ShadowGradient",
    }

    local function applySectionColor(label, color)
        if color == nil then
            return
        end

        if typeof(color) == "Color3" then
            clearGradient(label)
            label.TextColor3 = color
            return
        end

        local requested = tostring(color)
        local normalized = string.lower(requested):gsub("[%s_%-]", "")
        if normalized == "" or normalized == "default" then
            return
        end

        local gradientName = SECTION_GRADIENT_ALIASES[normalized]
        local source = gradientName and Gradients:FindFirstChild(gradientName)

        if not source then
            source = Gradients:FindFirstChild(requested)
        end

        if not source or not source:IsA("UIGradient") then
            warn("Unknown section color '" .. requested .. "'; keeping the default section style")
            return
        end

        clearGradient(label)
        label.TextColor3 = Color3.new(1, 1, 1)
        source:Clone().Parent = label
    end

    local function setToggleVisual(button, value, animate)
        local target = value and UDim2.fromScale(0.7, 0.5) or UDim2.fromScale(0.3, 0.5)
        if animate then
            TweenService:Create(
                button,
                TweenInfo.new(0.08, Enum.EasingStyle.Back, Enum.EasingDirection.In),
                {Position = target}
            ):Play()
        else
            button.Position = target
        end

        local label = button:FindFirstChild("TextLabel")
        if label then
            label.Text = value and "On" or "Off"
        end

        clearGradient(button)
        local source = Gradients:FindFirstChild(value and "GreenGradient" or "RedGradient")
        if source then
            source:Clone().Parent = button
        end
    end

    local function normalize(text)
        return string.lower(tostring(text or "")):gsub("%s+", " ")
    end

    local function copyValue(value, seen)
        if type(value) ~= "table" then
            return value
        end
        seen = seen or {}
        if seen[value] then
            return seen[value]
        end
        local clone = {}
        seen[value] = clone
        for key, child in pairs(value) do
            clone[copyValue(key, seen)] = copyValue(child, seen)
        end
        return clone
    end

    local function valuesEqual(left, right)
        local okLeft, encodedLeft = pcall(HttpService.JSONEncode, HttpService, left)
        local okRight, encodedRight = pcall(HttpService.JSONEncode, HttpService, right)
        return okLeft and okRight and encodedLeft == encodedRight
    end

    local AUTO_ADVANCE_ICON = "rbxassetid://17638332252"
    local AUTO_ADVANCE_OPEN_SOUND = "rbxassetid://15490882908"
    local AUTO_ADVANCE_CLOSE_SOUND = "rbxassetid://15490882838"

    local function createStatusBadge(name, gradientColors)
        local badge = Instance.new("Frame")
        badge.Name = name
        badge.AnchorPoint = Vector2.new(0.5, 0.5)
        badge.BackgroundColor3 = Color3.new(1, 1, 1)
        badge.BorderSizePixel = 0
        badge.Position = UDim2.new(0.800000012, 0, 0.200000003, 0)
        badge.Size = UDim2.new(0.200000003, 0, 0.200000003, 0)
        badge.ZIndex = 15

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(1, 0)
        corner.Parent = badge

        local aspect = Instance.new("UIAspectRatioConstraint")
        aspect.AspectRatio = 1
        aspect.Parent = badge

        local gradient = Instance.new("UIGradient")
        gradient.Name = name == "StatusOn" and "green gradient" or "red gradient"
        gradient.Color = ColorSequence.new(gradientColors)
        gradient.Rotation = -90
        gradient.Parent = badge

        local stroke = Instance.new("UIStroke")
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
        stroke.Color = Color3.new(0.082352944, 0.137254909, 0.184313729)
        stroke.LineJoinMode = Enum.LineJoinMode.Round
        stroke.Thickness = 3.626736164
        stroke.Parent = badge

        return badge
    end

    function Library:_updateLauncherStatus()
        local isOpen = self.Frame and self.Frame.Visible == true
        if self.LauncherStatusOn then
            self.LauncherStatusOn.Visible = isOpen
        end
        if self.LauncherStatusOff then
            self.LauncherStatusOff.Visible = not isOpen
        end
    end

    function Library:_playLauncherSound(isOpen)
        local settings = self.LauncherSettings
        if not settings or settings.SoundEnabled == false then
            return
        end

        local soundId = isOpen and settings.OpenSoundId or settings.CloseSoundId
        if type(soundId) == "number" then
            soundId = "rbxassetid://" .. tostring(soundId)
        end
        if type(soundId) ~= "string" or soundId == "" then
            return
        end

        local sound = self.LauncherSound
        if not sound then
            sound = Instance.new("Sound")
            sound.Name = "AutoAdvanceToggleSound"
            sound.Parent = SoundService
            self.LauncherSound = sound
        end
        sound.SoundId = soundId
        sound.Volume = tonumber(settings.SoundVolume) or 0.5
        sound.PlaybackSpeed = tonumber(settings.SoundPlaybackSpeed) or 1
        sound:Play()
    end

    function Library:SetVisible(visible, silent)
        visible = visible == true
        if not visible and self.ActiveDropdownClose then
            self.ActiveDropdownClose(true)
        end
        self.Frame.Visible = visible
        self:_updateLauncherStatus()
        if not silent then
            self:_playLauncherSound(visible)
            if self.ConfigReady and self.ConfigOnline and not self.ConfigSaveBusy then
                task.spawn(function()
                    self:SaveConfig()
                end)
            end
        end
        return visible
    end

    function Library:IsVisible()
        return self.Frame.Visible == true
    end

    function Library:ToggleVisible(silent)
        return self:SetVisible(not self:IsVisible(), silent)
    end

    function Library:SetLauncherVisible(visible)
        if self.LauncherButton then
            self.LauncherButton.Visible = visible == true
        end
    end

    function Library:ConfigureLauncher(launcherSettings)
        if launcherSettings == false then
            launcherSettings = {Enabled = false}
        elseif type(launcherSettings) ~= "table" then
            launcherSettings = {}
        end

        if self.LauncherButton then
            self.LauncherButton:Destroy()
            self.LauncherButton = nil
            self.LauncherStatusOn = nil
            self.LauncherStatusOff = nil
        end

        self.LauncherSettings = {
            Enabled = launcherSettings.Enabled ~= false,
            Visible = launcherSettings.Visible ~= false,
            Icon = launcherSettings.Icon or AUTO_ADVANCE_ICON,
            IconColor = launcherSettings.IconColor or Color3.new(1, 1, 1),
            IconTransparency = tonumber(launcherSettings.IconTransparency) or 0,
            Position = launcherSettings.Position or UDim2.new(0, 24, 0.5, 0),
            Size = launcherSettings.Size or UDim2.fromOffset(64, 64),
            AnchorPoint = launcherSettings.AnchorPoint or Vector2.new(0, 0.5),
            ZIndex = tonumber(launcherSettings.ZIndex) or 50,
            HoverScale = tonumber(launcherSettings.HoverScale) or 1.07,
            StartOpen = launcherSettings.StartOpen ~= false,
            SaveState = launcherSettings.SaveState ~= false,
            Flag = tostring(launcherSettings.Flag or "WindowVisible"),
            Tooltip = tostring(launcherSettings.Tooltip or "Open / Close UI"),
            SoundEnabled = launcherSettings.SoundEnabled ~= false,
            OpenSoundId = launcherSettings.OpenSoundId or AUTO_ADVANCE_OPEN_SOUND,
            CloseSoundId = launcherSettings.CloseSoundId or AUTO_ADVANCE_CLOSE_SOUND,
            SoundVolume = tonumber(launcherSettings.SoundVolume) or 0.5,
            SoundPlaybackSpeed = tonumber(launcherSettings.SoundPlaybackSpeed) or 1,
        }

        local settings = self.LauncherSettings
        if not settings.Enabled then
            self:SetVisible(settings.StartOpen, true)
            return nil
        end

        local button = Instance.new("TextButton")
        button.Name = "AutoAdvance"
        button.Active = true
        button.AutoButtonColor = false
        button.AnchorPoint = settings.AnchorPoint
        button.BackgroundColor3 = Color3.new(0, 0, 0)
        button.BackgroundTransparency = 1
        button.BorderSizePixel = 0
        button.Position = settings.Position
        button.Size = settings.Size
        button.Text = ""
        button.Visible = settings.Visible
        button.ZIndex = settings.ZIndex
        button:SetAttribute("Tooltip", settings.Tooltip)
        button.Parent = self.Screen

        local thumbnail = Instance.new("ImageLabel")
        thumbnail.Name = "Thumbnail"
        thumbnail.Active = false
        thumbnail.AnchorPoint = Vector2.new(0.5, 0.5)
        thumbnail.BackgroundColor3 = Color3.new(1, 1, 1)
        thumbnail.BackgroundTransparency = 1
        thumbnail.BorderSizePixel = 0
        thumbnail.Image = tostring(settings.Icon)
        thumbnail.ImageColor3 = settings.IconColor
        thumbnail.ImageTransparency = settings.IconTransparency
        thumbnail.Position = UDim2.fromScale(0.5, 0.5)
        thumbnail.ScaleType = Enum.ScaleType.Fit
        thumbnail.Size = UDim2.fromScale(1, 1)
        thumbnail.ZIndex = settings.ZIndex + 3
        thumbnail.Parent = button

        local statusOn = createStatusBadge("StatusOn", {
            ColorSequenceKeypoint.new(0, Color3.new(0.360783994, 0.937255025, 0)),
            ColorSequenceKeypoint.new(1, Color3.new(0.639216006, 0.992156982, 0.109803997)),
        })
        statusOn.ZIndex = settings.ZIndex + 5
        statusOn.Parent = button

        local statusOff = createStatusBadge("StatusOff", {
            ColorSequenceKeypoint.new(0, Color3.new(1, 0.00784314, 0.239216)),
            ColorSequenceKeypoint.new(1, Color3.new(1, 0.152941003, 0.49019599)),
        })
        statusOff.ZIndex = settings.ZIndex + 5
        statusOff.Parent = button

        local aspect = Instance.new("UIAspectRatioConstraint")
        aspect.AspectRatio = 1
        aspect.Parent = button

        local scale = Instance.new("UIScale")
        scale.Name = "ButtonUIScale"
        scale.Scale = 1
        scale.Parent = button

        self.LauncherButton = button
        self.LauncherStatusOn = statusOn
        self.LauncherStatusOff = statusOff

        GUIFX.ButtonFX(button, settings.HoverScale)
        button.Activated:Connect(function()
            self:ToggleVisible(false)
        end)

        self.LauncherControl = {
            Get = function()
                return self:IsVisible()
            end,
            Set = function(_, value)
                self:SetVisible(value == true, true)
            end,
        }

        self:SetVisible(settings.StartOpen, true)
        if settings.SaveState and settings.Flag ~= "" then
            self:BindConfig(settings.Flag, self.LauncherControl, settings.StartOpen)
        end
        return button
    end

    local INVENTORY_PAGE_LEFT_IMAGE = "rbxassetid://15862260433"
    local INVENTORY_PAGE_RIGHT_IMAGE = "rbxassetid://15862241934"

    local function normalizedPageLimit(value)
        local number = tonumber(value)
        if number == nil or number <= 0 or number == math.huge then
            return math.huge
        end
        return math.max(1, math.floor(number))
    end

    function Library:_setPageNavigatorSpace(enabled)
        local itemsFrame = self.ItemsFrame
        local original = self.ItemsFrameOriginalSize
        if not itemsFrame or not original then
            return
        end

        local reserve = enabled and 38 or 0
        itemsFrame.Size = UDim2.new(
            original.X.Scale,
            original.X.Offset,
            original.Y.Scale,
            original.Y.Offset - reserve
        )
    end

    function Library:_ensurePageNavigator()
        if self.PageNavigator then
            return self.PageNavigator
        end

        local navigator = Instance.new("Frame")
        navigator.Name = "PageNavigator"
        navigator.Active = false
        navigator.AnchorPoint = Vector2.new(0.5, 1)
        navigator.BackgroundColor3 = Color3.new(1, 1, 1)
        navigator.BackgroundTransparency = 0
        navigator.BorderSizePixel = 0
        navigator.Position = UDim2.new(0.5, 0, 1, -5)
        navigator.Size = UDim2.fromOffset(126, 28)
        navigator.Visible = false
        navigator.ZIndex = 60
        navigator.Parent = self.Frame

        local navigatorAspect = Instance.new("UIAspectRatioConstraint")
        navigatorAspect.Name = "UIAspectRatioConstraint"
        navigatorAspect.AspectRatio = 4.5
        navigatorAspect.Parent = navigator

        local navigatorCorner = Instance.new("UICorner")
        navigatorCorner.Name = "UICorner"
        navigatorCorner.CornerRadius = UDim.new(0.45, 0)
        navigatorCorner.Parent = navigator

        local navigatorStroke = Instance.new("UIStroke")
        navigatorStroke.Name = "UIStroke"
        navigatorStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        navigatorStroke.Color = Color3.new(0.164705887, 0.168627456, 0.192156881)
        navigatorStroke.LineJoinMode = Enum.LineJoinMode.Round
        navigatorStroke.Thickness = 3.868518591
        navigatorStroke.Parent = navigator

        local layout = Instance.new("UIListLayout")
        layout.Name = "UIListLayout"
        layout.FillDirection = Enum.FillDirection.Horizontal
        layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        layout.VerticalAlignment = Enum.VerticalAlignment.Center
        layout.Padding = UDim.new(0, 3)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Parent = navigator

        local function createArrow(name, layoutOrder, imageId)
            local button = Instance.new("TextButton")
            button.Name = name
            button.Active = true
            button.AutoButtonColor = true
            button.BackgroundTransparency = 1
            button.BorderSizePixel = 0
            button.LayoutOrder = layoutOrder
            button.Size = UDim2.fromScale(1, 1)
            button.Text = ""
            button.ZIndex = 61
            button.Parent = navigator

            local aspect = Instance.new("UIAspectRatioConstraint")
            aspect.Name = "UIAspectRatioConstraint"
            aspect.AspectRatio = 1
            aspect.Parent = button

            local image = Instance.new("ImageLabel")
            image.Name = "ImageLabel"
            image.AnchorPoint = Vector2.new(0.5, 0.5)
            image.BackgroundTransparency = 1
            image.Image = imageId
            image.ImageColor3 = Color3.new(0.149019614, 0.149019614, 0.149019614)
            image.Position = UDim2.fromScale(0.5, 0.5)
            image.ScaleType = Enum.ScaleType.Fit
            image.Size = UDim2.new(1, 0, 0.8, 0)
            image.ZIndex = 62
            image.Parent = button

            GUIFX.ButtonFX(button, 1.08)
            return button, image
        end

        local left, leftImage = createArrow("Left", 2, INVENTORY_PAGE_LEFT_IMAGE)

        local pageNumber = Instance.new("TextLabel")
        pageNumber.Name = "PageNumber"
        pageNumber.Active = false
        pageNumber.AnchorPoint = Vector2.new(0.5, 0.5)
        pageNumber.BackgroundTransparency = 1
        pageNumber.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
        pageNumber.LayoutOrder = 3
        pageNumber.Size = UDim2.new(0.375, 0, 1, 0)
        pageNumber.Text = "1 / 1"
        pageNumber.TextColor3 = Color3.new(1, 1, 1)
        pageNumber.TextScaled = true
        pageNumber.TextWrapped = true
        pageNumber.ZIndex = 62
        pageNumber.Parent = navigator

        local pageStroke = Instance.new("UIStroke")
        pageStroke.Name = "UIStroke"
        pageStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
        pageStroke.Color = Color3.new(0.164705887, 0.168627456, 0.192156866)
        pageStroke.LineJoinMode = Enum.LineJoinMode.Round
        pageStroke.Thickness = 2.901388884
        pageStroke.Parent = pageNumber

        local right, rightImage = createArrow("Right", 4, INVENTORY_PAGE_RIGHT_IMAGE)

        left.Activated:Connect(function()
            self:PreviousPage()
        end)
        right.Activated:Connect(function()
            self:NextPage()
        end)

        self.PageNavigator = navigator
        self.PageNumberLabel = pageNumber
        self.PageLeftButton = left
        self.PageRightButton = right
        self.PageLeftImage = leftImage
        self.PageRightImage = rightImage
        return navigator
    end

    function Library:_currentPageFor(tabName)
        tabName = tabName or self.ActiveTab or "__default"
        local page = tonumber(self.PageByTab[tabName]) or 1
        return math.max(1, math.floor(page))
    end

    function Library:_matchingRows(tabName, query)
        local rows = {}
        for _, entry in ipairs(self.Rows) do
            if entry.Tab == tabName then
                local matchesSearch = query == "" or string.find(entry.SearchText, query, 1, true) ~= nil
                if matchesSearch then
                    table.insert(rows, entry)
                end
            end
        end
        return rows
    end

    function Library:_refreshPagination()
        local activeTab = self.ActiveTab
        local query = normalize(self.SearchInput and self.SearchInput.Text or "")
        local limit = normalizedPageLimit(self.MaxElementLimit)

        if activeTab == nil then
            for _, entry in ipairs(self.Rows) do
                entry.Row.Visible = query == "" or string.find(entry.SearchText, query, 1, true) ~= nil
            end
            if self.PageNavigator then
                self.PageNavigator.Visible = false
            end
            self:_setPageNavigatorSpace(false)
            return
        end

        local matchingRows = self:_matchingRows(activeTab, query)
        local totalPages = 1
        if limit ~= math.huge then
            totalPages = math.max(1, math.ceil(#matchingRows / limit))
        end

        local currentPage = math.clamp(self:_currentPageFor(activeTab), 1, totalPages)
        self.PageByTab[activeTab] = currentPage
        self.PageCountByTab[activeTab] = totalPages

        local firstIndex = limit == math.huge and 1 or ((currentPage - 1) * limit + 1)
        local lastIndex = limit == math.huge and #matchingRows or math.min(#matchingRows, currentPage * limit)
        local visibleEntries = {}
        for index = firstIndex, lastIndex do
            local entry = matchingRows[index]
            if entry then
                visibleEntries[entry] = true
            end
        end

        for _, entry in ipairs(self.Rows) do
            entry.Row.Visible = entry.Tab == activeTab and visibleEntries[entry] == true
        end

        local showNavigator = limit ~= math.huge and totalPages > 1
        local navigator = self:_ensurePageNavigator()
        navigator.Visible = showNavigator
        self:_setPageNavigatorSpace(showNavigator)

        if self.PageNumberLabel then
            self.PageNumberLabel.Text = string.format("%d / %d", currentPage, totalPages)
        end

        local canGoLeft = currentPage > 1
        local canGoRight = currentPage < totalPages
        if self.PageLeftButton then
            self.PageLeftButton.Active = canGoLeft
            self.PageLeftButton.AutoButtonColor = canGoLeft
            self.PageLeftButton.Selectable = canGoLeft
        end
        if self.PageRightButton then
            self.PageRightButton.Active = canGoRight
            self.PageRightButton.AutoButtonColor = canGoRight
            self.PageRightButton.Selectable = canGoRight
        end
        if self.PageLeftImage then
            self.PageLeftImage.ImageTransparency = canGoLeft and 0 or 0.55
        end
        if self.PageRightImage then
            self.PageRightImage.ImageTransparency = canGoRight and 0 or 0.55
        end
    end

    function Library:SetPage(page)
        local activeTab = self.ActiveTab
        if activeTab == nil then
            return 1
        end

        local totalPages = tonumber(self.PageCountByTab[activeTab]) or 1
        local newPage = math.clamp(math.floor(tonumber(page) or 1), 1, math.max(1, totalPages))
        if self.ActiveDropdownClose then
            self.ActiveDropdownClose(true)
        end
        self.PageByTab[activeTab] = newPage
        self.Items.CanvasPosition = Vector2.zero
        self:_refreshPagination()
        return newPage
    end

    function Library:GetPage()
        local activeTab = self.ActiveTab
        return self:_currentPageFor(activeTab), (activeTab and self.PageCountByTab[activeTab]) or 1
    end

    function Library:NextPage()
        local current = self:GetPage()
        return self:SetPage(current + 1)
    end

    function Library:PreviousPage()
        local current = self:GetPage()
        return self:SetPage(current - 1)
    end

    function Library:SetMaxElementLimit(limit)
        self.MaxElementLimit = normalizedPageLimit(limit)
        for tabName in pairs(self.PageByTab) do
            self.PageByTab[tabName] = 1
        end
        self.Items.CanvasPosition = Vector2.zero
        self:_refreshPagination()
        return self.MaxElementLimit
    end

    function Library.new(screenGui)
        local self = setmetatable({}, Library)
        self.Screen = screenGui
        self.Frame = screenGui:WaitForChild("Frame")
        self.Items = self.Frame:WaitForChild("ItemsFrame"):WaitForChild("Items")
        self.Templates = {}
        self.Rows = {}
        self.Order = 0
        self.ItemsFrame = self.Frame:WaitForChild("ItemsFrame")
        self.ItemsFrameOriginalSize = self.ItemsFrame.Size
        self.MaxElementLimit = math.huge
        self.PageByTab = {}
        self.PageCountByTab = {}
        self.ActiveDropdownClose = nil
        self.ActiveDropdownRoot = nil
        self.ActiveTab = nil
        self._MountTab = nil
        self.TabButtons = {}
        self.TabOrder = {}
        self.ConfigBindings = {}
        self.ConfigSettings = nil
        self.ConfigReady = false
        self.ConfigOnline = false
        self.ConfigSaveBusy = false
        self.ConfigLastJSON = nil
        self.ConfigLoopToken = 0
        self.ToggleKey = Enum.KeyCode.RightShift

        for _, name in ipairs({"Toggle", "Slider", "Selector", "Title", "Locked"}) do
            local template = self.Items:FindFirstChild(name)
            if template then
                template.Visible = false
                self.Templates[name] = template
            end
        end

        self.Frame.ClipsDescendants = false
        self.Frame.Visible = true
        screenGui.Enabled = true

        local title = self.Frame:FindFirstChild("Title")
        self.TitleLabel = title
        if title then
            title.Text = "Settings"
        end

        local close = self.Frame:FindFirstChild("Close")
        if close then
            GUIFX.ButtonFX(close)
            close.Activated:Connect(function()
                if self.ActiveDropdownClose then
                    self.ActiveDropdownClose(true)
                end
                self:SetVisible(false, false)
            end)
        end

        local search = self.Frame:FindFirstChild("Search")
        local input = search and search:FindFirstChild("Input")
        self.SearchInput = input

        local function refreshSearch()
            self:_refreshPagination()
        end

        self.RefreshSearch = refreshSearch
        if input then
            input:GetPropertyChangedSignal("Text"):Connect(function()
                if self.ActiveTab then
                    self.PageByTab[self.ActiveTab] = 1
                end
                refreshSearch()
            end)
        end

        UserInputService.InputBegan:Connect(function(inputObject, processed)
            if not processed and inputObject.KeyCode == self.ToggleKey then
                self:ToggleVisible(false)
            end
        end)

        local layout = self.Items:FindFirstChildOfClass("UIListLayout")
        if layout then
            local function resize()
                self.Items.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 35)
            end
            layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(resize)
            task.defer(resize)
        end

        return self
    end

    function Library:_mount(row, name, searchText)
        self.Order += 1
        row.Name = name:gsub("[^%w%s_-]", "")
        row.LayoutOrder = self.Order
        row.Visible = true
        row.Parent = self.Items

        local mountedTab = self._MountTab or self.ActiveTab or "__default"
        table.insert(self.Rows, {
            Row = row,
            SearchText = normalize(searchText or name),
            Tab = mountedTab,
        })
        self.PageByTab[mountedTab] = self.PageByTab[mountedTab] or 1
        self:_refreshPagination()
        return row
    end

    function Library:_ensureTabBar()
        if self.TabBar then
            return self.TabBar
        end

        local tabBar = Instance.new("Frame")
        tabBar.Name = "InventoryTabs"
        tabBar.AnchorPoint = Vector2.new(1, 0.5)
        tabBar.AutomaticSize = Enum.AutomaticSize.Y
        tabBar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        tabBar.BorderSizePixel = 0
        tabBar.Position = UDim2.new(0, -7, 0.52, 0)
        tabBar.Size = UDim2.fromOffset(54, 0)
        tabBar.ZIndex = 45
        tabBar.Parent = self.Frame

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0.45, 0)
        corner.Parent = tabBar

        local stroke = Instance.new("UIStroke")
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        stroke.Color = Color3.fromRGB(42, 43, 49)
        stroke.Thickness = 4.835648
        stroke.Parent = tabBar

        local padding = Instance.new("UIPadding")
        padding.PaddingLeft = UDim.new(0.075, 0)
        padding.PaddingRight = UDim.new(0.075, 0)
        padding.Parent = tabBar

        local layout = Instance.new("UIListLayout")
        layout.FillDirection = Enum.FillDirection.Vertical
        layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Parent = tabBar

        self.TabBar = tabBar
        return tabBar
    end

    function Library:_renderTabs()
        for tabName, entry in pairs(self.TabButtons) do
            local selected = tabName == self.ActiveTab
            entry.Select.Visible = selected
            TweenService:Create(
                entry.Scale,
                TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
                {Scale = selected and 1.08 or 1}
            ):Play()
            TweenService:Create(
                entry.Icon,
                TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
                {ImageTransparency = selected and 0 or 0.08}
            ):Play()
        end

        if self.TitleLabel and self.ActiveTab then
            self.TitleLabel.Text = self.ActiveTab
        end
    end

    function Library:SelectTab(tabName)
        assert(self.TabButtons[tabName], "Unknown settings tab: " .. tostring(tabName))
        if self.ActiveDropdownClose then
            self.ActiveDropdownClose(true)
        end
        self.ActiveTab = tabName
        self.PageByTab[tabName] = self.PageByTab[tabName] or 1
        self.Items.CanvasPosition = Vector2.zero
        if self.SearchInput then
            self.SearchInput.Text = ""
        end
        self:_renderTabs()
        self.RefreshSearch()
    end

    function Library:_withTab(tabName, methodName, ...)
        local oldMountTab = self._MountTab
        self._MountTab = tabName
        local results = table.pack(pcall(Library[methodName], self, ...))
        self._MountTab = oldMountTab
        if not results[1] then
            error(results[2], 3)
        end
        return table.unpack(results, 2, results.n)
    end

    function Library:CreateTab(tabSettings, legacyIcon)
        local settings = type(tabSettings) == "table" and tabSettings or {
            Name = tostring(tabSettings),
            Icon = legacyIcon,
        }
        local name = tostring(settings.Name or "Tab")
        assert(not self.TabButtons[name], "A settings tab named '" .. name .. "' already exists")

        local tabBar = self:_ensureTabBar()
        local index = #self.TabOrder + 1
        local iconImage = settings.Icon or INVENTORY_TAB_ICONS[((index - 1) % #INVENTORY_TAB_ICONS) + 1]

        local button = Instance.new("TextButton")
        button.Name = name
        button.Active = true
        button.AutoButtonColor = false
        button.BackgroundTransparency = 1
        button.BorderSizePixel = 0
        button.LayoutOrder = index
        button.Size = UDim2.fromOffset(48, 48)
        button.Text = ""
        button.ZIndex = 50
        button.Parent = tabBar

        local scale = Instance.new("UIScale")
        scale.Name = "ButtonUIScale"
        scale.Parent = button

        local selectImage = Instance.new("ImageLabel")
        selectImage.Name = "Select"
        selectImage.BackgroundTransparency = 1
        selectImage.Image = INVENTORY_SELECT_IMAGE
        selectImage.ImageColor3 = Color3.fromRGB(0, 0, 0)
        selectImage.Size = UDim2.fromScale(1, 1)
        selectImage.Visible = false
        selectImage.ZIndex = 50
        selectImage.Parent = button

        local icon = Instance.new("ImageLabel")
        icon.Name = "Icon"
        icon.AnchorPoint = Vector2.new(0.5, 0.5)
        icon.BackgroundTransparency = 1
        icon.Image = iconImage
        icon.Position = UDim2.fromScale(0.5, 0.5)
        icon.ScaleType = Enum.ScaleType.Fit
        icon.Size = UDim2.fromScale(1, 1)
        icon.ZIndex = 51
        icon.Parent = button

        local aspect = Instance.new("UIAspectRatioConstraint")
        aspect.AspectRatio = 1
        aspect.Parent = icon

        button.Activated:Connect(function()
            self:SelectTab(name)
            if settings.Callback then
                settings.Callback(name)
            end
        end)
        GUIFX.ButtonFX(button, 1.06)

        self.PageByTab[name] = self.PageByTab[name] or 1
        self.PageCountByTab[name] = self.PageCountByTab[name] or 1

        self.TabButtons[name] = {
            Button = button,
            Select = selectImage,
            Icon = icon,
            Scale = scale,
        }
        table.insert(self.TabOrder, name)

        local tab = {
            Name = name,
            Window = self,
        }
        for _, methodName in ipairs({
            "AddSection",
            "AddButton",
            "AddToggle",
            "AddSelector",
            "AddDropdown",
            "AddSlider",
        }) do
            tab[methodName] = function(_, ...)
                return self:_withTab(name, methodName, ...)
            end
        end
        function tab:Select()
            self.Window:SelectTab(self.Name)
        end

        if self.ActiveTab == nil then
            self.ActiveTab = name
        end
        self:_renderTabs()
        self.RefreshSearch()
        return tab
    end

    function Library:EnableConfig(configSettings)
        configSettings = configSettings or {}
        local configName = tostring(configSettings.Name or "Settings")
        local folderName = tostring(configSettings.FolderName or "PlantVsCoinsUI")
        local fileName = tostring(configSettings.FileName or (configName .. ".json"))
        if not string.match(fileName, "%.json$") then
            fileName ..= ".json"
        end

        folderName = folderName:gsub("[^%w%._%-/]", "_")
        fileName = fileName:gsub("[^%w%._%-]", "_")

        self.ConfigSettings = {
            Name = configName,
            FolderName = folderName,
            FileName = fileName,
            Path = folderName .. "/" .. fileName,
            AutoSave = configSettings.AutoSave ~= false,
            SaveInterval = math.max(0.5, tonumber(configSettings.SaveInterval) or 1),
        }
        self.ConfigOnline = type(isfolder) == "function"
            and type(makefolder) == "function"
            and type(isfile) == "function"
            and type(readfile) == "function"
            and type(writefile) == "function"

        self.ConfigLoopToken += 1
        local loopToken = self.ConfigLoopToken
        task.spawn(function()
            while self.Screen.Parent and self.ConfigLoopToken == loopToken do
                task.wait(self.ConfigSettings.SaveInterval)
                if self.ConfigSettings.AutoSave and self.ConfigReady and self.ConfigOnline and not self.ConfigSaveBusy then
                    local data = self:GetConfigData()
                    local ok, encoded = pcall(HttpService.JSONEncode, HttpService, data)
                    if ok and encoded ~= self.ConfigLastJSON then
                        self:SaveConfig()
                    end
                end
            end
        end)
        return self
    end

    function Library:BindConfig(flag, control, defaultValue)
        assert(type(flag) == "string" and flag ~= "", "BindConfig requires a non-empty flag")
        assert(type(control) == "table" and type(control.Get) == "function" and type(control.Set) == "function", "BindConfig requires a UI control")
        self.ConfigBindings[flag] = {
            Control = control,
            Default = copyValue(defaultValue ~= nil and defaultValue or control:Get()),
        }
        return control
    end

    function Library:GetConfigData()
        local data = {}
        for flag, binding in pairs(self.ConfigBindings) do
            local ok, value = pcall(binding.Control.Get, binding.Control)
            if ok then
                data[flag] = copyValue(value)
            end
        end
        return data
    end

    function Library:_applyConfigData(data, useDefaults)
        for flag, binding in pairs(self.ConfigBindings) do
            local value = data and data[flag]
            if value == nil and useDefaults then
                value = binding.Default
            end
            if value ~= nil then
                local ok = pcall(binding.Control.Set, binding.Control, copyValue(value), false)
                if not ok and not valuesEqual(value, binding.Default) then
                    pcall(binding.Control.Set, binding.Control, copyValue(binding.Default), false)
                end
            end
        end
    end

    function Library:_ensureConfigFolder()
        if not self.ConfigOnline then
            return false, "Executor file functions are unavailable"
        end
        local ok, message = pcall(function()
            if not isfolder(self.ConfigSettings.FolderName) then
                makefolder(self.ConfigSettings.FolderName)
            end
        end)
        return ok, message
    end

    function Library:LoadConfig()
        assert(self.ConfigSettings, "Call EnableConfig before LoadConfig")
        if not self.ConfigOnline then
            self:_applyConfigData(nil, true)
            self.ConfigReady = true
            return false, "Executor file functions are unavailable; using session-only values"
        end

        local folderOK, folderMessage = self:_ensureConfigFolder()
        if not folderOK then
            self:_applyConfigData(nil, true)
            self.ConfigReady = true
            return false, folderMessage
        end

        if not isfile(self.ConfigSettings.Path) then
            self:_applyConfigData(nil, true)
            self.ConfigReady = true
            self.ConfigLastJSON = nil
            return true, {}
        end

        local readOK, contents = pcall(readfile, self.ConfigSettings.Path)
        if not readOK then
            self:_applyConfigData(nil, true)
            self.ConfigReady = true
            return false, contents
        end

        local decodeOK, loaded = pcall(HttpService.JSONDecode, HttpService, contents)
        if not decodeOK or type(loaded) ~= "table" then
            self:_applyConfigData(nil, true)
            self.ConfigReady = true
            return false, decodeOK and "Config root must be a table" or loaded
        end

        self:_applyConfigData(loaded, true)
        self.ConfigReady = true
        local encodedOK, encoded = pcall(HttpService.JSONEncode, HttpService, self:GetConfigData())
        self.ConfigLastJSON = encodedOK and encoded or nil
        return true, loaded
    end

    function Library:SaveConfig()
        assert(self.ConfigSettings, "Call EnableConfig before SaveConfig")
        if self.ConfigSaveBusy then
            return false, "Save already running"
        end
        local folderOK, folderMessage = self:_ensureConfigFolder()
        if not folderOK then
            return false, folderMessage
        end

        self.ConfigSaveBusy = true
        local data = self:GetConfigData()
        local encodedOK, encoded = pcall(HttpService.JSONEncode, HttpService, data)
        if not encodedOK then
            self.ConfigSaveBusy = false
            return false, encoded
        end

        local writeOK, writeMessage = pcall(writefile, self.ConfigSettings.Path, encoded)
        self.ConfigSaveBusy = false
        if not writeOK then
            return false, writeMessage
        end

        self.ConfigLastJSON = encoded
        self.ConfigOnline = true
        self.ConfigReady = true
        return true
    end

    function Library:ResetConfig(saveAfterReset)
        self:_applyConfigData(nil, true)
        self.ConfigReady = true
        if saveAfterReset ~= false and self.ConfigSettings then
            return self:SaveConfig()
        end
        return true
    end

    function Library:DeleteConfig()
        assert(self.ConfigSettings, "Call EnableConfig before DeleteConfig")
        if not self.ConfigOnline then
            return false, "Executor file functions are unavailable"
        end
        local ok, message = pcall(function()
            if isfile(self.ConfigSettings.Path) then
                if type(delfile) ~= "function" then
                    error("delfile is unavailable")
                end
                delfile(self.ConfigSettings.Path)
            end
        end)
        if not ok then
            return false, message
        end
        self.ConfigLastJSON = nil
        return self:ResetConfig(false)
    end

    function Library:AddButton(name, callback, buttonText)
        local row = self.Templates.Selector:Clone()
        row.SettingName.Text = tostring(name)
        local button = row.Toggle.Button
        button.TextLabel.Text = tostring(buttonText or "Run")
        self:_mount(row, tostring(name), tostring(name))
        GUIFX.ButtonFX(button)
        button.Activated:Connect(function()
            local ok, response = pcall(callback)
            if not ok then
                warn("Settings Button | " .. tostring(name) .. ": " .. tostring(response))
            end
        end)
        return {
            Press = function()
                return callback()
            end,
        }
    end

    function Library:AddSection(text, color)
        text = tostring(text)
        local row = self.Templates.Title:Clone()
        row.Text = text
        applySectionColor(row, color)
        return self:_mount(row, "Section " .. text, text)
    end

    function Library:AddToggle(name, default, callback)
        local row = self.Templates.Toggle:Clone()
        row.SettingName.Text = name
        local button = row.Toggle.Button
        local value = default == true

        self:_mount(row, name, name)
        setToggleVisual(button, value, false)
        GUIFX.ButtonFX(button)

        button.Activated:Connect(function()
            value = not value
            setToggleVisual(button, value, true)
            callback(value)
        end)

        return {
            Get = function()
                return value
            end,
            Set = function(_, newValue, silent)
                value = newValue == true
                setToggleVisual(button, value, true)
                if not silent then
                    callback(value)
                end
            end,
        }
    end

    function Library:AddSelector(name, values, default, callback)
        local row = self.Templates.Selector:Clone()
        row.SettingName.Text = name
        local button = row.Toggle.Button
        local index = table.find(values, default) or 1

        self:_mount(row, name, name .. " " .. table.concat(values, " "))
        GUIFX.ButtonFX(button)

        local function update(fire)
            button.TextLabel.Text = tostring(values[index])
            if fire then
                callback(values[index])
            end
        end

        button.Activated:Connect(function()
            index = index % #values + 1
            update(true)
        end)

        update(false)
        return {
            Get = function()
                return values[index]
            end,
            Set = function(_, newValue, silent)
                index = table.find(values, newValue) or index
                update(not silent)
            end,
        }
    end

    function Library:AddDropdown(dropdownSettings, legacyValues, legacyDefault, legacyCallback, legacyMultipleOptions)
        local library = self
        local legacyMode = type(dropdownSettings) ~= "table"
        local settings

        if legacyMode then
            settings = {
                Name = tostring(dropdownSettings),
                Options = legacyValues,
                CurrentOption = legacyDefault,
                MultipleOptions = legacyMultipleOptions == true,
                Callback = legacyCallback,
            }
        else
            settings = dropdownSettings
        end

        settings.Name = tostring(settings.Name or "Dropdown")
        settings.Options = settings.Options or {}
        settings.MultipleOptions = settings.MultipleOptions == true
        settings.Callback = settings.Callback or function() end
        settings.MaxVisibleOptions = math.max(1, tonumber(settings.MaxVisibleOptions) or 4)

        assert(type(settings.Options) == "table", "AddDropdown Options must be a table")

        local CLOSED_HEIGHT = 52
        local OPTION_HEIGHT = 36
        local OPTION_GAP = 6
        local PANEL_PADDING = 8
        local PANEL_GAP = 5
        local SEARCH_HEIGHT = 34
        local SEARCH_GAP = 6
        local TWEEN_OPEN = TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        local TWEEN_OPTION = TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

        local row = self.Templates.Selector:Clone()
        row.ClipsDescendants = true
        row.Size = UDim2.new(1, 0, 0, CLOSED_HEIGHT)
        row.SettingName.Text = settings.Name

        local rowAspect = row:FindFirstChildOfClass("UIAspectRatioConstraint")
        if rowAspect then
            rowAspect:Destroy()
        end

        local settingName = row.SettingName
        settingName.Size = UDim2.new(0.58, 0, 0, CLOSED_HEIGHT)
        settingName.Position = UDim2.new(0, 0, 0, CLOSED_HEIGHT / 2)

        local headerContainer = row.Toggle
        headerContainer.Size = UDim2.new(0.42, 0, 0, CLOSED_HEIGHT - 6)
        headerContainer.Position = UDim2.new(1, 0, 0, CLOSED_HEIGHT / 2)

        local headerButton = headerContainer.Button
        local selectedLabel = headerButton.TextLabel
        selectedLabel.Size = UDim2.new(0.72, 0, 0.6, 0)
        selectedLabel.Position = UDim2.new(0.42, 0, 0.5, 0)
        selectedLabel.TextXAlignment = Enum.TextXAlignment.Center

        local arrow = selectedLabel:Clone()
        arrow.Name = "DropdownArrow"
        arrow.Text = "▲"
        arrow.Size = UDim2.new(0.17, 0, 0.6, 0)
        arrow.Position = UDim2.new(0.88, 0, 0.5, 0)
        arrow.Rotation = 180
        arrow.Parent = headerButton

        local function optionsToText(options)
            local parts = {}
            for index, option in ipairs(options) do
                parts[index] = tostring(option)
            end
            return table.concat(parts, " ")
        end

        self:_mount(row, settings.Name, settings.Name .. " " .. optionsToText(settings.Options))
        local rowEntry = self.Rows[#self.Rows]
        GUIFX.ButtonFX(headerButton)

        local panel = self.Templates.Locked:Clone()
        panel.Name = "DropdownList"
        panel.AnchorPoint = Vector2.zero
        panel.Position = UDim2.fromOffset(8, CLOSED_HEIGHT + PANEL_GAP)
        panel.Size = UDim2.new(1, -16, 0, 0)
        panel.ClipsDescendants = true
        panel.Visible = false
        panel.ZIndex = 20
        panel.Parent = row

        local oldPriceFrame = panel:FindFirstChild("PriceFrame")
        if oldPriceFrame then
            oldPriceFrame:Destroy()
        end
        local panelAspect = panel:FindFirstChildOfClass("UIAspectRatioConstraint")
        if panelAspect then
            panelAspect:Destroy()
        end

        local panelStroke = panel:FindFirstChildOfClass("UIStroke")
        local panelBackgroundTransparency = panel.BackgroundTransparency
        local panelStrokeTransparency = panelStroke and panelStroke.Transparency or 0
        panel.BackgroundTransparency = 1
        if panelStroke then
            panelStroke.Transparency = 1
        end

        local searchTemplate = self.Frame:FindFirstChild("Search")
        assert(searchTemplate and searchTemplate:IsA("GuiObject"), "Dropdown search requires the Settings Search asset")

        local dropdownSearch = searchTemplate:Clone()
        dropdownSearch.Name = "DropdownSearch"
        dropdownSearch.AnchorPoint = Vector2.zero
        dropdownSearch.Position = UDim2.fromOffset(PANEL_PADDING, PANEL_PADDING)
        dropdownSearch.Size = UDim2.new(1, -(PANEL_PADDING * 2), 0, SEARCH_HEIGHT)
        dropdownSearch.Visible = true
        dropdownSearch.ZIndex = 22
        dropdownSearch.Parent = panel

        local searchInput = dropdownSearch:FindFirstChild("Input")
        assert(searchInput and searchInput:IsA("TextBox"), "Settings Search asset is missing its Input TextBox")
        searchInput.Text = ""
        searchInput.PlaceholderText = tostring(settings.SearchPlaceholder or "Search options...")
        searchInput.ClearTextOnFocus = false
        searchInput.ZIndex = 23

        for _, descendant in ipairs(dropdownSearch:GetDescendants()) do
            if descendant:IsA("GuiObject") then
                descendant.ZIndex = math.max(descendant.ZIndex, 23)
            end
        end

        local list = Instance.new("ScrollingFrame")
        list.Name = "Options"
        list.Active = true
        list.AnchorPoint = Vector2.zero
        list.AutomaticCanvasSize = Enum.AutomaticSize.Y
        list.BackgroundTransparency = 1
        list.BorderSizePixel = 0
        list.CanvasSize = UDim2.fromOffset(0, 0)
        list.ClipsDescendants = true
        list.Position = UDim2.fromOffset(PANEL_PADDING, PANEL_PADDING + SEARCH_HEIGHT + SEARCH_GAP)
        list.ScrollBarImageTransparency = 1
        list.ScrollBarThickness = 3
        list.Size = UDim2.new(
            1,
            -(PANEL_PADDING * 2),
            1,
            -(PANEL_PADDING * 2 + SEARCH_HEIGHT + SEARCH_GAP)
        )
        list.ZIndex = 21
        list.Parent = panel

        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, OPTION_GAP)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Parent = list

        local optionEntries = {}
        local currentOptions = {}
        local open = false
        local animating = false
        local destroyed = false

        local function copyArray(source)
            local result = {}
            for index, value in ipairs(source) do
                result[index] = value
            end
            return result
        end

        local function optionExists(value)
            return table.find(settings.Options, value) ~= nil
        end

        local function normalizeSelection(newSelection)
            local incoming
            if typeof(newSelection) == "table" then
                incoming = newSelection
            elseif newSelection == nil then
                incoming = {}
            else
                incoming = {newSelection}
            end

            local normalizedSelection = {}
            for _, option in ipairs(incoming) do
                if optionExists(option) and not table.find(normalizedSelection, option) then
                    table.insert(normalizedSelection, option)
                end
            end

            if not settings.MultipleOptions then
                if normalizedSelection[1] == nil then
                    return {}
                end
                return {normalizedSelection[1]}
            end

            return normalizedSelection
        end

        local function syncPublicSelection()
            settings.CurrentOption = copyArray(currentOptions)
        end

        local function getSelectedText()
            if settings.MultipleOptions then
                if #currentOptions == 0 then
                    return "None"
                elseif #currentOptions == 1 then
                    return tostring(currentOptions[1])
                end
                return "Various"
            end
            return tostring(currentOptions[1] or "None")
        end

        local function setButtonGradient(button, selected)
            clearGradient(button)
            local gradient = Gradients:FindFirstChild(selected and "GreenGradient" or "GreyGradient")
                or Gradients:FindFirstChild(selected and "LightGreenGradient" or "LightGreyGradient")
            if gradient then
                gradient:Clone().Parent = button
            end
        end

        local function renderSelection()
            selectedLabel.Text = getSelectedText()
            syncPublicSelection()

            for _, entry in ipairs(optionEntries) do
                local selected = table.find(currentOptions, entry.Value) ~= nil
                setButtonGradient(entry.Button, selected)
                entry.Button.TextLabel.TextTransparency = 0
                local textStroke = entry.Button.TextLabel:FindFirstChildOfClass("UIStroke")
                if textStroke then
                    textStroke.Transparency = selected and 0 or 0.2
                end
            end
        end

        local function fireCallback()
            local payload = copyArray(currentOptions)
            local success, response
            if legacyMode and not settings.MultipleOptions then
                success, response = pcall(settings.Callback, payload[1])
            else
                success, response = pcall(settings.Callback, payload)
            end

            if not success then
                local originalText = settingName.Text
                settingName.Text = "Callback Error"
                warn("Settings Dropdown | " .. settings.Name .. " callback error: " .. tostring(response))
                task.delay(0.65, function()
                    if settingName.Parent then
                        settingName.Text = originalText
                    end
                end)
            end
        end

        local function getFilteredOptionCount()
            local count = 0
            for _, entry in ipairs(optionEntries) do
                if entry.Button.Visible then
                    count += 1
                end
            end
            return count
        end

        local function getPanelHeight()
            local visibleCount = math.min(getFilteredOptionCount(), settings.MaxVisibleOptions)
            local optionsHeight = visibleCount * OPTION_HEIGHT + math.max(0, visibleCount - 1) * OPTION_GAP
            return PANEL_PADDING * 2 + SEARCH_HEIGHT + SEARCH_GAP + optionsHeight
        end

        local function getOpenHeight()
            return CLOSED_HEIGHT + PANEL_GAP + getPanelHeight() + 7
        end

        local function updateListCanvas()
            list.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y)
        end
        layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateListCanvas)

        local function refreshOptionSearch()
            local query = normalize(searchInput.Text)
            for _, entry in ipairs(optionEntries) do
                entry.Button.Visible = query == ""
                    or string.find(normalize(entry.Value), query, 1, true) ~= nil
            end

            updateListCanvas()
            if open then
                local panelHeight = getPanelHeight()
                panel.Size = UDim2.new(1, -16, 0, panelHeight)
                row.Size = UDim2.new(1, 0, 0, CLOSED_HEIGHT + PANEL_GAP + panelHeight + 7)
                list.ScrollBarImageTransparency = getFilteredOptionCount() > settings.MaxVisibleOptions and 0.45 or 1
            end
        end
        searchInput:GetPropertyChangedSignal("Text"):Connect(refreshOptionSearch)

        local closeDropdown

        local function setOptionFade(transparency)
            for _, entry in ipairs(optionEntries) do
                TweenService:Create(entry.Button, TWEEN_OPTION, {ImageTransparency = transparency}):Play()
                TweenService:Create(entry.Button.TextLabel, TWEEN_OPTION, {TextTransparency = transparency}):Play()
                local textStroke = entry.Button.TextLabel:FindFirstChildOfClass("UIStroke")
                if textStroke then
                    TweenService:Create(textStroke, TWEEN_OPTION, {Transparency = math.max(transparency, 0.15)}):Play()
                end
            end
        end

        local function rebuildOptions()
            for _, entry in ipairs(optionEntries) do
                entry.Button:Destroy()
            end
            table.clear(optionEntries)

            for index, option in ipairs(settings.Options) do
                local optionButton = self.Templates.Selector.Toggle.Button:Clone()
                optionButton.Name = tostring(option)
                optionButton.AnchorPoint = Vector2.zero
                optionButton.Position = UDim2.fromOffset(0, 0)
                optionButton.Size = UDim2.new(1, -4, 0, OPTION_HEIGHT)
                optionButton.LayoutOrder = index
                optionButton.ZIndex = 22
                optionButton.TextLabel.Text = tostring(option)
                optionButton.TextLabel.ZIndex = 23
                optionButton.Parent = list
                GUIFX.ButtonFX(optionButton, 1.015)

                optionButton.Activated:Connect(function()
                    if animating or destroyed then
                        return
                    end

                    local selectedIndex = table.find(currentOptions, option)
                    if settings.MultipleOptions then
                        if selectedIndex then
                            table.remove(currentOptions, selectedIndex)
                        else
                            table.insert(currentOptions, option)
                        end
                        renderSelection()
                        fireCallback()
                    else
                        if selectedIndex then
                            return
                        end
                        table.clear(currentOptions)
                        table.insert(currentOptions, option)
                        renderSelection()
                        fireCallback()
                        task.defer(function()
                            closeDropdown(false)
                        end)
                    end
                end)

                table.insert(optionEntries, {
                    Button = optionButton,
                    Value = option,
                })
            end

            refreshOptionSearch()
            renderSelection()
            if open then
                panel.Size = UDim2.new(1, -16, 0, getPanelHeight())
                row.Size = UDim2.new(1, 0, 0, getOpenHeight())
            end
        end

        closeDropdown = function(immediate)
            if not open or destroyed then
                return
            end

            open = false
            animating = true
            if self.ActiveDropdownClose == closeDropdown then
                self.ActiveDropdownClose = nil
            end

            searchInput:ReleaseFocus()

            if immediate then
                row.Size = UDim2.new(1, 0, 0, CLOSED_HEIGHT)
                arrow.Rotation = 180
                panel.Visible = false
                panel.BackgroundTransparency = 1
                panel.Size = UDim2.new(1, -16, 0, 0)
                if panelStroke then
                    panelStroke.Transparency = 1
                end
                list.ScrollBarImageTransparency = 1
                animating = false
                return
            end

            TweenService:Create(row, TWEEN_OPEN, {Size = UDim2.new(1, 0, 0, CLOSED_HEIGHT)}):Play()
            TweenService:Create(panel, TWEEN_OPEN, {
                Size = UDim2.new(1, -16, 0, 0),
                BackgroundTransparency = 1,
            }):Play()
            if panelStroke then
                TweenService:Create(panelStroke, TWEEN_OPTION, {Transparency = 1}):Play()
            end
            TweenService:Create(arrow, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {Rotation = 180}):Play()
            TweenService:Create(list, TWEEN_OPTION, {ScrollBarImageTransparency = 1}):Play()
            setOptionFade(1)

            task.delay(0.36, function()
                if not destroyed and not open then
                    panel.Visible = false
                    animating = false
                end
            end)
        end

        local function openDropdown()
            if destroyed or animating then
                return
            end
            if open then
                closeDropdown(false)
                return
            end

            if self.ActiveDropdownClose and self.ActiveDropdownClose ~= closeDropdown then
                self.ActiveDropdownClose(false)
            end

            searchInput.Text = ""
            refreshOptionSearch()
            open = true
            animating = true
            self.ActiveDropdownClose = closeDropdown
            panel.Visible = true
            panel.Size = UDim2.new(1, -16, 0, 0)
            panel.BackgroundTransparency = 1
            if panelStroke then
                panelStroke.Transparency = 1
            end

            for _, entry in ipairs(optionEntries) do
                entry.Button.ImageTransparency = 1
                entry.Button.TextLabel.TextTransparency = 1
            end

            TweenService:Create(row, TWEEN_OPEN, {Size = UDim2.new(1, 0, 0, getOpenHeight())}):Play()
            TweenService:Create(panel, TWEEN_OPEN, {
                Size = UDim2.new(1, -16, 0, getPanelHeight()),
                BackgroundTransparency = panelBackgroundTransparency,
            }):Play()
            if panelStroke then
                TweenService:Create(panelStroke, TWEEN_OPTION, {Transparency = panelStrokeTransparency}):Play()
            end
            TweenService:Create(arrow, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {Rotation = 0}):Play()
            TweenService:Create(list, TWEEN_OPTION, {
                ScrollBarImageTransparency = getFilteredOptionCount() > settings.MaxVisibleOptions and 0.45 or 1,
            }):Play()
            setOptionFade(0)

            task.delay(0.48, function()
                if not destroyed then
                    animating = false
                end
            end)
        end

        currentOptions = normalizeSelection(settings.CurrentOption)
        rebuildOptions()
        renderSelection()

        headerButton.Activated:Connect(openDropdown)
        row:GetPropertyChangedSignal("Visible"):Connect(function()
            if not row.Visible then
                closeDropdown(true)
            end
        end)
        row.Destroying:Connect(function()
            destroyed = true
            if self.ActiveDropdownClose == closeDropdown then
                self.ActiveDropdownClose = nil
            end
        end)

        function settings:Get()
            return copyArray(currentOptions)
        end

        function settings:Set(newOptions, silent)
            currentOptions = normalizeSelection(newOptions)
            renderSelection()
            if not silent then
                fireCallback()
            end
        end

        function settings:Refresh(newOptions, newCurrentOptions)
            if newOptions ~= nil then
                assert(type(newOptions) == "table", "Refresh options must be a table")
                settings.Options = newOptions
            end

            if newCurrentOptions ~= nil then
                currentOptions = normalizeSelection(newCurrentOptions)
            else

                currentOptions = normalizeSelection(currentOptions)
            end

            rowEntry.SearchText = normalize(settings.Name .. " " .. optionsToText(settings.Options))
            rebuildOptions()
            library.RefreshSearch()
            return copyArray(currentOptions)
        end

        function settings:Open()
            openDropdown()
        end

        function settings:Close()
            closeDropdown(false)
        end

        function settings:Destroy()
            closeDropdown(true)
            row:Destroy()
        end

        return settings
    end

    function Library:AddSlider(name, minimum, maximum, default, callback, step)
        local row = self.Templates.Slider:Clone()
        row.SettingName.Text = name

        local slider = row.Slider
        local knob = slider.Button
        local value = math.clamp(default or minimum, minimum, maximum)
        local increment = step or 1
        local dragging = false
        local touchInput

        self:_mount(row, name, name)

        slider.Active = true
        knob.Active = true
        GUIFX.ButtonFX(knob)

        local function formatValue(number)
            if math.abs(number - math.round(number)) < 1e-6 then
                return tostring(math.round(number))
            end
            return string.format("%.2f", number):gsub("0+$", ""):gsub("%.$", "")
        end

        local function render(fire)
            local alpha = maximum == minimum and 0 or (value - minimum) / (maximum - minimum)
            knob.Position = UDim2.fromScale(0.05 + 0.9 * alpha, 0.5)
            row.SettingName.Text = string.format("%s: %s", name, formatValue(value))
            if fire then
                callback(value)
            end
        end

        local function updateFromX(x)
            local width = slider.AbsoluteSize.X
            if width <= 0 then
                return
            end

            local alpha = math.clamp((x - slider.AbsolutePosition.X) / width, 0, 1)
            local raw = minimum + (maximum - minimum) * alpha
            local nextValue = math.clamp(math.round((raw - minimum) / increment) * increment + minimum, minimum, maximum)

            if nextValue ~= value then
                value = nextValue
                render(true)
            else
                render(false)
            end
        end

        local function beginDrag(inputObject)
            local inputType = inputObject.UserInputType
            if inputType ~= Enum.UserInputType.MouseButton1 and inputType ~= Enum.UserInputType.Touch then
                return
            end

            dragging = true
            touchInput = inputType == Enum.UserInputType.Touch and inputObject or nil
            updateFromX(inputObject.Position.X)
        end

        slider.InputBegan:Connect(beginDrag)
        knob.InputBegan:Connect(beginDrag)

        UserInputService.InputChanged:Connect(function(inputObject)
            if not dragging then
                return
            end

            if inputObject.UserInputType == Enum.UserInputType.MouseMovement then
                updateFromX(inputObject.Position.X)
            elseif touchInput and inputObject == touchInput then
                updateFromX(inputObject.Position.X)
            end
        end)

        UserInputService.InputEnded:Connect(function(inputObject)
            if inputObject.UserInputType == Enum.UserInputType.MouseButton1 or inputObject == touchInput then
                dragging = false
                touchInput = nil
            end
        end)

        render(false)
        return {
            Get = function()
                return value
            end,
            Set = function(_, newValue, silent)
                value = math.clamp(newValue, minimum, maximum)
                render(not silent)
            end,
        }
    end

    local NativeScreenTemplate
    local NativeScreenChecked = false

    local function isCompatibleNativeScreen(candidate)
        if typeof(candidate) ~= "Instance" or not candidate:IsA("ScreenGui") then
            return false
        end
        local frame = candidate:FindFirstChild("Frame")
        local itemsFrame = frame and frame:FindFirstChild("ItemsFrame")
        local items = itemsFrame and itemsFrame:FindFirstChild("Items")
        if not (frame and itemsFrame and items) then
            return false
        end
        return items:FindFirstChild("Toggle") ~= nil
            and items:FindFirstChild("Slider") ~= nil
            and items:FindFirstChild("Selector") ~= nil
            and items:FindFirstChild("Title") ~= nil
    end

    local function stripNativeScripts(root)
        for _, descendant in ipairs(root:GetDescendants()) do
            if descendant:IsA("LuaSourceContainer") then
                descendant:Destroy()
            end
        end
    end

    local function getNativeScreen()
        if not NativeScreenChecked then
            NativeScreenChecked = true
            local candidate = StarterGui:FindFirstChild("Settings")
            if isCompatibleNativeScreen(candidate) then
                local ok, clone = pcall(candidate.Clone, candidate)
                if ok and clone then
                    stripNativeScripts(clone)
                    clone.Parent = nil
                    NativeScreenTemplate = clone
                end
            end
        end

        if NativeScreenTemplate then
            local ok, clone = pcall(NativeScreenTemplate.Clone, NativeScreenTemplate)
            if ok and clone then
                clone.Parent = nil
                clone.Enabled = false
                clone.ResetOnSpawn = false
                return clone
            end
        end
        return nil
    end

  local function resolveUIParent()
	local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
	return player:WaitForChild("PlayerGui")
end
    function Library:CreateWindow(settings)
        settings = settings or {}
        local screen
        if settings.UseGameAssets ~= false then
            screen = getNativeScreen()
        end
        screen = screen or UIFactory.BuildScreen()
        screen.Name = tostring(settings.GuiName or "PlantVsCoinsSettings")

        local parent = resolveUIParent(screen)
        local old = parent:FindFirstChild(screen.Name)
        if old then
            old:Destroy()
        end
        screen.Parent = parent

        local window = Library.new(screen)
        window.ToggleKey = settings.ToggleKey or Enum.KeyCode.RightShift
        window.MaxElementLimit = normalizedPageLimit(settings.MaxElementLimit)

        local title = window.Frame:FindFirstChild("Title")
        if title then
            title.Text = tostring(settings.Name or "Plant vs Coins")
        end

        local saving = settings.ConfigurationSaving
        if type(saving) == "table" and saving.Enabled ~= false then
            window:EnableConfig({
                Name = saving.Name or settings.Name or "Settings",
                FolderName = saving.FolderName or "PlantVsCoinsUI",
                FileName = saving.FileName,
                AutoSave = saving.AutoSave ~= false,
                SaveInterval = saving.SaveInterval or 1,
            })
        end

        local launcher = settings.Launcher
        if launcher == nil then
            launcher = settings.AutoAdvanceButton
        end
        window:ConfigureLauncher(launcher)

        return window
    end

    function Library:Destroy()
        self.ConfigLoopToken += 1
        if self.LauncherSound then
            self.LauncherSound:Destroy()
            self.LauncherSound = nil
        end
        if self.Screen then
            self.Screen:Destroy()
        end
    end

    local GuiService = game:GetService("GuiService")
    local RunService = game:GetService("RunService")
    local ContextActionService = game:GetService("ContextActionService")
    local TextService = game:GetService("TextService")

    local function safeCall(callback, ...)
        if type(callback) ~= "function" then
            return true
        end
        local ok, result = pcall(callback, ...)
        if not ok then
            warn(tostring(result))
        end
        return ok, result
    end

    local function sanitizeProfileName(value)
        local name = tostring(value or "Default"):gsub("[^%w%._%-]", "_")
        if name == "" then
            name = "Default"
        end
        return name
    end

    local function colorToTable(color)
        return {
            R = math.clamp(math.floor(color.R * 255 + 0.5), 0, 255),
            G = math.clamp(math.floor(color.G * 255 + 0.5), 0, 255),
            B = math.clamp(math.floor(color.B * 255 + 0.5), 0, 255),
        }
    end

    local function tableToColor(value, fallback)
        if typeof(value) == "Color3" then
            return value
        end
        if type(value) == "string" then
            local hex = value:gsub("#", "")
            if #hex == 6 then
                local number = tonumber(hex, 16)
                if number then
                    return Color3.fromRGB(
                        bit32.rshift(number, 16) % 256,
                        bit32.rshift(number, 8) % 256,
                        number % 256
                    )
                end
            end
        end
        if type(value) == "table" then
            local r = tonumber(value.R or value.r or value[1])
            local g = tonumber(value.G or value.g or value[2])
            local b = tonumber(value.B or value.b or value[3])
            if r and g and b then
                if r <= 1 and g <= 1 and b <= 1 then
                    return Color3.new(r, g, b)
                end
                return Color3.fromRGB(r, g, b)
            end
        end
        return fallback or Color3.new(1, 1, 1)
    end

    local function colorToHex(color)
        return string.format("#%02X%02X%02X", math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5))
    end

    local function findSettingLabel(row)
        if not row then
            return nil
        end
        local direct = row:FindFirstChild("SettingName")
        if direct and direct:IsA("TextLabel") then
            return direct
        end
        if row:IsA("TextLabel") then
            return row
        end
        for _, descendant in ipairs(row:GetDescendants()) do
            if descendant:IsA("TextLabel") and descendant.Name == "SettingName" then
                return descendant
            end
        end
        return nil
    end

    local function removeRowEntry(window, row)
        for index = #window.Rows, 1, -1 do
            if window.Rows[index].Row == row then
                table.remove(window.Rows, index)
                break
            end
        end
        window:_refreshPagination()
    end

    local function setObjectInputEnabled(root, enabled)
        if not root then
            return
        end
        for _, object in ipairs(root:GetDescendants()) do
            if object:IsA("GuiButton") then
                object.Active = enabled
                object.Selectable = enabled
            elseif object:IsA("TextBox") then
                object.TextEditable = enabled
                object.Active = enabled
            end
        end
    end

    local OriginalMountV8 = Library._mount
    function Library:_mount(row, name, searchText)
        local mounted = OriginalMountV8(self, row, name, searchText)
        local entry = self.Rows[#self.Rows]
        entry.ManualVisible = true
        entry.SubTab = self._MountSubTab
        if not self._CreatingSection then
            local tabName = entry.Tab
            local sectionKey = tabName .. "" .. tostring(entry.SubTab or "")
            local section = self._ForcedSection or (self._ActiveSectionByTab and self._ActiveSectionByTab[sectionKey])
            if section then
                entry.Section = section
                table.insert(section.Entries, entry)
            end
        end
        return mounted
    end

    function Library:_entryAvailable(entry, tabName, query)
        if not entry.Row or not entry.Row.Parent then
            return false
        end
        if entry.Tab ~= tabName or entry.ManualVisible == false then
            return false
        end
        if entry.Section and entry.Section.Collapsed then
            return false
        end
        local activeSubTab = self.ActiveSubTabByTab and self.ActiveSubTabByTab[tabName]
        if entry.SubTab and activeSubTab and entry.SubTab ~= activeSubTab then
            return false
        end
        if entry.SubTab and not activeSubTab then
            return false
        end
        if query ~= "" and string.find(entry.SearchText, query, 1, true) == nil then
            return false
        end
        return true
    end

    function Library:_matchingRows(tabName, query)
        local rows = {}
        for _, entry in ipairs(self.Rows) do
            if self:_entryAvailable(entry, tabName, query) then
                table.insert(rows, entry)
            end
        end
        return rows
    end

    function Library:_applyContentInsets()
        if not self.ItemsFrame or not self.ItemsFrameOriginalSize or not self.ItemsFrameOriginalPosition then
            return
        end
        local topReserve = self.SubTabBar and self.SubTabBar.Visible and (((self.SubTabBar.AbsoluteSize.Y > 0) and math.floor(self.SubTabBar.AbsoluteSize.Y + 8) or (self.SubTabBar.Size.Y.Offset + 8))) or 0
        local bottomReserve = self._PageNavigatorSpaceEnabled and 38 or 0
        local originalSize = self.ItemsFrameOriginalSize
        local originalPosition = self.ItemsFrameOriginalPosition
        self.ItemsFrame.Position = UDim2.new(
            originalPosition.X.Scale,
            originalPosition.X.Offset,
            originalPosition.Y.Scale,
            originalPosition.Y.Offset + topReserve
        )
        self.ItemsFrame.Size = UDim2.new(
            originalSize.X.Scale,
            originalSize.X.Offset,
            originalSize.Y.Scale,
            originalSize.Y.Offset - topReserve - bottomReserve
        )
    end

    function Library:_setPageNavigatorSpace(enabled)
        self._PageNavigatorSpaceEnabled = enabled == true
        self:_applyContentInsets()
    end

    function Library:_refreshPagination()
        local activeTab = self.ActiveTab
        local query = normalize(self.SearchInput and self.SearchInput.Text or "")
        local limit = normalizedPageLimit(self.MaxElementLimit)
        if activeTab == nil then
            for _, entry in ipairs(self.Rows) do
                entry.Row.Visible = entry.ManualVisible ~= false and (query == "" or string.find(entry.SearchText, query, 1, true) ~= nil)
            end
            if self.PageNavigator then
                self.PageNavigator.Visible = false
            end
            self:_setPageNavigatorSpace(false)
            return
        end
        local matchingRows = self:_matchingRows(activeTab, query)
        local totalPages = 1
        if limit ~= math.huge then
            totalPages = math.max(1, math.ceil(#matchingRows / limit))
        end
        local currentPage = math.clamp(self:_currentPageFor(activeTab), 1, totalPages)
        self.PageByTab[activeTab] = currentPage
        self.PageCountByTab[activeTab] = totalPages
        local firstIndex = limit == math.huge and 1 or ((currentPage - 1) * limit + 1)
        local lastIndex = limit == math.huge and #matchingRows or math.min(#matchingRows, currentPage * limit)
        local visibleEntries = {}
        for index = firstIndex, lastIndex do
            local entry = matchingRows[index]
            if entry then
                visibleEntries[entry] = true
            end
        end
        for _, entry in ipairs(self.Rows) do
            entry.Row.Visible = visibleEntries[entry] == true
        end
        local showNavigator = limit ~= math.huge and totalPages > 1
        local navigator = self:_ensurePageNavigator()
        navigator.Visible = showNavigator
        self:_setPageNavigatorSpace(showNavigator)
        if self.PageNumberLabel then
            self.PageNumberLabel.Text = string.format("%d / %d", currentPage, totalPages)
        end
        local canGoLeft = currentPage > 1
        local canGoRight = currentPage < totalPages
        if self.PageLeftButton then
            self.PageLeftButton.Active = canGoLeft
            self.PageLeftButton.AutoButtonColor = canGoLeft
            self.PageLeftButton.Selectable = canGoLeft
        end
        if self.PageRightButton then
            self.PageRightButton.Active = canGoRight
            self.PageRightButton.AutoButtonColor = canGoRight
            self.PageRightButton.Selectable = canGoRight
        end
        if self.PageLeftImage then
            self.PageLeftImage.ImageTransparency = canGoLeft and 0 or 0.55
        end
        if self.PageRightImage then
            self.PageRightImage.ImageTransparency = canGoRight and 0 or 0.55
        end
    end

    local function measureInfoText(text, textSize, maxWidth)
        local value = tostring(text or "")
        local ok, bounds = pcall(function()
            return TextService:GetTextSize(value, textSize, Enum.Font.FredokaOne, Vector2.new(maxWidth, 1000))
        end)
        if ok and bounds then
            return bounds
        end
        return Vector2.new(math.min(maxWidth, math.max(1, #value) * textSize * 0.55), textSize)
    end

    local function shortenInfoNumber(value)
        local numberValue = tonumber(value)
        if numberValue == nil then
            return tostring(value or "")
        end
        local absolute = math.abs(numberValue)
        local suffixes = {
            {1e33, "d"},
            {1e30, "n"},
            {1e27, "o"},
            {1e24, "sp"},
            {1e21, "sx"},
            {1e18, "Qn"},
            {1e15, "q"},
            {1e12, "t"},
            {1e9, "b"},
            {1e6, "m"},
            {1e3, "k"},
        }
        for _, entry in ipairs(suffixes) do
            if absolute >= entry[1] then
                local scaled = numberValue / entry[1]
                local formatted
                if math.abs(scaled) >= 100 then
                    formatted = string.format("%.0f", scaled)
                elseif math.abs(scaled) >= 10 then
                    formatted = string.format("%.1f", scaled)
                else
                    formatted = string.format("%.2f", scaled)
                end
                formatted = formatted:gsub("(%..-)0+$", "%1"):gsub("%.$", "")
                return formatted .. entry[2]
            end
        end
        if numberValue % 1 == 0 then
            return tostring(math.floor(numberValue))
        end
        return tostring(numberValue)
    end

    local function firstInfoValue(sourceTable, ...)
        for index = 1, select("#", ...) do
            local key = select(index, ...)
            local value = sourceTable[key]
            if value ~= nil then
                return value
            end
        end
        return nil
    end

    local function joinInfoText(value)
        if value == nil then
            return nil
        end
        if type(value) ~= "table" then
            return tostring(value)
        end
        local parts = {}
        for _, entry in ipairs(value) do
            if entry ~= nil and tostring(entry) ~= "" then
                table.insert(parts, tostring(entry))
            end
        end
        if #parts == 0 then
            return nil
        end
        return table.concat(parts, "\n\n")
    end

    local function appendInfoText(current, value)
        local text = joinInfoText(value)
        if text == nil or text == "" then
            return current
        end
        if current == nil or current == "" then
            return text
        end
        return current .. "\n\n" .. text
    end

    local function formatInfoExists(value)
        if value == nil then
            return nil
        end
        local text
        if type(value) == "number" then
            text = shortenInfoNumber(value)
        else
            text = tostring(value)
        end
        if text == "" then
            return nil
        end
        if not text:lower():find("exist", 1, true) then
            text ..= " Exist"
        end
        return text
    end

    local function formatInfoPrice(value)
        if value == nil then
            return nil
        end
        if type(value) == "number" then
            return shortenInfoNumber(value)
        end
        local text = tostring(value)
        return text ~= "" and text or nil
    end

    local function applyInfoCurrency(result, value, fallbackAmount)
        if type(value) == "table" then
            local amount = firstInfoValue(value, "Text", "Amount", "Price", "Value")
            if amount == nil then
                amount = value[2] or fallbackAmount
            end
            local icon = firstInfoValue(value, "Icon", "Image", "CurrencyIcon")
            if icon == nil and type(value[1]) == "string" and value[1]:find("rbxasset", 1, true) then
                icon = value[1]
            end
            result.Price = formatInfoPrice(amount)
            if icon ~= nil then
                result.CurrencyIcon = tostring(icon)
            end
            if typeof(value.Color) == "Color3" then
                result.CurrencyColor = value.Color
            end
            if typeof(value.IconColor) == "Color3" then
                result.CurrencyIconColor = value.IconColor
            end
        else
            result.Price = formatInfoPrice(fallbackAmount ~= nil and fallbackAmount or value)
        end
    end

    local function resolveInfoTooltip(value)
        if type(value) == "function" then
            local ok, result = pcall(value)
            if not ok then
                warn(tostring(result))
                return nil
            end
            value = result
        end
        if value == nil then
            return nil
        end

        local result = {
            Title = nil,
            Rarity = nil,
            Description = nil,
            Duration = nil,
            Action = nil,
            Exists = nil,
            Price = nil,
            CurrencyIcon = "rbxassetid://14867116353",
            CurrencyColor = Color3.fromRGB(66, 245, 255),
            CurrencyIconColor = Color3.new(1, 1, 1),
            Width = nil,
            RarityColor = nil,
            RarityGradient = nil,
            RarityStrokeColor = nil,
        }

        if type(value) ~= "table" then
            result.Title = tostring(value)
            return result
        end

        result.Title = joinInfoText(firstInfoValue(value, "Title", "Name", "Text"))
        result.Rarity = joinInfoText(firstInfoValue(value, "Rarity", "Tier"))
        result.Description = joinInfoText(firstInfoValue(value, "Description", "Desc", "Body"))
        result.Duration = joinInfoText(firstInfoValue(value, "Duration", "Time"))
        result.Action = joinInfoText(firstInfoValue(value, "Action", "AdditionalDescription", "Hint", "Message"))
        result.Exists = formatInfoExists(value.Exists)
        result.Width = tonumber(firstInfoValue(value, "Width", "TooltipWidth"))
        if typeof(value.RarityColor) == "Color3" then
            result.RarityColor = value.RarityColor
        end
        if typeof(value.RarityGradient) == "ColorSequence" then
            result.RarityGradient = value.RarityGradient
        end
        if typeof(value.RarityStrokeColor) == "Color3" then
            result.RarityStrokeColor = value.RarityStrokeColor
        end
        if typeof(value.CurrencyColor) == "Color3" then
            result.CurrencyColor = value.CurrencyColor
        end
        if typeof(value.CurrencyIconColor) == "Color3" then
            result.CurrencyIconColor = value.CurrencyIconColor
        end

        local directIcon = firstInfoValue(value, "CurrencyIcon", "Icon")
        if directIcon ~= nil then
            result.CurrencyIcon = tostring(directIcon)
        end

        local directPrice = firstInfoValue(value, "Price", "PriceText", "Amount")
        if directPrice ~= nil then
            applyInfoCurrency(result, directPrice)
        elseif value.Currency ~= nil then
            applyInfoCurrency(result, value.Currency)
        end

        local blocks = value.Blocks
        if type(blocks) ~= "table" then
            blocks = value
        end

        for _, block in ipairs(blocks) do
            if type(block) == "table" then
                local kind = tostring(block[1] or block.Type or block.Kind or "")
                local normalized = kind:lower():gsub("[%s_%-]", "")
                local blockValue = block[2]
                if blockValue == nil then
                    blockValue = firstInfoValue(block, "Value", "Text", "Amount")
                end

                if normalized == "title" then
                    result.Title = joinInfoText(blockValue) or result.Title
                elseif normalized == "rarity" or normalized == "tier" then
                    result.Rarity = joinInfoText(blockValue) or result.Rarity
                    if typeof(block.Color) == "Color3" then
                        result.RarityColor = block.Color
                    end
                    if typeof(block.Gradient) == "ColorSequence" then
                        result.RarityGradient = block.Gradient
                    end
                elseif normalized == "desc" or normalized == "description" or normalized == "body" or normalized == "subtitle" then
                    result.Description = appendInfoText(result.Description, blockValue)
                elseif normalized == "duration" or normalized == "time" then
                    result.Duration = appendInfoText(result.Duration, blockValue)
                elseif normalized == "action" or normalized == "message" or normalized == "hint" or normalized == "additionaldescription" then
                    result.Action = appendInfoText(result.Action, blockValue)
                elseif normalized == "exists" or normalized == "exist" then
                    result.Exists = formatInfoExists(blockValue)
                elseif normalized == "currency" or normalized == "price" or normalized == "cost" then
                    applyInfoCurrency(result, blockValue, block[3])
                elseif normalized == "currencyicon" or normalized == "icon" then
                    if blockValue ~= nil then
                        result.CurrencyIcon = tostring(blockValue)
                    end
                elseif normalized == "width" then
                    result.Width = tonumber(blockValue) or result.Width
                end
            end
        end

        if result.Title == nil and value[1] ~= nil and type(value[1]) ~= "table" then
            result.Title = tostring(value[1])
        end

        return result
    end

    local INFO_RARITY_GRADIENTS = {
        basic = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(210, 215, 226)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(151, 158, 176)),
        }),
        rare = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(94, 215, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(109, 154, 255)),
        }),
        epic = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(225, 116, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(147, 91, 255)),
        }),
        legendary = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 223, 82)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 145, 49)),
        }),
        mythical = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 89, 144)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 46, 76)),
        }),
        exclusive = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(166, 139, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(173, 79, 255)),
        }),
        superior = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(200, 255, 255)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(220, 255, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(185, 255, 255)),
        }),
        secret = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(94, 94, 94)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
        }),
    }

    local function applyInfoRarityVisual(self, data)
        local label = self.TooltipRarityLabel
        local gradient = self.TooltipRarityGradient
        if not label or not gradient then
            return
        end
        local sequence = data.RarityGradient
        if sequence == nil and typeof(data.RarityColor) == "Color3" then
            sequence = ColorSequence.new(data.RarityColor)
        end
        if sequence == nil then
            local key = tostring(data.Rarity or ""):lower():gsub("[%s_%-]", "")
            sequence = INFO_RARITY_GRADIENTS[key] or INFO_RARITY_GRADIENTS.superior
        end
        gradient.Color = sequence
        label.TextColor3 = Color3.new(1, 1, 1)
        if self.TooltipRarityStroke then
            self.TooltipRarityStroke.Color = data.RarityStrokeColor or Color3.fromRGB(47, 80, 82)
        end
    end

    function Library:_ensureTooltip()
        if self.TooltipPanel then
            return self.TooltipPanel
        end

        local panel = Instance.new("Frame")
        panel.Name = "InfoOverlay"
        panel.Active = true
        panel.AnchorPoint = Vector2.new(0, 0)
        panel.BackgroundTransparency = 1
        panel.BorderSizePixel = 0
        panel.ClipsDescendants = false
        panel.Size = UDim2.fromOffset(320, 120)
        panel.Visible = false
        panel.ZIndex = 400
        panel.Parent = self.Screen

        local scale = Instance.new("UIScale")
        scale.Name = "UIScale"
        scale.Scale = 1
        scale.Parent = panel

        local shadow = Instance.new("ImageLabel")
        shadow.Name = "shadow"
        shadow.AnchorPoint = Vector2.new(0.5, 0.5)
        shadow.BackgroundTransparency = 1
        shadow.Image = "rbxassetid://14001321443"
        shadow.ImageColor3 = Color3.new(0, 0, 0)
        shadow.ImageTransparency = 0.85
        shadow.Position = UDim2.fromScale(0.5, 0.5)
        shadow.ScaleType = Enum.ScaleType.Slice
        shadow.Size = UDim2.new(1, 35, 1, 35)
        shadow.SliceCenter = Rect.new(50, 50, 150, 150)
        shadow.SliceScale = 0.8
        shadow.ZIndex = 400
        shadow.Parent = panel

        local main = Instance.new("Frame")
        main.Name = "Frame"
        main.BackgroundColor3 = Color3.new(1, 1, 1)
        main.BackgroundTransparency = 0
        main.BorderSizePixel = 0
        main.ClipsDescendants = true
        main.Size = UDim2.fromScale(1, 1)
        main.ZIndex = 401
        main.Parent = panel

        local mainCorner = Instance.new("UICorner")
        mainCorner.CornerRadius = UDim.new(0, 16)
        mainCorner.Parent = main

        local mainStroke = Instance.new("UIStroke")
        mainStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        mainStroke.Color = Color3.fromRGB(42, 43, 49)
        mainStroke.LineJoinMode = Enum.LineJoinMode.Round
        mainStroke.Thickness = 3
        mainStroke.Transparency = 0
        mainStroke.Parent = main

        local background = Instance.new("ImageLabel")
        background.Name = "background"
        background.AnchorPoint = Vector2.new(0, 1)
        background.BackgroundTransparency = 1
        background.Image = "rbxassetid://13581793331"
        background.ImageColor3 = Color3.fromRGB(20, 58, 67)
        background.ImageTransparency = 0.95
        background.Position = UDim2.new(0, 0, 1, 0)
        background.ScaleType = Enum.ScaleType.Tile
        background.Size = UDim2.fromScale(1, 1)
        background.TileSize = UDim2.fromOffset(171, 135)
        background.ZIndex = 401
        background.Parent = main

        local backgroundCorner = Instance.new("UICorner")
        backgroundCorner.CornerRadius = UDim.new(0, 16)
        backgroundCorner.Parent = background

        local backgroundGradient = Instance.new("UIGradient")
        backgroundGradient.Rotation = -90
        backgroundGradient.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(0.310087, 0.39375),
            NumberSequenceKeypoint.new(0.495641, 0.59375),
            NumberSequenceKeypoint.new(0.738481, 0.825),
            NumberSequenceKeypoint.new(1, 1),
        })
        backgroundGradient.Parent = background

        local blocks = Instance.new("Frame")
        blocks.Name = "Blocks"
        blocks.BackgroundTransparency = 1
        blocks.Size = UDim2.fromScale(1, 1)
        blocks.ZIndex = 402
        blocks.Parent = main

        local padding = Instance.new("UIPadding")
        padding.PaddingBottom = UDim.new(0, 9)
        padding.PaddingLeft = UDim.new(0, 16)
        padding.PaddingRight = UDim.new(0, 16)
        padding.PaddingTop = UDim.new(0, 9)
        padding.Parent = blocks

        local layout = Instance.new("UIListLayout")
        layout.FillDirection = Enum.FillDirection.Vertical
        layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        layout.Padding = UDim.new(0, 3)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.VerticalAlignment = Enum.VerticalAlignment.Top
        layout.Parent = blocks

        local function createBlock(name, order, height)
            local block = Instance.new("Frame")
            block.Name = name
            block.BackgroundTransparency = 1
            block.LayoutOrder = order
            block.Size = UDim2.new(1, 0, 0, height)
            block.Visible = false
            block.ZIndex = 402
            block.Parent = blocks
            return block
        end

        local function createText(parent, name, textSize, color, fontFace)
            local label = Instance.new("TextLabel")
            label.Name = name
            label.AnchorPoint = Vector2.new(0.5, 0.5)
            label.BackgroundTransparency = 1
            label.FontFace = fontFace or Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
            label.Position = UDim2.fromScale(0.5, 0.5)
            label.Size = UDim2.fromScale(1, 1)
            label.Text = ""
            label.TextColor3 = color
            label.TextSize = textSize
            label.TextWrapped = true
            label.TextXAlignment = Enum.TextXAlignment.Center
            label.TextYAlignment = Enum.TextYAlignment.Center
            label.ZIndex = 403
            label.Parent = parent
            return label
        end

        local function createDivider(name, order)
            local block = createBlock(name, order, 10)
            local line = Instance.new("Frame")
            line.Name = "Line"
            line.AnchorPoint = Vector2.new(0.5, 0.5)
            line.BackgroundColor3 = Color3.fromRGB(222, 226, 229)
            line.BorderSizePixel = 0
            line.Position = UDim2.fromScale(0.5, 0.5)
            line.Size = UDim2.new(1, 0, 0, 3)
            line.ZIndex = 403
            line.Parent = block
            local lineCorner = Instance.new("UICorner")
            lineCorner.CornerRadius = UDim.new(1, 0)
            lineCorner.Parent = line
            local lineGradient = Instance.new("UIGradient")
            lineGradient.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 1),
                NumberSequenceKeypoint.new(0.12, 0.2),
                NumberSequenceKeypoint.new(0.5, 0),
                NumberSequenceKeypoint.new(0.88, 0.2),
                NumberSequenceKeypoint.new(1, 1),
            })
            lineGradient.Parent = line
            return block
        end

        local titleBlock = createBlock("Title", 1, 32)
        local title = createText(titleBlock, "title", 32, Color3.fromRGB(42, 43, 49))
        title.TextYAlignment = Enum.TextYAlignment.Top

        local rarityBlock = createBlock("Rarity", 2, 24)
        local rarity = createText(
            rarityBlock,
            "title",
            22,
            Color3.new(1, 1, 1),
            Font.new("rbxassetid://11702779409", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
        )
        local rarityGradient = Instance.new("UIGradient")
        rarityGradient.Name = "Tier Gradient"
        rarityGradient.Color = INFO_RARITY_GRADIENTS.superior
        rarityGradient.Rotation = 100
        rarityGradient.Parent = rarity
        local rarityStroke = Instance.new("UIStroke")
        rarityStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
        rarityStroke.Color = Color3.fromRGB(47, 80, 82)
        rarityStroke.LineJoinMode = Enum.LineJoinMode.Round
        rarityStroke.Thickness = 2
        rarityStroke.Parent = rarity

        local dividerTop = createDivider("Div", 3)

        local bodyBlock = createBlock("Desc", 4, 20)
        local body = createText(bodyBlock, "title", 20, Color3.fromRGB(128, 128, 128))
        body.LineHeight = 1.05

        local actionBlock = createBlock("Message", 5, 22)
        local action = createText(actionBlock, "title", 20, Color3.fromRGB(128, 128, 128))
        action.LineHeight = 1.05

        local dividerBottom = createDivider("DivBottom", 6)

        local existsBlock = createBlock("Exists", 7, 22)
        local exists = createText(existsBlock, "title", 20, Color3.fromRGB(42, 43, 49))

        local currencyBlock = createBlock("Currency", 8, 40)
        local currencyContent = Instance.new("Frame")
        currencyContent.Name = "Content"
        currencyContent.AnchorPoint = Vector2.new(0.5, 0.5)
        currencyContent.BackgroundTransparency = 1
        currencyContent.Position = UDim2.fromScale(0.5, 0.5)
        currencyContent.Size = UDim2.fromOffset(120, 40)
        currencyContent.ZIndex = 403
        currencyContent.Parent = currencyBlock

        local currencyIcon = Instance.new("ImageLabel")
        currencyIcon.Name = "Icon"
        currencyIcon.AnchorPoint = Vector2.new(0, 0.5)
        currencyIcon.BackgroundTransparency = 1
        currencyIcon.Image = "rbxassetid://14867116353"
        currencyIcon.Position = UDim2.new(0, 0, 0.5, 0)
        currencyIcon.ScaleType = Enum.ScaleType.Fit
        currencyIcon.Size = UDim2.fromOffset(38, 38)
        currencyIcon.ZIndex = 404
        currencyIcon.Parent = currencyContent

        local iconAspect = Instance.new("UIAspectRatioConstraint")
        iconAspect.AspectRatio = 1
        iconAspect.Parent = currencyIcon

        local currencyAmount = createText(
            currencyContent,
            "Amount",
            28,
            Color3.fromRGB(66, 245, 255),
            Font.new("rbxassetid://11702779409", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
        )
        currencyAmount.AnchorPoint = Vector2.new(0, 0.5)
        currencyAmount.Position = UDim2.new(0, 42, 0.5, 0)
        currencyAmount.Size = UDim2.new(1, -42, 1, 0)
        currencyAmount.TextWrapped = false
        currencyAmount.TextXAlignment = Enum.TextXAlignment.Left
        local amountStroke = Instance.new("UIStroke")
        amountStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
        amountStroke.Color = Color3.new(0, 0, 0)
        amountStroke.LineJoinMode = Enum.LineJoinMode.Bevel
        amountStroke.Thickness = 2.5
        amountStroke.Parent = currencyAmount

        self.TooltipPanel = panel
        self.TooltipMain = main
        self.TooltipScale = scale
        self.TooltipBlocks = blocks
        self.TooltipLayout = layout
        self.TooltipTitleBlock = titleBlock
        self.TooltipTitleLabel = title
        self.TooltipRarityBlock = rarityBlock
        self.TooltipRarityLabel = rarity
        self.TooltipRarityGradient = rarityGradient
        self.TooltipRarityStroke = rarityStroke
        self.TooltipDividerTop = dividerTop
        self.TooltipBodyBlock = bodyBlock
        self.TooltipBodyLabel = body
        self.TooltipActionBlock = actionBlock
        self.TooltipActionLabel = action
        self.TooltipDividerBottom = dividerBottom
        self.TooltipExistsBlock = existsBlock
        self.TooltipExistsLabel = exists
        self.TooltipCurrencyBlock = currencyBlock
        self.TooltipCurrencyContent = currencyContent
        self.TooltipCurrencyIcon = currencyIcon
        self.TooltipCurrencyAmount = currencyAmount

        local moveConnection = UserInputService.InputChanged:Connect(function(inputObject)
            if panel.Visible and inputObject.UserInputType == Enum.UserInputType.MouseMovement then
                self:_positionTooltip(self.TooltipTarget)
            end
        end)
        self.TooltipMoveConnection = moveConnection
        if self._V8Connections then
            table.insert(self._V8Connections, moveConnection)
        else
            panel.Destroying:Connect(function()
                if moveConnection.Connected then
                    moveConnection:Disconnect()
                end
            end)
        end

        return panel
    end

    function Library:_positionTooltip(target)
        local panel = self.TooltipPanel
        if not panel or not panel.Visible then
            return
        end
        local camera = workspace.CurrentCamera
        local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
        local mousePosition = UserInputService:GetMouseLocation()
        if target and UserInputService.GamepadEnabled and GuiService.SelectedObject == target then
            mousePosition = target.AbsolutePosition + target.AbsoluteSize * 0.5
        end
        local panelSize = panel.AbsoluteSize
        if panelSize.X <= 0 or panelSize.Y <= 0 then
            panelSize = Vector2.new(panel.Size.X.Offset, panel.Size.Y.Offset)
        end
        local x = mousePosition.X + 12
        local y = mousePosition.Y + 12
        if x + panelSize.X >= viewport.X then
            x = mousePosition.X - panelSize.X - 12
        end
        if y + panelSize.Y >= viewport.Y then
            y = mousePosition.Y - panelSize.Y - 12
        end
        x = math.clamp(x, 0, math.max(0, viewport.X - panelSize.X))
        y = math.clamp(y, 0, math.max(0, viewport.Y - panelSize.Y))
        panel.Position = UDim2.fromOffset(x, y)
    end

    function Library:ShowTooltip(value, target)
        if self.TooltipsEnabled == false then
            return
        end

        local data = resolveInfoTooltip(value)
        if not data or not data.Title or data.Title == "" then
            self:HideTooltip()
            return
        end

        self:_ensureTooltip()

        local hasRarity = data.Rarity ~= nil and data.Rarity ~= ""
        local bodyText = data.Description
        if data.Duration ~= nil and data.Duration ~= "" then
            bodyText = appendInfoText(bodyText, data.Duration)
        end
        local hasBody = bodyText ~= nil and bodyText ~= ""
        local hasAction = data.Action ~= nil and data.Action ~= ""
        local hasExists = data.Exists ~= nil and data.Exists ~= ""
        local hasCurrency = data.Price ~= nil and data.Price ~= ""
        local rich = hasRarity or hasBody or hasAction or hasExists or hasCurrency

        local width
        if data.Width ~= nil then
            width = math.clamp(data.Width, 180, 420)
        elseif rich then
            width = 320
        else
            local compactBounds = measureInfoText(data.Title, 32, 300)
            width = math.clamp(compactBounds.X + 32, 100, 332)
        end
        local innerWidth = math.max(60, width - 32)

        local visibleBlocks = 0
        local contentHeight = 18

        local function setBlock(block, visible, height)
            block.Visible = visible
            if visible then
                block.Size = UDim2.new(1, 0, 0, height)
                contentHeight += height
                visibleBlocks += 1
            end
        end

        local titleBounds = measureInfoText(data.Title, 32, innerWidth)
        local titleHeight = math.max(32, titleBounds.Y)
        self.TooltipTitleLabel.Text = data.Title
        setBlock(self.TooltipTitleBlock, true, titleHeight)

        self.TooltipRarityLabel.Text = data.Rarity or ""
        setBlock(self.TooltipRarityBlock, hasRarity, 24)
        if hasRarity then
            applyInfoRarityVisual(self, data)
        end

        local showTopDivider = hasRarity and (hasBody or hasAction or hasExists or hasCurrency)
        setBlock(self.TooltipDividerTop, showTopDivider, 10)

        self.TooltipBodyLabel.Text = bodyText or ""
        local bodyHeight = 20
        if hasBody then
            bodyHeight = math.max(20, measureInfoText(bodyText, 20, innerWidth).Y)
        end
        setBlock(self.TooltipBodyBlock, hasBody, bodyHeight)

        self.TooltipActionLabel.Text = data.Action or ""
        local actionHeight = 22
        if hasAction then
            actionHeight = math.max(22, measureInfoText(data.Action, 20, innerWidth).Y)
        end
        setBlock(self.TooltipActionBlock, hasAction, actionHeight)

        local showBottomDivider = (hasExists or hasCurrency) and (hasBody or hasAction)
        setBlock(self.TooltipDividerBottom, showBottomDivider, 10)

        self.TooltipExistsLabel.Text = data.Exists or ""
        local existsHeight = 22
        if hasExists then
            existsHeight = math.max(22, measureInfoText(data.Exists, 20, innerWidth).Y)
        end
        setBlock(self.TooltipExistsBlock, hasExists, existsHeight)

        self.TooltipCurrencyAmount.Text = data.Price or ""
        self.TooltipCurrencyAmount.TextColor3 = data.CurrencyColor or Color3.fromRGB(66, 245, 255)
        self.TooltipCurrencyIcon.Image = data.CurrencyIcon or "rbxassetid://14867116353"
        self.TooltipCurrencyIcon.ImageColor3 = data.CurrencyIconColor or Color3.new(1, 1, 1)
        if hasCurrency then
            local amountBounds = measureInfoText(data.Price, 28, innerWidth - 42)
            local amountWidth = math.min(math.max(1, amountBounds.X + 4), innerWidth - 42)
            local contentWidth = math.min(innerWidth, 42 + amountWidth)
            self.TooltipCurrencyContent.Size = UDim2.fromOffset(contentWidth, 40)
        end
        setBlock(self.TooltipCurrencyBlock, hasCurrency, 40)

        if visibleBlocks > 1 then
            contentHeight += (visibleBlocks - 1) * 3
        end

        self.TooltipPanel.Size = UDim2.fromOffset(width, contentHeight)
        self.TooltipPanel.Visible = true
        self.TooltipTarget = target
        self.TooltipValue = value

        if self.TooltipScale then
            self.TooltipScale.Scale = 0.92
            TweenService:Create(
                self.TooltipScale,
                TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
                {Scale = 1}
            ):Play()
        end

        if self.TooltipSoundEnabled ~= false then
            local sound = Instance.new("Sound")
            sound.SoundId = "rbxassetid://6907626084"
            sound.Volume = 0.2
            sound.Parent = SoundService
            sound.Ended:Connect(function()
                sound:Destroy()
            end)
            pcall(function()
                sound:Play()
            end)
            task.delay(2, function()
                if sound.Parent then
                    sound:Destroy()
                end
            end)
        end

        task.defer(function()
            self:_positionTooltip(target)
        end)
    end

    function Library:HideTooltip()
        if self.TooltipPanel then
            self.TooltipPanel.Visible = false
        end
        self.TooltipTarget = nil
        self.TooltipValue = nil
    end

    function Library:AttachTooltip(object, value)
        if not object or not object:IsA("GuiObject") then
            return function() end
        end

        if type(value) == "string" or type(value) == "number" then
            object:SetAttribute("Tooltip", tostring(value))
        else
            object:SetAttribute("Tooltip", nil)
        end

        local connections = {}
        local touchToken = 0

        local function resolve()
            if type(value) == "function" then
                local ok, result = pcall(value)
                if not ok then
                    warn(tostring(result))
                    return nil
                end
                return result
            end
            return value
        end

        local function show()
            local tooltip = resolve()
            if tooltip ~= nil then
                self:ShowTooltip(tooltip, object)
            end
        end

        table.insert(connections, object.MouseEnter:Connect(show))
        table.insert(connections, object.MouseLeave:Connect(function()
            if self.TooltipTarget == object then
                self:HideTooltip()
            end
        end))
        table.insert(connections, object.SelectionGained:Connect(show))
        table.insert(connections, object.SelectionLost:Connect(function()
            if self.TooltipTarget == object then
                self:HideTooltip()
            end
        end))
        table.insert(connections, object.InputBegan:Connect(function(inputObject)
            if inputObject.UserInputType == Enum.UserInputType.Touch then
                touchToken += 1
                local token = touchToken
                task.delay(0.45, function()
                    if token == touchToken and object.Parent then
                        show()
                    end
                end)
            end
        end))
        table.insert(connections, object.InputEnded:Connect(function(inputObject)
            if inputObject.UserInputType == Enum.UserInputType.Touch then
                touchToken += 1
                task.delay(1.5, function()
                    if self.TooltipTarget == object then
                        self:HideTooltip()
                    end
                end)
            end
        end))

        return function()
            for _, connection in ipairs(connections) do
                connection:Disconnect()
            end
            if self.TooltipTarget == object then
                self:HideTooltip()
            end
        end
    end

    function Library:AttachItemTooltip(object, value)
        return self:AttachTooltip(object, value)
    end

    function Library:_ensureNotificationHost()
        if self.NotificationHost then
            return self.NotificationHost
        end
        local host = Instance.new("Frame")
        host.Name = "Notifications"
        host.AnchorPoint = Vector2.new(1, 0)
        host.AutomaticSize = Enum.AutomaticSize.Y
        host.BackgroundTransparency = 1
        host.Position = UDim2.new(1, -18, 0, 18)
        host.Size = UDim2.fromOffset(330, 0)
        host.ZIndex = 250
        host.Parent = self.Screen
        local layout = Instance.new("UIListLayout")
        layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
        layout.Padding = UDim.new(0, 8)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.VerticalAlignment = Enum.VerticalAlignment.Top
        layout.Parent = host
        self.NotificationHost = host
        self.NotificationOrder = 0
        return host
    end

    function Library:Notify(notificationSettings)
        local settings = type(notificationSettings) == "table" and notificationSettings or {Content = tostring(notificationSettings)}
        local host = self:_ensureNotificationHost()
        self.NotificationOrder += 1
        local panel = self.Templates.Locked:Clone()
        panel.Name = tostring(settings.Title or "Notification")
        panel.AnchorPoint = Vector2.new(1, 0)
        panel.AutomaticSize = Enum.AutomaticSize.None
        panel.ClipsDescendants = true
        panel.LayoutOrder = self.NotificationOrder
        panel.Size = UDim2.fromOffset(0, 92)
        panel.Visible = true
        panel.ZIndex = 251
        panel.Parent = host
        local price = panel:FindFirstChild("PriceFrame")
        if price then
            price:Destroy()
        end
        local aspect = panel:FindFirstChildOfClass("UIAspectRatioConstraint")
        if aspect then
            aspect:Destroy()
        end
        local title = Instance.new("TextLabel")
        title.Name = "Title"
        title.BackgroundTransparency = 1
        title.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
        title.Position = UDim2.fromOffset(16, 9)
        title.Size = UDim2.new(1, -55, 0, 26)
        title.Text = tostring(settings.Title or "Notification")
        title.TextColor3 = Color3.new(1, 1, 1)
        title.TextSize = 22
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.ZIndex = 253
        title.Parent = panel
        local titleStroke = Instance.new("UIStroke")
        titleStroke.Color = Color3.fromRGB(42, 43, 49)
        titleStroke.Thickness = 2
        titleStroke.Parent = title
        local content = Instance.new("TextLabel")
        content.Name = "Content"
        content.BackgroundTransparency = 1
        content.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
        content.Position = UDim2.fromOffset(16, 38)
        content.Size = UDim2.new(1, -32, 0, 43)
        content.Text = tostring(settings.Content or "")
        content.TextColor3 = Color3.fromRGB(248, 248, 248)
        content.TextSize = 16
        content.TextWrapped = true
        content.TextXAlignment = Enum.TextXAlignment.Left
        content.TextYAlignment = Enum.TextYAlignment.Top
        content.ZIndex = 253
        content.Parent = panel
        local close = Instance.new("TextButton")
        close.Name = "Close"
        close.AnchorPoint = Vector2.new(1, 0)
        close.AutoButtonColor = false
        close.BackgroundTransparency = 1
        close.Position = UDim2.new(1, -8, 0, 7)
        close.Size = UDim2.fromOffset(28, 28)
        close.Text = "×"
        close.FontFace = title.FontFace
        close.TextColor3 = Color3.new(1, 1, 1)
        close.TextSize = 27
        close.ZIndex = 254
        close.Parent = panel
        GUIFX.ButtonFX(close, 1.1)
        local notificationType = string.lower(tostring(settings.Type or "Info")):gsub("[%s_%-]", "")
        local notificationAliases = {
            success = "GreenGradient",
            error = "RedGradient",
            danger = "RedGradient",
            warning = "YellowGradient",
            info = "BlueGradient",
        }
        local gradientName = notificationAliases[notificationType] or SECTION_GRADIENT_ALIASES[notificationType] or "BlueGradient"
        local gradient = Gradients:FindFirstChild(gradientName)
        if gradient then
            gradient:Clone().Parent = panel
        end
        local closed = false
        local function dismiss()
            if closed then
                return
            end
            closed = true
            TweenService:Create(panel, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
                Size = UDim2.fromOffset(0, 92),
                BackgroundTransparency = 1,
            }):Play()
            task.delay(0.3, function()
                if panel.Parent then
                    panel:Destroy()
                end
            end)
        end
        close.Activated:Connect(dismiss)
        TweenService:Create(panel, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.fromOffset(320, 92),
        }):Play()
        local duration = tonumber(settings.Duration)
        if duration == nil then
            duration = 4
        end
        if duration > 0 then
            task.delay(duration, dismiss)
        end
        return {
            Close = dismiss,
            Destroy = dismiss,
            SetTitle = function(_, value)
                title.Text = tostring(value)
            end,
            SetContent = function(_, value)
                content.Text = tostring(value)
            end,
        }
    end

    local function buildNativeAlertTemplate()
        local frame = Instance.new("Frame")
        frame.Name = "Alert"
        frame.BackgroundColor3 = Color3.new(1, 1, 1)
        frame.BackgroundTransparency = 1
        frame.BorderSizePixel = 0
        frame.Size = UDim2.fromScale(1, 1)
        frame.Visible = true

        local title = Instance.new("TextLabel")
        title.Name = "Title"
        title.BackgroundColor3 = Color3.new(1, 1, 1)
        title.BackgroundTransparency = 1
        title.BorderSizePixel = 0
        title.Position = UDim2.new(0, 0, 0, 2)
        title.Size = UDim2.new(0.95, 0, 0.25, 0)
        title.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
        title.Text = "Quest Completed!"
        title.TextColor3 = Color3.fromRGB(255, 245, 106)
        title.TextScaled = true
        title.TextSize = 18
        title.TextStrokeColor3 = Color3.new(0, 0, 0)
        title.TextStrokeTransparency = 1
        title.TextWrapped = true
        title.TextXAlignment = Enum.TextXAlignment.Center
        title.TextYAlignment = Enum.TextYAlignment.Center
        title.Parent = frame

        local titleStroke = Instance.new("UIStroke")
        titleStroke.Color = Color3.new(0, 0, 0)
        titleStroke.Thickness = 3
        titleStroke.Transparency = 0
        titleStroke.Parent = title

        local desc = Instance.new("TextLabel")
        desc.Name = "Desc"
        desc.AnchorPoint = Vector2.new(0.5, 1)
        desc.BackgroundColor3 = Color3.new(1, 1, 1)
        desc.BackgroundTransparency = 1
        desc.BorderSizePixel = 0
        desc.Position = UDim2.new(0.5, 0, 1, 0)
        desc.Size = UDim2.new(0.8, 0, 0.7, -2)
        desc.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
        desc.Text = "Short desc"
        desc.TextColor3 = Color3.new(1, 1, 1)
        desc.TextScaled = true
        desc.TextSize = 18
        desc.TextStrokeColor3 = Color3.new(0, 0, 0)
        desc.TextStrokeTransparency = 1
        desc.TextWrapped = true
        desc.TextXAlignment = Enum.TextXAlignment.Center
        desc.TextYAlignment = Enum.TextYAlignment.Center
        desc.Parent = frame

        local descStroke = Instance.new("UIStroke")
        descStroke.Color = Color3.new(0, 0, 0)
        descStroke.Thickness = 2.5
        descStroke.Transparency = 0
        descStroke.Parent = desc

        local descSize = Instance.new("UITextSizeConstraint")
        descSize.MaxTextSize = 34
        descSize.MinTextSize = 1
        descSize.Parent = desc

        return frame
    end

    local function buildNativeImageAlertTemplate()
        local frame = Instance.new("Frame")
        frame.Name = "ImageAlert"
        frame.BackgroundColor3 = Color3.new(1, 1, 1)
        frame.BackgroundTransparency = 1
        frame.BorderSizePixel = 0
        frame.Size = UDim2.fromScale(1, 1)
        frame.Visible = true

        local holder = Instance.new("Frame")
        holder.Name = "Holder"
        holder.AnchorPoint = Vector2.new(0, 0.5)
        holder.BackgroundColor3 = Color3.new(1, 1, 1)
        holder.BackgroundTransparency = 1
        holder.BorderSizePixel = 0
        holder.Position = UDim2.new(0, 0, 0.5, 0)
        holder.Size = UDim2.fromScale(0.9, 0.9)
        holder.Parent = frame

        local holderAspect = Instance.new("UIAspectRatioConstraint")
        holderAspect.AspectRatio = 1
        holderAspect.AspectType = Enum.AspectType.FitWithinMaxSize
        holderAspect.DominantAxis = Enum.DominantAxis.Width
        holderAspect.Parent = holder

        local image = Instance.new("ImageLabel")
        image.Name = "ImageLabel"
        image.BackgroundColor3 = Color3.new(1, 1, 1)
        image.BackgroundTransparency = 1
        image.BorderSizePixel = 0
        image.Image = "rbxassetid://15000811448"
        image.ImageColor3 = Color3.new(1, 1, 1)
        image.ImageTransparency = 0
        image.ScaleType = Enum.ScaleType.Fit
        image.Size = UDim2.fromScale(1, 1)
        image.ZIndex = 5
        image.Parent = holder

        local textHolder = Instance.new("Frame")
        textHolder.Name = "TextHolder"
        textHolder.AnchorPoint = Vector2.new(1, 0.5)
        textHolder.BackgroundColor3 = Color3.new(1, 1, 1)
        textHolder.BackgroundTransparency = 1
        textHolder.BorderSizePixel = 0
        textHolder.Position = UDim2.new(1, 0, 0.5, 0)
        textHolder.Size = UDim2.fromScale(0.65, 0.95)
        textHolder.Parent = frame

        local layout = Instance.new("UIListLayout")
        layout.FillDirection = Enum.FillDirection.Vertical
        layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
        layout.Padding = UDim.new(0.08, 0)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.VerticalAlignment = Enum.VerticalAlignment.Top
        layout.Parent = textHolder

        local title = Instance.new("TextLabel")
        title.Name = "Title"
        title.BackgroundColor3 = Color3.new(1, 1, 1)
        title.BackgroundTransparency = 1
        title.BorderSizePixel = 0
        title.LayoutOrder = 1
        title.Size = UDim2.new(1, 0, 0.3, 0)
        title.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
        title.Text = "Coin Jar Event!"
        title.TextColor3 = Color3.fromRGB(255, 245, 106)
        title.TextScaled = true
        title.TextSize = 18
        title.TextStrokeColor3 = Color3.new(0, 0, 0)
        title.TextStrokeTransparency = 1
        title.TextWrapped = true
        title.TextXAlignment = Enum.TextXAlignment.Center
        title.TextYAlignment = Enum.TextYAlignment.Center
        title.Parent = textHolder

        local titleStroke = Instance.new("UIStroke")
        titleStroke.Color = Color3.new(0, 0, 0)
        titleStroke.Thickness = 3
        titleStroke.Transparency = 0
        titleStroke.Parent = title

        local desc = Instance.new("TextLabel")
        desc.Name = "Desc"
        desc.BackgroundColor3 = Color3.new(1, 1, 1)
        desc.BackgroundTransparency = 1
        desc.BorderSizePixel = 0
        desc.LayoutOrder = 3
        desc.Size = UDim2.new(1, 0, 0.3, 0)
        desc.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
        desc.Text = "Starting in Hot Springs"
        desc.TextColor3 = Color3.new(1, 1, 1)
        desc.TextScaled = true
        desc.TextSize = 18
        desc.TextStrokeColor3 = Color3.new(0, 0, 0)
        desc.TextStrokeTransparency = 1
        desc.TextWrapped = true
        desc.TextXAlignment = Enum.TextXAlignment.Center
        desc.TextYAlignment = Enum.TextYAlignment.Center
        desc.Parent = textHolder

        local descStroke = Instance.new("UIStroke")
        descStroke.Color = Color3.new(0, 0, 0)
        descStroke.Thickness = 2.5
        descStroke.Transparency = 0
        descStroke.Parent = desc

        return frame
    end

    local function cloneNativeNotificationTemplate(name)
        local replicatedStorage = game:GetService("ReplicatedStorage")
        local assets = replicatedStorage:FindFirstChild("Assets")
        local ui = assets and assets:FindFirstChild("UI")
        local notifications = ui and ui:FindFirstChild("Notifications")
        local top = notifications and notifications:FindFirstChild("Top")
        local template = top and top:FindFirstChild(name)
        if template then
            return template:Clone()
        end
        if name == "ImageAlert" then
            return buildNativeImageAlertTemplate()
        end
        return buildNativeAlertTemplate()
    end

    local function ensureNativeNotificationHost(self)
        local existing = self._NativeNotificationHost
        if existing and existing.Screen and existing.Screen.Parent then
            return existing
        end

        local parent = self.Screen and self.Screen.Parent
        if not parent then
            local player = Players.LocalPlayer
            parent = player and player:FindFirstChildOfClass("PlayerGui")
            if not parent and player then
                parent = player:WaitForChild("PlayerGui")
            end
        end

        local screen = Instance.new("ScreenGui")
        screen.Name = "Notifications"
        screen.AutoLocalize = true
        screen.ClipToDeviceSafeArea = true
        screen.DisplayOrder = self.Screen and (self.Screen.DisplayOrder - 1) or -1
        screen.Enabled = true
        screen.ResetOnSpawn = false
        screen.SafeAreaCompatibility = Enum.SafeAreaCompatibility.FullscreenExtension
        screen.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
        screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        screen.Parent = parent

        local top = Instance.new("Frame")
        top.Name = "Top"
        top.AnchorPoint = Vector2.new(0.5, 0)
        top.BackgroundColor3 = Color3.new(0, 0, 0)
        top.BackgroundTransparency = 0.8
        top.BorderSizePixel = 0
        top.ClipsDescendants = false
        top.Position = UDim2.new(.5,0,0,-9999)
        top.Size = UDim2.new(0.5, 25, 0.125, 25)
        top.Visible = false
        top.Parent = screen

        local topAspect = Instance.new("UIAspectRatioConstraint")
        topAspect.Name = "UIAspectRatioConstraint"
        topAspect.AspectRatio = 3
        topAspect.AspectType = Enum.AspectType.FitWithinMaxSize
        topAspect.DominantAxis = Enum.DominantAxis.Width
        topAspect.Parent = top

        local topPadding = Instance.new("UIPadding")
        topPadding.Name = "UIPadding"
        topPadding.PaddingBottom = UDim.new(0.025, 0)
        topPadding.PaddingLeft = UDim.new(0.025, 2)
        topPadding.PaddingRight = UDim.new(0.025, 2)
        topPadding.PaddingTop = UDim.new(0.025, 0)
        topPadding.Parent = top

        local topGradient = Instance.new("UIGradient")
        topGradient.Name = "UIGradient"
        topGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
            ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)),
        })
        topGradient.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(0.19202, 0),
            NumberSequenceKeypoint.new(1, 1),
        })
        topGradient.Offset = Vector2.new(0, 0)
        topGradient.Rotation = 90
        topGradient.Scale = 1
        topGradient.TileMode = Enum.GradientTileMode.Clamp
        topGradient.Type = Enum.GradientType.Linear
        topGradient.Parent = top

        existing = {
            Screen = screen,
            Top = top,
            Queue = {},
            Current = nil,
            Running = false,
        }
        self._NativeNotificationHost = existing
        return existing
    end

    local function removeQueuedNotification(host, handle)
        for index, queued in ipairs(host.Queue) do
            if queued == handle then
                table.remove(host.Queue, index)
                return true
            end
        end
        return false
    end

    local function processNativeNotificationQueue(host)
        if host.Running then
            return
        end
        host.Running = true
        task.spawn(function()
            while host.Screen and host.Screen.Parent do
                local handle = table.remove(host.Queue, 1)
                if not handle then
                    break
                end
                if not handle._Cancelled then
                    host.Current = handle
                    local top = host.Top
                    local frame = handle.Frame
                    frame.Parent = top
                    top.Visible = true
                    task.wait()
                    local hiddenPosition = UDim2.new(0.5, 0, 0, -top.AbsoluteSize.Y - 40)
                    top.Position = hiddenPosition
                    TweenService:Create(top, TweenInfo.new(0.65, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
                        Position = UDim2.new(0.5, 0, 0, 0),
                    }):Play()

                    if handle.Started then
                        task.spawn(handle.Started)
                    end

                    local deadline = os.clock() + handle.Time
                    while not handle._CloseRequested and os.clock() < deadline and frame.Parent do
                        task.wait(0.03)
                    end

                    local outTween = TweenService:Create(top, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                        Position = hiddenPosition,
                    })
                    outTween:Play()
                    outTween.Completed:Wait()

                    if frame.Parent then
                        frame:Destroy()
                    end
                    top.Visible = false
                    host.Current = nil
                    handle._Closed = true
                end
            end
            host.Running = false
            if #host.Queue > 0 and host.Screen and host.Screen.Parent then
                processNativeNotificationQueue(host)
            end
        end)
    end

    local function enqueueNativeNotification(self, frame, settings, started)
        local host = ensureNativeNotificationHost(self)
        local handle = {
            Frame = frame,
            Time = math.max(0, tonumber(settings.Time) or 4),
            Started = started,
            _Closed = false,
            _Cancelled = false,
            _CloseRequested = false,
        }

        function handle:Close()
            if self._Closed then
                return
            end
            if host.Current == self then
                self._CloseRequested = true
            elseif removeQueuedNotification(host, self) then
                self._Cancelled = true
                self._Closed = true
                if self.Frame and self.Frame.Parent then
                    self.Frame:Destroy()
                end
            end
        end

        handle.Destroy = handle.Close

        local count = #host.Queue + (host.Current and 1 or 0)
        if count >= 6 then
            handle._Cancelled = true
            handle._Closed = true
            frame:Destroy()
            return handle
        end

        table.insert(host.Queue, handle)
        processNativeNotificationQueue(host)
        return handle
    end

    function Library:Alert(alertSettings, config)
        local settings = type(alertSettings) == "table" and alertSettings or {Desc = tostring(alertSettings)}
        if settings.Desc == nil and settings.Content ~= nil then
            settings.Desc = tostring(settings.Content)
        end
        if settings.Time == nil and settings.Duration ~= nil then
            settings.Time = settings.Duration
        end

        local frame = cloneNativeNotificationTemplate("Alert")
        local title = frame:FindFirstChild("Title")
        local desc = frame:FindFirstChild("Desc")
        if title then
            title.Text = tostring(settings.Title or "Alert")
        end
        if desc then
            desc.Text = tostring(settings.Desc or "")
        end

        return enqueueNativeNotification(self, frame, settings)
    end

    function Library:ImageAlert(alertSettings, config)
        local settings = type(alertSettings) == "table" and alertSettings or {Title = tostring(alertSettings)}
        if settings.Desc == nil and settings.Content ~= nil then
            settings.Desc = tostring(settings.Content)
        end
        if settings.Time == nil and settings.Duration ~= nil then
            settings.Time = settings.Duration
        end

        local frame = cloneNativeNotificationTemplate("ImageAlert")
        local textHolder = frame:FindFirstChild("TextHolder")
        local holder = frame:FindFirstChild("Holder")
        local title = textHolder and textHolder:FindFirstChild("Title")
        local desc = textHolder and textHolder:FindFirstChild("Desc")
        local image = holder and holder:FindFirstChild("ImageLabel")

        if title then
            title.Text = tostring(settings.Title or "Alert")
        end
        if desc then
            local content = settings.Desc
            if content == nil or tostring(content) == "" then
                desc.Visible = settings.UpdateTask ~= nil
                desc.Text = ""
            else
                desc.Visible = true
                desc.Text = tostring(content)
            end
        end
        if image and settings.Image ~= nil then
            image.Image = tostring(settings.Image)
        end

        local function started()
            local sound = Instance.new("Sound")
            sound.SoundId = "rbxassetid://15434452209"
            sound.Volume = 0.5
            sound.Parent = frame
            sound:Play()
            sound.Ended:Connect(function()
                if sound.Parent then
                    sound:Destroy()
                end
            end)

            if settings.UpdateTask and title and desc then
                task.spawn(function()
                    while frame.Parent do
                        local nextTitle, nextDesc = settings.UpdateTask()
                        title.Text = tostring(nextTitle or "")
                        desc.Text = tostring(nextDesc or "")
                        task.wait()
                    end
                end)
            end
        end

        return enqueueNativeNotification(self, frame, settings, started)
    end


    local function applyPS99Properties(object, properties)
        for property, value in pairs(properties) do
            pcall(function() object[property] = value end)
        end
        return object
    end

    local buildPS99MessageScreenCompiled
    local buildPS99MessageScreenSource = [============[
return function(applyPS99Properties)
    return function()
        local objects = {}
        objects[1] = Instance.new("ScreenGui")
        applyPS99Properties(objects[1], {
            ["ClipToDeviceSafeArea"] = true,
            ["DisplayOrder"] = 100,
            ["SafeAreaCompatibility"] = Enum.SafeAreaCompatibility.FullscreenExtension,
            ["ScreenInsets"] = Enum.ScreenInsets.DeviceSafeInsets,
            ["Enabled"] = false,
            ["ResetOnSpawn"] = false,
            ["ZIndexBehavior"] = Enum.ZIndexBehavior.Global,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "Message",
        })
        objects[2] = Instance.new("Frame")
        applyPS99Properties(objects[2], {
            ["Style"] = Enum.FrameStyle.Custom,
            ["Active"] = false,
            ["AnchorPoint"] = Vector2.new(0.5, 0.5),
            ["AutomaticSize"] = Enum.AutomaticSize.None,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 0,
            ["BorderColor3"] = Color3.new(0.105882362, 0.164705887, 0.207843155),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 0,
            ["Position"] = UDim2.new(0.5, 0, 0.5, 0),
            ["Rotation"] = 0,
            ["Selectable"] = false,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(1, 0, 0.400000006, 120),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = true,
            ["ZIndex"] = 1,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "Frame",
        })
        objects[2].Parent = objects[1]
        objects[3] = Instance.new("UIAspectRatioConstraint")
        applyPS99Properties(objects[3], {
            ["AspectRatio"] = 1.25,
            ["AspectType"] = Enum.AspectType.FitWithinMaxSize,
            ["DominantAxis"] = Enum.DominantAxis.Width,
            ["Name"] = "UIAspectRatioConstraint",
        })
        objects[3].Parent = objects[2]
        objects[4] = Instance.new("ImageLabel")
        applyPS99Properties(objects[4], {
            ["Image"] = "rbxassetid://13581793331",
            ["ImageColor3"] = Color3.new(0.0784313753, 0.227450997, 0.262745112),
            ["ImageRectOffset"] = Vector2.new(0, 0),
            ["ImageRectSize"] = Vector2.new(0, 0),
            ["ImageTransparency"] = 0.949999988,
            ["ResampleMode"] = Enum.ResamplerMode.Default,
            ["ScaleType"] = Enum.ScaleType.Tile,
            ["SliceCenter"] = Rect.new(0, 0, 0, 0),
            ["SliceScale"] = 1,
            ["TileSize"] = UDim2.new(0, 171, 0, 135),
            ["Active"] = false,
            ["AnchorPoint"] = Vector2.new(0, 1),
            ["AutomaticSize"] = Enum.AutomaticSize.None,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 1,
            ["BorderColor3"] = Color3.new(0.105882362, 0.164705887, 0.207843155),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 0,
            ["Position"] = UDim2.new(0, 0, 1, 0),
            ["Rotation"] = 0,
            ["Selectable"] = false,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(1, 0, 1, 0),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = true,
            ["ZIndex"] = 2,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "background",
        })
        objects[4].Parent = objects[2]
        objects[5] = Instance.new("UIGradient")
        applyPS99Properties(objects[5], {
            ["Color"] = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1))}),
            ["Enabled"] = true,
            ["Offset"] = Vector2.new(0, 0),
            ["Rotation"] = -90,
            ["Scale"] = 1,
            ["TileMode"] = Enum.GradientTileMode.Clamp,
            ["Transparency"] = NumberSequence.new({NumberSequenceKeypoint.new(0, 0, 0), NumberSequenceKeypoint.new(0.310087, 0.39375, 0), NumberSequenceKeypoint.new(0.495641, 0.59375, 0), NumberSequenceKeypoint.new(0.738481, 0.825, 0), NumberSequenceKeypoint.new(1, 1, 0)}),
            ["Type"] = Enum.GradientType.Linear,
            ["Name"] = "UIGradient",
        })
        objects[5].Parent = objects[4]
        objects[6] = Instance.new("UICorner")
        applyPS99Properties(objects[6], {
            ["BottomLeftRadius"] = UDim.new(0.0350000001, 0),
            ["BottomRightRadius"] = UDim.new(0.0350000001, 0),
            ["TopLeftRadius"] = UDim.new(0.0350000001, 0),
            ["TopRightRadius"] = UDim.new(0.0350000001, 0),
            ["Name"] = "UICorner",
        })
        objects[6].Parent = objects[4]
        objects[7] = Instance.new("Frame")
        applyPS99Properties(objects[7], {
            ["Style"] = Enum.FrameStyle.Custom,
            ["Active"] = false,
            ["AnchorPoint"] = Vector2.new(0.5, 0.5),
            ["AutomaticSize"] = Enum.AutomaticSize.None,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 0,
            ["BorderColor3"] = Color3.new(0.105882362, 0.164705887, 0.207843155),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 0,
            ["Position"] = UDim2.new(0.5, 0, 0.5, 0),
            ["Rotation"] = 0,
            ["Selectable"] = false,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(1, 0, 1, 0),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = true,
            ["ZIndex"] = 1,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "Contents",
        })
        objects[7].Parent = objects[2]
        objects[8] = Instance.new("UICorner")
        applyPS99Properties(objects[8], {
            ["BottomLeftRadius"] = UDim.new(0.0500000007, 0),
            ["BottomRightRadius"] = UDim.new(0.0500000007, 0),
            ["TopLeftRadius"] = UDim.new(0.0500000007, 0),
            ["TopRightRadius"] = UDim.new(0.0500000007, 0),
            ["Name"] = "UICorner",
        })
        objects[8].Parent = objects[7]
        objects[9] = Instance.new("UIPadding")
        applyPS99Properties(objects[9], {
            ["PaddingBottom"] = UDim.new(0, 4),
            ["PaddingLeft"] = UDim.new(0, 4),
            ["PaddingRight"] = UDim.new(0, 4),
            ["PaddingTop"] = UDim.new(0, 4),
            ["Name"] = "UIPadding",
        })
        objects[9].Parent = objects[7]
        objects[10] = Instance.new("ImageButton")
        applyPS99Properties(objects[10], {
            ["HoverImage"] = "",
            ["Image"] = "rbxassetid://14423621163",
            ["ImageColor3"] = Color3.new(1, 1, 1),
            ["ImageRectOffset"] = Vector2.new(0, 0),
            ["ImageRectSize"] = Vector2.new(0, 0),
            ["ImageTransparency"] = 0,
            ["PressedImage"] = "rbxassetid://14423621349",
            ["ResampleMode"] = Enum.ResamplerMode.Default,
            ["ScaleType"] = Enum.ScaleType.Slice,
            ["SliceCenter"] = Rect.new(20, 20, 80, 80),
            ["SliceScale"] = 0.967129648,
            ["TileSize"] = UDim2.new(1, 0, 1, 0),
            ["AutoButtonColor"] = true,
            ["Modal"] = false,
            ["Selected"] = false,
            ["Style"] = Enum.FrameStyle.Custom,
            ["Active"] = true,
            ["AnchorPoint"] = Vector2.new(0.5, 0.5),
            ["AutomaticSize"] = Enum.AutomaticSize.None,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 1,
            ["BorderColor3"] = Color3.new(0.105882362, 0.164705887, 0.207843155),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 0,
            ["Position"] = UDim2.new(0.75, 0, 0.86406666, 0),
            ["Rotation"] = 0,
            ["Selectable"] = true,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(0.446375281, 0, 0.150000006, 25),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = true,
            ["ZIndex"] = 6,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "No",
        })
        objects[10].Parent = objects[7]
        objects[11] = Instance.new("TextLabel")
        applyPS99Properties(objects[11], {
            ["FontFace"] = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
            ["LineHeight"] = 1,
            ["LocalizationMatchIdentifier"] = "ffd648f3-e1a2-4aaa-a4ca-3d2d33940ff0",
            ["LocalizationMatchedSourceText"] = "No",
            ["MaxVisibleGraphemes"] = -1,
            ["OpenTypeFeatures"] = "",
            ["RichText"] = false,
            ["Text"] = "No",
            ["TextColor3"] = Color3.new(1, 1, 1),
            ["TextDirection"] = Enum.TextDirection.Auto,
            ["TextScaled"] = true,
            ["TextSize"] = 18,
            ["TextStrokeColor3"] = Color3.new(0, 0, 0),
            ["TextStrokeTransparency"] = 1,
            ["TextTransparency"] = 0,
            ["TextTruncate"] = Enum.TextTruncate.None,
            ["TextWrapped"] = true,
            ["TextXAlignment"] = Enum.TextXAlignment.Center,
            ["TextYAlignment"] = Enum.TextYAlignment.Center,
            ["Active"] = false,
            ["AnchorPoint"] = Vector2.new(0.5, 0.5),
            ["AutomaticSize"] = Enum.AutomaticSize.None,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 1,
            ["BorderColor3"] = Color3.new(0.105882362, 0.164705887, 0.207843155),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 0,
            ["Position"] = UDim2.new(0.5, 0, 0.5, 0),
            ["Rotation"] = 0,
            ["Selectable"] = false,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(0.899999976, 0, 0.600000024, 0),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = true,
            ["ZIndex"] = 6,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "TextLabel",
        })
        objects[11].Parent = objects[10]
        objects[12] = Instance.new("UIStroke")
        applyPS99Properties(objects[12], {
            ["ApplyStrokeMode"] = Enum.ApplyStrokeMode.Contextual,
            ["BorderOffset"] = UDim.new(0, 0),
            ["BorderStrokePosition"] = Enum.BorderStrokePosition.Outer,
            ["Color"] = Color3.new(0, 0, 0),
            ["Enabled"] = true,
            ["LineJoinMode"] = Enum.LineJoinMode.Bevel,
            ["StrokeSizingMode"] = Enum.StrokeSizingMode.FixedSize,
            ["Thickness"] = 2.90138888,
            ["Transparency"] = 0,
            ["ZIndex"] = 1,
            ["Name"] = "UIStroke",
        })
        objects[12].Parent = objects[11]
        objects[13] = Instance.new("UIGradient")
        applyPS99Properties(objects[13], {
            ["Color"] = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.new(1, 0.00784314, 0.239216)), ColorSequenceKeypoint.new(1, Color3.new(1, 0.152941, 0.490196))}),
            ["Enabled"] = true,
            ["Offset"] = Vector2.new(0, 0),
            ["Rotation"] = -90,
            ["Scale"] = 1,
            ["TileMode"] = Enum.GradientTileMode.Clamp,
            ["Transparency"] = NumberSequence.new({NumberSequenceKeypoint.new(0, 0, 0), NumberSequenceKeypoint.new(1, 0, 0)}),
            ["Type"] = Enum.GradientType.Linear,
            ["Name"] = "red gradient",
        })
        objects[13].Parent = objects[10]
        objects[14] = Instance.new("ImageLabel")
        applyPS99Properties(objects[14], {
            ["Image"] = "rbxasset://textures/ui/Controls/DefaultController/ButtonB@2x.png",
            ["ImageColor3"] = Color3.new(0, 0, 0),
            ["ImageRectOffset"] = Vector2.new(0, 0),
            ["ImageRectSize"] = Vector2.new(0, 0),
            ["ImageTransparency"] = 0,
            ["ResampleMode"] = Enum.ResamplerMode.Default,
            ["ScaleType"] = Enum.ScaleType.Fit,
            ["SliceCenter"] = Rect.new(0, 0, 0, 0),
            ["SliceScale"] = 1,
            ["TileSize"] = UDim2.new(1, 0, 1, 0),
            ["Active"] = false,
            ["AnchorPoint"] = Vector2.new(1, 0),
            ["AutomaticSize"] = Enum.AutomaticSize.None,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 1,
            ["BorderColor3"] = Color3.new(0, 0, 0),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 0,
            ["Position"] = UDim2.new(1, 0, 0, 0),
            ["Rotation"] = 0,
            ["Selectable"] = false,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(1, 0, 0.400000006, 0),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = false,
            ["ZIndex"] = 10,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "ConsoleButton",
        })
        objects[14].Parent = objects[10]
        objects[15] = Instance.new("UIAspectRatioConstraint")
        applyPS99Properties(objects[15], {
            ["AspectRatio"] = 1,
            ["AspectType"] = Enum.AspectType.FitWithinMaxSize,
            ["DominantAxis"] = Enum.DominantAxis.Width,
            ["Name"] = "UIAspectRatioConstraint",
        })
        objects[15].Parent = objects[14]
        objects[16] = Instance.new("UIScale")
        applyPS99Properties(objects[16], {
            ["Scale"] = 1,
            ["Name"] = "ButtonUIScale",
        })
        objects[16].Parent = objects[10]
        objects[17] = Instance.new("ImageButton")
        applyPS99Properties(objects[17], {
            ["HoverImage"] = "",
            ["Image"] = "rbxassetid://14423621163",
            ["ImageColor3"] = Color3.new(1, 1, 1),
            ["ImageRectOffset"] = Vector2.new(0, 0),
            ["ImageRectSize"] = Vector2.new(0, 0),
            ["ImageTransparency"] = 0,
            ["PressedImage"] = "rbxassetid://14423621349",
            ["ResampleMode"] = Enum.ResamplerMode.Default,
            ["ScaleType"] = Enum.ScaleType.Slice,
            ["SliceCenter"] = Rect.new(20, 20, 80, 80),
            ["SliceScale"] = 0.967129648,
            ["TileSize"] = UDim2.new(1, 0, 1, 0),
            ["AutoButtonColor"] = true,
            ["Modal"] = false,
            ["Selected"] = false,
            ["Style"] = Enum.FrameStyle.Custom,
            ["Active"] = true,
            ["AnchorPoint"] = Vector2.new(0.5, 0.5),
            ["AutomaticSize"] = Enum.AutomaticSize.None,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 1,
            ["BorderColor3"] = Color3.new(0.105882362, 0.164705887, 0.207843155),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 0,
            ["Position"] = UDim2.new(0.5, 0, 0.86406666, 0),
            ["Rotation"] = 0,
            ["Selectable"] = true,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(0.446375281, 0, 0.150000006, 25),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = false,
            ["ZIndex"] = 6,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "Ok",
        })
        objects[17].Parent = objects[7]
        objects[18] = Instance.new("UIGradient")
        applyPS99Properties(objects[18], {
            ["Color"] = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.new(0.360784, 0.937255, 0)), ColorSequenceKeypoint.new(1, Color3.new(0.639216, 0.992157, 0.109804))}),
            ["Enabled"] = true,
            ["Offset"] = Vector2.new(0, 0),
            ["Rotation"] = -90,
            ["Scale"] = 1,
            ["TileMode"] = Enum.GradientTileMode.Clamp,
            ["Transparency"] = NumberSequence.new({NumberSequenceKeypoint.new(0, 0, 0), NumberSequenceKeypoint.new(1, 0, 0)}),
            ["Type"] = Enum.GradientType.Linear,
            ["Name"] = "green gradient",
        })
        objects[18].Parent = objects[17]
        objects[19] = Instance.new("TextLabel")
        applyPS99Properties(objects[19], {
            ["FontFace"] = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
            ["LineHeight"] = 1,
            ["LocalizationMatchIdentifier"] = "327b59f3-3152-41a8-8434-3a067c37f8a4",
            ["LocalizationMatchedSourceText"] = "Ok!",
            ["MaxVisibleGraphemes"] = -1,
            ["OpenTypeFeatures"] = "",
            ["RichText"] = false,
            ["Text"] = "Ok!",
            ["TextColor3"] = Color3.new(1, 1, 1),
            ["TextDirection"] = Enum.TextDirection.Auto,
            ["TextScaled"] = true,
            ["TextSize"] = 18,
            ["TextStrokeColor3"] = Color3.new(0, 0, 0),
            ["TextStrokeTransparency"] = 1,
            ["TextTransparency"] = 0,
            ["TextTruncate"] = Enum.TextTruncate.None,
            ["TextWrapped"] = true,
            ["TextXAlignment"] = Enum.TextXAlignment.Center,
            ["TextYAlignment"] = Enum.TextYAlignment.Center,
            ["Active"] = false,
            ["AnchorPoint"] = Vector2.new(0.5, 0.5),
            ["AutomaticSize"] = Enum.AutomaticSize.None,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 1,
            ["BorderColor3"] = Color3.new(0.105882362, 0.164705887, 0.207843155),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 0,
            ["Position"] = UDim2.new(0.5, 0, 0.5, 0),
            ["Rotation"] = 0,
            ["Selectable"] = false,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(0.899999976, 0, 0.600000024, 0),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = true,
            ["ZIndex"] = 6,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "TextLabel",
        })
        objects[19].Parent = objects[17]
        objects[20] = Instance.new("UIStroke")
        applyPS99Properties(objects[20], {
            ["ApplyStrokeMode"] = Enum.ApplyStrokeMode.Contextual,
            ["BorderOffset"] = UDim.new(0, 0),
            ["BorderStrokePosition"] = Enum.BorderStrokePosition.Outer,
            ["Color"] = Color3.new(0, 0, 0),
            ["Enabled"] = true,
            ["LineJoinMode"] = Enum.LineJoinMode.Bevel,
            ["StrokeSizingMode"] = Enum.StrokeSizingMode.FixedSize,
            ["Thickness"] = 2.90138888,
            ["Transparency"] = 0,
            ["ZIndex"] = 1,
            ["Name"] = "UIStroke",
        })
        objects[20].Parent = objects[19]
        objects[21] = Instance.new("ImageLabel")
        applyPS99Properties(objects[21], {
            ["Image"] = "rbxasset://textures/ui/Controls/DefaultController/ButtonA@2x.png",
            ["ImageColor3"] = Color3.new(0, 0, 0),
            ["ImageRectOffset"] = Vector2.new(0, 0),
            ["ImageRectSize"] = Vector2.new(0, 0),
            ["ImageTransparency"] = 0,
            ["ResampleMode"] = Enum.ResamplerMode.Default,
            ["ScaleType"] = Enum.ScaleType.Fit,
            ["SliceCenter"] = Rect.new(0, 0, 0, 0),
            ["SliceScale"] = 1,
            ["TileSize"] = UDim2.new(1, 0, 1, 0),
            ["Active"] = false,
            ["AnchorPoint"] = Vector2.new(1, 0),
            ["AutomaticSize"] = Enum.AutomaticSize.None,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 1,
            ["BorderColor3"] = Color3.new(0, 0, 0),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 0,
            ["Position"] = UDim2.new(1, 0, 0, 0),
            ["Rotation"] = 0,
            ["Selectable"] = false,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(1, 0, 0.400000006, 0),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = false,
            ["ZIndex"] = 10,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "ConsoleButton",
        })
        objects[21].Parent = objects[17]
        objects[22] = Instance.new("UIAspectRatioConstraint")
        applyPS99Properties(objects[22], {
            ["AspectRatio"] = 1,
            ["AspectType"] = Enum.AspectType.FitWithinMaxSize,
            ["DominantAxis"] = Enum.DominantAxis.Width,
            ["Name"] = "UIAspectRatioConstraint",
        })
        objects[22].Parent = objects[21]
        objects[23] = Instance.new("UIScale")
        applyPS99Properties(objects[23], {
            ["Scale"] = 1,
            ["Name"] = "ButtonUIScale",
        })
        objects[23].Parent = objects[17]
        objects[24] = Instance.new("ImageButton")
        applyPS99Properties(objects[24], {
            ["HoverImage"] = "",
            ["Image"] = "rbxassetid://14423621163",
            ["ImageColor3"] = Color3.new(1, 1, 1),
            ["ImageRectOffset"] = Vector2.new(0, 0),
            ["ImageRectSize"] = Vector2.new(0, 0),
            ["ImageTransparency"] = 0,
            ["PressedImage"] = "rbxassetid://14423621349",
            ["ResampleMode"] = Enum.ResamplerMode.Default,
            ["ScaleType"] = Enum.ScaleType.Slice,
            ["SliceCenter"] = Rect.new(20, 20, 80, 80),
            ["SliceScale"] = 0.967129648,
            ["TileSize"] = UDim2.new(1, 0, 1, 0),
            ["AutoButtonColor"] = true,
            ["Modal"] = false,
            ["Selected"] = false,
            ["Style"] = Enum.FrameStyle.Custom,
            ["Active"] = true,
            ["AnchorPoint"] = Vector2.new(0.5, 0.5),
            ["AutomaticSize"] = Enum.AutomaticSize.None,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 1,
            ["BorderColor3"] = Color3.new(0.105882362, 0.164705887, 0.207843155),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 0,
            ["Position"] = UDim2.new(0.25, 0, 0.86406666, 0),
            ["Rotation"] = 0,
            ["Selectable"] = true,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(0.446375281, 0, 0.150000006, 25),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = false,
            ["ZIndex"] = 6,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "Option1",
        })
        objects[24].Parent = objects[7]
        objects[25] = Instance.new("TextLabel")
        applyPS99Properties(objects[25], {
            ["FontFace"] = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
            ["LineHeight"] = 1,
            ["LocalizationMatchIdentifier"] = "",
            ["LocalizationMatchedSourceText"] = "Option {number1}",
            ["MaxVisibleGraphemes"] = -1,
            ["OpenTypeFeatures"] = "",
            ["RichText"] = false,
            ["Text"] = "Option 1",
            ["TextColor3"] = Color3.new(1, 1, 1),
            ["TextDirection"] = Enum.TextDirection.Auto,
            ["TextScaled"] = true,
            ["TextSize"] = 18,
            ["TextStrokeColor3"] = Color3.new(0, 0, 0),
            ["TextStrokeTransparency"] = 1,
            ["TextTransparency"] = 0,
            ["TextTruncate"] = Enum.TextTruncate.None,
            ["TextWrapped"] = true,
            ["TextXAlignment"] = Enum.TextXAlignment.Center,
            ["TextYAlignment"] = Enum.TextYAlignment.Center,
            ["Active"] = false,
            ["AnchorPoint"] = Vector2.new(0.5, 0.5),
            ["AutomaticSize"] = Enum.AutomaticSize.None,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 1,
            ["BorderColor3"] = Color3.new(0.105882362, 0.164705887, 0.207843155),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 0,
            ["Position"] = UDim2.new(0.5, 0, 0.5, 0),
            ["Rotation"] = 0,
            ["Selectable"] = false,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(0.899999976, 0, 0.600000024, 0),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = true,
            ["ZIndex"] = 6,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "TextLabel",
        })
        objects[25].Parent = objects[24]
        objects[26] = Instance.new("UIStroke")
        applyPS99Properties(objects[26], {
            ["ApplyStrokeMode"] = Enum.ApplyStrokeMode.Contextual,
            ["BorderOffset"] = UDim.new(0, 0),
            ["BorderStrokePosition"] = Enum.BorderStrokePosition.Outer,
            ["Color"] = Color3.new(0, 0, 0),
            ["Enabled"] = true,
            ["LineJoinMode"] = Enum.LineJoinMode.Bevel,
            ["StrokeSizingMode"] = Enum.StrokeSizingMode.FixedSize,
            ["Thickness"] = 2.90138888,
            ["Transparency"] = 0,
            ["ZIndex"] = 1,
            ["Name"] = "UIStroke",
        })
        objects[26].Parent = objects[25]
        objects[27] = Instance.new("UIGradient")
        applyPS99Properties(objects[27], {
            ["Color"] = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.new(0.341176, 0.847059, 1)), ColorSequenceKeypoint.new(1, Color3.new(0.529412, 1, 0.976471))}),
            ["Enabled"] = true,
            ["Offset"] = Vector2.new(0, 0),
            ["Rotation"] = -90,
            ["Scale"] = 1,
            ["TileMode"] = Enum.GradientTileMode.Clamp,
            ["Transparency"] = NumberSequence.new({NumberSequenceKeypoint.new(0, 0, 0), NumberSequenceKeypoint.new(1, 0, 0)}),
            ["Type"] = Enum.GradientType.Linear,
            ["Name"] = "blue gradient",
        })
        objects[27].Parent = objects[24]
        objects[28] = Instance.new("ImageLabel")
        applyPS99Properties(objects[28], {
            ["Image"] = "rbxasset://textures/ui/Controls/DefaultController/ButtonA@2x.png",
            ["ImageColor3"] = Color3.new(0, 0, 0),
            ["ImageRectOffset"] = Vector2.new(0, 0),
            ["ImageRectSize"] = Vector2.new(0, 0),
            ["ImageTransparency"] = 0,
            ["ResampleMode"] = Enum.ResamplerMode.Default,
            ["ScaleType"] = Enum.ScaleType.Fit,
            ["SliceCenter"] = Rect.new(0, 0, 0, 0),
            ["SliceScale"] = 1,
            ["TileSize"] = UDim2.new(1, 0, 1, 0),
            ["Active"] = false,
            ["AnchorPoint"] = Vector2.new(1, 0),
            ["AutomaticSize"] = Enum.AutomaticSize.None,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 1,
            ["BorderColor3"] = Color3.new(0, 0, 0),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 0,
            ["Position"] = UDim2.new(1, 0, 0, 0),
            ["Rotation"] = 0,
            ["Selectable"] = false,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(1, 0, 0.400000006, 0),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = false,
            ["ZIndex"] = 10,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "ConsoleButton",
        })
        objects[28].Parent = objects[24]
        objects[29] = Instance.new("UIAspectRatioConstraint")
        applyPS99Properties(objects[29], {
            ["AspectRatio"] = 1,
            ["AspectType"] = Enum.AspectType.FitWithinMaxSize,
            ["DominantAxis"] = Enum.DominantAxis.Width,
            ["Name"] = "UIAspectRatioConstraint",
        })
        objects[29].Parent = objects[28]
        objects[30] = Instance.new("UIScale")
        applyPS99Properties(objects[30], {
            ["Scale"] = 1,
            ["Name"] = "ButtonUIScale",
        })
        objects[30].Parent = objects[24]
        objects[31] = Instance.new("ImageButton")
        applyPS99Properties(objects[31], {
            ["HoverImage"] = "",
            ["Image"] = "rbxassetid://14423621163",
            ["ImageColor3"] = Color3.new(1, 1, 1),
            ["ImageRectOffset"] = Vector2.new(0, 0),
            ["ImageRectSize"] = Vector2.new(0, 0),
            ["ImageTransparency"] = 0,
            ["PressedImage"] = "rbxassetid://14423621349",
            ["ResampleMode"] = Enum.ResamplerMode.Default,
            ["ScaleType"] = Enum.ScaleType.Slice,
            ["SliceCenter"] = Rect.new(20, 20, 80, 80),
            ["SliceScale"] = 0.967129648,
            ["TileSize"] = UDim2.new(1, 0, 1, 0),
            ["AutoButtonColor"] = true,
            ["Modal"] = false,
            ["Selected"] = false,
            ["Style"] = Enum.FrameStyle.Custom,
            ["Active"] = true,
            ["AnchorPoint"] = Vector2.new(0.5, 0.5),
            ["AutomaticSize"] = Enum.AutomaticSize.None,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 1,
            ["BorderColor3"] = Color3.new(0.105882362, 0.164705887, 0.207843155),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 0,
            ["Position"] = UDim2.new(0.75, 0, 0.86406666, 0),
            ["Rotation"] = 0,
            ["Selectable"] = true,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(0.446375281, 0, 0.150000006, 25),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = false,
            ["ZIndex"] = 6,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "Option2",
        })
        objects[31].Parent = objects[7]
        objects[32] = Instance.new("TextLabel")
        applyPS99Properties(objects[32], {
            ["FontFace"] = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
            ["LineHeight"] = 1,
            ["LocalizationMatchIdentifier"] = "",
            ["LocalizationMatchedSourceText"] = "Option {number1}",
            ["MaxVisibleGraphemes"] = -1,
            ["OpenTypeFeatures"] = "",
            ["RichText"] = false,
            ["Text"] = "Option 1",
            ["TextColor3"] = Color3.new(1, 1, 1),
            ["TextDirection"] = Enum.TextDirection.Auto,
            ["TextScaled"] = true,
            ["TextSize"] = 18,
            ["TextStrokeColor3"] = Color3.new(0, 0, 0),
            ["TextStrokeTransparency"] = 1,
            ["TextTransparency"] = 0,
            ["TextTruncate"] = Enum.TextTruncate.None,
            ["TextWrapped"] = true,
            ["TextXAlignment"] = Enum.TextXAlignment.Center,
            ["TextYAlignment"] = Enum.TextYAlignment.Center,
            ["Active"] = false,
            ["AnchorPoint"] = Vector2.new(0.5, 0.5),
            ["AutomaticSize"] = Enum.AutomaticSize.None,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 1,
            ["BorderColor3"] = Color3.new(0.105882362, 0.164705887, 0.207843155),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 0,
            ["Position"] = UDim2.new(0.5, 0, 0.5, 0),
            ["Rotation"] = 0,
            ["Selectable"] = false,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(0.899999976, 0, 0.600000024, 0),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = true,
            ["ZIndex"] = 6,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "TextLabel",
        })
        objects[32].Parent = objects[31]
        objects[33] = Instance.new("UIStroke")
        applyPS99Properties(objects[33], {
            ["ApplyStrokeMode"] = Enum.ApplyStrokeMode.Contextual,
            ["BorderOffset"] = UDim.new(0, 0),
            ["BorderStrokePosition"] = Enum.BorderStrokePosition.Outer,
            ["Color"] = Color3.new(0, 0, 0),
            ["Enabled"] = true,
            ["LineJoinMode"] = Enum.LineJoinMode.Bevel,
            ["StrokeSizingMode"] = Enum.StrokeSizingMode.FixedSize,
            ["Thickness"] = 2.90138888,
            ["Transparency"] = 0,
            ["ZIndex"] = 1,
            ["Name"] = "UIStroke",
        })
        objects[33].Parent = objects[32]
        objects[34] = Instance.new("UIGradient")
        applyPS99Properties(objects[34], {
            ["Color"] = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.new(0.341176, 0.847059, 1)), ColorSequenceKeypoint.new(1, Color3.new(0.529412, 1, 0.976471))}),
            ["Enabled"] = true,
            ["Offset"] = Vector2.new(0, 0),
            ["Rotation"] = -90,
            ["Scale"] = 1,
            ["TileMode"] = Enum.GradientTileMode.Clamp,
            ["Transparency"] = NumberSequence.new({NumberSequenceKeypoint.new(0, 0, 0), NumberSequenceKeypoint.new(1, 0, 0)}),
            ["Type"] = Enum.GradientType.Linear,
            ["Name"] = "blue gradient",
        })
        objects[34].Parent = objects[31]
        objects[35] = Instance.new("ImageLabel")
        applyPS99Properties(objects[35], {
            ["Image"] = "rbxasset://textures/ui/Controls/DefaultController/ButtonX@2x.png",
            ["ImageColor3"] = Color3.new(0, 0, 0),
            ["ImageRectOffset"] = Vector2.new(0, 0),
            ["ImageRectSize"] = Vector2.new(0, 0),
            ["ImageTransparency"] = 0,
            ["ResampleMode"] = Enum.ResamplerMode.Default,
            ["ScaleType"] = Enum.ScaleType.Fit,
            ["SliceCenter"] = Rect.new(0, 0, 0, 0),
            ["SliceScale"] = 1,
            ["TileSize"] = UDim2.new(1, 0, 1, 0),
            ["Active"] = false,
            ["AnchorPoint"] = Vector2.new(1, 0),
            ["AutomaticSize"] = Enum.AutomaticSize.None,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 1,
            ["BorderColor3"] = Color3.new(0, 0, 0),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 0,
            ["Position"] = UDim2.new(1, 0, 0, 0),
            ["Rotation"] = 0,
            ["Selectable"] = false,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(1, 0, 0.400000006, 0),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = false,
            ["ZIndex"] = 10,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "ConsoleButton",
        })
        objects[35].Parent = objects[31]
        objects[36] = Instance.new("UIAspectRatioConstraint")
        applyPS99Properties(objects[36], {
            ["AspectRatio"] = 1,
            ["AspectType"] = Enum.AspectType.FitWithinMaxSize,
            ["DominantAxis"] = Enum.DominantAxis.Width,
            ["Name"] = "UIAspectRatioConstraint",
        })
        objects[36].Parent = objects[35]
        objects[37] = Instance.new("UIScale")
        applyPS99Properties(objects[37], {
            ["Scale"] = 1,
            ["Name"] = "ButtonUIScale",
        })
        objects[37].Parent = objects[31]
        objects[38] = Instance.new("ImageButton")
        applyPS99Properties(objects[38], {
            ["HoverImage"] = "",
            ["Image"] = "rbxassetid://14423621163",
            ["ImageColor3"] = Color3.new(1, 1, 1),
            ["ImageRectOffset"] = Vector2.new(0, 0),
            ["ImageRectSize"] = Vector2.new(0, 0),
            ["ImageTransparency"] = 0,
            ["PressedImage"] = "rbxassetid://14423621349",
            ["ResampleMode"] = Enum.ResamplerMode.Default,
            ["ScaleType"] = Enum.ScaleType.Slice,
            ["SliceCenter"] = Rect.new(20, 20, 80, 80),
            ["SliceScale"] = 0.967129648,
            ["TileSize"] = UDim2.new(1, 0, 1, 0),
            ["AutoButtonColor"] = true,
            ["Modal"] = false,
            ["Selected"] = false,
            ["Style"] = Enum.FrameStyle.Custom,
            ["Active"] = true,
            ["AnchorPoint"] = Vector2.new(0.5, 0.5),
            ["AutomaticSize"] = Enum.AutomaticSize.None,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 1,
            ["BorderColor3"] = Color3.new(0.105882362, 0.164705887, 0.207843155),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 0,
            ["Position"] = UDim2.new(0.25, 0, 0.86406666, 0),
            ["Rotation"] = 0,
            ["Selectable"] = true,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(0.446375281, 0, 0.150000006, 25),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = true,
            ["ZIndex"] = 6,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "Yes",
        })
        objects[38].Parent = objects[7]
        objects[39] = Instance.new("UIGradient")
        applyPS99Properties(objects[39], {
            ["Color"] = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.new(0.360784, 0.937255, 0)), ColorSequenceKeypoint.new(1, Color3.new(0.639216, 0.992157, 0.109804))}),
            ["Enabled"] = true,
            ["Offset"] = Vector2.new(0, 0),
            ["Rotation"] = -90,
            ["Scale"] = 1,
            ["TileMode"] = Enum.GradientTileMode.Clamp,
            ["Transparency"] = NumberSequence.new({NumberSequenceKeypoint.new(0, 0, 0), NumberSequenceKeypoint.new(1, 0, 0)}),
            ["Type"] = Enum.GradientType.Linear,
            ["Name"] = "green gradient",
        })
        objects[39].Parent = objects[38]
        objects[40] = Instance.new("TextLabel")
        applyPS99Properties(objects[40], {
            ["FontFace"] = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
            ["LineHeight"] = 1,
            ["LocalizationMatchIdentifier"] = "0be263d1-c5c1-4d96-bd59-193306bb39ba",
            ["LocalizationMatchedSourceText"] = "Yes!",
            ["MaxVisibleGraphemes"] = -1,
            ["OpenTypeFeatures"] = "",
            ["RichText"] = false,
            ["Text"] = "Yes!",
            ["TextColor3"] = Color3.new(1, 1, 1),
            ["TextDirection"] = Enum.TextDirection.Auto,
            ["TextScaled"] = true,
            ["TextSize"] = 18,
            ["TextStrokeColor3"] = Color3.new(0, 0, 0),
            ["TextStrokeTransparency"] = 1,
            ["TextTransparency"] = 0,
            ["TextTruncate"] = Enum.TextTruncate.None,
            ["TextWrapped"] = true,
            ["TextXAlignment"] = Enum.TextXAlignment.Center,
            ["TextYAlignment"] = Enum.TextYAlignment.Center,
            ["Active"] = false,
            ["AnchorPoint"] = Vector2.new(0.5, 0.5),
            ["AutomaticSize"] = Enum.AutomaticSize.None,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 1,
            ["BorderColor3"] = Color3.new(0.105882362, 0.164705887, 0.207843155),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 0,
            ["Position"] = UDim2.new(0.5, 0, 0.5, 0),
            ["Rotation"] = 0,
            ["Selectable"] = false,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(0.899999976, 0, 0.600000024, 0),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = true,
            ["ZIndex"] = 6,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "TextLabel",
        })
        objects[40].Parent = objects[38]
        objects[41] = Instance.new("UIStroke")
        applyPS99Properties(objects[41], {
            ["ApplyStrokeMode"] = Enum.ApplyStrokeMode.Contextual,
            ["BorderOffset"] = UDim.new(0, 0),
            ["BorderStrokePosition"] = Enum.BorderStrokePosition.Outer,
            ["Color"] = Color3.new(0, 0, 0),
            ["Enabled"] = true,
            ["LineJoinMode"] = Enum.LineJoinMode.Bevel,
            ["StrokeSizingMode"] = Enum.StrokeSizingMode.FixedSize,
            ["Thickness"] = 2.90138888,
            ["Transparency"] = 0,
            ["ZIndex"] = 1,
            ["Name"] = "UIStroke",
        })
        objects[41].Parent = objects[40]
        objects[42] = Instance.new("ImageLabel")
        applyPS99Properties(objects[42], {
            ["Image"] = "rbxasset://textures/ui/Controls/DefaultController/ButtonA@2x.png",
            ["ImageColor3"] = Color3.new(0, 0, 0),
            ["ImageRectOffset"] = Vector2.new(0, 0),
            ["ImageRectSize"] = Vector2.new(0, 0),
            ["ImageTransparency"] = 0,
            ["ResampleMode"] = Enum.ResamplerMode.Default,
            ["ScaleType"] = Enum.ScaleType.Fit,
            ["SliceCenter"] = Rect.new(0, 0, 0, 0),
            ["SliceScale"] = 1,
            ["TileSize"] = UDim2.new(1, 0, 1, 0),
            ["Active"] = false,
            ["AnchorPoint"] = Vector2.new(1, 0),
            ["AutomaticSize"] = Enum.AutomaticSize.None,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 1,
            ["BorderColor3"] = Color3.new(0, 0, 0),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 0,
            ["Position"] = UDim2.new(1, 0, 0, 0),
            ["Rotation"] = 0,
            ["Selectable"] = false,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(1, 0, 0.400000006, 0),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = false,
            ["ZIndex"] = 10,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "ConsoleButton",
        })
        objects[42].Parent = objects[38]
        objects[43] = Instance.new("UIAspectRatioConstraint")
        applyPS99Properties(objects[43], {
            ["AspectRatio"] = 1,
            ["AspectType"] = Enum.AspectType.FitWithinMaxSize,
            ["DominantAxis"] = Enum.DominantAxis.Width,
            ["Name"] = "UIAspectRatioConstraint",
        })
        objects[43].Parent = objects[42]
        objects[44] = Instance.new("Frame")
        applyPS99Properties(objects[44], {
            ["Style"] = Enum.FrameStyle.Custom,
            ["Active"] = false,
            ["AnchorPoint"] = Vector2.new(0.5, 0.5),
            ["AutomaticSize"] = Enum.AutomaticSize.None,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 1,
            ["BorderColor3"] = Color3.new(0.105882362, 0.164705887, 0.207843155),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 0,
            ["Position"] = UDim2.new(0.0299999993, 0, 0.119999997, 0),
            ["Rotation"] = 0,
            ["Selectable"] = false,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(0.349999994, 0, 0.349999994, 0),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = false,
            ["ZIndex"] = 110,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "CircularBar",
        })
        objects[44].Parent = objects[38]
        objects[45] = Instance.new("UIAspectRatioConstraint")
        applyPS99Properties(objects[45], {
            ["AspectRatio"] = 1,
            ["AspectType"] = Enum.AspectType.FitWithinMaxSize,
            ["DominantAxis"] = Enum.DominantAxis.Width,
            ["Name"] = "UIAspectRatioConstraint",
        })
        objects[45].Parent = objects[44]
        objects[46] = Instance.new("ImageLabel")
        applyPS99Properties(objects[46], {
            ["Image"] = "rbxassetid://8897745728",
            ["ImageColor3"] = Color3.new(0, 0, 0),
            ["ImageRectOffset"] = Vector2.new(0, 0),
            ["ImageRectSize"] = Vector2.new(0, 0),
            ["ImageTransparency"] = 0,
            ["ResampleMode"] = Enum.ResamplerMode.Default,
            ["ScaleType"] = Enum.ScaleType.Fit,
            ["SliceCenter"] = Rect.new(0, 0, 0, 0),
            ["SliceScale"] = 1,
            ["TileSize"] = UDim2.new(1, 0, 1, 0),
            ["Active"] = false,
            ["AnchorPoint"] = Vector2.new(0.5, 0.5),
            ["AutomaticSize"] = Enum.AutomaticSize.None,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 1,
            ["BorderColor3"] = Color3.new(0.105882362, 0.164705887, 0.207843155),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 0,
            ["Position"] = UDim2.new(0.5, 0, 0.5, 0),
            ["Rotation"] = 0,
            ["Selectable"] = false,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(1, 0, 1, 0),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = true,
            ["ZIndex"] = 110,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "Left",
        })
        objects[46].Parent = objects[44]
        objects[47] = Instance.new("UIGradient")
        applyPS99Properties(objects[47], {
            ["Color"] = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1))}),
            ["Enabled"] = true,
            ["Offset"] = Vector2.new(0, 0),
            ["Rotation"] = 180,
            ["Scale"] = 1,
            ["TileMode"] = Enum.GradientTileMode.Clamp,
            ["Transparency"] = NumberSequence.new({NumberSequenceKeypoint.new(0, 0, 0), NumberSequenceKeypoint.new(0.499, 0, 0), NumberSequenceKeypoint.new(0.5, 1, 0), NumberSequenceKeypoint.new(1, 1, 0)}),
            ["Type"] = Enum.GradientType.Linear,
            ["Name"] = "UIGradient",
        })
        objects[47].Parent = objects[46]
        objects[48] = Instance.new("ImageLabel")
        applyPS99Properties(objects[48], {
            ["Image"] = "rbxassetid://8897746094",
            ["ImageColor3"] = Color3.new(0, 0, 0),
            ["ImageRectOffset"] = Vector2.new(0, 0),
            ["ImageRectSize"] = Vector2.new(0, 0),
            ["ImageTransparency"] = 0,
            ["ResampleMode"] = Enum.ResamplerMode.Default,
            ["ScaleType"] = Enum.ScaleType.Fit,
            ["SliceCenter"] = Rect.new(0, 0, 0, 0),
            ["SliceScale"] = 1,
            ["TileSize"] = UDim2.new(1, 0, 1, 0),
            ["Active"] = false,
            ["AnchorPoint"] = Vector2.new(0.5, 0.5),
            ["AutomaticSize"] = Enum.AutomaticSize.None,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 1,
            ["BorderColor3"] = Color3.new(0.105882362, 0.164705887, 0.207843155),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 0,
            ["Position"] = UDim2.new(0.5, 0, 0.5, 0),
            ["Rotation"] = 0,
            ["Selectable"] = false,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(1, 0, 1, 0),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = true,
            ["ZIndex"] = 110,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "Right",
        })
        objects[48].Parent = objects[44]
        objects[49] = Instance.new("UIGradient")
        applyPS99Properties(objects[49], {
            ["Color"] = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1))}),
            ["Enabled"] = true,
            ["Offset"] = Vector2.new(0, 0),
            ["Rotation"] = 180,
            ["Scale"] = 1,
            ["TileMode"] = Enum.GradientTileMode.Clamp,
            ["Transparency"] = NumberSequence.new({NumberSequenceKeypoint.new(0, 0, 0), NumberSequenceKeypoint.new(0.499, 0, 0), NumberSequenceKeypoint.new(0.5, 1, 0), NumberSequenceKeypoint.new(1, 1, 0)}),
            ["Type"] = Enum.GradientType.Linear,
            ["Name"] = "UIGradient",
        })
        objects[49].Parent = objects[48]
        objects[50] = Instance.new("UIScale")
        applyPS99Properties(objects[50], {
            ["Scale"] = 1,
            ["Name"] = "ButtonUIScale",
        })
        objects[50].Parent = objects[38]
        objects[51] = Instance.new("ImageLabel")
        applyPS99Properties(objects[51], {
            ["Image"] = "rbxassetid://14968178095",
            ["ImageColor3"] = Color3.new(1, 1, 1),
            ["ImageRectOffset"] = Vector2.new(0, 0),
            ["ImageRectSize"] = Vector2.new(0, 0),
            ["ImageTransparency"] = 0,
            ["ResampleMode"] = Enum.ResamplerMode.Default,
            ["ScaleType"] = Enum.ScaleType.Fit,
            ["SliceCenter"] = Rect.new(0, 0, 0, 0),
            ["SliceScale"] = 1,
            ["TileSize"] = UDim2.new(1, 0, 1, 0),
            ["Active"] = false,
            ["AnchorPoint"] = Vector2.new(0.5, 0),
            ["AutomaticSize"] = Enum.AutomaticSize.None,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 1,
            ["BorderColor3"] = Color3.new(0.105882362, 0.164705887, 0.207843155),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 0,
            ["Position"] = UDim2.new(0.5, 0, 0.439999998, 0),
            ["Rotation"] = 0,
            ["Selectable"] = false,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(0.800000012, 0, 0.234999999, 0),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = false,
            ["ZIndex"] = 8,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "CustomIcon",
        })
        objects[51].Parent = objects[7]
        objects[52] = Instance.new("TextLabel")
        applyPS99Properties(objects[52], {
            ["FontFace"] = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
            ["LineHeight"] = 1,
            ["LocalizationMatchIdentifier"] = "",
            ["LocalizationMatchedSourceText"] = "Buy these items for {number1} Diamonds?",
            ["MaxVisibleGraphemes"] = -1,
            ["OpenTypeFeatures"] = "",
            ["RichText"] = false,
            ["Text"] = "Buy these items for 10,312 Diamonds?",
            ["TextColor3"] = Color3.new(0.164705887, 0.168627456, 0.192156866),
            ["TextDirection"] = Enum.TextDirection.Auto,
            ["TextScaled"] = true,
            ["TextSize"] = 14,
            ["TextStrokeColor3"] = Color3.new(0.0666666701, 0.227450997, 0.282352954),
            ["TextStrokeTransparency"] = 1,
            ["TextTransparency"] = 0,
            ["TextTruncate"] = Enum.TextTruncate.AtEnd,
            ["TextWrapped"] = true,
            ["TextXAlignment"] = Enum.TextXAlignment.Center,
            ["TextYAlignment"] = Enum.TextYAlignment.Center,
            ["Active"] = false,
            ["AnchorPoint"] = Vector2.new(0.5, 0),
            ["AutomaticSize"] = Enum.AutomaticSize.None,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 1,
            ["BorderColor3"] = Color3.new(0.105882362, 0.164705887, 0.207843155),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 0,
            ["Position"] = UDim2.new(0.5, 0, 0.164999992, 0),
            ["Rotation"] = 0,
            ["Selectable"] = false,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(0.850000024, 0, 0.25, 0),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = true,
            ["ZIndex"] = 7,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "CustomDesc",
        })
        objects[52].Parent = objects[7]
        objects[53] = Instance.new("UITextSizeConstraint")
        applyPS99Properties(objects[53], {
            ["MaxTextSize"] = 55,
            ["MinTextSize"] = 10,
            ["Name"] = "UITextSizeConstraint",
        })
        objects[53].Parent = objects[52]
        objects[54] = Instance.new("TextLabel")
        applyPS99Properties(objects[54], {
            ["FontFace"] = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
            ["LineHeight"] = 1,
            ["LocalizationMatchIdentifier"] = "9f2e7402-31de-4604-bbde-e6fe767e67c8",
            ["LocalizationMatchedSourceText"] = "Bubble pop-up description?",
            ["MaxVisibleGraphemes"] = -1,
            ["OpenTypeFeatures"] = "",
            ["RichText"] = false,
            ["Text"] = "Bubble pop-up description?",
            ["TextColor3"] = Color3.new(0.164705887, 0.168627456, 0.192156866),
            ["TextDirection"] = Enum.TextDirection.Auto,
            ["TextScaled"] = true,
            ["TextSize"] = 14,
            ["TextStrokeColor3"] = Color3.new(0.0666666701, 0.227450997, 0.282352954),
            ["TextStrokeTransparency"] = 1,
            ["TextTransparency"] = 0,
            ["TextTruncate"] = Enum.TextTruncate.AtEnd,
            ["TextWrapped"] = true,
            ["TextXAlignment"] = Enum.TextXAlignment.Center,
            ["TextYAlignment"] = Enum.TextYAlignment.Center,
            ["Active"] = false,
            ["AnchorPoint"] = Vector2.new(0.5, 0),
            ["AutomaticSize"] = Enum.AutomaticSize.None,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 1,
            ["BorderColor3"] = Color3.new(0.105882362, 0.164705887, 0.207843155),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 0,
            ["Position"] = UDim2.new(0.5, 0, 0.165000007, 0),
            ["Rotation"] = 0,
            ["Selectable"] = false,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(0.899999976, 0, 0.550000012, 0),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = false,
            ["ZIndex"] = 7,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "Desc",
        })
        objects[54].Parent = objects[7]
        objects[55] = Instance.new("UITextSizeConstraint")
        applyPS99Properties(objects[55], {
            ["MaxTextSize"] = 60,
            ["MinTextSize"] = 10,
            ["Name"] = "UITextSizeConstraint",
        })
        objects[55].Parent = objects[54]
        objects[56] = Instance.new("Frame")
        applyPS99Properties(objects[56], {
            ["Style"] = Enum.FrameStyle.Custom,
            ["Active"] = false,
            ["AnchorPoint"] = Vector2.new(0.5, 0),
            ["AutomaticSize"] = Enum.AutomaticSize.X,
            ["BackgroundColor3"] = Color3.new(0, 0, 0),
            ["BackgroundTransparency"] = 1,
            ["BorderColor3"] = Color3.new(0.105882362, 0.164705887, 0.207843155),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 3,
            ["Position"] = UDim2.new(0.5, 0, 0.439999998, 0),
            ["Rotation"] = 0,
            ["Selectable"] = false,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(0.800000012, 0, 0.234999999, 0),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = false,
            ["ZIndex"] = 1,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "CurrencyCoins",
        })
        objects[56].Parent = objects[7]
        objects[57] = Instance.new("Frame")
        applyPS99Properties(objects[57], {
            ["Style"] = Enum.FrameStyle.Custom,
            ["Active"] = false,
            ["AnchorPoint"] = Vector2.new(0, 0),
            ["AutomaticSize"] = Enum.AutomaticSize.X,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 1,
            ["BorderColor3"] = Color3.new(0.105882362, 0.164705887, 0.207843155),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 1000,
            ["Position"] = UDim2.new(0, 0, 0, 0),
            ["Rotation"] = 0,
            ["Selectable"] = false,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(0, 0, 1, 0),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = true,
            ["ZIndex"] = 1,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "Gold Coins",
        })
        objects[57].Parent = objects[56]
        objects[58] = Instance.new("ImageLabel")
        applyPS99Properties(objects[58], {
            ["Image"] = "rbxassetid://14867116080",
            ["ImageColor3"] = Color3.new(1, 1, 1),
            ["ImageRectOffset"] = Vector2.new(0, 0),
            ["ImageRectSize"] = Vector2.new(0, 0),
            ["ImageTransparency"] = 0,
            ["ResampleMode"] = Enum.ResamplerMode.Default,
            ["ScaleType"] = Enum.ScaleType.Fit,
            ["SliceCenter"] = Rect.new(0, 0, 0, 0),
            ["SliceScale"] = 1,
            ["TileSize"] = UDim2.new(1, 0, 1, 0),
            ["Active"] = false,
            ["AnchorPoint"] = Vector2.new(0, 0),
            ["AutomaticSize"] = Enum.AutomaticSize.None,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 1,
            ["BorderColor3"] = Color3.new(0.105882362, 0.164705887, 0.207843155),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 0,
            ["Position"] = UDim2.new(0, 0, 0, 0),
            ["Rotation"] = 0,
            ["Selectable"] = false,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(1, 0, 0.899999976, 0),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = true,
            ["ZIndex"] = 1,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "Icon",
        })
        objects[58].Parent = objects[57]
        objects[59] = Instance.new("UIAspectRatioConstraint")
        applyPS99Properties(objects[59], {
            ["AspectRatio"] = 1,
            ["AspectType"] = Enum.AspectType.FitWithinMaxSize,
            ["DominantAxis"] = Enum.DominantAxis.Width,
            ["Name"] = "UIAspectRatioConstraint",
        })
        objects[59].Parent = objects[58]
        objects[60] = Instance.new("TextLabel")
        applyPS99Properties(objects[60], {
            ["FontFace"] = Font.new("rbxassetid://11702779409", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
            ["LineHeight"] = 0.899999976,
            ["LocalizationMatchIdentifier"] = "",
            ["LocalizationMatchedSourceText"] = "",
            ["MaxVisibleGraphemes"] = -1,
            ["OpenTypeFeatures"] = "",
            ["RichText"] = false,
            ["Text"] = "999",
            ["TextColor3"] = Color3.new(1, 0.988235295, 0.858823538),
            ["TextDirection"] = Enum.TextDirection.Auto,
            ["TextScaled"] = true,
            ["TextSize"] = 18,
            ["TextStrokeColor3"] = Color3.new(0, 0, 0),
            ["TextStrokeTransparency"] = 1,
            ["TextTransparency"] = 0,
            ["TextTruncate"] = Enum.TextTruncate.None,
            ["TextWrapped"] = true,
            ["TextXAlignment"] = Enum.TextXAlignment.Center,
            ["TextYAlignment"] = Enum.TextYAlignment.Center,
            ["Active"] = false,
            ["AnchorPoint"] = Vector2.new(0, 0),
            ["AutomaticSize"] = Enum.AutomaticSize.X,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 1,
            ["BorderColor3"] = Color3.new(0.105882362, 0.164705887, 0.207843155),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 0,
            ["Position"] = UDim2.new(0, 0, 0, 0),
            ["Rotation"] = 0,
            ["Selectable"] = false,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(0, 0, 0.800000012, 0),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = true,
            ["ZIndex"] = 2,
            ["AutoLocalize"] = false,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "Amount",
        })
        objects[60].Parent = objects[57]
        objects[61] = Instance.new("UIStroke")
        applyPS99Properties(objects[61], {
            ["ApplyStrokeMode"] = Enum.ApplyStrokeMode.Contextual,
            ["BorderOffset"] = UDim.new(0, 0),
            ["BorderStrokePosition"] = Enum.BorderStrokePosition.Outer,
            ["Color"] = Color3.new(0, 0, 0),
            ["Enabled"] = true,
            ["LineJoinMode"] = Enum.LineJoinMode.Bevel,
            ["StrokeSizingMode"] = Enum.StrokeSizingMode.FixedSize,
            ["Thickness"] = 4.83564806,
            ["Transparency"] = 0,
            ["ZIndex"] = 1,
            ["Name"] = "UIStroke",
        })
        objects[61].Parent = objects[60]
        objects[62] = Instance.new("UIListLayout")
        applyPS99Properties(objects[62], {
            ["HorizontalFlex"] = Enum.UIFlexAlignment.None,
            ["ItemLineAlignment"] = Enum.ItemLineAlignment.Automatic,
            ["Padding"] = UDim.new(0, 2),
            ["VerticalFlex"] = Enum.UIFlexAlignment.None,
            ["Wraps"] = false,
            ["FillDirection"] = Enum.FillDirection.Horizontal,
            ["HorizontalAlignment"] = Enum.HorizontalAlignment.Center,
            ["SortOrder"] = Enum.SortOrder.LayoutOrder,
            ["VerticalAlignment"] = Enum.VerticalAlignment.Top,
            ["Name"] = "UIListLayout",
        })
        objects[62].Parent = objects[57]
        objects[63] = Instance.new("Frame")
        applyPS99Properties(objects[63], {
            ["Style"] = Enum.FrameStyle.Custom,
            ["Active"] = false,
            ["AnchorPoint"] = Vector2.new(0, 0),
            ["AutomaticSize"] = Enum.AutomaticSize.X,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 1,
            ["BorderColor3"] = Color3.new(0.105882362, 0.164705887, 0.207843155),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 100,
            ["Position"] = UDim2.new(0, 0, 0, 0),
            ["Rotation"] = 0,
            ["Selectable"] = false,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(0, 0, 1, 0),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = true,
            ["ZIndex"] = 1,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "Gold Bars",
        })
        objects[63].Parent = objects[56]
        objects[64] = Instance.new("ImageLabel")
        applyPS99Properties(objects[64], {
            ["Image"] = "rbxassetid://14867116225",
            ["ImageColor3"] = Color3.new(1, 1, 1),
            ["ImageRectOffset"] = Vector2.new(0, 0),
            ["ImageRectSize"] = Vector2.new(0, 0),
            ["ImageTransparency"] = 0,
            ["ResampleMode"] = Enum.ResamplerMode.Default,
            ["ScaleType"] = Enum.ScaleType.Fit,
            ["SliceCenter"] = Rect.new(0, 0, 0, 0),
            ["SliceScale"] = 1,
            ["TileSize"] = UDim2.new(1, 0, 1, 0),
            ["Active"] = false,
            ["AnchorPoint"] = Vector2.new(0, 0),
            ["AutomaticSize"] = Enum.AutomaticSize.None,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 1,
            ["BorderColor3"] = Color3.new(0.105882362, 0.164705887, 0.207843155),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 0,
            ["Position"] = UDim2.new(0, 0, 0, 0),
            ["Rotation"] = 0,
            ["Selectable"] = false,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(1, 0, 0.899999976, 0),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = true,
            ["ZIndex"] = 1,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "Icon",
        })
        objects[64].Parent = objects[63]
        objects[65] = Instance.new("UIAspectRatioConstraint")
        applyPS99Properties(objects[65], {
            ["AspectRatio"] = 1,
            ["AspectType"] = Enum.AspectType.FitWithinMaxSize,
            ["DominantAxis"] = Enum.DominantAxis.Width,
            ["Name"] = "UIAspectRatioConstraint",
        })
        objects[65].Parent = objects[64]
        objects[66] = Instance.new("TextLabel")
        applyPS99Properties(objects[66], {
            ["FontFace"] = Font.new("rbxassetid://11702779409", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
            ["LineHeight"] = 0.899999976,
            ["LocalizationMatchIdentifier"] = "",
            ["LocalizationMatchedSourceText"] = "",
            ["MaxVisibleGraphemes"] = -1,
            ["OpenTypeFeatures"] = "",
            ["RichText"] = false,
            ["Text"] = "999",
            ["TextColor3"] = Color3.new(1, 0.972549021, 0.607843161),
            ["TextDirection"] = Enum.TextDirection.Auto,
            ["TextScaled"] = true,
            ["TextSize"] = 18,
            ["TextStrokeColor3"] = Color3.new(0, 0, 0),
            ["TextStrokeTransparency"] = 1,
            ["TextTransparency"] = 0,
            ["TextTruncate"] = Enum.TextTruncate.None,
            ["TextWrapped"] = true,
            ["TextXAlignment"] = Enum.TextXAlignment.Center,
            ["TextYAlignment"] = Enum.TextYAlignment.Center,
            ["Active"] = false,
            ["AnchorPoint"] = Vector2.new(0, 0),
            ["AutomaticSize"] = Enum.AutomaticSize.X,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 1,
            ["BorderColor3"] = Color3.new(0.105882362, 0.164705887, 0.207843155),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 0,
            ["Position"] = UDim2.new(0, 0, 0, 0),
            ["Rotation"] = 0,
            ["Selectable"] = false,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(0, 0, 0.800000012, 0),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = true,
            ["ZIndex"] = 2,
            ["AutoLocalize"] = false,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "Amount",
        })
        objects[66].Parent = objects[63]
        objects[67] = Instance.new("UIStroke")
        applyPS99Properties(objects[67], {
            ["ApplyStrokeMode"] = Enum.ApplyStrokeMode.Contextual,
            ["BorderOffset"] = UDim.new(0, 0),
            ["BorderStrokePosition"] = Enum.BorderStrokePosition.Outer,
            ["Color"] = Color3.new(0, 0, 0),
            ["Enabled"] = true,
            ["LineJoinMode"] = Enum.LineJoinMode.Bevel,
            ["StrokeSizingMode"] = Enum.StrokeSizingMode.FixedSize,
            ["Thickness"] = 4.83564806,
            ["Transparency"] = 0,
            ["ZIndex"] = 1,
            ["Name"] = "UIStroke",
        })
        objects[67].Parent = objects[66]
        objects[68] = Instance.new("UIListLayout")
        applyPS99Properties(objects[68], {
            ["HorizontalFlex"] = Enum.UIFlexAlignment.None,
            ["ItemLineAlignment"] = Enum.ItemLineAlignment.Automatic,
            ["Padding"] = UDim.new(0, 2),
            ["VerticalFlex"] = Enum.UIFlexAlignment.None,
            ["Wraps"] = false,
            ["FillDirection"] = Enum.FillDirection.Horizontal,
            ["HorizontalAlignment"] = Enum.HorizontalAlignment.Center,
            ["SortOrder"] = Enum.SortOrder.LayoutOrder,
            ["VerticalAlignment"] = Enum.VerticalAlignment.Top,
            ["Name"] = "UIListLayout",
        })
        objects[68].Parent = objects[63]
        objects[69] = Instance.new("UIListLayout")
        applyPS99Properties(objects[69], {
            ["HorizontalFlex"] = Enum.UIFlexAlignment.None,
            ["ItemLineAlignment"] = Enum.ItemLineAlignment.Automatic,
            ["Padding"] = UDim.new(0.0599999987, 0),
            ["VerticalFlex"] = Enum.UIFlexAlignment.None,
            ["Wraps"] = false,
            ["FillDirection"] = Enum.FillDirection.Horizontal,
            ["HorizontalAlignment"] = Enum.HorizontalAlignment.Center,
            ["SortOrder"] = Enum.SortOrder.LayoutOrder,
            ["VerticalAlignment"] = Enum.VerticalAlignment.Top,
            ["Name"] = "UIListLayout",
        })
        objects[69].Parent = objects[56]
        objects[70] = Instance.new("Frame")
        applyPS99Properties(objects[70], {
            ["Style"] = Enum.FrameStyle.Custom,
            ["Active"] = false,
            ["AnchorPoint"] = Vector2.new(0, 0),
            ["AutomaticSize"] = Enum.AutomaticSize.X,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 1,
            ["BorderColor3"] = Color3.new(0.105882362, 0.164705887, 0.207843155),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 10,
            ["Position"] = UDim2.new(0, 0, 0, 0),
            ["Rotation"] = 0,
            ["Selectable"] = false,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(0, 0, 1, 0),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = false,
            ["ZIndex"] = 1,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "Platinum Coins",
        })
        objects[70].Parent = objects[56]
        objects[71] = Instance.new("ImageLabel")
        applyPS99Properties(objects[71], {
            ["Image"] = "rbxassetid://14867115964",
            ["ImageColor3"] = Color3.new(1, 1, 1),
            ["ImageRectOffset"] = Vector2.new(0, 0),
            ["ImageRectSize"] = Vector2.new(0, 0),
            ["ImageTransparency"] = 0,
            ["ResampleMode"] = Enum.ResamplerMode.Default,
            ["ScaleType"] = Enum.ScaleType.Fit,
            ["SliceCenter"] = Rect.new(0, 0, 0, 0),
            ["SliceScale"] = 1,
            ["TileSize"] = UDim2.new(1, 0, 1, 0),
            ["Active"] = false,
            ["AnchorPoint"] = Vector2.new(0, 0),
            ["AutomaticSize"] = Enum.AutomaticSize.None,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 1,
            ["BorderColor3"] = Color3.new(0.105882362, 0.164705887, 0.207843155),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 0,
            ["Position"] = UDim2.new(0, 0, 0, 0),
            ["Rotation"] = 0,
            ["Selectable"] = false,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(1, 0, 0.899999976, 0),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = true,
            ["ZIndex"] = 1,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "Icon",
        })
        objects[71].Parent = objects[70]
        objects[72] = Instance.new("UIAspectRatioConstraint")
        applyPS99Properties(objects[72], {
            ["AspectRatio"] = 1,
            ["AspectType"] = Enum.AspectType.FitWithinMaxSize,
            ["DominantAxis"] = Enum.DominantAxis.Width,
            ["Name"] = "UIAspectRatioConstraint",
        })
        objects[72].Parent = objects[71]
        objects[73] = Instance.new("TextLabel")
        applyPS99Properties(objects[73], {
            ["FontFace"] = Font.new("rbxassetid://11702779409", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
            ["LineHeight"] = 0.899999976,
            ["LocalizationMatchIdentifier"] = "",
            ["LocalizationMatchedSourceText"] = "",
            ["MaxVisibleGraphemes"] = -1,
            ["OpenTypeFeatures"] = "",
            ["RichText"] = false,
            ["Text"] = "99",
            ["TextColor3"] = Color3.new(0.968627453, 1, 0.996078432),
            ["TextDirection"] = Enum.TextDirection.Auto,
            ["TextScaled"] = true,
            ["TextSize"] = 18,
            ["TextStrokeColor3"] = Color3.new(0, 0, 0),
            ["TextStrokeTransparency"] = 1,
            ["TextTransparency"] = 0,
            ["TextTruncate"] = Enum.TextTruncate.None,
            ["TextWrapped"] = true,
            ["TextXAlignment"] = Enum.TextXAlignment.Center,
            ["TextYAlignment"] = Enum.TextYAlignment.Center,
            ["Active"] = false,
            ["AnchorPoint"] = Vector2.new(0, 0),
            ["AutomaticSize"] = Enum.AutomaticSize.X,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 1,
            ["BorderColor3"] = Color3.new(0.105882362, 0.164705887, 0.207843155),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 0,
            ["Position"] = UDim2.new(0, 0, 0, 0),
            ["Rotation"] = 0,
            ["Selectable"] = false,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(0, 0, 0.800000012, 0),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = true,
            ["ZIndex"] = 2,
            ["AutoLocalize"] = false,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "Amount",
        })
        objects[73].Parent = objects[70]
        objects[74] = Instance.new("UIStroke")
        applyPS99Properties(objects[74], {
            ["ApplyStrokeMode"] = Enum.ApplyStrokeMode.Contextual,
            ["BorderOffset"] = UDim.new(0, 0),
            ["BorderStrokePosition"] = Enum.BorderStrokePosition.Outer,
            ["Color"] = Color3.new(0, 0, 0),
            ["Enabled"] = true,
            ["LineJoinMode"] = Enum.LineJoinMode.Bevel,
            ["StrokeSizingMode"] = Enum.StrokeSizingMode.FixedSize,
            ["Thickness"] = 4.83564806,
            ["Transparency"] = 0,
            ["ZIndex"] = 1,
            ["Name"] = "UIStroke",
        })
        objects[74].Parent = objects[73]
        objects[75] = Instance.new("UIListLayout")
        applyPS99Properties(objects[75], {
            ["HorizontalFlex"] = Enum.UIFlexAlignment.None,
            ["ItemLineAlignment"] = Enum.ItemLineAlignment.Automatic,
            ["Padding"] = UDim.new(0, 2),
            ["VerticalFlex"] = Enum.UIFlexAlignment.None,
            ["Wraps"] = false,
            ["FillDirection"] = Enum.FillDirection.Horizontal,
            ["HorizontalAlignment"] = Enum.HorizontalAlignment.Center,
            ["SortOrder"] = Enum.SortOrder.LayoutOrder,
            ["VerticalAlignment"] = Enum.VerticalAlignment.Top,
            ["Name"] = "UIListLayout",
        })
        objects[75].Parent = objects[70]
        objects[76] = Instance.new("Frame")
        applyPS99Properties(objects[76], {
            ["Style"] = Enum.FrameStyle.Custom,
            ["Active"] = false,
            ["AnchorPoint"] = Vector2.new(0, 0),
            ["AutomaticSize"] = Enum.AutomaticSize.X,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 1,
            ["BorderColor3"] = Color3.new(0.105882362, 0.164705887, 0.207843155),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 1,
            ["Position"] = UDim2.new(0, 0, 0, 0),
            ["Rotation"] = 0,
            ["Selectable"] = false,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(0, 0, 1, 0),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = false,
            ["ZIndex"] = 1,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "Platinum Bars",
        })
        objects[76].Parent = objects[56]
        objects[77] = Instance.new("ImageLabel")
        applyPS99Properties(objects[77], {
            ["Image"] = "rbxassetid://14867115795",
            ["ImageColor3"] = Color3.new(1, 1, 1),
            ["ImageRectOffset"] = Vector2.new(0, 0),
            ["ImageRectSize"] = Vector2.new(0, 0),
            ["ImageTransparency"] = 0,
            ["ResampleMode"] = Enum.ResamplerMode.Default,
            ["ScaleType"] = Enum.ScaleType.Fit,
            ["SliceCenter"] = Rect.new(0, 0, 0, 0),
            ["SliceScale"] = 1,
            ["TileSize"] = UDim2.new(1, 0, 1, 0),
            ["Active"] = false,
            ["AnchorPoint"] = Vector2.new(0, 0),
            ["AutomaticSize"] = Enum.AutomaticSize.None,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 1,
            ["BorderColor3"] = Color3.new(0.105882362, 0.164705887, 0.207843155),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 0,
            ["Position"] = UDim2.new(0, 0, 0, 0),
            ["Rotation"] = 0,
            ["Selectable"] = false,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(1, 0, 0.899999976, 0),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = true,
            ["ZIndex"] = 1,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "Icon",
        })
        objects[77].Parent = objects[76]
        objects[78] = Instance.new("UIAspectRatioConstraint")
        applyPS99Properties(objects[78], {
            ["AspectRatio"] = 1,
            ["AspectType"] = Enum.AspectType.FitWithinMaxSize,
            ["DominantAxis"] = Enum.DominantAxis.Width,
            ["Name"] = "UIAspectRatioConstraint",
        })
        objects[78].Parent = objects[77]
        objects[79] = Instance.new("TextLabel")
        applyPS99Properties(objects[79], {
            ["FontFace"] = Font.new("rbxassetid://11702779409", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
            ["LineHeight"] = 0.899999976,
            ["LocalizationMatchIdentifier"] = "",
            ["LocalizationMatchedSourceText"] = "",
            ["MaxVisibleGraphemes"] = -1,
            ["OpenTypeFeatures"] = "",
            ["RichText"] = false,
            ["Text"] = "9",
            ["TextColor3"] = Color3.new(0.835294127, 1, 0.968627453),
            ["TextDirection"] = Enum.TextDirection.Auto,
            ["TextScaled"] = true,
            ["TextSize"] = 18,
            ["TextStrokeColor3"] = Color3.new(0, 0, 0),
            ["TextStrokeTransparency"] = 1,
            ["TextTransparency"] = 0,
            ["TextTruncate"] = Enum.TextTruncate.None,
            ["TextWrapped"] = true,
            ["TextXAlignment"] = Enum.TextXAlignment.Center,
            ["TextYAlignment"] = Enum.TextYAlignment.Center,
            ["Active"] = false,
            ["AnchorPoint"] = Vector2.new(0, 0),
            ["AutomaticSize"] = Enum.AutomaticSize.X,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 1,
            ["BorderColor3"] = Color3.new(0.105882362, 0.164705887, 0.207843155),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 0,
            ["Position"] = UDim2.new(0, 0, 0, 0),
            ["Rotation"] = 0,
            ["Selectable"] = false,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(0, 0, 0.800000012, 0),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = true,
            ["ZIndex"] = 2,
            ["AutoLocalize"] = false,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "Amount",
        })
        objects[79].Parent = objects[76]
        objects[80] = Instance.new("UIStroke")
        applyPS99Properties(objects[80], {
            ["ApplyStrokeMode"] = Enum.ApplyStrokeMode.Contextual,
            ["BorderOffset"] = UDim.new(0, 0),
            ["BorderStrokePosition"] = Enum.BorderStrokePosition.Outer,
            ["Color"] = Color3.new(0, 0, 0),
            ["Enabled"] = true,
            ["LineJoinMode"] = Enum.LineJoinMode.Bevel,
            ["StrokeSizingMode"] = Enum.StrokeSizingMode.FixedSize,
            ["Thickness"] = 4.83564806,
            ["Transparency"] = 0,
            ["ZIndex"] = 1,
            ["Name"] = "UIStroke",
        })
        objects[80].Parent = objects[79]
        objects[81] = Instance.new("UIListLayout")
        applyPS99Properties(objects[81], {
            ["HorizontalFlex"] = Enum.UIFlexAlignment.None,
            ["ItemLineAlignment"] = Enum.ItemLineAlignment.Automatic,
            ["Padding"] = UDim.new(0, 2),
            ["VerticalFlex"] = Enum.UIFlexAlignment.None,
            ["Wraps"] = false,
            ["FillDirection"] = Enum.FillDirection.Horizontal,
            ["HorizontalAlignment"] = Enum.HorizontalAlignment.Center,
            ["SortOrder"] = Enum.SortOrder.LayoutOrder,
            ["VerticalAlignment"] = Enum.VerticalAlignment.Top,
            ["Name"] = "UIListLayout",
        })
        objects[81].Parent = objects[76]
        objects[82] = Instance.new("UIPadding")
        applyPS99Properties(objects[82], {
            ["PaddingBottom"] = UDim.new(0.0700000003, 0),
            ["PaddingLeft"] = UDim.new(0, 8),
            ["PaddingRight"] = UDim.new(0, 8),
            ["PaddingTop"] = UDim.new(0.0700000003, 0),
            ["Name"] = "UIPadding",
        })
        objects[82].Parent = objects[56]
        objects[83] = Instance.new("ScrollingFrame")
        applyPS99Properties(objects[83], {
            ["AutomaticCanvasSize"] = Enum.AutomaticSize.X,
            ["BottomImage"] = "rbxasset://textures/ui/Scroll/scroll-bottom.png",
            ["CanvasPosition"] = Vector2.new(0, 0),
            ["CanvasSize"] = UDim2.new(0, 0, 0, 0),
            ["ElasticBehavior"] = Enum.ElasticBehavior.WhenScrollable,
            ["HorizontalScrollBarInset"] = Enum.ScrollBarInset.None,
            ["MidImage"] = "rbxasset://textures/ui/Scroll/scroll-middle.png",
            ["ScrollBarImageColor3"] = Color3.new(0, 0, 0),
            ["ScrollBarImageTransparency"] = 0,
            ["ScrollBarThickness"] = 12,
            ["ScrollingDirection"] = Enum.ScrollingDirection.Y,
            ["ScrollingEnabled"] = true,
            ["TopImage"] = "rbxasset://textures/ui/Scroll/scroll-top.png",
            ["VerticalScrollBarInset"] = Enum.ScrollBarInset.None,
            ["VerticalScrollBarPosition"] = Enum.VerticalScrollBarPosition.Right,
            ["Active"] = true,
            ["AnchorPoint"] = Vector2.new(0.5, 0),
            ["AutomaticSize"] = Enum.AutomaticSize.None,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 0,
            ["BorderColor3"] = Color3.new(0, 0, 0),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 0,
            ["Position"] = UDim2.new(0.5, 0, 0.419999987, 0),
            ["Rotation"] = 0,
            ["Selectable"] = true,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(1, 0, 0.300000012, 0),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = true,
            ["ZIndex"] = 1,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = true,
            ["Name"] = "CustomHolder",
        })
        objects[83].Parent = objects[7]
        objects[84] = Instance.new("UIListLayout")
        applyPS99Properties(objects[84], {
            ["HorizontalFlex"] = Enum.UIFlexAlignment.None,
            ["ItemLineAlignment"] = Enum.ItemLineAlignment.Automatic,
            ["Padding"] = UDim.new(0, 10),
            ["VerticalFlex"] = Enum.UIFlexAlignment.None,
            ["Wraps"] = false,
            ["FillDirection"] = Enum.FillDirection.Horizontal,
            ["HorizontalAlignment"] = Enum.HorizontalAlignment.Center,
            ["SortOrder"] = Enum.SortOrder.LayoutOrder,
            ["VerticalAlignment"] = Enum.VerticalAlignment.Center,
            ["Name"] = "UIListLayout",
        })
        objects[84].Parent = objects[83]
        objects[85] = Instance.new("UICorner")
        applyPS99Properties(objects[85], {
            ["BottomLeftRadius"] = UDim.new(0.0350000001, 0),
            ["BottomRightRadius"] = UDim.new(0.0350000001, 0),
            ["TopLeftRadius"] = UDim.new(0.0350000001, 0),
            ["TopRightRadius"] = UDim.new(0.0350000001, 0),
            ["Name"] = "UICorner",
        })
        objects[85].Parent = objects[2]
        objects[86] = Instance.new("ImageLabel")
        applyPS99Properties(objects[86], {
            ["Image"] = "rbxassetid://14001321443",
            ["ImageColor3"] = Color3.new(0, 0, 0),
            ["ImageRectOffset"] = Vector2.new(0, 0),
            ["ImageRectSize"] = Vector2.new(0, 0),
            ["ImageTransparency"] = 0.75,
            ["ResampleMode"] = Enum.ResamplerMode.Default,
            ["ScaleType"] = Enum.ScaleType.Slice,
            ["SliceCenter"] = Rect.new(50, 50, 150, 150),
            ["SliceScale"] = 1,
            ["TileSize"] = UDim2.new(1, 0, 1, 0),
            ["Active"] = false,
            ["AnchorPoint"] = Vector2.new(0.5, 0.5),
            ["AutomaticSize"] = Enum.AutomaticSize.None,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 1,
            ["BorderColor3"] = Color3.new(0, 0, 0),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 0,
            ["Position"] = UDim2.new(0.5, 0, 0.5, 0),
            ["Rotation"] = 0,
            ["Selectable"] = false,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(1, 35, 1, 35),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = true,
            ["ZIndex"] = -1,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "shadow",
        })
        objects[86].Parent = objects[2]
        objects[87] = Instance.new("UIStroke")
        applyPS99Properties(objects[87], {
            ["ApplyStrokeMode"] = Enum.ApplyStrokeMode.Contextual,
            ["BorderOffset"] = UDim.new(0, 0),
            ["BorderStrokePosition"] = Enum.BorderStrokePosition.Outer,
            ["Color"] = Color3.new(0.164705887, 0.168627456, 0.192156866),
            ["Enabled"] = true,
            ["LineJoinMode"] = Enum.LineJoinMode.Round,
            ["StrokeSizingMode"] = Enum.StrokeSizingMode.FixedSize,
            ["Thickness"] = 6.76990747,
            ["Transparency"] = 0,
            ["ZIndex"] = 1,
            ["Name"] = "UIStroke",
        })
        objects[87].Parent = objects[2]
        objects[88] = Instance.new("Frame")
        applyPS99Properties(objects[88], {
            ["Style"] = Enum.FrameStyle.Custom,
            ["Active"] = false,
            ["AnchorPoint"] = Vector2.new(0, 0),
            ["AutomaticSize"] = Enum.AutomaticSize.None,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 0,
            ["BorderColor3"] = Color3.new(0.105882362, 0.164705887, 0.207843155),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 0,
            ["Position"] = UDim2.new(0, 0, 0, 0),
            ["Rotation"] = 0,
            ["Selectable"] = false,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(1, 0, 0.150000006, 0),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = true,
            ["ZIndex"] = 2,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "Top",
        })
        objects[88].Parent = objects[2]
        objects[89] = Instance.new("UIGradient")
        applyPS99Properties(objects[89], {
            ["Color"] = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.new(0.215686, 0.764706, 1)), ColorSequenceKeypoint.new(1, Color3.new(0.368627, 0.937255, 1))}),
            ["Enabled"] = true,
            ["Offset"] = Vector2.new(0, 0),
            ["Rotation"] = -90,
            ["Scale"] = 1,
            ["TileMode"] = Enum.GradientTileMode.Clamp,
            ["Transparency"] = NumberSequence.new({NumberSequenceKeypoint.new(0, 0, 0), NumberSequenceKeypoint.new(1, 0, 0)}),
            ["Type"] = Enum.GradientType.Linear,
            ["Name"] = "UIGradient",
        })
        objects[89].Parent = objects[88]
        objects[90] = Instance.new("Frame")
        applyPS99Properties(objects[90], {
            ["Style"] = Enum.FrameStyle.Custom,
            ["Active"] = false,
            ["AnchorPoint"] = Vector2.new(0, 1),
            ["AutomaticSize"] = Enum.AutomaticSize.None,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 0,
            ["BorderColor3"] = Color3.new(0.105882362, 0.164705887, 0.207843155),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 0,
            ["Position"] = UDim2.new(0, 0, 1, 0),
            ["Rotation"] = 0,
            ["Selectable"] = false,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(1, 0, 0.5, 0),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = true,
            ["ZIndex"] = 1,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "background-side",
        })
        objects[90].Parent = objects[88]
        objects[91] = Instance.new("UIGradient")
        applyPS99Properties(objects[91], {
            ["Color"] = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.new(0.215686, 0.764706, 1)), ColorSequenceKeypoint.new(1, Color3.new(0.368627, 0.937255, 1))}),
            ["Enabled"] = true,
            ["Offset"] = Vector2.new(0, -0.5),
            ["Rotation"] = -90,
            ["Scale"] = 1,
            ["TileMode"] = Enum.GradientTileMode.Clamp,
            ["Transparency"] = NumberSequence.new({NumberSequenceKeypoint.new(0, 0, 0), NumberSequenceKeypoint.new(1, 0, 0)}),
            ["Type"] = Enum.GradientType.Linear,
            ["Name"] = "UIGradient",
        })
        objects[91].Parent = objects[90]
        objects[92] = Instance.new("UICorner")
        applyPS99Properties(objects[92], {
            ["BottomLeftRadius"] = UDim.new(0.239999995, 0),
            ["BottomRightRadius"] = UDim.new(0.239999995, 0),
            ["TopLeftRadius"] = UDim.new(0.239999995, 0),
            ["TopRightRadius"] = UDim.new(0.239999995, 0),
            ["Name"] = "UICorner",
        })
        objects[92].Parent = objects[88]
        objects[93] = Instance.new("TextLabel")
        applyPS99Properties(objects[93], {
            ["FontFace"] = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
            ["LineHeight"] = 1,
            ["LocalizationMatchIdentifier"] = "c15c36f4-f01f-4e5e-afab-d05105f45cc8",
            ["LocalizationMatchedSourceText"] = "You're so lucky!",
            ["MaxVisibleGraphemes"] = -1,
            ["OpenTypeFeatures"] = "",
            ["RichText"] = false,
            ["Text"] = "You're so lucky!",
            ["TextColor3"] = Color3.new(1, 1, 1),
            ["TextDirection"] = Enum.TextDirection.Auto,
            ["TextScaled"] = true,
            ["TextSize"] = 14,
            ["TextStrokeColor3"] = Color3.new(0.0666666701, 0.227450997, 0.282352954),
            ["TextStrokeTransparency"] = 1,
            ["TextTransparency"] = 0,
            ["TextTruncate"] = Enum.TextTruncate.AtEnd,
            ["TextWrapped"] = true,
            ["TextXAlignment"] = Enum.TextXAlignment.Center,
            ["TextYAlignment"] = Enum.TextYAlignment.Center,
            ["Active"] = false,
            ["AnchorPoint"] = Vector2.new(0.5, 0.5),
            ["AutomaticSize"] = Enum.AutomaticSize.None,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 1,
            ["BorderColor3"] = Color3.new(0.105882362, 0.164705887, 0.207843155),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 0,
            ["Position"] = UDim2.new(0.5, 0, 0.50000006, 0),
            ["Rotation"] = 0,
            ["Selectable"] = false,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(0.899999976, 0, 0.675000012, 0),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = true,
            ["ZIndex"] = 2,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "Title",
        })
        objects[93].Parent = objects[88]
        objects[94] = Instance.new("UIStroke")
        applyPS99Properties(objects[94], {
            ["ApplyStrokeMode"] = Enum.ApplyStrokeMode.Contextual,
            ["BorderOffset"] = UDim.new(0, 0),
            ["BorderStrokePosition"] = Enum.BorderStrokePosition.Outer,
            ["Color"] = Color3.new(0, 0, 0),
            ["Enabled"] = true,
            ["LineJoinMode"] = Enum.LineJoinMode.Bevel,
            ["StrokeSizingMode"] = Enum.StrokeSizingMode.FixedSize,
            ["Thickness"] = 2.90138888,
            ["Transparency"] = 0,
            ["ZIndex"] = 1,
            ["Name"] = "UIStroke",
        })
        objects[94].Parent = objects[93]
        objects[95] = Instance.new("ImageButton")
        applyPS99Properties(objects[95], {
            ["HoverImage"] = "",
            ["Image"] = "rbxassetid://14423621163",
            ["ImageColor3"] = Color3.new(1, 1, 1),
            ["ImageRectOffset"] = Vector2.new(0, 0),
            ["ImageRectSize"] = Vector2.new(0, 0),
            ["ImageTransparency"] = 0,
            ["PressedImage"] = "rbxassetid://14423621349",
            ["ResampleMode"] = Enum.ResamplerMode.Default,
            ["ScaleType"] = Enum.ScaleType.Slice,
            ["SliceCenter"] = Rect.new(20, 20, 80, 80),
            ["SliceScale"] = 0.967129648,
            ["TileSize"] = UDim2.new(1, 0, 1, 0),
            ["AutoButtonColor"] = true,
            ["Modal"] = false,
            ["Selected"] = false,
            ["Style"] = Enum.FrameStyle.Custom,
            ["Active"] = true,
            ["AnchorPoint"] = Vector2.new(0.5, 0.5),
            ["AutomaticSize"] = Enum.AutomaticSize.None,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 1,
            ["BorderColor3"] = Color3.new(0.105882362, 0.164705887, 0.207843155),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 0,
            ["Position"] = UDim2.new(0.990999997, 0, 0, 0),
            ["Rotation"] = 0,
            ["Selectable"] = false,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(1, 0, 0.0599999987, 45),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = true,
            ["ZIndex"] = 50,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "Close",
        })
        objects[95].Parent = objects[2]
        objects[96] = Instance.new("UIAspectRatioConstraint")
        applyPS99Properties(objects[96], {
            ["AspectRatio"] = 1.04999995,
            ["AspectType"] = Enum.AspectType.FitWithinMaxSize,
            ["DominantAxis"] = Enum.DominantAxis.Width,
            ["Name"] = "UIAspectRatioConstraint",
        })
        objects[96].Parent = objects[95]
        objects[97] = Instance.new("UIGradient")
        applyPS99Properties(objects[97], {
            ["Color"] = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.new(1, 0.00784314, 0.239216)), ColorSequenceKeypoint.new(1, Color3.new(1, 0.152941, 0.490196))}),
            ["Enabled"] = true,
            ["Offset"] = Vector2.new(0, 0),
            ["Rotation"] = -90,
            ["Scale"] = 1,
            ["TileMode"] = Enum.GradientTileMode.Clamp,
            ["Transparency"] = NumberSequence.new({NumberSequenceKeypoint.new(0, 0, 0), NumberSequenceKeypoint.new(1, 0, 0)}),
            ["Type"] = Enum.GradientType.Linear,
            ["Name"] = "red gradient",
        })
        objects[97].Parent = objects[95]
        objects[98] = Instance.new("TextLabel")
        applyPS99Properties(objects[98], {
            ["FontFace"] = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
            ["LineHeight"] = 1,
            ["LocalizationMatchIdentifier"] = "",
            ["LocalizationMatchedSourceText"] = "",
            ["MaxVisibleGraphemes"] = -1,
            ["OpenTypeFeatures"] = "",
            ["RichText"] = false,
            ["Text"] = "X",
            ["TextColor3"] = Color3.new(1, 1, 1),
            ["TextDirection"] = Enum.TextDirection.Auto,
            ["TextScaled"] = true,
            ["TextSize"] = 18,
            ["TextStrokeColor3"] = Color3.new(0, 0, 0),
            ["TextStrokeTransparency"] = 1,
            ["TextTransparency"] = 0,
            ["TextTruncate"] = Enum.TextTruncate.None,
            ["TextWrapped"] = true,
            ["TextXAlignment"] = Enum.TextXAlignment.Center,
            ["TextYAlignment"] = Enum.TextYAlignment.Center,
            ["Active"] = false,
            ["AnchorPoint"] = Vector2.new(0.5, 0.5),
            ["AutomaticSize"] = Enum.AutomaticSize.None,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 1,
            ["BorderColor3"] = Color3.new(0.105882362, 0.164705887, 0.207843155),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 0,
            ["Position"] = UDim2.new(0.5, 0, 0.5, 0),
            ["Rotation"] = 0,
            ["Selectable"] = false,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(0.899999976, 0, 0.600000024, 0),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = true,
            ["ZIndex"] = 50,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "TextLabel",
        })
        objects[98].Parent = objects[95]
        objects[99] = Instance.new("UIStroke")
        applyPS99Properties(objects[99], {
            ["ApplyStrokeMode"] = Enum.ApplyStrokeMode.Contextual,
            ["BorderOffset"] = UDim.new(0, 0),
            ["BorderStrokePosition"] = Enum.BorderStrokePosition.Outer,
            ["Color"] = Color3.new(0, 0, 0),
            ["Enabled"] = true,
            ["LineJoinMode"] = Enum.LineJoinMode.Bevel,
            ["StrokeSizingMode"] = Enum.StrokeSizingMode.FixedSize,
            ["Thickness"] = 2.90138888,
            ["Transparency"] = 0,
            ["ZIndex"] = 1,
            ["Name"] = "UIStroke",
        })
        objects[99].Parent = objects[98]
        objects[100] = Instance.new("ImageLabel")
        applyPS99Properties(objects[100], {
            ["Image"] = "rbxassetid://14001321443",
            ["ImageColor3"] = Color3.new(0, 0, 0),
            ["ImageRectOffset"] = Vector2.new(0, 0),
            ["ImageRectSize"] = Vector2.new(0, 0),
            ["ImageTransparency"] = 0.75,
            ["ResampleMode"] = Enum.ResamplerMode.Default,
            ["ScaleType"] = Enum.ScaleType.Slice,
            ["SliceCenter"] = Rect.new(50, 50, 150, 150),
            ["SliceScale"] = 0.75,
            ["TileSize"] = UDim2.new(1, 0, 1, 0),
            ["Active"] = false,
            ["AnchorPoint"] = Vector2.new(0.5, 0.5),
            ["AutomaticSize"] = Enum.AutomaticSize.None,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 1,
            ["BorderColor3"] = Color3.new(0, 0, 0),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 0,
            ["Position"] = UDim2.new(0.5, 0, 0.600000024, 0),
            ["Rotation"] = 0,
            ["Selectable"] = false,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(1, 0, 1.10000002, 0),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = true,
            ["ZIndex"] = 49,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "shadow",
        })
        objects[100].Parent = objects[95]
        objects[101] = Instance.new("UIScale")
        applyPS99Properties(objects[101], {
            ["Scale"] = 1,
            ["Name"] = "ButtonUIScale",
        })
        objects[101].Parent = objects[95]
        objects[102] = Instance.new("UIPadding")
        applyPS99Properties(objects[102], {
            ["PaddingBottom"] = UDim.new(0, 0),
            ["PaddingLeft"] = UDim.new(0, 0),
            ["PaddingRight"] = UDim.new(0, 0),
            ["PaddingTop"] = UDim.new(0, -12),
            ["Name"] = "UIPadding",
        })
        objects[102].Parent = objects[1]
        return objects[1]
    end
end
]============]

    local function buildPS99MessageScreen()
        if not buildPS99MessageScreenCompiled then
            local compiler = loadstring or load
            assert(type(compiler) == "function", "PlantVsCoinsUI: loadstring is required for the embedded message UI fallback")
            local chunk, compileError = compiler(buildPS99MessageScreenSource)
            assert(chunk, compileError)
            buildPS99MessageScreenCompiled = chunk()(applyPS99Properties)
            buildPS99MessageScreenSource = nil
        end
        return buildPS99MessageScreenCompiled()
    end

    local buildPS99BottomMessageTemplateCompiled
    local buildPS99BottomMessageTemplateSource = [============[
return function(applyPS99Properties)
    return function()
        local objects = {}
        objects[1] = Instance.new("CanvasGroup")
        applyPS99Properties(objects[1], {
            ["GroupColor3"] = Color3.new(1, 1, 1),
            ["GroupTransparency"] = 0,
            ["Active"] = false,
            ["AnchorPoint"] = Vector2.new(0, 0),
            ["AutomaticSize"] = Enum.AutomaticSize.None,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 1,
            ["BorderColor3"] = Color3.new(0, 0, 0),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = true,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 0,
            ["Position"] = UDim2.new(0, 0, 0, 0),
            ["Rotation"] = 0,
            ["Selectable"] = false,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(1, 0, 0.200000003, 0),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = true,
            ["ZIndex"] = 1,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "Message",
        })
        objects[2] = Instance.new("Frame")
        applyPS99Properties(objects[2], {
            ["Style"] = Enum.FrameStyle.Custom,
            ["Active"] = false,
            ["AnchorPoint"] = Vector2.new(0.5, 0),
            ["AutomaticSize"] = Enum.AutomaticSize.None,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 1,
            ["BorderColor3"] = Color3.new(0, 0, 0),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 0,
            ["Position"] = UDim2.new(0.5, 0, 0, 0),
            ["Rotation"] = 0,
            ["Selectable"] = false,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(1, 0, 1, 0),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = true,
            ["ZIndex"] = 2,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "Frame",
        })
        objects[2].Parent = objects[1]
        objects[3] = Instance.new("UIListLayout")
        applyPS99Properties(objects[3], {
            ["HorizontalFlex"] = Enum.UIFlexAlignment.None,
            ["ItemLineAlignment"] = Enum.ItemLineAlignment.Automatic,
            ["Padding"] = UDim.new(0, 12),
            ["VerticalFlex"] = Enum.UIFlexAlignment.None,
            ["Wraps"] = false,
            ["FillDirection"] = Enum.FillDirection.Horizontal,
            ["HorizontalAlignment"] = Enum.HorizontalAlignment.Center,
            ["SortOrder"] = Enum.SortOrder.LayoutOrder,
            ["VerticalAlignment"] = Enum.VerticalAlignment.Top,
            ["Name"] = "UIListLayout",
        })
        objects[3].Parent = objects[2]
        objects[4] = Instance.new("TextLabel")
        applyPS99Properties(objects[4], {
            ["FontFace"] = Font.new("rbxassetid://11702779409", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
            ["LineHeight"] = 1,
            ["LocalizationMatchIdentifier"] = "",
            ["LocalizationMatchedSourceText"] = "",
            ["MaxVisibleGraphemes"] = -1,
            ["OpenTypeFeatures"] = "",
            ["RichText"] = true,
            ["Text"] = "Generic message w00t!",
            ["TextColor3"] = Color3.new(0.0901960805, 0.168627456, 0.223529428),
            ["TextDirection"] = Enum.TextDirection.Auto,
            ["TextScaled"] = true,
            ["TextSize"] = 18,
            ["TextStrokeColor3"] = Color3.new(0, 0, 0),
            ["TextStrokeTransparency"] = 1,
            ["TextTransparency"] = 0,
            ["TextTruncate"] = Enum.TextTruncate.None,
            ["TextWrapped"] = true,
            ["TextXAlignment"] = Enum.TextXAlignment.Center,
            ["TextYAlignment"] = Enum.TextYAlignment.Center,
            ["Active"] = false,
            ["AnchorPoint"] = Vector2.new(0, 0),
            ["AutomaticSize"] = Enum.AutomaticSize.X,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 1,
            ["BorderColor3"] = Color3.new(0.105882362, 0.164705887, 0.207843155),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 2,
            ["Position"] = UDim2.new(0, 0, 0, 0),
            ["Rotation"] = 0,
            ["Selectable"] = false,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(0, 0, 1, 0),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = true,
            ["ZIndex"] = 2,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "TextLabel",
        })
        objects[4].Parent = objects[2]
        objects[5] = Instance.new("ImageLabel")
        applyPS99Properties(objects[5], {
            ["Image"] = "rbxassetid://13873482240",
            ["ImageColor3"] = Color3.new(0, 0, 0),
            ["ImageRectOffset"] = Vector2.new(0, 0),
            ["ImageRectSize"] = Vector2.new(0, 0),
            ["ImageTransparency"] = 0.649999976,
            ["ResampleMode"] = Enum.ResamplerMode.Default,
            ["ScaleType"] = Enum.ScaleType.Stretch,
            ["SliceCenter"] = Rect.new(0, 0, 0, 0),
            ["SliceScale"] = 1,
            ["TileSize"] = UDim2.new(1, 0, 1, 0),
            ["Active"] = false,
            ["AnchorPoint"] = Vector2.new(0.5, 0),
            ["AutomaticSize"] = Enum.AutomaticSize.None,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 1,
            ["BorderColor3"] = Color3.new(0, 0, 0),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 0,
            ["Position"] = UDim2.new(0.5, 0, 0.100000001, 0),
            ["Rotation"] = 0,
            ["Selectable"] = false,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(0.400000006, 0, 1, 0),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = true,
            ["ZIndex"] = 1,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "Shadow",
        })
        objects[5].Parent = objects[1]
        return objects[1]
    end
end
]============]

    local function buildPS99BottomMessageTemplate()
        if not buildPS99BottomMessageTemplateCompiled then
            local compiler = loadstring or load
            assert(type(compiler) == "function", "PlantVsCoinsUI: loadstring is required for the embedded bottom-message template fallback")
            local chunk, compileError = compiler(buildPS99BottomMessageTemplateSource)
            assert(chunk, compileError)
            buildPS99BottomMessageTemplateCompiled = chunk()(applyPS99Properties)
            buildPS99BottomMessageTemplateSource = nil
        end
        return buildPS99BottomMessageTemplateCompiled()
    end

    local buildPS99BottomHostCompiled
    local buildPS99BottomHostSource = [============[
return function(applyPS99Properties)
    return function()
        local objects = {}
        objects[1] = Instance.new("Frame")
        applyPS99Properties(objects[1], {
            ["Style"] = Enum.FrameStyle.Custom,
            ["Active"] = false,
            ["AnchorPoint"] = Vector2.new(0.5, 1),
            ["AutomaticSize"] = Enum.AutomaticSize.None,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 1,
            ["BorderColor3"] = Color3.new(0.105882362, 0.164705887, 0.207843155),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 0,
            ["Position"] = UDim2.new(0.5, 0, 0.800000012, -40),
            ["Rotation"] = 0,
            ["Selectable"] = false,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(0.5, 25, 0.119999997, 55),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = true,
            ["ZIndex"] = 1,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "Bottom",
        })
        objects[2] = Instance.new("UIListLayout")
        applyPS99Properties(objects[2], {
            ["HorizontalFlex"] = Enum.UIFlexAlignment.None,
            ["ItemLineAlignment"] = Enum.ItemLineAlignment.Automatic,
            ["Padding"] = UDim.new(0.0250000004, 0),
            ["VerticalFlex"] = Enum.UIFlexAlignment.None,
            ["Wraps"] = false,
            ["FillDirection"] = Enum.FillDirection.Vertical,
            ["HorizontalAlignment"] = Enum.HorizontalAlignment.Center,
            ["SortOrder"] = Enum.SortOrder.LayoutOrder,
            ["VerticalAlignment"] = Enum.VerticalAlignment.Bottom,
            ["Name"] = "UIListLayout",
        })
        objects[2].Parent = objects[1]
        return objects[1]
    end
end
]============]

    local function buildPS99BottomHost()
        if not buildPS99BottomHostCompiled then
            local compiler = loadstring or load
            assert(type(compiler) == "function", "PlantVsCoinsUI: loadstring is required for the embedded bottom-message host fallback")
            local chunk, compileError = compiler(buildPS99BottomHostSource)
            assert(chunk, compileError)
            buildPS99BottomHostCompiled = chunk()(applyPS99Properties)
            buildPS99BottomHostSource = nil
        end
        return buildPS99BottomHostCompiled()
    end


    local function getPS99UIParent(self)
        local parent = self.Screen and self.Screen.Parent
        if parent then
            return parent
        end
        local player = Players.LocalPlayer
        if not player then
            return nil
        end
        return player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui")
    end

    local function playPS99UISound(soundId, volume, parent)
        local sound = Instance.new("Sound")
        sound.SoundId = soundId
        sound.Volume = volume
        sound.Parent = parent or game:GetService("SoundService")
        sound:Play()
        sound.Ended:Connect(function()
            if sound.Parent then
                sound:Destroy()
            end
        end)
        task.delay(10, function()
            if sound.Parent then
                sound:Destroy()
            end
        end)
        return sound
    end

    local function findDirect(parent, name)
        return parent and parent:FindFirstChild(name)
    end

    function Library:Message(messageSettings, options)
        local settings
        local message
        if type(messageSettings) == "table" then
            settings = messageSettings
            message = settings.Message or settings.Content or settings.Desc or ""
        else
            settings = type(options) == "table" and options or {}
            message = messageSettings
        end

        if self.ActivePS99Message then
            return nil
        end

        local parent = getPS99UIParent(self)
        if not parent then
            return nil
        end

        local screen = buildPS99MessageScreen()
        local frame = findDirect(screen, "Frame")
        local contents = findDirect(frame, "Contents")
        local top = findDirect(frame, "Top")
        local title = findDirect(top, "Title")
        local close = findDirect(frame, "Close")
        local ok = findDirect(contents, "Ok")
        local no = findDirect(contents, "No")
        local yes = findDirect(contents, "Yes")
        local option1 = findDirect(contents, "Option1")
        local option2 = findDirect(contents, "Option2")
        local desc = findDirect(contents, "Desc")
        local customDesc = findDirect(contents, "CustomDesc")
        local customIcon = findDirect(contents, "CustomIcon")
        local customHolder = findDirect(contents, "CustomHolder")
        local currencyCoins = findDirect(contents, "CurrencyCoins")

        local isError = settings.err == true or settings.Error == true or settings.Type == "Error"
        local icon = settings.icon or settings.Icon
        if isError and not icon then
            icon = "rbxassetid://14693511016"
        end
        local titleText = settings.title or settings.Title
        if titleText == nil then
            titleText = isError and "Oops!" or "Hey!"
        end

        if title then
            title.Text = tostring(titleText)
        end
        if customIcon then
            customIcon.Visible = icon ~= nil and tostring(icon) ~= ""
            customIcon.Image = customIcon.Visible and tostring(icon) or ""
            customIcon.ImageColor3 = settings.iconColor or settings.IconColor or Color3.new(1, 1, 1)
        end
        if customDesc then
            customDesc.Visible = customIcon and customIcon.Visible or false
            customDesc.Text = tostring(message or "")
        end
        if desc then
            desc.Visible = not (customIcon and customIcon.Visible)
            desc.Text = tostring(message or "")
        end
        if ok then
            ok.Visible = true
        end
        if close then
            close.Visible = true
        end
        if no then
            no.Visible = false
        end
        if yes then
            yes.Visible = false
        end
        if option1 then
            option1.Visible = false
        end
        if option2 then
            option2.Visible = false
        end
        if customHolder then
            customHolder.Visible = false
        end
        if currencyCoins then
            currencyCoins.Visible = false
        end

        screen.Parent = parent
        screen.Enabled = true

        local scale = frame:FindFirstChildOfClass("UIScale")
        if not scale then
            scale = Instance.new("UIScale")
            scale.Name = "TabControllerUIScale"
            scale.Parent = frame
        end
        scale.Scale = 0.975
        frame.Position = UDim2.new(0.5, 0, 0.6, frame.Position.Y.Offset)

        TweenService:Create(frame, TweenInfo.new(0.1, Enum.EasingStyle.Circular, Enum.EasingDirection.Out), {
            Position = UDim2.new(0.5, 0, 0.5, 0),
        }):Play()
        TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Circular, Enum.EasingDirection.Out), {
            Scale = 1,
        }):Play()

        playPS99UISound("rbxassetid://12413423178", 0.5, screen)

        local closed = false
        local handle = {}
        self.ActivePS99Message = handle

        local function closeMessage(immediate)
            if closed then
                return
            end
            closed = true
            if self.ActivePS99Message == handle then
                self.ActivePS99Message = nil
            end

            if immediate then
                screen:Destroy()
                return
            end

            local tween = TweenService:Create(frame, TweenInfo.new(0.045, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {
                Position = UDim2.new(0.5, 0, 0.6, frame.Position.Y.Offset),
            })
            TweenService:Create(scale, TweenInfo.new(0.045, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {
                Scale = 0.85,
            }):Play()
            tween:Play()
            tween.Completed:Connect(function()
                if screen.Parent then
                    screen:Destroy()
                end
            end)
        end

        function handle:Close(immediate)
            closeMessage(immediate == true)
        end
        handle.Destroy = handle.Close
        handle.Screen = screen
        handle.Frame = frame

        if ok then
            GUIFX.ButtonFX(ok)
            ok.Activated:Connect(function()
                closeMessage(false)
                if settings.Callback then
                    safeCall(settings.Callback)
                end
            end)
        end
        if close then
            GUIFX.ButtonFX(close)
            close.Activated:Connect(function()
                closeMessage(false)
            end)
        end

        return handle
    end

    function Library:Error(messageSettings)
        if type(messageSettings) == "table" then
            local settings = {}
            for key, value in pairs(messageSettings) do
                settings[key] = value
            end
            settings.err = true
            return self:Message(settings)
        end
        return self:Message(tostring(messageSettings or "Something went wrong."), {err = true})
    end

    Library.CreateMessage = Library.Message
    Library.ErrorMessage = Library.Error
    Library.CreateError = Library.Error

    local function ensurePS99BottomMessageHost(self)
        local state = self._PS99BottomMessageState
        if state and state.Host and state.Host.Parent then
            return state
        end

        local nativeHost = ensureNativeNotificationHost(self)
        local bottom = nativeHost.Screen:FindFirstChild("Bottom")
        if not bottom then
            bottom = buildPS99BottomHost()
            bottom.Parent = nativeHost.Screen
        end

        state = {
            Host = bottom,
            Queue = {},
            Renders = {},
            LayoutOrder = 0,
            Running = false,
        }
        self._PS99BottomMessageState = state
        return state
    end

    local function removePS99BottomEntry(list, entry)
        for index, value in ipairs(list) do
            if value == entry then
                table.remove(list, index)
                return true
            end
        end
        return false
    end

    local function fadePS99BottomMessage(entry, state)
        if entry.Tweening then
            return
        end
        entry.Tweening = true
        local frame = entry.Frame
        local gradient = frame and frame:FindFirstChildOfClass("UIGradient")
        if gradient then
            gradient.Rotation = 45
            local started = os.clock()
            while frame.Parent do
                local alpha = math.clamp((os.clock() - started) / 0.35, 0, 1)
                local first = TweenService:GetValue(alpha, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
                local rest = TweenService:GetValue(alpha, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
                gradient.Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, first),
                    NumberSequenceKeypoint.new(1 - alpha * 0.99, rest),
                    NumberSequenceKeypoint.new(1, rest),
                })
                if alpha >= 1 then
                    break
                end
                RunService.RenderStepped:Wait()
            end
        end
        if frame and frame.Parent then
            frame:Destroy()
        end
        removePS99BottomEntry(state.Renders, entry)
        entry.Closed = true
    end

    local function processPS99BottomMessages(self, state)
        if state.Running then
            return
        end
        state.Running = true
        task.spawn(function()
            local lastCreated = 0
            while state.Host and state.Host.Parent do
                local now = os.clock()

                for index = #state.Renders, 1, -1 do
                    local entry = state.Renders[index]
                    if entry.CloseRequested or now - entry.Created > entry.Time then
                        task.spawn(fadePS99BottomMessage, entry, state)
                    end
                end

                if #state.Queue > 0 and #state.Renders < 3 and now - lastCreated >= 0.1 then
                    local entry = table.remove(state.Queue, 1)
                    if not entry.Cancelled then
                        lastCreated = now
                        state.LayoutOrder += 1
                        entry.Created = now
                        table.insert(state.Renders, entry)

                        local frame = entry.Frame
                        local scale = frame:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
                        scale.Parent = frame
                        scale.Scale = 1.35

                        local gradient = Instance.new("UIGradient")
                        gradient.Parent = frame

                        frame.AnchorPoint = Vector2.new(0.5, 0.5)
                        frame.LayoutOrder = state.LayoutOrder
                        frame.Parent = state.Host

                        TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                            Scale = 1,
                        }):Play()

                        if entry.Sound then
                            playPS99UISound(entry.Sound, entry.SoundVolume or 0.75, frame)
                        end
                        playPS99UISound("rbxassetid://14254721038", 0.6, frame)

                        task.delay(0.65, function()
                            local shadow = frame:FindFirstChild("Shadow")
                            if shadow and shadow:IsA("ImageLabel") then
                                TweenService:Create(shadow, TweenInfo.new(1.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
                                    ImageTransparency = 1,
                                }):Play()
                            end
                        end)
                    end
                end

                if #state.Queue == 0 and #state.Renders == 0 then
                    break
                end
                RunService.RenderStepped:Wait()
            end
            state.Running = false
            if #state.Queue > 0 and state.Host and state.Host.Parent then
                processPS99BottomMessages(self, state)
            end
        end)
    end

    function Library:BottomMessage(messageSettings, config)
        local settings
        if type(messageSettings) == "table" then
            settings = {}
            for key, value in pairs(messageSettings) do
                settings[key] = value
            end
        else
            settings = {Message = tostring(messageSettings)}
        end
        if type(config) == "table" then
            for key, value in pairs(config) do
                settings[key] = value
            end
        end

        local state = ensurePS99BottomMessageHost(self)
        local frame = buildPS99BottomMessageTemplate()
        local holder = frame:FindFirstChild("Frame")
        local textLabel = holder and holder:FindFirstChild("TextLabel")
        local text = tostring(settings.Message or settings.Content or settings.Text or "")
        local color = settings.Color

        if textLabel then
            if typeof(color) == "Color3" then
                textLabel.Text = ("<stroke color=\"#172b39\" joins=\"bevel\" thickness=\"3\" transparency=\"0\"><font color=\"#%s\">%s</font></stroke>"):format(color:ToHex(), text)
            else
                textLabel.Text = ("<stroke color=\"#172b39\" joins=\"bevel\" thickness=\"3\" transparency=\"0\"><font color=\"#ffffff\">%s</font></stroke>"):format(text)
            end
        end

        local entry = {
            Frame = frame,
            Time = math.max(0, tonumber(settings.Time or settings.Duration) or 4),
            Sound = settings.Sound,
            SoundVolume = settings.SoundVolume,
            Cancelled = false,
            Closed = false,
            CloseRequested = false,
        }

        local handle = {
            Frame = frame,
        }

        function handle:Close()
            if entry.Closed then
                return
            end
            if removePS99BottomEntry(state.Queue, entry) then
                entry.Cancelled = true
                entry.Closed = true
                if frame.Parent then
                    frame:Destroy()
                end
                return
            end
            entry.CloseRequested = true
        end
        handle.Destroy = handle.Close

        if #state.Queue + #state.Renders >= 20 then
            entry.Cancelled = true
            entry.Closed = true
            frame:Destroy()
            return handle
        end

        table.insert(state.Queue, entry)
        processPS99BottomMessages(self, state)
        return handle
    end

    Library.NotificationMessage = Library.BottomMessage
    Library.CreateBottomMessage = Library.BottomMessage

    local function applyGoalProperties(object, properties)
        for property, value in pairs(properties) do
            local success = pcall(function()
                object[property] = value
            end)
            if not success and object:IsA("UICorner") and string.find(property, "Radius", 1, true) then
                pcall(function()
                    object.CornerRadius = value
                end)
            end
        end
        return object
    end

    local buildPS99GoalScreenCompiled
    local buildPS99GoalScreenSource = [============[
return function(applyGoalProperties)
    return function()
        local objects = {}
        objects[1] = Instance.new("ScreenGui")
        applyGoalProperties(objects[1], {
            ["ClipToDeviceSafeArea"] = true,
            ["DisplayOrder"] = 0,
            ["SafeAreaCompatibility"] = Enum.SafeAreaCompatibility.FullscreenExtension,
            ["ScreenInsets"] = Enum.ScreenInsets.DeviceSafeInsets,
            ["Enabled"] = true,
            ["ResetOnSpawn"] = false,
            ["ZIndexBehavior"] = Enum.ZIndexBehavior.Global,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "Goal",
        })
        objects[2] = Instance.new("UIPadding")
        applyGoalProperties(objects[2], {
            ["PaddingBottom"] = UDim.new(0, 0),
            ["PaddingLeft"] = UDim.new(0, 0),
            ["PaddingRight"] = UDim.new(0, 0),
            ["PaddingTop"] = UDim.new(0, -12),
            ["Name"] = "UIPadding",
        })
        objects[2].Parent = objects[1]
        objects[3] = Instance.new("Frame")
        applyGoalProperties(objects[3], {
            ["Style"] = Enum.FrameStyle.Custom,
            ["Active"] = false,
            ["AnchorPoint"] = Vector2.new(0.5, 0),
            ["AutomaticSize"] = Enum.AutomaticSize.None,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 0,
            ["BorderColor3"] = Color3.new(0.105882362, 0.164705887, 0.207843155),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 0,
            ["Position"] = UDim2.new(0.5, 0, 0.0299999993, 15),
            ["Rotation"] = 0,
            ["Selectable"] = false,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(1, 0, 0.147499993, 0),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = true,
            ["ZIndex"] = 1,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "Frame",
        })
        objects[3].Parent = objects[1]
        objects[4] = Instance.new("ImageLabel")
        applyGoalProperties(objects[4], {
            ["Image"] = "rbxassetid://13581793331",
            ["ImageColor3"] = Color3.new(0.0784313753, 0.227450997, 0.262745112),
            ["ImageRectOffset"] = Vector2.new(0, 0),
            ["ImageRectSize"] = Vector2.new(0, 0),
            ["ImageTransparency"] = 0.949999988,
            ["ResampleMode"] = Enum.ResamplerMode.Default,
            ["ScaleType"] = Enum.ScaleType.Tile,
            ["SliceCenter"] = Rect.new(0, 0, 0, 0),
            ["SliceScale"] = 1,
            ["TileSize"] = UDim2.new(0, 171, 0, 135),
            ["Active"] = false,
            ["AnchorPoint"] = Vector2.new(0, 1),
            ["AutomaticSize"] = Enum.AutomaticSize.None,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 1,
            ["BorderColor3"] = Color3.new(0.105882362, 0.164705887, 0.207843155),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 0,
            ["Position"] = UDim2.new(0, 0, 1, 0),
            ["Rotation"] = 0,
            ["Selectable"] = false,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(1, 0, 1, 0),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = true,
            ["ZIndex"] = 2,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "background",
        })
        objects[4].Parent = objects[3]
        objects[5] = Instance.new("UIGradient")
        applyGoalProperties(objects[5], {
            ["Color"] = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1))}),
            ["Enabled"] = true,
            ["Offset"] = Vector2.new(0, 0),
            ["Rotation"] = -90,
            ["Scale"] = 1,
            ["TileMode"] = Enum.GradientTileMode.Clamp,
            ["Transparency"] = NumberSequence.new({NumberSequenceKeypoint.new(0, 0, 0), NumberSequenceKeypoint.new(0.310087, 0.39375, 0), NumberSequenceKeypoint.new(0.495641, 0.59375, 0), NumberSequenceKeypoint.new(0.738481, 0.825, 0), NumberSequenceKeypoint.new(1, 1, 0)}),
            ["Type"] = Enum.GradientType.Linear,
            ["Name"] = "UIGradient",
        })
        objects[5].Parent = objects[4]
        objects[6] = Instance.new("UICorner")
        applyGoalProperties(objects[6], {
            ["BottomLeftRadius"] = UDim.new(0.0350000001, 0),
            ["BottomRightRadius"] = UDim.new(0.0350000001, 0),
            ["TopLeftRadius"] = UDim.new(0.0350000001, 0),
            ["TopRightRadius"] = UDim.new(0.0350000001, 0),
            ["Name"] = "UICorner",
        })
        objects[6].Parent = objects[4]
        objects[7] = Instance.new("UIStroke")
        applyGoalProperties(objects[7], {
            ["BorderOffset"] = UDim.new(0, 0),
            ["Color"] = Color3.new(0.164705887, 0.168627456, 0.192156866),
            ["Enabled"] = true,
            ["Thickness"] = 4.83564806,
            ["Transparency"] = 0,
            ["ZIndex"] = 1,
            ["Name"] = "UIStroke",
        })
        objects[7].Parent = objects[3]
        objects[8] = Instance.new("UICorner")
        applyGoalProperties(objects[8], {
            ["BottomLeftRadius"] = UDim.new(0.0350000001, 0),
            ["BottomRightRadius"] = UDim.new(0.0350000001, 0),
            ["TopLeftRadius"] = UDim.new(0.0350000001, 0),
            ["TopRightRadius"] = UDim.new(0.0350000001, 0),
            ["Name"] = "UICorner",
        })
        objects[8].Parent = objects[3]
        objects[9] = Instance.new("Frame")
        applyGoalProperties(objects[9], {
            ["Style"] = Enum.FrameStyle.Custom,
            ["Active"] = false,
            ["AnchorPoint"] = Vector2.new(0, 1),
            ["AutomaticSize"] = Enum.AutomaticSize.None,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 1,
            ["BorderColor3"] = Color3.new(0, 0, 0),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 0,
            ["Position"] = UDim2.new(0, 0, 1.5, 0),
            ["Rotation"] = 0,
            ["Selectable"] = false,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(1, 0, 0.400000006, 0),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = true,
            ["ZIndex"] = 1,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "Buttons",
        })
        objects[9].Parent = objects[3]
        objects[10] = Instance.new("ImageButton")
        applyGoalProperties(objects[10], {
            ["Image"] = "rbxassetid://14423621163",
            ["ImageColor3"] = Color3.new(1, 1, 1),
            ["ImageRectOffset"] = Vector2.new(0, 0),
            ["ImageRectSize"] = Vector2.new(0, 0),
            ["ImageTransparency"] = 0,
            ["PressedImage"] = "rbxassetid://14423621349",
            ["ResampleMode"] = Enum.ResamplerMode.Default,
            ["ScaleType"] = Enum.ScaleType.Slice,
            ["SliceCenter"] = Rect.new(20, 20, 80, 80),
            ["SliceScale"] = 0.967129648,
            ["TileSize"] = UDim2.new(1, 0, 1, 0),
            ["AutoButtonColor"] = true,
            ["Modal"] = false,
            ["Selected"] = false,
            ["Style"] = Enum.FrameStyle.Custom,
            ["Active"] = true,
            ["AnchorPoint"] = Vector2.new(0, 0.5),
            ["AutomaticSize"] = Enum.AutomaticSize.None,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 1,
            ["BorderColor3"] = Color3.new(0.105882362, 0.164705887, 0.207843155),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 0,
            ["Position"] = UDim2.new(0, 0, 0.5, 0),
            ["Rotation"] = 0,
            ["Selectable"] = true,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(1, 0, 1.29999995, 0),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = false,
            ["ZIndex"] = 6,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "Teleport",
        })
        objects[10].Parent = objects[9]
        objects[11] = Instance.new("UIGradient")
        applyGoalProperties(objects[11], {
            ["Color"] = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.new(0.360784, 0.937255, 0)), ColorSequenceKeypoint.new(1, Color3.new(0.639216, 0.992157, 0.109804))}),
            ["Enabled"] = true,
            ["Offset"] = Vector2.new(0, 0),
            ["Rotation"] = -90,
            ["Scale"] = 1,
            ["TileMode"] = Enum.GradientTileMode.Clamp,
            ["Transparency"] = NumberSequence.new({NumberSequenceKeypoint.new(0, 0, 0), NumberSequenceKeypoint.new(1, 0, 0)}),
            ["Type"] = Enum.GradientType.Linear,
            ["Name"] = "GreenGradient",
        })
        objects[11].Parent = objects[10]
        objects[12] = Instance.new("TextLabel")
        applyGoalProperties(objects[12], {
            ["FontFace"] = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
            ["LineHeight"] = 1,
            ["MaxVisibleGraphemes"] = -1,
            ["RichText"] = false,
            ["Text"] = "Return to Area",
            ["TextColor3"] = Color3.new(1, 1, 1),
            ["TextDirection"] = Enum.TextDirection.Auto,
            ["TextScaled"] = true,
            ["TextSize"] = 18,
            ["TextStrokeColor3"] = Color3.new(0, 0, 0),
            ["TextStrokeTransparency"] = 1,
            ["TextTransparency"] = 0,
            ["TextTruncate"] = Enum.TextTruncate.None,
            ["TextWrapped"] = true,
            ["TextXAlignment"] = Enum.TextXAlignment.Center,
            ["TextYAlignment"] = Enum.TextYAlignment.Center,
            ["Active"] = false,
            ["AnchorPoint"] = Vector2.new(0.5, 0.5),
            ["AutomaticSize"] = Enum.AutomaticSize.None,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 1,
            ["BorderColor3"] = Color3.new(0.105882362, 0.164705887, 0.207843155),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 0,
            ["Position"] = UDim2.new(0.5, 0, 0.5, 0),
            ["Rotation"] = 0,
            ["Selectable"] = false,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(0.899999976, 0, 0.600000024, 0),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = true,
            ["ZIndex"] = 6,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "TextLabel",
        })
        objects[12].Parent = objects[10]
        objects[13] = Instance.new("UIStroke")
        applyGoalProperties(objects[13], {
            ["BorderOffset"] = UDim.new(0, 0),
            ["Color"] = Color3.new(0, 0, 0),
            ["Enabled"] = true,
            ["Thickness"] = 2.90138888,
            ["Transparency"] = 0,
            ["ZIndex"] = 1,
            ["Name"] = "UIStroke",
        })
        objects[13].Parent = objects[12]
        objects[14] = Instance.new("ImageLabel")
        applyGoalProperties(objects[14], {
            ["Image"] = "rbxasset://textures/ui/Controls/DefaultController/ButtonA@2x.png",
            ["ImageColor3"] = Color3.new(0, 0, 0),
            ["ImageRectOffset"] = Vector2.new(0, 0),
            ["ImageRectSize"] = Vector2.new(0, 0),
            ["ImageTransparency"] = 0,
            ["ResampleMode"] = Enum.ResamplerMode.Default,
            ["ScaleType"] = Enum.ScaleType.Fit,
            ["SliceCenter"] = Rect.new(0, 0, 0, 0),
            ["SliceScale"] = 1,
            ["TileSize"] = UDim2.new(1, 0, 1, 0),
            ["Active"] = false,
            ["AnchorPoint"] = Vector2.new(1, 0),
            ["AutomaticSize"] = Enum.AutomaticSize.None,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 1,
            ["BorderColor3"] = Color3.new(0, 0, 0),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 0,
            ["Position"] = UDim2.new(1, 0, 0, 0),
            ["Rotation"] = 0,
            ["Selectable"] = false,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(1, 0, 0.400000006, 0),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = false,
            ["ZIndex"] = 10,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "ConsoleButton",
        })
        objects[14].Parent = objects[10]
        objects[15] = Instance.new("UIAspectRatioConstraint")
        applyGoalProperties(objects[15], {
            ["AspectRatio"] = 1,
            ["AspectType"] = Enum.AspectType.FitWithinMaxSize,
            ["DominantAxis"] = Enum.DominantAxis.Width,
            ["Name"] = "UIAspectRatioConstraint",
        })
        objects[15].Parent = objects[14]
        objects[16] = Instance.new("UIScale")
        applyGoalProperties(objects[16], {
            ["Scale"] = 1,
            ["Name"] = "ButtonUIScale",
        })
        objects[16].Parent = objects[10]
        objects[17] = Instance.new("UIPadding")
        applyGoalProperties(objects[17], {
            ["PaddingBottom"] = UDim.new(0.0500000007, 0),
            ["PaddingLeft"] = UDim.new(0.0500000007, 0),
            ["PaddingRight"] = UDim.new(0.0500000007, 0),
            ["PaddingTop"] = UDim.new(0, 0),
            ["Name"] = "UIPadding",
        })
        objects[17].Parent = objects[9]
        objects[18] = Instance.new("UIListLayout")
        applyGoalProperties(objects[18], {
            ["Padding"] = UDim.new(0.0250000004, 0),
            ["Wraps"] = false,
            ["FillDirection"] = Enum.FillDirection.Horizontal,
            ["HorizontalAlignment"] = Enum.HorizontalAlignment.Center,
            ["SortOrder"] = Enum.SortOrder.LayoutOrder,
            ["VerticalAlignment"] = Enum.VerticalAlignment.Center,
            ["Name"] = "UIListLayout",
        })
        objects[18].Parent = objects[9]
        objects[19] = Instance.new("ImageLabel")
        applyGoalProperties(objects[19], {
            ["Image"] = "rbxassetid://14001321443",
            ["ImageColor3"] = Color3.new(0, 0, 0),
            ["ImageRectOffset"] = Vector2.new(0, 0),
            ["ImageRectSize"] = Vector2.new(0, 0),
            ["ImageTransparency"] = 0.75,
            ["ResampleMode"] = Enum.ResamplerMode.Default,
            ["ScaleType"] = Enum.ScaleType.Slice,
            ["SliceCenter"] = Rect.new(50, 50, 150, 150),
            ["SliceScale"] = 1,
            ["TileSize"] = UDim2.new(1, 0, 1, 0),
            ["Active"] = false,
            ["AnchorPoint"] = Vector2.new(0.5, 0.5),
            ["AutomaticSize"] = Enum.AutomaticSize.None,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 1,
            ["BorderColor3"] = Color3.new(0, 0, 0),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 0,
            ["Position"] = UDim2.new(0.5, 0, 0.5, 0),
            ["Rotation"] = 0,
            ["Selectable"] = false,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(1, 35, 1, 35),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = true,
            ["ZIndex"] = -2,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "shadow",
        })
        objects[19].Parent = objects[3]
        objects[20] = Instance.new("UIAspectRatioConstraint")
        applyGoalProperties(objects[20], {
            ["AspectRatio"] = 2.4000001,
            ["AspectType"] = Enum.AspectType.FitWithinMaxSize,
            ["DominantAxis"] = Enum.DominantAxis.Width,
            ["Name"] = "UIAspectRatioConstraint",
        })
        objects[20].Parent = objects[3]
        objects[21] = Instance.new("Frame")
        applyGoalProperties(objects[21], {
            ["Style"] = Enum.FrameStyle.Custom,
            ["Active"] = false,
            ["AnchorPoint"] = Vector2.new(0.5, 0.5),
            ["AutomaticSize"] = Enum.AutomaticSize.None,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 0,
            ["BorderColor3"] = Color3.new(0.105882362, 0.164705887, 0.207843155),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 0,
            ["Position"] = UDim2.new(1.00009656, 0, 0.0121528208, 0),
            ["Rotation"] = 0,
            ["Selectable"] = false,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(0.159044489, 0, 0.24160248, 0),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = false,
            ["ZIndex"] = 13,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "Notification",
        })
        objects[21].Parent = objects[3]
        objects[22] = Instance.new("UICorner")
        applyGoalProperties(objects[22], {
            ["BottomLeftRadius"] = UDim.new(1, 0),
            ["BottomRightRadius"] = UDim.new(1, 0),
            ["TopLeftRadius"] = UDim.new(1, 0),
            ["TopRightRadius"] = UDim.new(1, 0),
            ["Name"] = "UICorner",
        })
        objects[22].Parent = objects[21]
        objects[23] = Instance.new("TextLabel")
        applyGoalProperties(objects[23], {
            ["FontFace"] = Font.new("rbxassetid://11702779409", Enum.FontWeight.ExtraBold, Enum.FontStyle.Normal),
            ["LineHeight"] = 0.899999976,
            ["MaxVisibleGraphemes"] = -1,
            ["RichText"] = false,
            ["Text"] = "99",
            ["TextColor3"] = Color3.new(1, 1, 1),
            ["TextDirection"] = Enum.TextDirection.Auto,
            ["TextScaled"] = true,
            ["TextSize"] = 18,
            ["TextStrokeColor3"] = Color3.new(0, 0, 0),
            ["TextStrokeTransparency"] = 1,
            ["TextTransparency"] = 0,
            ["TextTruncate"] = Enum.TextTruncate.None,
            ["TextWrapped"] = true,
            ["TextXAlignment"] = Enum.TextXAlignment.Center,
            ["TextYAlignment"] = Enum.TextYAlignment.Center,
            ["Active"] = false,
            ["AnchorPoint"] = Vector2.new(0.5, 0.5),
            ["AutomaticSize"] = Enum.AutomaticSize.None,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 1,
            ["BorderColor3"] = Color3.new(0.105882362, 0.164705887, 0.207843155),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 0,
            ["Position"] = UDim2.new(0.5, 0, 0.5, 0),
            ["Rotation"] = 0,
            ["Selectable"] = false,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(0.800000012, 0, 0.699999988, 0),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = true,
            ["ZIndex"] = 14,
            ["AutoLocalize"] = false,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "Count",
        })
        objects[23].Parent = objects[21]
        objects[24] = Instance.new("UIStroke")
        applyGoalProperties(objects[24], {
            ["BorderOffset"] = UDim.new(0, 0),
            ["Color"] = Color3.new(0, 0, 0),
            ["Enabled"] = true,
            ["Thickness"] = 2.41782403,
            ["Transparency"] = 0,
            ["ZIndex"] = 1,
            ["Name"] = "UIStroke",
        })
        objects[24].Parent = objects[23]
        objects[25] = Instance.new("UIStroke")
        applyGoalProperties(objects[25], {
            ["BorderOffset"] = UDim.new(0, 0),
            ["Color"] = Color3.new(0.301960796, 0, 0),
            ["Enabled"] = true,
            ["Thickness"] = 3.38495374,
            ["Transparency"] = 0,
            ["ZIndex"] = 1,
            ["Name"] = "UIStroke",
        })
        objects[25].Parent = objects[21]
        objects[26] = Instance.new("UIAspectRatioConstraint")
        applyGoalProperties(objects[26], {
            ["AspectRatio"] = 1,
            ["AspectType"] = Enum.AspectType.FitWithinMaxSize,
            ["DominantAxis"] = Enum.DominantAxis.Width,
            ["Name"] = "UIAspectRatioConstraint",
        })
        objects[26].Parent = objects[21]
        objects[27] = Instance.new("UIGradient")
        applyGoalProperties(objects[27], {
            ["Color"] = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.new(1, 0.00784314, 0.239216)), ColorSequenceKeypoint.new(1, Color3.new(1, 0.152941, 0.490196))}),
            ["Enabled"] = true,
            ["Offset"] = Vector2.new(0, 0),
            ["Rotation"] = -90,
            ["Scale"] = 1,
            ["TileMode"] = Enum.GradientTileMode.Clamp,
            ["Transparency"] = NumberSequence.new({NumberSequenceKeypoint.new(0, 0, 0), NumberSequenceKeypoint.new(1, 0, 0)}),
            ["Type"] = Enum.GradientType.Linear,
            ["Name"] = "red gradient",
        })
        objects[27].Parent = objects[21]
        objects[28] = Instance.new("Frame")
        applyGoalProperties(objects[28], {
            ["Style"] = Enum.FrameStyle.Custom,
            ["Active"] = false,
            ["AnchorPoint"] = Vector2.new(0.5, 1),
            ["AutomaticSize"] = Enum.AutomaticSize.None,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 1,
            ["BorderColor3"] = Color3.new(0, 0, 0),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 0,
            ["Position"] = UDim2.new(0.5, 0, 1, 0),
            ["Rotation"] = 0,
            ["Selectable"] = false,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(1, 0, 0.400000006, 0),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = true,
            ["ZIndex"] = 1,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "Progress",
        })
        objects[28].Parent = objects[3]
        objects[29] = Instance.new("UIListLayout")
        applyGoalProperties(objects[29], {
            ["Padding"] = UDim.new(0, 0),
            ["Wraps"] = false,
            ["FillDirection"] = Enum.FillDirection.Vertical,
            ["HorizontalAlignment"] = Enum.HorizontalAlignment.Center,
            ["SortOrder"] = Enum.SortOrder.LayoutOrder,
            ["VerticalAlignment"] = Enum.VerticalAlignment.Center,
            ["Name"] = "UIListLayout",
        })
        objects[29].Parent = objects[28]
        objects[30] = Instance.new("Frame")
        applyGoalProperties(objects[30], {
            ["Style"] = Enum.FrameStyle.Custom,
            ["Active"] = false,
            ["AnchorPoint"] = Vector2.new(0.5, 0),
            ["AutomaticSize"] = Enum.AutomaticSize.None,
            ["BackgroundColor3"] = Color3.new(0, 0, 0),
            ["BackgroundTransparency"] = 1,
            ["BorderColor3"] = Color3.new(0.105882362, 0.164705887, 0.207843155),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 2,
            ["Position"] = UDim2.new(0.5, 0, 0, 0),
            ["Rotation"] = 0,
            ["Selectable"] = false,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(1, 0, 0.150000006, 0),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = true,
            ["ZIndex"] = 10,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "div",
        })
        objects[30].Parent = objects[28]
        objects[31] = Instance.new("TextLabel")
        applyGoalProperties(objects[31], {
            ["FontFace"] = Font.new("rbxassetid://11702779409", Enum.FontWeight.ExtraBold, Enum.FontStyle.Normal),
            ["LineHeight"] = 0.889999986,
            ["MaxVisibleGraphemes"] = -1,
            ["RichText"] = false,
            ["Text"] = "0/1",
            ["TextColor3"] = Color3.new(0.43921569, 0.929411769, 0.988235295),
            ["TextDirection"] = Enum.TextDirection.Auto,
            ["TextScaled"] = true,
            ["TextSize"] = 18,
            ["TextStrokeColor3"] = Color3.new(0.0745098069, 0.188235313, 0.223529428),
            ["TextStrokeTransparency"] = 1,
            ["TextTransparency"] = 0,
            ["TextTruncate"] = Enum.TextTruncate.None,
            ["TextWrapped"] = true,
            ["TextXAlignment"] = Enum.TextXAlignment.Center,
            ["TextYAlignment"] = Enum.TextYAlignment.Center,
            ["Active"] = false,
            ["AnchorPoint"] = Vector2.new(0.5, 1),
            ["AutomaticSize"] = Enum.AutomaticSize.None,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 1,
            ["BorderColor3"] = Color3.new(0.105882362, 0.164705887, 0.207843155),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 3,
            ["Position"] = UDim2.new(0.5, 0, 0.999999881, 0),
            ["Rotation"] = 0,
            ["Selectable"] = false,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(1, 0, 0.400000006, 0),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = true,
            ["ZIndex"] = 2,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "Amount",
        })
        objects[31].Parent = objects[28]
        objects[32] = Instance.new("UIStroke")
        applyGoalProperties(objects[32], {
            ["BorderOffset"] = UDim.new(0, 0),
            ["Color"] = Color3.new(0, 0, 0),
            ["Enabled"] = true,
            ["Thickness"] = 2.41782403,
            ["Transparency"] = 0,
            ["ZIndex"] = 1,
            ["Name"] = "UIStroke",
        })
        objects[32].Parent = objects[31]
        objects[33] = Instance.new("Frame")
        applyGoalProperties(objects[33], {
            ["Style"] = Enum.FrameStyle.Custom,
            ["Active"] = false,
            ["AnchorPoint"] = Vector2.new(0.5, 0),
            ["AutomaticSize"] = Enum.AutomaticSize.None,
            ["BackgroundColor3"] = Color3.new(0, 0, 0),
            ["BackgroundTransparency"] = 0.5,
            ["BorderColor3"] = Color3.new(0.105882362, 0.164705887, 0.207843155),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 0,
            ["Position"] = UDim2.new(0.5, 0, 0.219999999, 0),
            ["Rotation"] = 0,
            ["Selectable"] = false,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(0.800000012, 0, 0.200000003, 0),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = true,
            ["ZIndex"] = 2,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "ProgressBar",
        })
        objects[33].Parent = objects[28]
        objects[34] = Instance.new("UICorner")
        applyGoalProperties(objects[34], {
            ["BottomLeftRadius"] = UDim.new(1, 0),
            ["BottomRightRadius"] = UDim.new(1, 0),
            ["TopLeftRadius"] = UDim.new(1, 0),
            ["TopRightRadius"] = UDim.new(1, 0),
            ["Name"] = "UICorner",
        })
        objects[34].Parent = objects[33]
        objects[35] = Instance.new("Frame")
        applyGoalProperties(objects[35], {
            ["Style"] = Enum.FrameStyle.Custom,
            ["Active"] = false,
            ["AnchorPoint"] = Vector2.new(0, 0.5),
            ["AutomaticSize"] = Enum.AutomaticSize.None,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 0,
            ["BorderColor3"] = Color3.new(0.105882362, 0.164705887, 0.207843155),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 0,
            ["Position"] = UDim2.new(0, 0, 0.5, 0),
            ["Rotation"] = 0,
            ["Selectable"] = false,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(0, 1, 1.10000002, 0),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = true,
            ["ZIndex"] = 3,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "Bar",
        })
        objects[35].Parent = objects[33]
        objects[36] = Instance.new("UIStroke")
        applyGoalProperties(objects[36], {
            ["BorderOffset"] = UDim.new(0, 0),
            ["Color"] = Color3.new(0.0666666701, 0.192156881, 0.227450997),
            ["Enabled"] = true,
            ["Thickness"] = 1.9342593,
            ["Transparency"] = 0,
            ["ZIndex"] = 1,
            ["Name"] = "UIStroke",
        })
        objects[36].Parent = objects[35]
        objects[37] = Instance.new("UIGradient")
        applyGoalProperties(objects[37], {
            ["Color"] = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.new(0.341176, 0.847059, 1)), ColorSequenceKeypoint.new(1, Color3.new(0.529412, 1, 0.976471))}),
            ["Enabled"] = true,
            ["Offset"] = Vector2.new(0, 0),
            ["Rotation"] = -90,
            ["Scale"] = 1,
            ["TileMode"] = Enum.GradientTileMode.Clamp,
            ["Transparency"] = NumberSequence.new({NumberSequenceKeypoint.new(0, 0, 0), NumberSequenceKeypoint.new(1, 0, 0)}),
            ["Type"] = Enum.GradientType.Linear,
            ["Name"] = "UIGradient",
        })
        objects[37].Parent = objects[35]
        objects[38] = Instance.new("UICorner")
        applyGoalProperties(objects[38], {
            ["BottomLeftRadius"] = UDim.new(1, 0),
            ["BottomRightRadius"] = UDim.new(1, 0),
            ["TopLeftRadius"] = UDim.new(1, 0),
            ["TopRightRadius"] = UDim.new(1, 0),
            ["Name"] = "UICorner",
        })
        objects[38].Parent = objects[35]
        objects[39] = Instance.new("Frame")
        applyGoalProperties(objects[39], {
            ["Style"] = Enum.FrameStyle.Custom,
            ["Active"] = false,
            ["AnchorPoint"] = Vector2.new(0.5, 0),
            ["AutomaticSize"] = Enum.AutomaticSize.None,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 1,
            ["BorderColor3"] = Color3.new(0, 0, 0),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 0,
            ["Position"] = UDim2.new(0.5, 0, 0, 0),
            ["Rotation"] = 0,
            ["Selectable"] = false,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(1, 0, 0.600000024, 0),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = true,
            ["ZIndex"] = 1,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "Message",
        })
        objects[39].Parent = objects[3]
        objects[40] = Instance.new("Frame")
        applyGoalProperties(objects[40], {
            ["Style"] = Enum.FrameStyle.Custom,
            ["Active"] = false,
            ["AnchorPoint"] = Vector2.new(1, 0.5),
            ["AutomaticSize"] = Enum.AutomaticSize.None,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 1,
            ["BorderColor3"] = Color3.new(0, 0, 0),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 2,
            ["Position"] = UDim2.new(1, 0, 0.5, 0),
            ["Rotation"] = 0,
            ["Selectable"] = false,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(0.699999988, 0, 1, 0),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = true,
            ["ZIndex"] = 1,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "Text",
        })
        objects[40].Parent = objects[39]
        objects[41] = Instance.new("TextLabel")
        applyGoalProperties(objects[41], {
            ["FontFace"] = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
            ["LineHeight"] = 1,
            ["MaxVisibleGraphemes"] = -1,
            ["RichText"] = false,
            ["Text"] = "Garden Quest!",
            ["TextColor3"] = Color3.new(0.43921569, 0.929411769, 0.988235295),
            ["TextDirection"] = Enum.TextDirection.Auto,
            ["TextScaled"] = true,
            ["TextSize"] = 14,
            ["TextStrokeColor3"] = Color3.new(0.0666666701, 0.227450997, 0.282352954),
            ["TextStrokeTransparency"] = 1,
            ["TextTransparency"] = 0,
            ["TextWrapped"] = true,
            ["TextXAlignment"] = Enum.TextXAlignment.Center,
            ["TextYAlignment"] = Enum.TextYAlignment.Center,
            ["Active"] = false,
            ["AnchorPoint"] = Vector2.new(0.5, 0),
            ["AutomaticSize"] = Enum.AutomaticSize.None,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 1,
            ["BorderColor3"] = Color3.new(0.105882362, 0.164705887, 0.207843155),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 0,
            ["Position"] = UDim2.new(0.5, 0, 0.164999992, 0),
            ["Rotation"] = 0,
            ["Selectable"] = false,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(1, 0, 0.5, 0),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = true,
            ["ZIndex"] = 7,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "Title",
        })
        objects[41].Parent = objects[40]
        objects[42] = Instance.new("UIStroke")
        applyGoalProperties(objects[42], {
            ["BorderOffset"] = UDim.new(0, 0),
            ["Color"] = Color3.new(0, 0, 0),
            ["Enabled"] = true,
            ["Thickness"] = 2.90138888,
            ["Transparency"] = 0,
            ["ZIndex"] = 1,
            ["Name"] = "UIStroke",
        })
        objects[42].Parent = objects[41]
        objects[43] = Instance.new("TextLabel")
        applyGoalProperties(objects[43], {
            ["FontFace"] = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
            ["LineHeight"] = 1,
            ["MaxVisibleGraphemes"] = -1,
            ["RichText"] = false,
            ["Text"] = "Place your unit in the lane!",
            ["TextColor3"] = Color3.new(0.164705887, 0.168627456, 0.192156866),
            ["TextDirection"] = Enum.TextDirection.Auto,
            ["TextScaled"] = true,
            ["TextSize"] = 14,
            ["TextStrokeColor3"] = Color3.new(0.0666666701, 0.227450997, 0.282352954),
            ["TextStrokeTransparency"] = 1,
            ["TextTransparency"] = 0,
            ["TextWrapped"] = true,
            ["TextXAlignment"] = Enum.TextXAlignment.Center,
            ["TextYAlignment"] = Enum.TextYAlignment.Center,
            ["Active"] = false,
            ["AnchorPoint"] = Vector2.new(0.5, 0),
            ["AutomaticSize"] = Enum.AutomaticSize.None,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 1,
            ["BorderColor3"] = Color3.new(0.105882362, 0.164705887, 0.207843155),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 0,
            ["Position"] = UDim2.new(0.5, 0, 0.164999992, 0),
            ["Rotation"] = 0,
            ["Selectable"] = false,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(1, 0, 0.5, 0),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = true,
            ["ZIndex"] = 7,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "Desc",
        })
        objects[43].Parent = objects[40]
        objects[44] = Instance.new("UIListLayout")
        applyGoalProperties(objects[44], {
            ["Padding"] = UDim.new(0, 0),
            ["Wraps"] = false,
            ["FillDirection"] = Enum.FillDirection.Vertical,
            ["HorizontalAlignment"] = Enum.HorizontalAlignment.Center,
            ["SortOrder"] = Enum.SortOrder.LayoutOrder,
            ["VerticalAlignment"] = Enum.VerticalAlignment.Center,
            ["Name"] = "UIListLayout",
        })
        objects[44].Parent = objects[40]
        objects[45] = Instance.new("UIPadding")
        applyGoalProperties(objects[45], {
            ["PaddingBottom"] = UDim.new(0.100000001, 0),
            ["PaddingLeft"] = UDim.new(0.0250000004, 0),
            ["PaddingRight"] = UDim.new(0.0250000004, 0),
            ["PaddingTop"] = UDim.new(0.100000001, 0),
            ["Name"] = "UIPadding",
        })
        objects[45].Parent = objects[40]
        objects[46] = Instance.new("ImageLabel")
        applyGoalProperties(objects[46], {
            ["Image"] = "rbxassetid://17638331997",
            ["ImageColor3"] = Color3.new(1, 1, 1),
            ["ImageRectOffset"] = Vector2.new(0, 0),
            ["ImageRectSize"] = Vector2.new(0, 0),
            ["ImageTransparency"] = 0,
            ["ResampleMode"] = Enum.ResamplerMode.Default,
            ["ScaleType"] = Enum.ScaleType.Fit,
            ["SliceCenter"] = Rect.new(0, 0, 0, 0),
            ["SliceScale"] = 1,
            ["TileSize"] = UDim2.new(1, 0, 1, 0),
            ["Active"] = false,
            ["AnchorPoint"] = Vector2.new(0, 0.5),
            ["AutomaticSize"] = Enum.AutomaticSize.None,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 1,
            ["BorderColor3"] = Color3.new(0, 0, 0),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 1,
            ["Position"] = UDim2.new(0, 0, 0.5, 0),
            ["Rotation"] = 0,
            ["Selectable"] = false,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(1, 0, 1, 0),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = true,
            ["ZIndex"] = 5,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "SideIcon",
        })
        objects[46].Parent = objects[39]
        objects[47] = Instance.new("UIAspectRatioConstraint")
        applyGoalProperties(objects[47], {
            ["AspectRatio"] = 1,
            ["AspectType"] = Enum.AspectType.FitWithinMaxSize,
            ["DominantAxis"] = Enum.DominantAxis.Width,
            ["Name"] = "UIAspectRatioConstraint",
        })
        objects[47].Parent = objects[46]
        objects[48] = Instance.new("UIListLayout")
        applyGoalProperties(objects[48], {
            ["Padding"] = UDim.new(0, 0),
            ["Wraps"] = false,
            ["FillDirection"] = Enum.FillDirection.Horizontal,
            ["HorizontalAlignment"] = Enum.HorizontalAlignment.Center,
            ["SortOrder"] = Enum.SortOrder.LayoutOrder,
            ["VerticalAlignment"] = Enum.VerticalAlignment.Center,
            ["Name"] = "UIListLayout",
        })
        objects[48].Parent = objects[39]
        objects[49] = Instance.new("UIPadding")
        applyGoalProperties(objects[49], {
            ["PaddingBottom"] = UDim.new(0, 0),
            ["PaddingLeft"] = UDim.new(0, 0),
            ["PaddingRight"] = UDim.new(0, 0),
            ["PaddingTop"] = UDim.new(0.0299999993, 0),
            ["Name"] = "UIPadding",
        })
        objects[49].Parent = objects[39]
        objects[50] = Instance.new("Frame")
        applyGoalProperties(objects[50], {
            ["Style"] = Enum.FrameStyle.Custom,
            ["Active"] = false,
            ["AnchorPoint"] = Vector2.new(0, 0),
            ["AutomaticSize"] = Enum.AutomaticSize.None,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 0,
            ["BorderColor3"] = Color3.new(0, 0, 0),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 0,
            ["Position"] = UDim2.new(0.150000006, 0, 1.10000002, 0),
            ["Rotation"] = 0,
            ["Selectable"] = false,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(0.75, 0, 0.5, 0),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = false,
            ["ZIndex"] = 1,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "BonusReward",
        })
        objects[50].Parent = objects[3]
        objects[51] = Instance.new("ImageLabel")
        applyGoalProperties(objects[51], {
            ["Image"] = "rbxassetid://13581793331",
            ["ImageColor3"] = Color3.new(0.0784313753, 0.227450997, 0.262745112),
            ["ImageRectOffset"] = Vector2.new(0, 0),
            ["ImageRectSize"] = Vector2.new(0, 0),
            ["ImageTransparency"] = 0.949999988,
            ["ResampleMode"] = Enum.ResamplerMode.Default,
            ["ScaleType"] = Enum.ScaleType.Tile,
            ["SliceCenter"] = Rect.new(0, 0, 0, 0),
            ["SliceScale"] = 1,
            ["TileSize"] = UDim2.new(0, 171, 0, 135),
            ["Active"] = false,
            ["AnchorPoint"] = Vector2.new(0, 1),
            ["AutomaticSize"] = Enum.AutomaticSize.None,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 1,
            ["BorderColor3"] = Color3.new(0.105882362, 0.164705887, 0.207843155),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 0,
            ["Position"] = UDim2.new(0, 0, 1, 0),
            ["Rotation"] = 0,
            ["Selectable"] = false,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(1, 0, 1, 0),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = true,
            ["ZIndex"] = 2,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "background",
        })
        objects[51].Parent = objects[50]
        objects[52] = Instance.new("UIGradient")
        applyGoalProperties(objects[52], {
            ["Color"] = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1))}),
            ["Enabled"] = true,
            ["Offset"] = Vector2.new(0, 0),
            ["Rotation"] = -90,
            ["Scale"] = 1,
            ["TileMode"] = Enum.GradientTileMode.Clamp,
            ["Transparency"] = NumberSequence.new({NumberSequenceKeypoint.new(0, 0, 0), NumberSequenceKeypoint.new(0.310087, 0.39375, 0), NumberSequenceKeypoint.new(0.495641, 0.59375, 0), NumberSequenceKeypoint.new(0.738481, 0.825, 0), NumberSequenceKeypoint.new(1, 1, 0)}),
            ["Type"] = Enum.GradientType.Linear,
            ["Name"] = "UIGradient",
        })
        objects[52].Parent = objects[51]
        objects[53] = Instance.new("UICorner")
        applyGoalProperties(objects[53], {
            ["BottomLeftRadius"] = UDim.new(0.0350000001, 0),
            ["BottomRightRadius"] = UDim.new(0.0350000001, 0),
            ["TopLeftRadius"] = UDim.new(0.0350000001, 0),
            ["TopRightRadius"] = UDim.new(0.0350000001, 0),
            ["Name"] = "UICorner",
        })
        objects[53].Parent = objects[51]
        objects[54] = Instance.new("ImageLabel")
        applyGoalProperties(objects[54], {
            ["Image"] = "rbxassetid://14001321443",
            ["ImageColor3"] = Color3.new(0, 0, 0),
            ["ImageRectOffset"] = Vector2.new(0, 0),
            ["ImageRectSize"] = Vector2.new(0, 0),
            ["ImageTransparency"] = 0.75,
            ["ResampleMode"] = Enum.ResamplerMode.Default,
            ["ScaleType"] = Enum.ScaleType.Slice,
            ["SliceCenter"] = Rect.new(50, 50, 150, 150),
            ["SliceScale"] = 1,
            ["TileSize"] = UDim2.new(1, 0, 1, 0),
            ["Active"] = false,
            ["AnchorPoint"] = Vector2.new(0.5, 0.5),
            ["AutomaticSize"] = Enum.AutomaticSize.None,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 1,
            ["BorderColor3"] = Color3.new(0, 0, 0),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 0,
            ["Position"] = UDim2.new(0.5, 0, 0.5, 0),
            ["Rotation"] = 0,
            ["Selectable"] = false,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(1, 35, 1, 35),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = true,
            ["ZIndex"] = -2,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "shadow",
        })
        objects[54].Parent = objects[50]
        objects[55] = Instance.new("UIStroke")
        applyGoalProperties(objects[55], {
            ["BorderOffset"] = UDim.new(0, 0),
            ["Color"] = Color3.new(0.164705887, 0.168627456, 0.192156866),
            ["Enabled"] = true,
            ["Thickness"] = 4.83564806,
            ["Transparency"] = 0,
            ["ZIndex"] = 1,
            ["Name"] = "UIStroke",
        })
        objects[55].Parent = objects[50]
        objects[56] = Instance.new("UICorner")
        applyGoalProperties(objects[56], {
            ["BottomLeftRadius"] = UDim.new(0.0350000001, 0),
            ["BottomRightRadius"] = UDim.new(0.0350000001, 0),
            ["TopLeftRadius"] = UDim.new(0.0350000001, 0),
            ["TopRightRadius"] = UDim.new(0.0350000001, 0),
            ["Name"] = "UICorner",
        })
        objects[56].Parent = objects[50]
        objects[57] = Instance.new("ImageLabel")
        applyGoalProperties(objects[57], {
            ["Image"] = "rbxassetid://15048277894",
            ["ImageColor3"] = Color3.new(1, 1, 1),
            ["ImageRectOffset"] = Vector2.new(0, 0),
            ["ImageRectSize"] = Vector2.new(0, 0),
            ["ImageTransparency"] = 0,
            ["ResampleMode"] = Enum.ResamplerMode.Default,
            ["ScaleType"] = Enum.ScaleType.Fit,
            ["SliceCenter"] = Rect.new(0, 0, 0, 0),
            ["SliceScale"] = 1,
            ["TileSize"] = UDim2.new(1, 0, 1, 0),
            ["Active"] = false,
            ["AnchorPoint"] = Vector2.new(0, 0.5),
            ["AutomaticSize"] = Enum.AutomaticSize.None,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 1,
            ["BorderColor3"] = Color3.new(0, 0, 0),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 1,
            ["Position"] = UDim2.new(0.725000024, 0, 0.5, 0),
            ["Rotation"] = 0,
            ["Selectable"] = false,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(0.850000024, 0, 0.850000024, 0),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = true,
            ["ZIndex"] = 5,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "RewardImage",
        })
        objects[57].Parent = objects[50]
        objects[58] = Instance.new("UIAspectRatioConstraint")
        applyGoalProperties(objects[58], {
            ["AspectRatio"] = 1,
            ["AspectType"] = Enum.AspectType.FitWithinMaxSize,
            ["DominantAxis"] = Enum.DominantAxis.Width,
            ["Name"] = "UIAspectRatioConstraint",
        })
        objects[58].Parent = objects[57]
        objects[59] = Instance.new("TextLabel")
        applyGoalProperties(objects[59], {
            ["FontFace"] = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
            ["LineHeight"] = 1,
            ["MaxVisibleGraphemes"] = -1,
            ["RichText"] = false,
            ["Text"] = "Bonus Item:",
            ["TextColor3"] = Color3.new(0.988235354, 0.941176534, 0.435294151),
            ["TextDirection"] = Enum.TextDirection.Auto,
            ["TextScaled"] = true,
            ["TextSize"] = 14,
            ["TextStrokeColor3"] = Color3.new(0.0666666701, 0.227450997, 0.282352954),
            ["TextStrokeTransparency"] = 1,
            ["TextTransparency"] = 0,
            ["TextWrapped"] = true,
            ["TextXAlignment"] = Enum.TextXAlignment.Center,
            ["TextYAlignment"] = Enum.TextYAlignment.Center,
            ["Active"] = false,
            ["AnchorPoint"] = Vector2.new(0.5, 0),
            ["AutomaticSize"] = Enum.AutomaticSize.None,
            ["BackgroundColor3"] = Color3.new(1, 1, 1),
            ["BackgroundTransparency"] = 1,
            ["BorderColor3"] = Color3.new(0.105882362, 0.164705887, 0.207843155),
            ["BorderMode"] = Enum.BorderMode.Outline,
            ["BorderSizePixel"] = 0,
            ["ClipsDescendants"] = false,
            ["Draggable"] = false,
            ["InputSink"] = Enum.InputSink.None,
            ["Interactable"] = true,
            ["LayoutOrder"] = 0,
            ["Position"] = UDim2.new(0.379999995, 0, 0.25, 0),
            ["Rotation"] = 0,
            ["Selectable"] = false,
            ["SelectionOrder"] = 0,
            ["Size"] = UDim2.new(1, 0, 0.5, 0),
            ["SizeConstraint"] = Enum.SizeConstraint.RelativeXY,
            ["Visible"] = true,
            ["ZIndex"] = 7,
            ["AutoLocalize"] = true,
            ["SelectionBehaviorDown"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorLeft"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorRight"] = Enum.SelectionBehavior.Escape,
            ["SelectionBehaviorUp"] = Enum.SelectionBehavior.Escape,
            ["SelectionGroup"] = false,
            ["Name"] = "Title",
        })
        objects[59].Parent = objects[50]
        objects[60] = Instance.new("UIStroke")
        applyGoalProperties(objects[60], {
            ["BorderOffset"] = UDim.new(0, 0),
            ["Color"] = Color3.new(0, 0, 0),
            ["Enabled"] = true,
            ["Thickness"] = 2.90138888,
            ["Transparency"] = 0,
            ["ZIndex"] = 1,
            ["Name"] = "UIStroke",
        })
        objects[60].Parent = objects[59]
        return objects[1]
    end
end
]============]

    local function buildPS99GoalScreen()
        if not buildPS99GoalScreenCompiled then
            local compiler = loadstring or load
            assert(type(compiler) == "function", "PlantVsCoinsUI: loadstring is required for the embedded goal UI fallback")
            local chunk, compileError = compiler(buildPS99GoalScreenSource)
            assert(chunk, compileError)
            buildPS99GoalScreenCompiled = chunk()(applyGoalProperties)
            buildPS99GoalScreenSource = nil
        end
        return buildPS99GoalScreenCompiled()
    end


    local function playPS99GoalShimmer(frame)
        if not frame or not frame.Parent then
            return
        end

        local shimmer = Instance.new("Frame")
        applyGoalProperties(shimmer, {
            Name = "Shimmer",
            Active = false,
            AnchorPoint = Vector2.new(0.5, 1),
            AutomaticSize = Enum.AutomaticSize.None,
            BackgroundColor3 = Color3.new(1, 1, 1),
            BackgroundTransparency = 0.5,
            BorderColor3 = Color3.new(0, 0, 0),
            BorderMode = Enum.BorderMode.Outline,
            BorderSizePixel = 0,
            ClipsDescendants = true,
            Interactable = true,
            Position = UDim2.new(0.5, 0, 0.99, 0),
            Rotation = 0,
            Selectable = false,
            Size = UDim2.new(0.96, 0, 0.93, 0),
            Visible = true,
            ZIndex = 11,
        })
        shimmer.Parent = frame

        local corner = Instance.new("UICorner")
        applyGoalProperties(corner, {
            BottomLeftRadius = UDim.new(0.18, 0),
            BottomRightRadius = UDim.new(0.18, 0),
            TopLeftRadius = UDim.new(0.18, 0),
            TopRightRadius = UDim.new(0.18, 0),
            CornerRadius = UDim.new(0.18, 0),
        })
        corner.Parent = shimmer

        local gradient = Instance.new("UIGradient")
        gradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
            ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)),
        })
        gradient.Enabled = true
        gradient.Offset = Vector2.new(-1, 0)
        gradient.Rotation = 25
        gradient.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1, 0),
            NumberSequenceKeypoint.new(0.375312, 0.18125, 0),
            NumberSequenceKeypoint.new(0.5, 0, 0),
            NumberSequenceKeypoint.new(0.639651, 0.1875, 0),
            NumberSequenceKeypoint.new(1, 1, 0),
        })
        gradient.Parent = shimmer

        local tween = TweenService:Create(
            gradient,
            TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
            {Offset = Vector2.new(1, 0)}
        )
        tween:Play()
        tween.Completed:Connect(function()
            if shimmer.Parent then
                shimmer:Destroy()
            end
        end)
    end

    local function playPS99GoalWiggle(frame)
        task.spawn(function()
            local elapsed = 0
            while elapsed < 1 and frame and frame.Parent do
                local delta = RunService.RenderStepped:Wait()
                elapsed += delta
                local alpha = math.clamp(elapsed, 0, 1)
                local rotation = 15 * math.sin(math.pi * 2 * (1 + alpha) * 6)
                frame.Rotation = rotation / (4 ^ (5 * alpha))
            end
            if frame and frame.Parent then
                frame.Rotation = 0
            end
        end)
    end

    local function playPS99GoalCompleteSound()
        local sound = Instance.new("Sound")
        sound.Name = "GoalComplete"
        sound.SoundId = "rbxassetid://17600460910"
        sound.Volume = 1
        sound.PlaybackSpeed = 1.1
        sound.Parent = SoundService
        sound.Ended:Connect(function()
            sound:Destroy()
        end)
        sound:Play()
        task.delay(8, function()
            if sound.Parent then
                sound:Destroy()
            end
        end)
    end

    local function getGoalParent(window)
        local parent = window.Screen and window.Screen.Parent
        if parent then
            return parent
        end
        local player = Players.LocalPlayer
        if player then
            return player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui")
        end
        return CoreGui
    end

    function Library:CreateGoal(goalSettings, legacyDescription, legacyIcon, legacyCurrent, legacyMaximum, legacyCallback)
        local settings
        if type(goalSettings) == "table" then
            settings = goalSettings
        else
            settings = {
                Title = tostring(goalSettings or "Goal"),
                Description = legacyDescription,
                Icon = legacyIcon,
                CurrentValue = legacyCurrent,
                MaxValue = legacyMaximum,
                ShowButton = type(legacyCallback) == "function",
                ButtonCallback = legacyCallback,
            }
        end

        if self.ActiveGoal and self.ActiveGoal.Destroy then
            self.ActiveGoal:Destroy()
        end

        local screen = buildPS99GoalScreen()
        screen.Enabled = false
        screen.DisplayOrder = tonumber(settings.DisplayOrder) or 0
        screen.Parent = getGoalParent(self)

        local frame = screen:WaitForChild("Frame")
        local message = frame:WaitForChild("Message")
        local textHolder = message:WaitForChild("Text")
        local titleLabel = textHolder:WaitForChild("Title")
        local descriptionLabel = textHolder:WaitForChild("Desc")
        local sideIcon = message:WaitForChild("SideIcon")
        local progressFrame = frame:WaitForChild("Progress")
        local amountLabel = progressFrame:WaitForChild("Amount")
        local progressBar = progressFrame:WaitForChild("ProgressBar")
        local bar = progressBar:WaitForChild("Bar")
        local teleport = frame:WaitForChild("Buttons"):WaitForChild("Teleport")
        local teleportText = teleport:WaitForChild("TextLabel")
        local notification = frame:WaitForChild("Notification")
        local notificationCount = notification:WaitForChild("Count")
        local bonusReward = frame:WaitForChild("BonusReward")
        local bonusTitle = bonusReward:WaitForChild("Title")
        local bonusImage = bonusReward:WaitForChild("RewardImage")

        local currentValue = tonumber(settings.CurrentValue or settings.Current or settings.Value)
        if currentValue == nil and type(settings.Progress) == "number" then
            currentValue = settings.Progress
        end
        currentValue = currentValue or 0

        local maximumValue = tonumber(settings.MaxValue or settings.Maximum or settings.Max or settings.Total or settings.Goal) or 1
        maximumValue = math.max(maximumValue, 0)

        local destroyed = false
        local completed = false
        local targetFill = bar.Size.X.Scale
        local progressProvider = type(settings.Progress) == "function" and settings.Progress or settings.UpdateProgress
        local descriptionProvider = type(settings.Description) == "function" and settings.Description or nil
        local titleProvider = type(settings.Title) == "function" and settings.Title or nil
        local connections = {}
        local control = {}
        local window = self

        local function formatNumber(value)
            if type(shortenInfoNumber) == "function" then
                return shortenInfoNumber(value)
            end
            local number = tonumber(value) or 0
            if number % 1 == 0 then
                return tostring(math.floor(number))
            end
            return tostring(number)
        end

        local function getText(value, fallback)
            if type(value) == "function" then
                local ok, result = safeCall(value)
                if ok and result ~= nil then
                    return tostring(result)
                end
                return tostring(fallback or "")
            end
            if value == nil then
                return tostring(fallback or "")
            end
            return tostring(value)
        end

        local function setBonus(value)
            local data = type(value) == "table" and value or nil
            bonusReward.Visible = data ~= nil and data.Visible ~= false
            if not data then
                return
            end
            bonusTitle.Text = tostring(data.Title or data.Text or "Bonus Item:")
            bonusImage.Image = tostring(data.Image or data.Icon or "rbxassetid://15048277894")
        end

        local function setNotification(value)
            local number = tonumber(value)
            notification.Visible = number ~= nil and number > 0
            if number then
                notificationCount.Text = tostring(math.max(0, math.floor(number)))
            end
        end

        local buttonData = type(settings.Button) == "table" and settings.Button or nil
        local buttonCallback = buttonData and buttonData.Callback
            or settings.ButtonCallback
            or settings.TeleportCallback
            or settings.OnTeleport
        if not buttonCallback and settings.ShowButton == true then
            buttonCallback = settings.Callback
        end
        teleport.Visible = type(buttonCallback) == "function" or settings.ShowButton == true
        teleportText.Text = tostring(
            buttonData and (buttonData.Text or buttonData.Name)
                or settings.ButtonText
                or "Return to Area"
        )

        if teleport.Visible then
            GUIFX.ButtonFX(teleport)
            table.insert(connections, teleport.Activated:Connect(function()
                safeCall(buttonCallback, control)
            end))
        end

        local function runCompletionEffect()
            playPS99GoalCompleteSound()
            playPS99GoalShimmer(frame)
            playPS99GoalWiggle(frame)
            safeCall(settings.OnComplete, control)
            if settings.AutoCloseAfter ~= nil then
                local delayTime = math.max(0, tonumber(settings.AutoCloseAfter) or 0)
                task.delay(delayTime, function()
                    if not destroyed then
                        control:Destroy()
                    end
                end)
            end
        end

        local function render(fireCompletion)
            if destroyed then
                return
            end

            titleLabel.Text = getText(titleProvider or settings.Title or settings.Name, "Goal")
            descriptionLabel.Text = getText(descriptionProvider or settings.Description or settings.Content, "")
            sideIcon.Image = tostring(settings.Icon or settings.Image or "rbxassetid://17638233159")

            local safeMaximum = math.max(maximumValue, 0)
            local displayedCurrent = currentValue
            if safeMaximum > 0 then
                displayedCurrent = math.min(currentValue, safeMaximum)
                targetFill = math.clamp(displayedCurrent / safeMaximum, 0, 1)
            else
                displayedCurrent = 0
                targetFill = 0
            end

            bar:SetAttribute("TargetFill", targetFill)
            if targetFill < bar.Size.X.Scale then
                bar.Size = UDim2.new(targetFill, bar.Size.X.Offset, bar.Size.Y.Scale, bar.Size.Y.Offset)
            end

            amountLabel.Text = string.format("%s/%s", formatNumber(displayedCurrent), formatNumber(safeMaximum))

            local isComplete = safeMaximum > 0 and displayedCurrent >= safeMaximum
            if isComplete and not completed then
                completed = true
                if fireCompletion then
                    runCompletionEffect()
                end
            elseif not isComplete then
                completed = false
            end
        end

        table.insert(connections, RunService.RenderStepped:Connect(function(deltaTime)
            if destroyed then
                return
            end
            local currentFill = bar.Size.X.Scale
            local difference = math.abs(currentFill - targetFill)
            if difference >= 0.01 then
                local nextFill = currentFill + (targetFill - currentFill) * (1 - math.exp(-10 * deltaTime))
                bar.Size = UDim2.new(nextFill, bar.Size.X.Offset, bar.Size.Y.Scale, bar.Size.Y.Offset)
            end
        end))

        if type(progressProvider) == "function" or descriptionProvider or titleProvider then
            local elapsed = 0
            local updateInterval = math.max(0.03, tonumber(settings.UpdateInterval) or 0.1)
            table.insert(connections, RunService.RenderStepped:Connect(function(deltaTime)
                if destroyed then
                    return
                end
                elapsed += deltaTime
                if elapsed < updateInterval then
                    return
                end
                elapsed = 0

                if type(progressProvider) == "function" then
                    local ok, value, maximum = pcall(progressProvider, control)
                    if not ok then
                        warn(tostring(value))
                    else
                        if tonumber(value) ~= nil then
                            currentValue = tonumber(value)
                        end
                        if tonumber(maximum) ~= nil then
                            maximumValue = math.max(0, tonumber(maximum))
                        end
                    end
                end
                render(true)
            end))
        end

        function control:Get()
            return currentValue, maximumValue
        end

        function control:GetScreen()
            return screen
        end

        function control:SetProgress(value, maximum, silent)
            if tonumber(value) ~= nil then
                currentValue = tonumber(value)
            end
            if tonumber(maximum) ~= nil then
                maximumValue = math.max(0, tonumber(maximum))
            end
            render(silent ~= true)
            return control
        end

        function control:SetTitle(value)
            settings.Title = value
            titleProvider = type(value) == "function" and value or nil
            render(false)
            return control
        end

        function control:SetDescription(value)
            settings.Description = value
            descriptionProvider = type(value) == "function" and value or nil
            render(false)
            return control
        end

        function control:SetIcon(value)
            settings.Icon = tostring(value or "")
            render(false)
            return control
        end

        function control:SetVisible(value)
            screen.Enabled = value == true
            return control
        end

        function control:SetButton(value)
            local data = type(value) == "table" and value or {}
            local callback = type(value) == "function" and value or data.Callback
            if callback ~= nil then
                buttonCallback = callback
            end
            if data.Text or data.Name then
                teleportText.Text = tostring(data.Text or data.Name)
            end
            teleport.Visible = value ~= false and (type(buttonCallback) == "function" or data.Visible == true)
            return control
        end

        function control:SetBonusReward(value)
            setBonus(value)
            return control
        end

        function control:SetNotification(value)
            setNotification(value)
            return control
        end

        function control:Refresh()
            if type(progressProvider) == "function" then
                local ok, value, maximum = pcall(progressProvider, control)
                if not ok then
                    warn(tostring(value))
                else
                    if tonumber(value) ~= nil then
                        currentValue = tonumber(value)
                    end
                    if tonumber(maximum) ~= nil then
                        maximumValue = math.max(0, tonumber(maximum))
                    end
                end
            end
            render(true)
            return control
        end

        function control:Complete()
            currentValue = maximumValue
            render(true)
            return control
        end

        function control:Destroy()
            if destroyed then
                return
            end
            destroyed = true
            for _, connection in ipairs(connections) do
                pcall(function()
                    connection:Disconnect()
                end)
            end
            if self == control and screen and screen.Parent then
                screen:Destroy()
            end
            if window.ActiveGoal == control then
                window.ActiveGoal = nil
            end
        end

        control.Close = control.Destroy
        control.Remove = control.Destroy

        setBonus(settings.BonusReward)
        setNotification(settings.NotificationCount)
        render(false)
        screen.Enabled = settings.Visible ~= false
        if completed and settings.PlayCompletionOnCreate == true then
            runCompletionEffect()
        end

        self.ActiveGoal = control
        return control
    end

    Library.Goal = Library.CreateGoal

    Library.ShowAlert = Library.Alert
    Library.ShowImageAlert = Library.ImageAlert


    function Library:Prompt(promptSettings)
        local settings = type(promptSettings) == "table" and promptSettings or {Content = tostring(promptSettings)}
        if self.ActivePrompt and self.ActivePrompt.Close then
            self.ActivePrompt:Close(false)
        end
        GuiService.SelectedObject = nil
        local overlay = Instance.new("TextButton")
        overlay.Name = "Modal"
        overlay.Active = true
        overlay.AutoButtonColor = false
        overlay.BackgroundColor3 = Color3.new(0, 0, 0)
        overlay.BackgroundTransparency = 1
        overlay.Modal = true
        overlay.Size = UDim2.fromScale(1, 1)
        overlay.Text = ""
        overlay.ZIndex = 300
        overlay.Parent = self.Screen
        local panel = self.Templates.Locked:Clone()
        panel.Name = "Prompt"
        panel.AnchorPoint = Vector2.new(0.5, 0.5)
        panel.ClipsDescendants = false
        panel.Position = UDim2.fromScale(0.5, 0.5)
        panel.Size = UDim2.fromOffset(0, 0)
        panel.Visible = true
        panel.ZIndex = 301
        panel.Parent = overlay
        local price = panel:FindFirstChild("PriceFrame")
        if price then
            price:Destroy()
        end
        local aspect = panel:FindFirstChildOfClass("UIAspectRatioConstraint")
        if aspect then
            aspect:Destroy()
        end
        local title = Instance.new("TextLabel")
        title.BackgroundTransparency = 1
        title.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
        title.Position = UDim2.fromOffset(18, 14)
        title.Size = UDim2.new(1, -36, 0, 34)
        title.Text = tostring(settings.Title or "Confirm")
        title.TextColor3 = Color3.new(1, 1, 1)
        title.TextScaled = true
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.ZIndex = 303
        title.Parent = panel
        local titleStroke = Instance.new("UIStroke")
        titleStroke.Color = Color3.fromRGB(42, 43, 49)
        titleStroke.Thickness = 2.5
        titleStroke.Parent = title
        local content = Instance.new("TextLabel")
        content.BackgroundTransparency = 1
        content.FontFace = title.FontFace
        content.Position = UDim2.fromOffset(18, 56)
        content.Size = UDim2.new(1, -36, 0, 66)
        content.Text = tostring(settings.Content or "Are you sure?")
        content.TextColor3 = Color3.fromRGB(245, 245, 245)
        content.TextSize = 18
        content.TextWrapped = true
        content.TextXAlignment = Enum.TextXAlignment.Left
        content.TextYAlignment = Enum.TextYAlignment.Top
        content.ZIndex = 303
        content.Parent = panel
        local function createPromptButton(name, text, position, gradientName)
            local source = self.Templates.Selector.Toggle.Button
            local button = source:Clone()
            button.Name = name
            button.AnchorPoint = Vector2.new(0.5, 1)
            button.Position = position
            button.Size = UDim2.new(0.42, 0, 0, 48)
            button.Selectable = true
            button.ZIndex = 304
            button.Parent = panel
            local buttonText = button:FindFirstChild("TextLabel", true)
            if buttonText and buttonText:IsA("TextLabel") then
                buttonText.Text = text
                buttonText.Visible = true
                buttonText.TextTransparency = 0
                buttonText.TextColor3 = Color3.new(1, 1, 1)
                buttonText.ZIndex = button.ZIndex + 2
            end
            clearGradient(button)
            local gradient = Gradients:FindFirstChild(gradientName)
            if gradient then
                gradient:Clone().Parent = button
            end
            GUIFX.ButtonFX(button)
            return button
        end
        local cancel = createPromptButton("Cancel", tostring(settings.CancelText or "Cancel"), UDim2.new(0.27, 0, 1, -14), "GreyGradient")
        local confirm = createPromptButton("Confirm", tostring(settings.ConfirmText or "Confirm"), UDim2.new(0.73, 0, 1, -14), settings.Dangerous and "RedGradient" or "GreenGradient")
        local resolved = false
        local prompt = {}
        local function close(result)
            if resolved then
                return
            end
            resolved = true
            local selectedObject = GuiService.SelectedObject
            if selectedObject and (selectedObject == cancel or selectedObject == confirm or selectedObject:IsDescendantOf(overlay)) then
                GuiService.SelectedObject = nil
            end
            TweenService:Create(overlay, TweenInfo.new(0.22), {BackgroundTransparency = 1}):Play()
            TweenService:Create(panel, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Size = UDim2.fromOffset(0, 0)}):Play()
            task.delay(0.25, function()
                if overlay.Parent then
                    overlay:Destroy()
                end
            end)
            if self.ActivePrompt == prompt then
                self.ActivePrompt = nil
            end
            safeCall(settings.Callback, result)
        end
        function prompt:Close(result)
            close(result == true)
        end
        function prompt:Confirm()
            close(true)
        end
        function prompt:Cancel()
            close(false)
        end
        cancel.Activated:Connect(function()
            close(false)
        end)
        confirm.Activated:Connect(function()
            close(true)
        end)
        if settings.CloseOnOverlay ~= false then
            overlay.Activated:Connect(function()
                close(false)
            end)
        end
        self.ActivePrompt = prompt
        TweenService:Create(overlay, TweenInfo.new(0.25), {BackgroundTransparency = 0.42}):Play()
        TweenService:Create(panel, TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.fromOffset(390, 190)}):Play()
        task.defer(function()
            if resolved or not confirm.Parent then
                return
            end
            local lastInputType = UserInputService:GetLastInputType()
            if string.find(lastInputType.Name, "Gamepad", 1, true) == 1 then
                GuiService.SelectedObject = confirm
            else
                GuiService.SelectedObject = nil
            end
        end)
        return prompt
    end

    Library.Confirm = Library.Prompt

    function Library:_createLockOverlay(row)
        local overlay = Instance.new("TextButton")
        overlay.Name = "InteractionBlocker"
        overlay.Active = true
        overlay.AutoButtonColor = false
        overlay.BackgroundColor3 = Color3.fromRGB(42, 43, 49)
        overlay.BackgroundTransparency = 0.38
        overlay.BorderSizePixel = 0
        overlay.Size = UDim2.fromScale(1, 1)
        overlay.Text = ""
        overlay.Visible = false
        overlay.ZIndex = 120
        overlay.Parent = row
        local corner = row:FindFirstChildOfClass("UICorner")
        if corner then
            corner:Clone().Parent = overlay
        end
        local label = Instance.new("TextLabel")
        label.Name = "Reason"
        label.AnchorPoint = Vector2.new(1, 0.5)
        label.BackgroundTransparency = 1
        label.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
        label.Position = UDim2.new(1, -12, 0.5, 0)
        label.Size = UDim2.new(0.48, 0, 0.7, 0)
        label.Text = "Locked"
        label.TextColor3 = Color3.new(1, 1, 1)
        label.TextScaled = true
        label.TextXAlignment = Enum.TextXAlignment.Right
        label.ZIndex = 121
        label.Parent = overlay
        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(42, 43, 49)
        stroke.Thickness = 2
        stroke.Parent = label
        return overlay, label
    end

    function Library:_decorateControl(control, row, settings, controlType)
        control = control or {}
        settings = type(settings) == "table" and settings or {}
        control.Type = controlType or control.Type or "Element"
        control._Settings = settings
        control.Row = row
        control.Window = self
        control.Name = tostring(settings.Name or control.Name or (findSettingLabel(row) and findSettingLabel(row).Text) or control.Type)
        control.Enabled = settings.Enabled ~= false
        control.Locked = settings.Locked == true
        control.LockReason = tostring(settings.LockReason or settings.LockedReason or "This option is locked")
        local label = findSettingLabel(row)
        local overlay, overlayLabel
        local tooltipDisconnect
        local originalDestroy = control.Destroy
        local originalSet = control.Set
        local function refreshOverlay()
            local blocked = not control.Enabled or control.Locked
            if blocked and not overlay then
                overlay, overlayLabel = self:_createLockOverlay(row)
                overlay.Activated:Connect(function()
                    if control.Locked then
                        self:Notify({Title = control.Name, Content = control.LockReason, Type = "Red", Duration = 3})
                    end
                end)
            end
            if overlay then
                overlay.Visible = blocked
                overlayLabel.Text = control.Locked and "Locked" or "Disabled"
            end
            setObjectInputEnabled(row, not blocked)
            if overlay then
                overlay.Active = blocked
            end
        end
        function control:SetName(value)
            control.Name = tostring(value)
            if control._Settings then
                control._Settings.Name = control.Name
            end
            if label then
                label.Text = control.Name
            end
            return control
        end
        function control:SetVisible(value)
            local visible = value == true
            for _, entry in ipairs(self.Window.Rows) do
                if entry.Row == row then
                    entry.ManualVisible = visible
                    break
                end
            end
            self.Window:_refreshPagination()
            return control
        end
        function control:SetEnabled(value)
            control.Enabled = value == true
            refreshOverlay()
            return control
        end
        function control:SetLocked(value, reason)
            control.Locked = value == true
            if reason ~= nil then
                control.LockReason = tostring(reason)
            end
            refreshOverlay()
            return control
        end
        function control:SetTooltip(value)
            if tooltipDisconnect then
                tooltipDisconnect()
                tooltipDisconnect = nil
            end
            local hasValue = value ~= nil
            if type(value) == "string" then
                hasValue = value ~= ""
            end
            if hasValue then
                tooltipDisconnect = self.Window:AttachTooltip(row, value)
            else
                row:SetAttribute("Tooltip", nil)
            end
            return control
        end
        function control:Destroy()
            if tooltipDisconnect then
                tooltipDisconnect()
                tooltipDisconnect = nil
            end
            if originalDestroy then
                pcall(originalDestroy, control)
            elseif row and row.Parent then
                row:Destroy()
            end
            removeRowEntry(self.Window, row)
        end
        if originalSet then
            function control:Set(value, silent)
                if (not control.Enabled or control.Locked) and not silent then
                    return control.Get and control:Get() or nil
                end
                return originalSet(control, value, silent)
            end
        end
        if settings.Tooltip then
            control:SetTooltip(settings.Tooltip)
        end
        refreshOverlay()
        if settings.Visible == false then
            control:SetVisible(false)
        end
        if settings.Flag and self.ConfigSettings then
            self:BindConfig(tostring(settings.Flag), control, settings.Default ~= nil and settings.Default or (control.Get and control:Get() or nil))
        end
        return control
    end

    local OriginalAddButtonV8 = Library.AddButton
    function Library:AddButton(nameOrSettings, callback, buttonText)
        local settings = type(nameOrSettings) == "table" and nameOrSettings or {
            Name = tostring(nameOrSettings),
            Callback = callback,
            ButtonText = buttonText,
        }
        settings.Name = tostring(settings.Name or "Button")
        settings.Callback = settings.Callback or function() end
        local control = OriginalAddButtonV8(self, settings.Name, settings.Callback, settings.ButtonText or settings.Text or "Run")
        local row = self.Rows[#self.Rows].Row
        control.Get = control.Get or function()
            return nil
        end
        control.Set = control.Set or function()
            return nil
        end
        return self:_decorateControl(control, row, settings, "Button")
    end

    local OriginalAddToggleV8 = Library.AddToggle
    function Library:AddToggle(nameOrSettings, default, callback)
        local settings = type(nameOrSettings) == "table" and nameOrSettings or {
            Name = tostring(nameOrSettings),
            Default = default,
            Callback = callback,
        }
        settings.Name = tostring(settings.Name or "Toggle")
        settings.Default = settings.Default == true or settings.CurrentValue == true
        settings.Callback = settings.Callback or function() end
        local control = OriginalAddToggleV8(self, settings.Name, settings.Default, settings.Callback)
        local row = self.Rows[#self.Rows].Row
        return self:_decorateControl(control, row, settings, "Toggle")
    end

    local OriginalAddSelectorV8 = Library.AddSelector
    function Library:AddSelector(nameOrSettings, values, default, callback)
        local settings = type(nameOrSettings) == "table" and nameOrSettings or {
            Name = tostring(nameOrSettings),
            Values = values,
            Default = default,
            Callback = callback,
        }
        settings.Name = tostring(settings.Name or "Selector")
        settings.Values = settings.Values or settings.Options or {}
        settings.Default = settings.Default ~= nil and settings.Default or settings.CurrentValue
        settings.Callback = settings.Callback or function() end
        local control = OriginalAddSelectorV8(self, settings.Name, settings.Values, settings.Default, settings.Callback)
        local row = self.Rows[#self.Rows].Row
        return self:_decorateControl(control, row, settings, "Selector")
    end

    local OriginalAddDropdownV8 = Library.AddDropdown
    function Library:AddDropdown(settingsOrName, legacyValues, legacyDefault, legacyCallback, legacyMultiple)
        local settings = type(settingsOrName) == "table" and settingsOrName or {
            Name = tostring(settingsOrName),
            Options = legacyValues,
            CurrentOption = legacyDefault,
            Callback = legacyCallback,
            MultipleOptions = legacyMultiple,
        }
        local control = OriginalAddDropdownV8(self, settings)
        local row = self.Rows[#self.Rows].Row
        settings.Default = settings.CurrentOption
        return self:_decorateControl(control, row, settings, "Dropdown")
    end

    local OriginalAddSliderV8 = Library.AddSlider
    function Library:AddSlider(nameOrSettings, minimum, maximum, default, callback, step)
        local settings = type(nameOrSettings) == "table" and nameOrSettings or {
            Name = tostring(nameOrSettings),
            Minimum = minimum,
            Maximum = maximum,
            Default = default,
            Callback = callback,
            Step = step,
        }
        settings.Name = tostring(settings.Name or "Slider")
        settings.Minimum = tonumber(settings.Minimum or settings.Range and settings.Range[1]) or 0
        settings.Maximum = tonumber(settings.Maximum or settings.Range and settings.Range[2]) or 100
        settings.Default = tonumber(settings.Default ~= nil and settings.Default or settings.CurrentValue) or settings.Minimum
        settings.Callback = settings.Callback or function() end
        local control = OriginalAddSliderV8(self, settings.Name, settings.Minimum, settings.Maximum, settings.Default, settings.Callback, settings.Step or settings.Increment)
        local row = self.Rows[#self.Rows].Row
        local sliderSet = control.Set
        control.Set = function(selfControl, value, silent)
            local result = sliderSet(selfControl, value, silent)
            local current = selfControl:Get()
            local text = math.abs(current - math.round(current)) < 1e-6 and tostring(math.round(current)) or string.format("%.2f", current):gsub("0+$", ""):gsub("%.$", "")
            row.SettingName.Text = string.format("%s: %s", settings.Name, text)
            return result
        end
        return self:_decorateControl(control, row, settings, "Slider")
    end

    local OriginalAddSectionV8 = Library.AddSection
    function Library:AddSection(textOrSettings, color, options)
        local settings
        if type(textOrSettings) == "table" then
            settings = textOrSettings
        else
            settings = type(options) == "table" and options or {}
            settings.Name = tostring(textOrSettings)
            settings.Color = color
        end
        settings.Name = tostring(settings.Name or settings.Title or "Section")
        settings.Color = settings.Color or color
        settings.Collapsible = settings.Collapsible == true
        settings.DefaultCollapsed = settings.DefaultCollapsed == true or settings.Collapsed == true
        local tabName = self._MountTab or self.ActiveTab or "__default"
        self._CreatingSection = true
        local row = OriginalAddSectionV8(self, settings.Name, settings.Color)
        self._CreatingSection = false
        local section = {
            Type = "Section",
            Name = settings.Name,
            Row = row,
            Window = self,
            Tab = tabName,
            Entries = {},
            Collapsible = settings.Collapsible,
            Collapsed = false,
            SubTab = self._MountSubTab,
            Animating = false,
            AnimationToken = 0,
            EntryVisualStates = {},
        }
        local sectionKey = tabName .. "" .. tostring(section.SubTab or "")
        self._ActiveSectionByTab[sectionKey] = section
        local arrow
        local button
        local updateArrowPosition
        local SECTION_TWEEN = TweenInfo.new(0.42, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        local ARROW_TWEEN = TweenInfo.new(0.7, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

        local function captureVisualState(targetRow)
            local state = {
                Size = targetRow.Size,
                ClipsDescendants = targetRow.ClipsDescendants,
                Properties = {},
            }
            local objects = {targetRow}
            for _, descendant in ipairs(targetRow:GetDescendants()) do
                table.insert(objects, descendant)
            end
            for _, object in ipairs(objects) do
                local properties = {}
                if object:IsA("GuiObject") then
                    properties.BackgroundTransparency = object.BackgroundTransparency
                end
                if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
                    properties.TextTransparency = object.TextTransparency
                    properties.TextStrokeTransparency = object.TextStrokeTransparency
                end
                if object:IsA("ImageLabel") or object:IsA("ImageButton") then
                    properties.ImageTransparency = object.ImageTransparency
                end
                if object:IsA("ScrollingFrame") then
                    properties.ScrollBarImageTransparency = object.ScrollBarImageTransparency
                end
                if object:IsA("UIStroke") then
                    properties.Transparency = object.Transparency
                end
                if next(properties) then
                    state.Properties[object] = properties
                end
            end
            return state
        end

        local function tweenVisualState(targetRow, state, collapsed)
            targetRow.ClipsDescendants = true
            local targetSize = collapsed and UDim2.new(state.Size.X.Scale, state.Size.X.Offset, 0, 0) or state.Size
            TweenService:Create(targetRow, SECTION_TWEEN, {Size = targetSize}):Play()
            for object, properties in pairs(state.Properties) do
                if object.Parent then
                    local goals = {}
                    for property, value in pairs(properties) do
                        goals[property] = collapsed and 1 or value
                    end
                    TweenService:Create(object, SECTION_TWEEN, goals):Play()
                end
            end
        end

        local function applyCollapsedVisual(targetRow, state)
            targetRow.ClipsDescendants = true
            targetRow.Size = UDim2.new(state.Size.X.Scale, state.Size.X.Offset, 0, 0)
            for object, properties in pairs(state.Properties) do
                if object.Parent then
                    for property in pairs(properties) do
                        object[property] = 1
                    end
                end
            end
        end

        local function restoreVisualState(targetRow, state)
            if not targetRow.Parent then
                return
            end
            targetRow.Size = state.Size
            targetRow.ClipsDescendants = state.ClipsDescendants
            for object, properties in pairs(state.Properties) do
                if object.Parent then
                    for property, value in pairs(properties) do
                        object[property] = value
                    end
                end
            end
        end

        local function getEntryState(entry)
            local targetRow = entry.Row
            local state = section.EntryVisualStates[entry]
            if not state or not targetRow or not targetRow.Parent then
                if not targetRow or not targetRow.Parent then
                    return nil
                end
                state = captureVisualState(targetRow)
                section.EntryVisualStates[entry] = state
            end
            return state
        end

        if settings.Collapsible then
            button = Instance.new("TextButton")
            button.Name = "Collapse"
            button.Active = true
            button.AutoButtonColor = false
            button.BackgroundTransparency = 1
            button.AnchorPoint = Vector2.new(0.5, 0.5)
            button.Position = UDim2.fromScale(0.5, 0.5)
            button.Size = UDim2.new(1, 0, 1, 0)
            button.Text = ""
            button.Selectable = true
            button.ZIndex = row.ZIndex + 5
            button.Parent = row

            arrow = Instance.new("TextLabel")
            arrow.Name = "DropdownArrow"
            arrow.AnchorPoint = Vector2.new(1, 0.5)
            arrow.BackgroundTransparency = 1
            arrow.FontFace = row.FontFace
            arrow.Position = UDim2.new(1, -4, 0.5, 0)
            arrow.Size = UDim2.fromOffset(24, 24)
            arrow.Text = "▲"
            arrow.TextColor3 = row.TextColor3
            arrow.TextScaled = true
            arrow.TextStrokeColor3 = row.TextStrokeColor3
            arrow.TextStrokeTransparency = row.TextStrokeTransparency
            arrow.Rotation = 0
            arrow.ZIndex = button.ZIndex + 1
            arrow.Parent = button

            local rowGradient = row:FindFirstChildOfClass("UIGradient")
            if rowGradient then
                rowGradient:Clone().Parent = arrow
            end

            updateArrowPosition = function()
                arrow.Position = UDim2.new(1, -4, 0.5, 0)
            end

            row:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateArrowPosition)
            task.defer(updateArrowPosition)
            GUIFX.ButtonFX(button, 1.01)
        end

        function section:SetCollapsed(value, immediate)
            if not self.Collapsible then
                return false
            end

            local targetCollapsed = value == true
            if self.Animating then
                self.AnimationToken += 1
                self.Animating = false
                for _, entry in ipairs(self.Entries) do
                    local targetRow = entry.Row
                    local state = self.EntryVisualStates[entry]
                    if targetRow and state then
                        restoreVisualState(targetRow, state)
                    end
                end
            end
            if self.Collapsed == targetCollapsed then
                if arrow then
                    arrow.Rotation = targetCollapsed and 180 or 0
                end
                return self.Collapsed
            end

            if self.Window.ActiveDropdownClose then
                self.Window.ActiveDropdownClose(true)
            end

            self.AnimationToken += 1
            local token = self.AnimationToken
            self.Animating = immediate ~= true

            if arrow then
                if immediate then
                    arrow.Rotation = targetCollapsed and 180 or 0
                else
                    TweenService:Create(arrow, ARROW_TWEEN, {Rotation = targetCollapsed and 180 or 0}):Play()
                end
            end

            if targetCollapsed then
                local animatedRows = {}
                for _, entry in ipairs(self.Entries) do
                    local targetRow = entry.Row
                    if targetRow and targetRow.Parent then
                        self.EntryVisualStates[entry] = captureVisualState(targetRow)
                        if targetRow.Visible then
                            table.insert(animatedRows, entry)
                        end
                    end
                end

                if immediate or #animatedRows == 0 then
                    self.Collapsed = true
                    self.Window.PageByTab[self.Tab] = 1
                    self.Window:_refreshPagination()
                    self.Animating = false
                    return true
                end

                for _, entry in ipairs(animatedRows) do
                    local targetRow = entry.Row
                    local state = self.EntryVisualStates[entry]
                    tweenVisualState(targetRow, state, true)
                end

                task.delay(0.43, function()
                    if token ~= self.AnimationToken then
                        return
                    end
                    self.Collapsed = true
                    self.Window.PageByTab[self.Tab] = 1
                    self.Window:_refreshPagination()
                    for _, entry in ipairs(self.Entries) do
                        local targetRow = entry.Row
                        local state = self.EntryVisualStates[entry]
                        if targetRow and state then
                            restoreVisualState(targetRow, state)
                        end
                    end
                    self.Animating = false
                end)
            else
                for _, entry in ipairs(self.Entries) do
                    local targetRow = entry.Row
                    if targetRow and targetRow.Parent then
                        local state = getEntryState(entry)
                        if state then
                            applyCollapsedVisual(targetRow, state)
                        end
                    end
                end

                self.Collapsed = false
                self.Window.PageByTab[self.Tab] = 1
                self.Window:_refreshPagination()

                if immediate then
                    for _, entry in ipairs(self.Entries) do
                        local targetRow = entry.Row
                        local state = self.EntryVisualStates[entry]
                        if targetRow and state then
                            restoreVisualState(targetRow, state)
                        end
                    end
                    self.Animating = false
                    return false
                end

                task.defer(function()
                    if token ~= self.AnimationToken then
                        return
                    end
                    for _, entry in ipairs(self.Entries) do
                        local targetRow = entry.Row
                        local state = self.EntryVisualStates[entry]
                        if targetRow and targetRow.Parent and targetRow.Visible and state then
                            tweenVisualState(targetRow, state, false)
                        elseif targetRow and state then
                            restoreVisualState(targetRow, state)
                        end
                    end
                end)

                task.delay(0.43, function()
                    if token ~= self.AnimationToken then
                        return
                    end
                    for _, entry in ipairs(self.Entries) do
                        local targetRow = entry.Row
                        local state = self.EntryVisualStates[entry]
                        if targetRow and state then
                            restoreVisualState(targetRow, state)
                        end
                    end
                    self.Animating = false
                end)
            end

            return targetCollapsed
        end

        function section:Toggle()
            return self:SetCollapsed(not self.Collapsed)
        end
        function section:Get()
            return self.Collapsed
        end
        function section:Set(value)
            return self:SetCollapsed(value)
        end
        function section:SetName(value)
            self.Name = tostring(value)
            row.Text = self.Name
            if updateArrowPosition then
                task.defer(updateArrowPosition)
            end
            return self
        end
        function section:SetVisible(value)
            for _, entry in ipairs(self.Window.Rows) do
                if entry.Row == row then
                    entry.ManualVisible = value == true
                    break
                end
            end
            self.Window:_refreshPagination()
            return self
        end
        function section:SetEnabled(value)
            if button then
                button.Active = value == true
                button.Selectable = value == true
            end
            return self
        end
        function section:SetLocked(value, reason)
            if value then
                self.Window:Notify({Title = self.Name, Content = tostring(reason or "This section is locked"), Type = "Red"})
            end
            return self
        end
        function section:SetTooltip(value)
            if button then
                self.Window:AttachTooltip(button, value)
            end
            return self
        end
        function section:Destroy()
            self.AnimationToken += 1
            for _, entry in ipairs(self.Entries) do
                if entry.Row and entry.Row.Parent then
                    entry.Row:Destroy()
                end
            end
            if row.Parent then
                row:Destroy()
            end
            removeRowEntry(self.Window, row)
        end
        function section:_add(methodName, ...)
            local oldSection = self.Window._ForcedSection
            local oldSubTab = self.Window._MountSubTab
            self.Window._ForcedSection = self
            self.Window._MountSubTab = self.SubTab
            local result = self.Window:_withTab(self.Tab, methodName, ...)
            self.Window._ForcedSection = oldSection
            self.Window._MountSubTab = oldSubTab
            local entry = self.Entries[#self.Entries]
            if entry and entry.Row and entry.Row.Parent then
                self.EntryVisualStates[entry] = captureVisualState(entry.Row)
            end
            return result
        end
        for _, methodName in ipairs({"AddButton", "AddToggle", "AddSelector", "AddDropdown", "AddSlider", "AddKeybind", "AddProgress", "AddColorPicker"}) do
            section[methodName] = function(selfSection, ...)
                return selfSection:_add(methodName, ...)
            end
        end
        if button then
            button.Activated:Connect(function()
                if not section.Animating then
                    section:Toggle()
                end
            end)
        end
        if settings.Tooltip then
            section:SetTooltip(settings.Tooltip)
        end
        if settings.DefaultCollapsed then
            section:SetCollapsed(true, true)
        end
        return section
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
        local currentKey = settings.CurrentKey or settings.Default or Enum.KeyCode.Unknown
        local listening = false
        local holding = false
        local holdToken = 0
        self:_mount(row, settings.Name, settings.Name .. " keybind")
        GUIFX.ButtonFX(button)
        local function normalizeKey(value)
            if typeof(value) == "EnumItem" then
                return value
            end
            local keyName = tostring(value or "Unknown"):gsub("Enum.KeyCode.", ""):gsub("Enum.UserInputType.", "")
            return Enum.KeyCode[keyName] or Enum.UserInputType[keyName] or Enum.KeyCode.Unknown
        end
        local function render()
            label.Text = listening and "Press a key..." or currentKey.Name
        end
        local beganConnection
        local endedConnection
        button.Activated:Connect(function()
            listening = true
            render()
        end)
        beganConnection = UserInputService.InputBegan:Connect(function(inputObject, processed)
            if listening then
                local candidate = inputObject.KeyCode ~= Enum.KeyCode.Unknown and inputObject.KeyCode or inputObject.UserInputType
                if candidate == Enum.KeyCode.Escape then
                    listening = false
                    render()
                    return
                end
                currentKey = candidate
                listening = false
                render()
                safeCall(settings.ChangedCallback, currentKey)
                return
            end
            if processed and not settings.IgnoreProcessed then
                return
            end
            local candidate = inputObject.KeyCode ~= Enum.KeyCode.Unknown and inputObject.KeyCode or inputObject.UserInputType
            if candidate ~= currentKey then
                return
            end
            if settings.HoldToInteract then
                if holding then
                    return
                end
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
                safeCall(settings.Callback, currentKey)
            end
        end)
        endedConnection = UserInputService.InputEnded:Connect(function(inputObject)
            local candidate = inputObject.KeyCode ~= Enum.KeyCode.Unknown and inputObject.KeyCode or inputObject.UserInputType
            if candidate == currentKey and settings.HoldToInteract then
                holding = false
                holdToken += 1
                safeCall(settings.Callback, false)
            end
        end)
        local control = {
            Get = function()
                return currentKey.Name
            end,
            Set = function(_, value, silent)
                currentKey = normalizeKey(value)
                render()
                if not silent then
                    safeCall(settings.ChangedCallback, currentKey)
                end
            end,
            Destroy = function()
                beganConnection:Disconnect()
                endedConnection:Disconnect()
                row:Destroy()
            end,
        }
        render()
        return self:_decorateControl(control, row, settings, "Keybind")
    end

    function Library:AddProgress(progressSettings, legacyMaximum, legacyValue)
        local settings = type(progressSettings) == "table" and progressSettings or {
            Name = tostring(progressSettings),
            Maximum = legacyMaximum,
            CurrentValue = legacyValue,
        }
        settings.Name = tostring(settings.Name or "Progress")
        settings.Minimum = tonumber(settings.Minimum) or 0
        settings.Maximum = tonumber(settings.Maximum or settings.MaxValue) or 100
        settings.CurrentValue = tonumber(settings.CurrentValue or settings.Default) or settings.Minimum
        settings.Suffix = tostring(settings.Suffix or "")
        settings.Callback = settings.Callback or function() end
        local row = self.Templates.Slider:Clone()
        row.SettingName.Text = settings.Name
        local slider = row.Slider
        local knob = slider:FindFirstChild("Button")
        if knob then
            knob:Destroy()
        end
        local bar = slider:FindFirstChild("Bar") or slider
        bar.ClipsDescendants = true
        local fill = Instance.new("Frame")
        fill.Name = "Progress"
        fill.AnchorPoint = Vector2.zero
        fill.BackgroundColor3 = Color3.new(1, 1, 1)
        fill.BorderSizePixel = 0
        fill.Position = UDim2.fromScale(0, 0)
        fill.Size = UDim2.fromScale(0, 1)
        fill.ZIndex = bar.ZIndex + 1
        fill.Parent = bar
        local corner = bar:FindFirstChildOfClass("UICorner")
        if corner then
            corner:Clone().Parent = fill
        end
        local gradientName = SECTION_GRADIENT_ALIASES[string.lower(tostring(settings.Color or settings.Gradient or "Green")):gsub("[%s_%-]", "")] or "GreenGradient"
        local gradient = Gradients:FindFirstChild(gradientName)
        if gradient then
            gradient:Clone().Parent = fill
        end
        local value = math.clamp(settings.CurrentValue, settings.Minimum, settings.Maximum)
        self:_mount(row, settings.Name, settings.Name .. " progress")
        local function render(fire)
            local alpha = settings.Maximum == settings.Minimum and 0 or (value - settings.Minimum) / (settings.Maximum - settings.Minimum)
            TweenService:Create(fill, TweenInfo.new(0.28, Enum.EasingStyle.Quint), {Size = UDim2.fromScale(alpha, 1)}):Play()
            row.SettingName.Text = string.format("%s: %s%s", settings.Name, tostring(math.floor(value * 100 + 0.5) / 100), settings.Suffix)
            if fire then
                safeCall(settings.Callback, value, alpha)
            end
        end
        local control = {
            Get = function()
                return value
            end,
            Set = function(_, newValue, silent)
                value = math.clamp(tonumber(newValue) or value, settings.Minimum, settings.Maximum)
                render(not silent)
                return value
            end,
            SetMaximum = function(_, newMaximum)
                settings.Maximum = tonumber(newMaximum) or settings.Maximum
                value = math.clamp(value, settings.Minimum, settings.Maximum)
                render(false)
            end,
        }
        render(false)
        return self:_decorateControl(control, row, settings, "Progress")
    end

    function Library:AddColorPicker(colorSettings, legacyColor, legacyCallback)
        local settings = type(colorSettings) == "table" and colorSettings or {
            Name = tostring(colorSettings),
            Color = legacyColor,
            Callback = legacyCallback,
        }
        settings.Name = tostring(settings.Name or "Color Picker")
        settings.Callback = settings.Callback or function() end

        local currentColor = tableToColor(settings.Color or settings.Default or settings.CurrentColor, Color3.new(1, 0, 0))
        local h, s, v = currentColor:ToHSV()

        local row = self.Templates.Selector:Clone()
        row.SettingName.Text = settings.Name

        local button = row.Toggle.Button
        local label = button.TextLabel
        label.Text = colorToHex(currentColor)

        self:_mount(row, settings.Name, settings.Name .. " color")
        GUIFX.ButtonFX(button)

        local popup = Instance.new("Frame")
        popup.Name = "ColorPickerSidePanel"
        popup.Active = true
        popup.AnchorPoint = Vector2.zero
        popup.BackgroundColor3 = Color3.new(1, 1, 1)
        popup.BackgroundTransparency = 0
        popup.BorderSizePixel = 0
        popup.ClipsDescendants = false
        popup.Position = UDim2.fromOffset(8, 8)
        popup.Size = UDim2.fromOffset(148, 310)
        popup.Visible = false
        popup.ZIndex = 80
        popup.Parent = self.Screen

        local popupCorner = Instance.new("UICorner")
        popupCorner.CornerRadius = UDim.new(0.08, 0)
        popupCorner.Parent = popup

        local popupStroke = Instance.new("UIStroke")
        popupStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        popupStroke.Color = Color3.new(0, 0, 0)
        popupStroke.LineJoinMode = Enum.LineJoinMode.Round
        popupStroke.Thickness = 2.90138888
        popupStroke.Transparency = 0
        popupStroke.Parent = popup

        local shadow = Instance.new("ImageLabel")
        shadow.Name = "shadow"
        shadow.AnchorPoint = Vector2.new(0.5, 0.5)
        shadow.BackgroundTransparency = 1
        shadow.Image = "rbxassetid://14001321443"
        shadow.ImageColor3 = Color3.new(0, 0, 0)
        shadow.ImageTransparency = 0.75
        shadow.Position = UDim2.fromScale(0.5, 0.5)
        shadow.ScaleType = Enum.ScaleType.Slice
        shadow.Size = UDim2.new(1, 35, 1, 35)
        shadow.SliceCenter = Rect.new(50, 50, 150, 150)
        shadow.SliceScale = 1
        shadow.ZIndex = 79
        shadow.Parent = popup

        local background = Instance.new("ImageLabel")
        background.Name = "background"
        background.AnchorPoint = Vector2.new(0, 1)
        background.BackgroundTransparency = 1
        background.Image = "rbxassetid://13581793331"
        background.ImageColor3 = Color3.new(0.0784313753, 0.227450997, 0.262745112)
        background.ImageTransparency = 0.949999988
        background.Position = UDim2.new(0, 0, 1, 0)
        background.ScaleType = Enum.ScaleType.Tile
        background.Size = UDim2.fromScale(1, 1)
        background.TileSize = UDim2.fromOffset(171, 135)
        background.ZIndex = 81
        background.Parent = popup

        local backgroundCorner = Instance.new("UICorner")
        backgroundCorner.CornerRadius = UDim.new(0.08, 0)
        backgroundCorner.Parent = background

        local backgroundGradient = Instance.new("UIGradient")
        backgroundGradient.Rotation = -90
        backgroundGradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(1, 1, 1))
        backgroundGradient.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(0.310086995, 0.393750012),
            NumberSequenceKeypoint.new(0.495640993, 0.59375),
            NumberSequenceKeypoint.new(0.738480985, 0.824999988),
            NumberSequenceKeypoint.new(1, 1),
        })
        backgroundGradient.Parent = background

        local title = Instance.new("TextLabel")
        title.Name = "Title"
        title.BackgroundTransparency = 1
        title.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
        title.Position = UDim2.fromOffset(10, 8)
        title.Size = UDim2.new(1, -50, 0, 28)
        title.Text = "Colors"
        title.TextColor3 = Color3.fromRGB(42, 43, 49)
        title.TextScaled = true
        title.TextStrokeTransparency = 1
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.ZIndex = 83
        title.Parent = popup

        local titleConstraint = Instance.new("UITextSizeConstraint")
        titleConstraint.MinTextSize = 12
        titleConstraint.MaxTextSize = 20
        titleConstraint.Parent = title

        local close = Instance.new("ImageButton")
        close.Name = "Close"
        close.Active = true
        close.AnchorPoint = Vector2.new(0.5, 0.5)
        close.AutoButtonColor = true
        close.BackgroundTransparency = 1
        close.Image = "rbxassetid://14423621163"
        close.PressedImage = "rbxassetid://14423621349"
        close.Position = UDim2.new(1, -2, 0, 0)
        close.ScaleType = Enum.ScaleType.Slice
        close.Size = UDim2.fromOffset(38, 38)
        close.SliceCenter = Rect.new(20, 20, 80, 80)
        close.SliceScale = 0.967129648
        close.ZIndex = 88
        close.Parent = popup

        local closeGradient = Instance.new("UIGradient")
        closeGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.new(1, 0.00784313958, 0.239216)),
            ColorSequenceKeypoint.new(1, Color3.new(1, 0.152941003, 0.49019599)),
        })
        closeGradient.Rotation = -90
        closeGradient.Parent = close

        local closeShadow = Instance.new("ImageLabel")
        closeShadow.Name = "shadow"
        closeShadow.AnchorPoint = Vector2.new(0.5, 0.5)
        closeShadow.BackgroundTransparency = 1
        closeShadow.Image = "rbxassetid://14001321443"
        closeShadow.ImageColor3 = Color3.new(0, 0, 0)
        closeShadow.ImageTransparency = 0.75
        closeShadow.Position = UDim2.fromScale(0.5, 0.6)
        closeShadow.ScaleType = Enum.ScaleType.Slice
        closeShadow.Size = UDim2.new(1, 0, 1.1, 0)
        closeShadow.SliceCenter = Rect.new(50, 50, 150, 150)
        closeShadow.SliceScale = 0.75
        closeShadow.ZIndex = 87
        closeShadow.Parent = close

        local closeText = Instance.new("TextLabel")
        closeText.Name = "TextLabel"
        closeText.AnchorPoint = Vector2.new(0.5, 0.5)
        closeText.BackgroundTransparency = 1
        closeText.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
        closeText.Position = UDim2.fromScale(0.5, 0.5)
        closeText.Size = UDim2.fromScale(0.9, 0.6)
        closeText.Text = "X"
        closeText.TextColor3 = Color3.new(1, 1, 1)
        closeText.TextScaled = true
        closeText.ZIndex = 89
        closeText.Parent = close

        local closeTextStroke = Instance.new("UIStroke")
        closeTextStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
        closeTextStroke.Color = Color3.new(0, 0, 0)
        closeTextStroke.LineJoinMode = Enum.LineJoinMode.Bevel
        closeTextStroke.Thickness = 2.90138888
        closeTextStroke.Parent = closeText

        local sv = Instance.new("TextButton")
        sv.Name = "SaturationValue"
        sv.Active = true
        sv.AutoButtonColor = false
        sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
        sv.BorderSizePixel = 0
        sv.Position = UDim2.fromOffset(10, 48)
        sv.Size = UDim2.fromOffset(106, 154)
        sv.Text = ""
        sv.ZIndex = 83
        sv.Parent = popup

        local svCorner = Instance.new("UICorner")
        svCorner.CornerRadius = UDim.new(0, 12)
        svCorner.Parent = sv

        local svStroke = Instance.new("UIStroke")
        svStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        svStroke.Color = Color3.new(0, 0, 0)
        svStroke.LineJoinMode = Enum.LineJoinMode.Round
        svStroke.Thickness = 2
        svStroke.Parent = sv

        local whiteGradient = Instance.new("UIGradient")
        whiteGradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(1, 1, 1))
        whiteGradient.Transparency = NumberSequence.new(0, 1)
        whiteGradient.Parent = sv

        local dark = Instance.new("Frame")
        dark.BackgroundColor3 = Color3.new(0, 0, 0)
        dark.BorderSizePixel = 0
        dark.Size = UDim2.fromScale(1, 1)
        dark.ZIndex = 84
        dark.Parent = sv

        local darkCorner = svCorner:Clone()
        darkCorner.Parent = dark

        local darkGradient = Instance.new("UIGradient")
        darkGradient.Rotation = 90
        darkGradient.Color = ColorSequence.new(Color3.new(0, 0, 0), Color3.new(0, 0, 0))
        darkGradient.Transparency = NumberSequence.new(1, 0)
        darkGradient.Parent = dark

        local cursor = Instance.new("ImageLabel")
        cursor.Name = "Cursor"
        cursor.AnchorPoint = Vector2.new(0.5, 0.5)
        cursor.BackgroundTransparency = 1
        cursor.Image = "rbxassetid://15055735376"
        cursor.ImageColor3 = Color3.new(1, 1, 1)
        cursor.Size = UDim2.fromOffset(16, 16)
        cursor.ZIndex = 86
        cursor.Parent = sv

        local hue = Instance.new("TextButton")
        hue.Name = "Hue"
        hue.Active = true
        hue.AutoButtonColor = false
        hue.BackgroundColor3 = Color3.new(1, 1, 1)
        hue.BorderSizePixel = 0
        hue.Position = UDim2.fromOffset(123, 48)
        hue.Size = UDim2.fromOffset(15, 154)
        hue.Text = ""
        hue.ZIndex = 83
        hue.Parent = popup

        local hueCorner = Instance.new("UICorner")
        hueCorner.CornerRadius = UDim.new(0, 7)
        hueCorner.Parent = hue

        local hueStroke = Instance.new("UIStroke")
        hueStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        hueStroke.Color = Color3.new(0, 0, 0)
        hueStroke.LineJoinMode = Enum.LineJoinMode.Round
        hueStroke.Thickness = 2
        hueStroke.Parent = hue

        local hueGradient = Instance.new("UIGradient")
        hueGradient.Rotation = 90
        hueGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)),
            ColorSequenceKeypoint.new(0.17, Color3.fromHSV(0.17, 1, 1)),
            ColorSequenceKeypoint.new(0.33, Color3.fromHSV(0.33, 1, 1)),
            ColorSequenceKeypoint.new(0.5, Color3.fromHSV(0.5, 1, 1)),
            ColorSequenceKeypoint.new(0.67, Color3.fromHSV(0.67, 1, 1)),
            ColorSequenceKeypoint.new(0.83, Color3.fromHSV(0.83, 1, 1)),
            ColorSequenceKeypoint.new(1, Color3.fromHSV(1, 1, 1)),
        })
        hueGradient.Parent = hue

        local hueCursor = Instance.new("ImageLabel")
        hueCursor.Name = "HueCursor"
        hueCursor.AnchorPoint = Vector2.new(0.5, 0.5)
        hueCursor.BackgroundTransparency = 1
        hueCursor.Image = "rbxassetid://14423621163"
        hueCursor.ImageColor3 = Color3.new(1, 1, 1)
        hueCursor.ScaleType = Enum.ScaleType.Slice
        hueCursor.Size = UDim2.fromOffset(23, 10)
        hueCursor.SliceCenter = Rect.new(20, 20, 80, 80)
        hueCursor.SliceScale = 0.45
        hueCursor.ZIndex = 86
        hueCursor.Parent = hue

        local preview = Instance.new("ImageLabel")
        preview.Name = "Preview"
        preview.BackgroundTransparency = 1
        preview.Image = "rbxassetid://14423621163"
        preview.ImageColor3 = currentColor
        preview.Position = UDim2.fromOffset(10, 213)
        preview.ScaleType = Enum.ScaleType.Slice
        preview.Size = UDim2.fromOffset(128, 38)
        preview.SliceCenter = Rect.new(20, 20, 80, 80)
        preview.SliceScale = 0.967129648
        preview.ZIndex = 83
        preview.Parent = popup

        local hexInput = Instance.new("TextBox")
        hexInput.Name = "Hex"
        hexInput.BackgroundTransparency = 1
        hexInput.ClearTextOnFocus = false
        hexInput.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
        hexInput.PlaceholderText = "#FFFFFF"
        hexInput.Position = UDim2.fromOffset(6, 4)
        hexInput.Size = UDim2.new(1, -12, 1, -8)
        hexInput.Text = colorToHex(currentColor)
        hexInput.TextColor3 = Color3.new(1, 1, 1)
        hexInput.TextScaled = true
        hexInput.TextStrokeColor3 = Color3.new(0, 0, 0)
        hexInput.TextStrokeTransparency = 0
        hexInput.ZIndex = 84
        hexInput.Parent = preview

        local hexConstraint = Instance.new("UITextSizeConstraint")
        hexConstraint.MinTextSize = 12
        hexConstraint.MaxTextSize = 18
        hexConstraint.Parent = hexInput

        local confirm = Instance.new("ImageButton")
        confirm.Name = "Confirm"
        confirm.Active = true
        confirm.AutoButtonColor = true
        confirm.BackgroundTransparency = 1
        confirm.Image = "rbxassetid://14423621163"
        confirm.PressedImage = "rbxassetid://14423621349"
        confirm.Position = UDim2.fromOffset(10, 261)
        confirm.ScaleType = Enum.ScaleType.Slice
        confirm.Size = UDim2.fromOffset(128, 38)
        confirm.SliceCenter = Rect.new(20, 20, 80, 80)
        confirm.SliceScale = 0.967129648
        confirm.ZIndex = 83
        confirm.Parent = popup

        local confirmGradientSource = Gradients:FindFirstChild("GreenGradient")
        if confirmGradientSource then
            confirmGradientSource:Clone().Parent = confirm
        else
            local confirmGradient = Instance.new("UIGradient")
            confirmGradient.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.new(0.360783994, 0.937255025, 0)),
                ColorSequenceKeypoint.new(1, Color3.new(0.639216006, 0.992156982, 0.109803997)),
            })
            confirmGradient.Rotation = -90
            confirmGradient.Parent = confirm
        end

        local confirmShadow = Instance.new("ImageLabel")
        confirmShadow.Name = "shadow"
        confirmShadow.AnchorPoint = Vector2.new(0.5, 0.5)
        confirmShadow.BackgroundTransparency = 1
        confirmShadow.Image = "rbxassetid://14001321443"
        confirmShadow.ImageColor3 = Color3.new(0, 0, 0)
        confirmShadow.ImageTransparency = 0.75
        confirmShadow.Position = UDim2.fromScale(0.5, 0.6)
        confirmShadow.ScaleType = Enum.ScaleType.Slice
        confirmShadow.Size = UDim2.new(1, 0, 1.1, 0)
        confirmShadow.SliceCenter = Rect.new(50, 50, 150, 150)
        confirmShadow.SliceScale = 0.75
        confirmShadow.ZIndex = 82
        confirmShadow.Parent = confirm

        local confirmText = Instance.new("TextLabel")
        confirmText.Name = "TextLabel"
        confirmText.AnchorPoint = Vector2.new(0.5, 0.5)
        confirmText.BackgroundTransparency = 1
        confirmText.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
        confirmText.Position = UDim2.fromScale(0.5, 0.5)
        confirmText.Size = UDim2.new(1, -12, 0.72, 0)
        confirmText.Text = "Confirm"
        confirmText.TextColor3 = Color3.new(1, 1, 1)
        confirmText.TextScaled = true
        confirmText.ZIndex = 85
        confirmText.Parent = confirm

        local confirmTextConstraint = Instance.new("UITextSizeConstraint")
        confirmTextConstraint.MinTextSize = 13
        confirmTextConstraint.MaxTextSize = 20
        confirmTextConstraint.Parent = confirmText

        local confirmTextStroke = Instance.new("UIStroke")
        confirmTextStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
        confirmTextStroke.Color = Color3.new(0, 0, 0)
        confirmTextStroke.LineJoinMode = Enum.LineJoinMode.Bevel
        confirmTextStroke.Thickness = 2.2
        confirmTextStroke.Parent = confirmText

        local svInput = Instance.new("TextButton")
        svInput.Name = "Input"
        svInput.Active = true
        svInput.AutoButtonColor = false
        svInput.BackgroundTransparency = 1
        svInput.Size = UDim2.fromScale(1, 1)
        svInput.Text = ""
        svInput.ZIndex = 87
        svInput.Parent = sv

        local hueInput = Instance.new("TextButton")
        hueInput.Name = "Input"
        hueInput.Active = true
        hueInput.AutoButtonColor = false
        hueInput.BackgroundTransparency = 1
        hueInput.Size = UDim2.fromScale(1, 1)
        hueInput.Text = ""
        hueInput.ZIndex = 87
        hueInput.Parent = hue

        local open = false
        local destroyed = false
        local draggingSV = false
        local draggingHue = false
        local activeSVInput
        local activeHueInput
        local popupTargetPosition = popup.Position
        local colorBeforeOpen = currentColor

        local function toVector2(position)
            if typeof(position) == "Vector2" then
                return position
            end
            return Vector2.new(position.X, position.Y)
        end

        local function getViewportSize()
            local camera = workspace.CurrentCamera
            if camera then
                return camera.ViewportSize
            end
            return Vector2.new(1920, 1080)
        end

        local function positionPopup(applyPosition)
            local viewport = getViewportSize()
            local framePosition = self.Frame.AbsolutePosition
            local frameSize = self.Frame.AbsoluteSize
            local popupSize = popup.AbsoluteSize
            if popupSize.X <= 0 or popupSize.Y <= 0 then
                popupSize = Vector2.new(148, 310)
            end

            local x = framePosition.X + frameSize.X + 12
            x = math.clamp(x, 8, math.max(8, viewport.X - popupSize.X - 8))
            local y = framePosition.Y + 128
            y = math.clamp(y, 8, math.max(8, viewport.Y - popupSize.Y - 8))
            popupTargetPosition = UDim2.fromOffset(math.round(x), math.round(y))

            if applyPosition ~= false then
                popup.Position = popupTargetPosition
            end
        end

        local function render(fire)
            currentColor = Color3.fromHSV(h, s, v)
            clearGradient(button)
            button.BackgroundColor3 = currentColor
            if button:IsA("ImageButton") or button:IsA("ImageLabel") then
                button.ImageColor3 = currentColor
                button.ImageTransparency = 0
            end
            label.Text = colorToHex(currentColor)
            hexInput.Text = colorToHex(currentColor)
            sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
            cursor.Position = UDim2.fromScale(s, 1 - v)
            hueCursor.Position = UDim2.fromScale(0.5, h)
            preview.ImageColor3 = currentColor
            if fire then
                safeCall(settings.Callback, currentColor)
            end
        end

        local function restoreColor(color)
            currentColor = tableToColor(color, currentColor)
            h, s, v = currentColor:ToHSV()
            render(false)
        end

        local function updateSV(position)
            local point = toVector2(position)
            local relative = point - sv.AbsolutePosition
            s = math.clamp(relative.X / math.max(1, sv.AbsoluteSize.X), 0, 1)
            v = 1 - math.clamp(relative.Y / math.max(1, sv.AbsoluteSize.Y), 0, 1)
            render(false)
        end

        local function updateHue(position)
            local point = toVector2(position)
            local relative = point - hue.AbsolutePosition
            h = math.clamp(relative.Y / math.max(1, hue.AbsoluteSize.Y), 0, 1)
            render(false)
        end

        local closePicker

        closePicker = function(immediate, keepCurrent)
            if destroyed then
                return
            end
            if not open and not popup.Visible then
                return
            end

            if not keepCurrent then
                restoreColor(colorBeforeOpen)
            end

            open = false
            draggingSV = false
            draggingHue = false
            activeSVInput = nil
            activeHueInput = nil

            if self.ActiveDropdownClose == closePicker then
                self.ActiveDropdownClose = nil
            end
            if self.ActiveDropdownRoot == popup then
                self.ActiveDropdownRoot = nil
            end

            if immediate then
                popup.Visible = false
                popup.Position = popupTargetPosition
                return
            end

            local closedPosition = UDim2.fromOffset(popupTargetPosition.X.Offset + 12, popupTargetPosition.Y.Offset)
            TweenService:Create(popup, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {
                Position = closedPosition,
            }):Play()

            task.delay(0.21, function()
                if not destroyed and not open then
                    popup.Visible = false
                    popup.Position = popupTargetPosition
                end
            end)
        end

        local function openPicker()
            if destroyed then
                return
            end
            if open then
                closePicker(false, false)
                return
            end

            if self.ActiveDropdownClose and self.ActiveDropdownClose ~= closePicker then
                self.ActiveDropdownClose(false)
            end

            colorBeforeOpen = currentColor
            open = true
            self.ActiveDropdownClose = closePicker
            self.ActiveDropdownRoot = popup
            positionPopup(false)
            popup.Position = UDim2.fromOffset(popupTargetPosition.X.Offset + 12, popupTargetPosition.Y.Offset)
            popup.Visible = true
            TweenService:Create(popup, TweenInfo.new(0.25, Enum.EasingStyle.Quint), {
                Position = popupTargetPosition,
            }):Play()
        end

        button.Activated:Connect(openPicker)
        close.Activated:Connect(function()
            closePicker(false, false)
        end)
        confirm.Activated:Connect(function()
            if not open or destroyed then
                return
            end
            colorBeforeOpen = currentColor
            safeCall(settings.Callback, currentColor)
            closePicker(false, true)
        end)
        GUIFX.ButtonFX(close)
        GUIFX.ButtonFX(confirm)

        svInput.InputBegan:Connect(function(inputObject)
            if inputObject.UserInputType == Enum.UserInputType.MouseButton1 or inputObject.UserInputType == Enum.UserInputType.Touch then
                draggingSV = true
                activeSVInput = inputObject.UserInputType == Enum.UserInputType.Touch and inputObject or nil
                updateSV(inputObject.Position)
            end
        end)

        hueInput.InputBegan:Connect(function(inputObject)
            if inputObject.UserInputType == Enum.UserInputType.MouseButton1 or inputObject.UserInputType == Enum.UserInputType.Touch then
                draggingHue = true
                activeHueInput = inputObject.UserInputType == Enum.UserInputType.Touch and inputObject or nil
                updateHue(inputObject.Position)
            end
        end)

        UserInputService.InputChanged:Connect(function(inputObject)
            if draggingSV then
                if inputObject.UserInputType == Enum.UserInputType.MouseMovement or inputObject == activeSVInput then
                    updateSV(inputObject.Position)
                end
            elseif draggingHue then
                if inputObject.UserInputType == Enum.UserInputType.MouseMovement or inputObject == activeHueInput then
                    updateHue(inputObject.Position)
                end
            end
        end)

        UserInputService.InputEnded:Connect(function(inputObject)
            if inputObject.UserInputType == Enum.UserInputType.MouseButton1 or inputObject == activeSVInput then
                draggingSV = false
                activeSVInput = nil
            end
            if inputObject.UserInputType == Enum.UserInputType.MouseButton1 or inputObject == activeHueInput then
                draggingHue = false
                activeHueInput = nil
            end
        end)

        hexInput.FocusLost:Connect(function()
            local parsed = tableToColor(hexInput.Text, currentColor)
            h, s, v = parsed:ToHSV()
            render(false)
        end)

        row:GetPropertyChangedSignal("Visible"):Connect(function()
            if not row.Visible then
                closePicker(true, false)
            end
        end)

        row.Destroying:Connect(function()
            if self.ActiveDropdownClose == closePicker then
                self.ActiveDropdownClose = nil
            end
            if self.ActiveDropdownRoot == popup then
                self.ActiveDropdownRoot = nil
            end
            destroyed = true
            if popup then
                popup:Destroy()
                popup = nil
            end
        end)

        self.Frame:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
            if open and not destroyed then
                positionPopup(true)
            end
        end)

        self.Frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
            if open and not destroyed then
                positionPopup(true)
            end
        end)

        local control = {
            Get = function()
                return currentColor
            end,
            Set = function(_, value, silent)
                currentColor = tableToColor(value, currentColor)
                h, s, v = currentColor:ToHSV()
                colorBeforeOpen = currentColor
                render(not silent)
                return currentColor
            end,
            Serialize = function()
                return colorToTable(currentColor)
            end,
            Open = function()
                openPicker()
            end,
            Close = function()
                closePicker(false, false)
            end,
            Destroy = function()
                if destroyed then
                    return
                end
                closePicker(true, true)
                destroyed = true
                if popup then
                    popup:Destroy()
                    popup = nil
                end
                if row then
                    row:Destroy()
                end
            end,
        }

        render(false)
        return self:_decorateControl(control, row, settings, "ColorPicker")
    end


    function Library:_ensureSubTabBar()
        if self.SubTabBar then
            return self.SubTabBar
        end
        local bar = Instance.new("Frame")
        bar.Name = "SideTabs"
        bar.AnchorPoint = Vector2.new(0.5, 0)
        bar.BackgroundTransparency = 1
        bar.Position = UDim2.new(0.5, 0, 0, 0)
        bar.Size = UDim2.new(1, -14, 0, 42)
        bar.Visible = false
        bar.ZIndex = 70
        bar.Parent = self.ItemsFrame.Parent

        local padding = Instance.new("UIPadding")
        padding.PaddingLeft = UDim.new(0, 8)
        padding.PaddingRight = UDim.new(0, 8)
        padding.Parent = bar

        local layout = Instance.new("UIListLayout")
        layout.FillDirection = Enum.FillDirection.Horizontal
        layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        layout.Padding = UDim.new(0, 8)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.VerticalAlignment = Enum.VerticalAlignment.Center
        layout.Parent = bar

        self.SubTabBar = bar
        return bar
    end

    function Library:_renderSubTabs()
        local bar = self:_ensureSubTabBar()
        for _, child in ipairs(bar:GetChildren()) do
            if child:IsA("GuiButton") then
                child:Destroy()
            end
        end
        local subTabs = self.SubTabsByTab[self.ActiveTab]
        if not subTabs or #subTabs.Order == 0 then
            bar.Visible = false
            self:_applyContentInsets()
            return
        end
        bar.Visible = true
        local activeName = self.ActiveSubTabByTab[self.ActiveTab] or subTabs.Order[1]
        self.ActiveSubTabByTab[self.ActiveTab] = activeName
        for index, name in ipairs(subTabs.Order) do
            local data = subTabs.Map[name]
            local isActive = name == activeName
            local iconOffset = data.Icon and 22 or 0
            local width = math.max(96, #name * 11 + 40 + iconOffset)

            local button = Instance.new("ImageButton")
            button.Name = name
            button.Active = true
            button.AutoButtonColor = false
            button.BackgroundTransparency = 1
            button.Image = "rbxassetid://14423621163"
            button.PressedImage = "rbxassetid://14423621349"
            button.ScaleType = Enum.ScaleType.Slice
            button.SliceCenter = Rect.new(20, 20, 80, 80)
            button.SliceScale = 0.967129648
            button.LayoutOrder = index
            button.Size = UDim2.fromOffset(width, isActive and 40 or 36)
            button.ZIndex = 71
            button.Parent = bar

            local inner = Instance.new("Frame")
            inner.Name = "Fill"
            inner.AnchorPoint = Vector2.new(0.5, 0.5)
            inner.BackgroundColor3 = Color3.new(1, 1, 1)
            inner.BorderSizePixel = 0
            inner.Position = UDim2.fromScale(0.5, 0.5)
            inner.Size = UDim2.new(1, -12, 1, -10)
            inner.ZIndex = 72
            inner.Parent = button

            local innerCorner = Instance.new("UICorner")
            innerCorner.CornerRadius = UDim.new(0.45, 0)
            innerCorner.Parent = inner

            local innerStroke = Instance.new("UIStroke")
            innerStroke.Color = Color3.fromRGB(42, 43, 49)
            innerStroke.Thickness = isActive and 3.2 or 2.6
            innerStroke.Parent = inner

            local gradient = Gradients:FindFirstChild(isActive and "GreenGradient" or "LightGreyGradient") or Gradients:FindFirstChild(isActive and "GreenGradient" or "GreyGradient")
            if gradient then
                gradient:Clone().Parent = inner
            end

            local label = Instance.new("TextLabel")
            label.Name = "Label"
            label.BackgroundTransparency = 1
            label.AnchorPoint = Vector2.new(0.5, 0.5)
            label.Position = UDim2.fromScale(0.5, 0.5)
            label.Size = UDim2.new(1, data.Icon and -16 or -12, 1, 0)
            label.ZIndex = 73
            label.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
            label.Text = name
            label.TextScaled = true
            label.TextWrapped = true
            label.TextColor3 = isActive and Color3.new(1, 1, 1) or Color3.fromRGB(76, 76, 84)
            label.TextStrokeColor3 = Color3.new(0, 0, 0)
            label.TextStrokeTransparency = isActive and 0 or 0.35
            label.Parent = inner

            local textConstraint = Instance.new("UITextSizeConstraint")
            textConstraint.MinTextSize = 12
            textConstraint.MaxTextSize = 20
            textConstraint.Parent = label

            if data.Icon then
                local icon = Instance.new("ImageLabel")
                icon.BackgroundTransparency = 1
                icon.AnchorPoint = Vector2.new(0, 0.5)
                icon.Image = data.Icon
                icon.Position = UDim2.new(0, 10, 0.5, 0)
                icon.Size = UDim2.fromOffset(20, 20)
                icon.ZIndex = 74
                icon.Parent = inner
                label.Position = UDim2.new(0.5, 10, 0.5, 0)
                label.Size = UDim2.new(1, -32, 1, 0)
            end

            GUIFX.ButtonFX(button, isActive and 1.045 or 1.03)
            button.Activated:Connect(function()
                self:SelectSubTab(self.ActiveTab, name)
                safeCall(data.Callback, name)
            end)
            data.Button = button
        end
        self:_applyContentInsets()
    end

    function Library:SelectSubTab(tabName, subTabName)
        local collection = self.SubTabsByTab[tabName]
        assert(collection and collection.Map[subTabName], "Unknown subtab: " .. tostring(subTabName))
        if self.ActiveDropdownClose then
            self.ActiveDropdownClose(true)
        end
        self.ActiveSubTabByTab[tabName] = subTabName
        self.PageByTab[tabName] = 1
        if self.SearchInput then
            self.SearchInput.Text = ""
        end
        if self.ActiveTab == tabName then
            self:_renderSubTabs()
            self:_refreshPagination()
        end
    end

    function Library:AddSubTab(tabName, subTabSettings, legacyIcon)
        local settings = type(subTabSettings) == "table" and subTabSettings or {
            Name = tostring(subTabSettings),
            Icon = legacyIcon,
        }
        settings.Name = tostring(settings.Name or "SubTab")
        local collection = self.SubTabsByTab[tabName]
        if not collection then
            collection = {Order = {}, Map = {}}
            self.SubTabsByTab[tabName] = collection
        end
        assert(not collection.Map[settings.Name], "A subtab named '" .. settings.Name .. "' already exists")
        local data = {
            Name = settings.Name,
            Icon = settings.Icon,
            Callback = settings.Callback,
        }
        collection.Map[settings.Name] = data
        table.insert(collection.Order, settings.Name)
        if not self.ActiveSubTabByTab[tabName] then
            self.ActiveSubTabByTab[tabName] = settings.Name
        end
        local subTab = {
            Name = settings.Name,
            Tab = tabName,
            Window = self,
        }
        function subTab:Select()
            self.Window:SelectSubTab(self.Tab, self.Name)
        end
        function subTab:_add(methodName, ...)
            local oldSubTab = self.Window._MountSubTab
            self.Window._MountSubTab = self.Name
            local result = self.Window:_withTab(self.Tab, methodName, ...)
            self.Window._MountSubTab = oldSubTab
            return result
        end
        for _, methodName in ipairs({"AddSection", "AddButton", "AddToggle", "AddSelector", "AddDropdown", "AddSlider", "AddKeybind", "AddProgress", "AddColorPicker"}) do
            subTab[methodName] = function(selfSubTab, ...)
                return selfSubTab:_add(methodName, ...)
            end
        end
        if self.ActiveTab == tabName then
            self:_renderSubTabs()
            self:_refreshPagination()
        end
        return subTab
    end

    local OriginalSelectTabV8 = Library.SelectTab
    function Library:SelectTab(tabName)
        OriginalSelectTabV8(self, tabName)
        self:_renderSubTabs()
        self:_refreshPagination()
    end

    local OriginalCreateTabV8 = Library.CreateTab
    function Library:CreateTab(tabSettings, legacyIcon)
        local tab = OriginalCreateTabV8(self, tabSettings, legacyIcon)
        function tab:AddSubTab(settings, icon)
            return self.Window:AddSubTab(self.Name, settings, icon)
        end
        for _, methodName in ipairs({"AddKeybind", "AddProgress", "AddColorPicker"}) do
            tab[methodName] = function(_, ...)
                return self:_withTab(tab.Name, methodName, ...)
            end
        end
        return tab
    end

    local OriginalGetConfigDataV8 = Library.GetConfigData
    function Library:GetConfigData()
        local data = {}
        for flag, binding in pairs(self.ConfigBindings) do
            local control = binding.Control
            local ok, value
            if type(control.Serialize) == "function" then
                ok, value = pcall(control.Serialize, control)
            else
                ok, value = pcall(control.Get, control)
            end
            if ok then
                data[flag] = copyValue(value)
            end
        end
        return data
    end

    function Library:_applyConfigData(data, useDefaults)
        for flag, binding in pairs(self.ConfigBindings) do
            local value = data and data[flag]
            if value == nil and useDefaults then
                value = binding.Default
            end
            if value ~= nil then
                local control = binding.Control
                local setter = type(control.Deserialize) == "function" and control.Deserialize or control.Set
                local ok = pcall(setter, control, copyValue(value), false)
                if not ok and not valuesEqual(value, binding.Default) then
                    pcall(setter, control, copyValue(binding.Default), false)
                end
            end
        end
    end

    function Library:_profilePath(profileName)
        local settings = self.ConfigSettings
        assert(settings, "Call EnableConfig before using config profiles")
        local profile = sanitizeProfileName(profileName or settings.Profile or "Default")
        local base = settings.BaseFileName or settings.FileName or "Settings.json"
        base = base:gsub("%.json$", "")
        return settings.FolderName .. "/" .. base .. "_" .. profile .. ".json", profile
    end

    function Library:SetConfigProfile(profileName)
        local path, profile = self:_profilePath(profileName)
        self.ConfigSettings.Profile = profile
        self.ConfigSettings.Path = path
        self.ConfigSettings.FileName = path:match("([^/]+)$") or self.ConfigSettings.FileName
        self.ConfigLastJSON = nil
        self.KnownProfiles[profile] = true
        return profile
    end

    local OriginalEnableConfigV8 = Library.EnableConfig
    function Library:EnableConfig(configSettings)
        configSettings = configSettings or {}
        OriginalEnableConfigV8(self, configSettings)
        self.ConfigSettings.BaseFileName = self.ConfigSettings.FileName
        self.ConfigSettings.Profile = sanitizeProfileName(configSettings.Profile or "Default")
        self.KnownProfiles = self.KnownProfiles or {}
        self:SetConfigProfile(self.ConfigSettings.Profile)
        return self
    end

    local OriginalLoadConfigV8 = Library.LoadConfig
    function Library:LoadConfig(profileName)
        if profileName ~= nil then
            self:SetConfigProfile(profileName)
        end
        return OriginalLoadConfigV8(self)
    end

    local OriginalSaveConfigV8 = Library.SaveConfig
    function Library:SaveConfig(profileName)
        if profileName ~= nil then
            self:SetConfigProfile(profileName)
        end
        return OriginalSaveConfigV8(self)
    end

    local OriginalDeleteConfigV8 = Library.DeleteConfig
    function Library:DeleteConfig(profileName)
        if profileName ~= nil then
            self:SetConfigProfile(profileName)
        end
        local profile = self.ConfigSettings and self.ConfigSettings.Profile
        local ok, message = OriginalDeleteConfigV8(self)
        if ok and profile then
            self.KnownProfiles[profile] = nil
        end
        return ok, message
    end

    function Library:CreateConfig(profileName, loadAfterCreate)
        local profile = self:SetConfigProfile(profileName)
        local ok, message = self:SaveConfig()
        if ok and loadAfterCreate == true then
            self:LoadConfig(profile)
        end
        return ok, message
    end

    function Library:GetConfigList()
        local result = {}
        for profile in pairs(self.KnownProfiles or {}) do
            table.insert(result, profile)
        end
        if type(listfiles) == "function" and self.ConfigSettings then
            local ok, files = pcall(listfiles, self.ConfigSettings.FolderName)
            if ok and type(files) == "table" then
                local base = (self.ConfigSettings.BaseFileName or "Settings.json"):gsub("%.json$", "")
                for _, path in ipairs(files) do
                    local file = tostring(path):match("([^/\\]+)$") or tostring(path)
                    local profile = file:match("^" .. base:gsub("([^%w])", "%%%1") .. "_(.+)%.json$")
                    if profile and not table.find(result, profile) then
                        table.insert(result, profile)
                    end
                end
            end
        end
        table.sort(result)
        return result
    end

    function Library:_configureResponsive(settings)
        self.ResponsiveSettings = settings
        local scale = self.Frame:FindFirstChild("ResponsiveScale")
        if not scale then
            scale = Instance.new("UIScale")
            scale.Name = "ResponsiveScale"
            scale.Parent = self.Frame
        end
        self.ResponsiveScale = scale
        local function update()
            if settings.Enabled == false then
                scale.Scale = 1
                return
            end
            local camera = workspace.CurrentCamera
            local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
            local design = settings.DesignResolution or Vector2.new(1280, 720)
            local factor = math.min(viewport.X / design.X, viewport.Y / design.Y)
            scale.Scale = math.clamp(factor, tonumber(settings.MinimumScale) or 0.68, tonumber(settings.MaximumScale) or 1.15)
        end
        if workspace.CurrentCamera then
            table.insert(self._V8Connections, workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(update))
        end
        update()
    end

    function Library:_configureLauncherDrag(settings)
        local button = self.LauncherButton
        if not button or settings.Draggable == false then
            return
        end
        local dragging = false
        local dragInput
        local startPosition
        local startPointer
        table.insert(self._V8Connections, button.InputBegan:Connect(function(inputObject)
            if inputObject.UserInputType == Enum.UserInputType.MouseButton1 or inputObject.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragInput = inputObject
                startPointer = inputObject.Position
                startPosition = button.Position
            end
        end))
        table.insert(self._V8Connections, UserInputService.InputChanged:Connect(function(inputObject)
            if not dragging then
                return
            end
            if inputObject.UserInputType == Enum.UserInputType.MouseMovement or inputObject == dragInput then
                local delta = inputObject.Position - startPointer
                button.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X, startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
            end
        end))
        table.insert(self._V8Connections, UserInputService.InputEnded:Connect(function(inputObject)
            if inputObject.UserInputType == Enum.UserInputType.MouseButton1 or inputObject == dragInput then
                dragging = false
                dragInput = nil
            end
        end))
    end

    function Library:_configureGamepad(settings)
        if settings.Enabled == false then
            return
        end
        local actionName = "PlantVsCoinsUI_Gamepad_" .. HttpService:GenerateGUID(false)
        self.GamepadActionName = actionName
        ContextActionService:BindAction(actionName, function(_, state, inputObject)
            if state ~= Enum.UserInputState.Begin or not self:IsVisible() then
                return Enum.ContextActionResult.Pass
            end
            if #self.TabOrder == 0 then
                return Enum.ContextActionResult.Pass
            end
            if inputObject.KeyCode == Enum.KeyCode.ButtonL1 then
                local index = table.find(self.TabOrder, self.ActiveTab) or 1
                index = ((index - 2) % #self.TabOrder) + 1
                self:SelectTab(self.TabOrder[index])
                return Enum.ContextActionResult.Sink
            elseif inputObject.KeyCode == Enum.KeyCode.ButtonR1 then
                local index = table.find(self.TabOrder, self.ActiveTab) or 1
                index = (index % #self.TabOrder) + 1
                self:SelectTab(self.TabOrder[index])
                return Enum.ContextActionResult.Sink
            elseif inputObject.KeyCode == Enum.KeyCode.DPadLeft then
                self:PreviousPage()
                return Enum.ContextActionResult.Sink
            elseif inputObject.KeyCode == Enum.KeyCode.DPadRight then
                self:NextPage()
                return Enum.ContextActionResult.Sink
            elseif inputObject.KeyCode == Enum.KeyCode.ButtonB and self.ActivePrompt then
                self.ActivePrompt:Cancel()
                return Enum.ContextActionResult.Sink
            end
            return Enum.ContextActionResult.Pass
        end, false, Enum.KeyCode.ButtonL1, Enum.KeyCode.ButtonR1, Enum.KeyCode.DPadLeft, Enum.KeyCode.DPadRight, Enum.KeyCode.ButtonB)
    end

    function Library:_configureOutsideClose()
        table.insert(self._V8Connections, UserInputService.InputBegan:Connect(function(inputObject)
            if not self.ActiveDropdownClose then
                return
            end
            if inputObject.UserInputType ~= Enum.UserInputType.MouseButton1 and inputObject.UserInputType ~= Enum.UserInputType.Touch then
                return
            end
            local position = inputObject.Position
            local point = Vector2.new(position.X, position.Y)
            local framePosition = self.Frame.AbsolutePosition
            local frameSize = self.Frame.AbsoluteSize
            local insideFrame = point.X >= framePosition.X
                and point.X <= framePosition.X + frameSize.X
                and point.Y >= framePosition.Y
                and point.Y <= framePosition.Y + frameSize.Y

            local insideActiveRoot = false
            local activeRoot = self.ActiveDropdownRoot
            if activeRoot and activeRoot.Parent and activeRoot.Visible then
                local rootPosition = activeRoot.AbsolutePosition
                local rootSize = activeRoot.AbsoluteSize
                insideActiveRoot = point.X >= rootPosition.X
                    and point.X <= rootPosition.X + rootSize.X
                    and point.Y >= rootPosition.Y
                    and point.Y <= rootPosition.Y + rootSize.Y
            end

            if not insideFrame and not insideActiveRoot then
                self.ActiveDropdownClose(false)
            end
        end))
    end

    local function resolveGargantuanInstance(value)
        if typeof(value) == "Instance" then
            return value
        end
        if type(value) ~= "string" or value == "" then
            return nil
        end

        local normalized = value
            :gsub("%[%\"([^%\"]+)%\"%]", ".%1")
            :gsub("%['([^']+)'%]", ".%1")
            :gsub("/", ".")
            :gsub("^game%.", "")

        local parts = {}
        for part in normalized:gmatch("[^%.]+") do
            table.insert(parts, part)
        end

        local current
        local startIndex = 1
        local first = parts[1]
        if first == "workspace" or first == "Workspace" then
            current = workspace
            startIndex = 2
        elseif first == "ReplicatedStorage" then
            current = game:GetService("ReplicatedStorage")
            startIndex = 2
        elseif first == "Players" then
            current = game:GetService("Players")
            startIndex = 2
        elseif first == "Lighting" then
            current = game:GetService("Lighting")
            startIndex = 2
        elseif first == "StarterGui" then
            current = game:GetService("StarterGui")
            startIndex = 2
        elseif first == "CoreGui" then
            current = game:GetService("CoreGui")
            startIndex = 2
        else
            current = game
        end

        for index = startIndex, #parts do
            if not current then
                return nil
            end
            current = current:FindFirstChild(parts[index])
        end

        if current then
            return current
        end

        local searchName = parts[#parts]
        if searchName and searchName ~= "" then
            return workspace:FindFirstChild(searchName, true)
                or game:GetService("ReplicatedStorage"):FindFirstChild(searchName, true)
        end
        return nil
    end

    local function findGargantuanPrimaryPart(model)
        if not model then
            return nil
        end
        if model:IsA("BasePart") then
            return model
        end
        if model:IsA("Model") then
            if model.PrimaryPart then
                return model.PrimaryPart
            end
            local preferred = model:FindFirstChild("HumanoidRootPart", true)
                or model:FindFirstChild("Root", true)
                or model:FindFirstChild("Main", true)
                or model:FindFirstChild("center", true)
            if preferred and preferred:IsA("BasePart") then
                model.PrimaryPart = preferred
                return preferred
            end
            for _, descendant in ipairs(model:GetDescendants()) do
                if descendant:IsA("BasePart") then
                    model.PrimaryPart = descendant
                    return descendant
                end
            end
        end
        return nil
    end

    local function sanitizeGargantuanModel(model)
        for _, descendant in ipairs(model:GetDescendants()) do
            if descendant:IsA("BaseScript") then
                descendant.Disabled = true
            elseif descendant:IsA("BasePart") then
                descendant.Anchored = true
                descendant.CanCollide = false
                descendant.CanQuery = false
                descendant.CanTouch = false
            end
        end
    end

    local function cloneGargantuanModel(source)
        if not source then
            return nil
        end
        local oldArchivable = source.Archivable
        if not oldArchivable then
            source.Archivable = true
        end
        local ok, clone = pcall(function()
            return source:Clone()
        end)
        source.Archivable = oldArchivable
        if not ok or not clone then
            return nil
        end
        if clone:IsA("BasePart") then
            local wrapper = Instance.new("Model")
            wrapper.Name = clone.Name
            clone.Parent = wrapper
            wrapper.PrimaryPart = clone
            clone = wrapper
        end
        if not clone:IsA("Model") then
            clone:Destroy()
            return nil
        end
        local primary = findGargantuanPrimaryPart(clone)
        if not primary then
            clone:Destroy()
            return nil
        end
        sanitizeGargantuanModel(clone)
        return clone
    end

    local function resolveGargantuanOrigin(value, player, pet)
        if typeof(value) == "CFrame" then
            return value
        elseif typeof(value) == "Vector3" then
            return CFrame.new(value)
        elseif typeof(value) == "Instance" then
            if value:IsA("Model") then
                return value:GetPivot()
            elseif value:IsA("BasePart") then
                return value.CFrame
            end
        end

        if player and player.Character then
            local root = player.Character:FindFirstChild("HumanoidRootPart")
            if root then
                return root.CFrame
            end
            if player.Character:IsA("Model") then
                return player.Character:GetPivot()
            end
        end

        if pet then
            if pet:IsA("Model") then
                return pet:GetPivot()
            elseif pet:IsA("BasePart") then
                return pet.CFrame
            end
        end

        local localPlayer = Players.LocalPlayer
        if localPlayer and localPlayer.Character then
            local root = localPlayer.Character:FindFirstChild("HumanoidRootPart")
            if root then
                return root.CFrame
            end
        end
        return CFrame.new(0, 5, 0)
    end

    local function createGargantuanEggProxy(settings, origin)
        local configuredEgg = resolveGargantuanInstance(settings.Egg)
        local sourcePart
        if configuredEgg then
            if configuredEgg:IsA("Model") then
                sourcePart = configuredEgg:FindFirstChildWhichIsA("BasePart", true)
            elseif configuredEgg:IsA("BasePart") then
                sourcePart = configuredEgg
            end
        end

        if not sourcePart then
            local replicatedStorage = game:GetService("ReplicatedStorage")
            local directory = replicatedStorage:FindFirstChild("Library")
            directory = directory and directory:FindFirstChild("Directory")
            local eggs = directory and directory:FindFirstChild("Eggs")
            if eggs then
                for _, descendant in ipairs(eggs:GetDescendants()) do
                    if descendant:IsA("BasePart") and descendant.Name == "Egg" then
                        sourcePart = descendant
                        break
                    end
                end
            end
        end

        local model = Instance.new("Model")
        model.Name = "GargantuanEgg"
        local part
        if sourcePart then
            local oldArchivable = sourcePart.Archivable
            sourcePart.Archivable = true
            local ok, clone = pcall(function()
                return sourcePart:Clone()
            end)
            sourcePart.Archivable = oldArchivable
            if ok then
                part = clone
            end
        end

        if not part then
            part = Instance.new("Part")
            part.Name = "Egg"
            part.Shape = Enum.PartType.Ball
            part.Size = Vector3.new(8, 10, 8)
            part.Material = Enum.Material.SmoothPlastic
            part.Color = Color3.fromRGB(34, 25, 56)
            part.Reflectance = 0.08
        end

        part.Anchored = true
        part.CanCollide = false
        part.CanQuery = false
        part.CanTouch = false
        part.Parent = model
        model.PrimaryPart = part
        model:PivotTo(origin)
        return model
    end

    local function createGargantuanOverlay(parent)
        local screen = Instance.new("ScreenGui")
        screen.Name = "PlantVsCoinsGargantuanAnimation"
        screen.IgnoreGuiInset = true
        screen.ResetOnSpawn = false
        screen.DisplayOrder = 2147483647
        screen.ZIndexBehavior = Enum.ZIndexBehavior.Global

        local frame = Instance.new("Frame")
        frame.Name = "Frame"
        frame.BackgroundColor3 = Color3.new(1, 1, 1)
        frame.BackgroundTransparency = 0
        frame.BorderSizePixel = 0
        frame.Size = UDim2.fromScale(1, 1)
        frame.ZIndex = 2147483647
        frame.Parent = screen

        screen.Parent = parent
        return screen, frame
    end

    local function createGargantuanAvatar(userId, player, origin)
        local description
        if player and player.Character then
            local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                pcall(function()
                    description = humanoid:GetAppliedDescription()
                end)
            end
        end
        if not description and userId then
            pcall(function()
                description = Players:GetHumanoidDescriptionFromUserId(userId)
            end)
        end
        if not description then
            local localPlayer = Players.LocalPlayer
            local humanoid = localPlayer and localPlayer.Character and localPlayer.Character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                pcall(function()
                    description = humanoid:GetAppliedDescription()
                end)
            end
        end

        local avatar
        if description then
            pcall(function()
                avatar = Players:CreateHumanoidModelFromDescription(
                    description,
                    Enum.HumanoidRigType.R15,
                    Enum.AssetTypeVerification.ClientOnly
                )
            end)
        end
        if not avatar then
            local localPlayer = Players.LocalPlayer
            local character = localPlayer and localPlayer.Character
            if character then
                local oldArchivable = character.Archivable
                character.Archivable = true
                pcall(function()
                    avatar = character:Clone()
                end)
                character.Archivable = oldArchivable
            end
        end
        if not avatar then
            return nil
        end

        avatar.Name = "GargantuanAnimationPlayer"
        local root = avatar:FindFirstChild("HumanoidRootPart") or avatar.PrimaryPart
        if root and root:IsA("BasePart") then
            avatar.PrimaryPart = root
        end
        for _, descendant in ipairs(avatar:GetDescendants()) do
            if descendant:IsA("BaseScript") then
                descendant.Disabled = true
            elseif descendant:IsA("BasePart") then
                descendant.CanCollide = false
                descendant.CanQuery = false
                descendant.CanTouch = false
                descendant.Anchored = descendant == root
            end
        end
        avatar:PivotTo(origin)
        return avatar
    end

    local function playGargantuanHumanoidAnimation(avatar, animationId, looped)
        if not avatar then
            return nil
        end
        local humanoid = avatar:FindFirstChildOfClass("Humanoid")
        if not humanoid then
            return nil
        end
        local animator = humanoid:FindFirstChildOfClass("Animator")
        if not animator then
            animator = Instance.new("Animator")
            animator.Parent = humanoid
        end
        local animation = Instance.new("Animation")
        animation.AnimationId = tostring(animationId):find("rbxassetid://", 1, true)
            and tostring(animationId)
            or "rbxassetid://" .. tostring(animationId)
        local track
        pcall(function()
            track = animator:LoadAnimation(animation)
            track.Looped = looped == true
            track:Play(0.1)
        end)
        animation:Destroy()
        return track
    end

    local GARGANTUAN_SOUND_DATA = {
        {"rbxassetid://103142314399286", 2, false},
        {"rbxassetid://132890725631565", 2, false},
        {"rbxassetid://75109993331758", 2, false},
        {"rbxassetid://136660441341294", 2.5, false},
        {"rbxassetid://72907996701257", 2.5, false},
        {"rbxassetid://110392170052468", 3, false},
        {"rbxassetid://133290131260832", 1, true},
        {"rbxassetid://84998174688050", 1.25, false},
        {"rbxassetid://121402032110151", 2, false},
        {"rbxassetid://92748852841796", 2, false},
        {"rbxassetid://127591765433602", 2, false},
        {"rbxassetid://130290538463214", 2, false},
        {"rbxassetid://135940719095629", 1.5, false},
        {"rbxassetid://121904522137191", 3, false},
    }

    local GARGANTUAN_SKYBOX = {
        SkyboxBk = "rbxassetid://138540021614807",
        SkyboxDn = "rbxassetid://90482335790307",
        SkyboxFt = "rbxassetid://99233289310782",
        SkyboxLf = "rbxassetid://111253388832579",
        SkyboxRt = "rbxassetid://80274178837189",
        SkyboxUp = "rbxassetid://90584530006628",
    }

    local GARGANTUAN_SKY_STAGES = {
        "rbxassetid://91951324406560",
        "rbxassetid://82040892409095",
        "rbxassetid://72044795462699",
    }

    function Library:PlayGargantuanAnimation(settings)
        if settings == nil and type(self) == "table" and self.Pet ~= nil then
            settings = self
            self = Library
        end
        settings = type(settings) == "table" and settings or {}

        local petSource = resolveGargantuanInstance(settings.Pet)
        assert(petSource and (petSource:IsA("Model") or petSource:IsA("BasePart")), "PlayGargantuanAnimation: Pet must be a Model, BasePart, or valid instance path")

        local playerValue = settings.Player
        local player
        local userId
        if typeof(playerValue) == "Instance" and playerValue:IsA("Player") then
            player = playerValue
            userId = player.UserId
        else
            userId = tonumber(playerValue)
            assert(userId, "PlayGargantuanAnimation: Player must be a Player or user id")
            player = Players:GetPlayerByUserId(userId)
        end

        if self._ActiveGargantuanAnimation and self._ActiveGargantuanAnimation.IsPlaying then
            self._ActiveGargantuanAnimation:Stop()
        end

        local completedBindable = Instance.new("BindableEvent")
        local state = {
            stopped = false,
            cleaned = false,
            tweens = {},
            connections = {},
            instances = {},
            screenStates = {},
            coreStates = {},
        }
        local controller = {
            IsPlaying = true,
            Completed = completedBindable.Event,
        }

        function controller:Stop()
            state.stopped = true
        end

        function controller:Wait()
            if not self.IsPlaying then
                return self.Success, self.Error
            end
            return completedBindable.Event:Wait()
        end

        function controller:Destroy()
            self:Stop()
            if not self.IsPlaying then
                completedBindable:Destroy()
            end
        end

        self._ActiveGargantuanAnimation = controller

        local speed = tonumber(settings.Speed) or 1
        speed = math.clamp(speed, 0.1, 5)
        local soundMultiplier = math.max(0, tonumber(settings.SoundVolume) or 1)
        local useSounds = settings.Sounds ~= false
        local useParticles = settings.Particles ~= false
        local hideUI = settings.HideUI ~= false
        local camera = workspace.CurrentCamera
        local lighting = game:GetService("Lighting")
        local starterGui = game:GetService("StarterGui")
        local replicatedStorage = game:GetService("ReplicatedStorage")
        local localPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
        local playerGui = localPlayer:WaitForChild("PlayerGui")
        local origin = resolveGargantuanOrigin(settings.Origin or settings.Position, player, petSource)
        local originalCameraType = camera.CameraType
        local originalCameraSubject = camera.CameraSubject
        local originalCameraCFrame = camera.CFrame
        local originalFOV = camera.FieldOfView
        local baseCameraCFrame = originalCameraCFrame
        local shakeMagnitude = 0
        local shakeRotation = 0
        local shakeEnd = 0
        local sustainedShake = 0
        local createdSky = false
        local sky = lighting:FindFirstChildOfClass("Sky")
        local oldSky = {}
        local atmosphere
        local overlay
        local overlayFrame
        local eggModel
        local petModel
        local avatar
        local sounds = {}
        local tempFolder

        local function rememberInstance(instance)
            if instance then
                table.insert(state.instances, instance)
            end
            return instance
        end

        local function addConnection(connection)
            table.insert(state.connections, connection)
            return connection
        end

        local function scaledTime(seconds)
            return math.max(0, seconds / speed)
        end

        local function waitFor(seconds)
            local finish = os.clock() + scaledTime(seconds)
            while os.clock() < finish do
                if state.stopped then
                    return false
                end
                RunService.Heartbeat:Wait()
            end
            return not state.stopped
        end

        local function tweenObject(instance, goals, duration, style, direction)
            if not instance or not instance.Parent then
                return nil
            end
            local tween = TweenService:Create(
                instance,
                TweenInfo.new(
                    scaledTime(duration),
                    style or Enum.EasingStyle.Sine,
                    direction or Enum.EasingDirection.Out
                ),
                goals
            )
            table.insert(state.tweens, tween)
            tween:Play()
            return tween
        end

        local function tweenPivot(model, target, duration, style, direction)
            if not model or not model.Parent then
                return false
            end
            local start = model:GetPivot()
            local total = scaledTime(duration)
            if total <= 0 then
                model:PivotTo(target)
                return true
            end
            local began = os.clock()
            while true do
                if state.stopped or not model.Parent then
                    return false
                end
                local alpha = math.clamp((os.clock() - began) / total, 0, 1)
                local eased = TweenService:GetValue(
                    alpha,
                    style or Enum.EasingStyle.Sine,
                    direction or Enum.EasingDirection.Out
                )
                model:PivotTo(start:Lerp(target, eased))
                if alpha >= 1 then
                    break
                end
                RunService.RenderStepped:Wait()
            end
            model:PivotTo(target)
            return true
        end

        local function setCamera(value)
            baseCameraCFrame = value
        end

        local function shakeOnce(magnitude, rotation, duration)
            shakeMagnitude = math.max(shakeMagnitude, magnitude or 0)
            shakeRotation = math.max(shakeRotation, rotation or 0)
            shakeEnd = math.max(shakeEnd, os.clock() + scaledTime(duration or 1))
        end

        local function setSustainedShake(value)
            sustainedShake = math.max(0, value or 0)
        end

        local function playSound(index, playbackSpeed, volumeOverride)
            if not useSounds then
                return nil
            end
            local sound = sounds[index]
            if not sound then
                return nil
            end
            if playbackSpeed then
                sound.PlaybackSpeed = playbackSpeed
            end
            if volumeOverride then
                sound.Volume = volumeOverride * soundMultiplier
            end
            sound.TimePosition = 0
            sound:Play()
            return sound
        end

        local function emitDescendants(root, onlyName)
            if not root then
                return
            end
            for _, descendant in ipairs(root:GetDescendants()) do
                if descendant:IsA("ParticleEmitter") and (not onlyName or descendant.Name == onlyName) then
                    local count = descendant:GetAttribute("EmitCount") or 1
                    descendant:Emit(math.max(1, tonumber(count) or 1))
                elseif descendant:IsA("Beam") or descendant:IsA("Trail") then
                    descendant.Enabled = true
                end
            end
        end

        local function cloneParticle(name, pivot, scale)
            if not useParticles then
                return nil
            end
            local assets = replicatedStorage:FindFirstChild("Assets")
            local particles = assets and assets:FindFirstChild("Particles")
            local gargantuan = particles and particles:FindFirstChild("Gargantuan")
            local source = gargantuan and gargantuan:FindFirstChild(name)
            if not source then
                return nil
            end
            local clone = source:Clone()
            rememberInstance(clone)
            clone.Parent = tempFolder
            if clone:IsA("Model") then
                clone:PivotTo(pivot)
                if scale and scale ~= 1 then
                    pcall(function()
                        clone:ScaleTo(scale)
                    end)
                end
            elseif clone:IsA("BasePart") then
                clone.CFrame = pivot
                if scale and scale ~= 1 then
                    clone.Size *= scale
                end
            end
            return clone
        end

        local function cleanup()
            if state.cleaned then
                return
            end
            state.cleaned = true
            state.stopped = true

            for _, tween in ipairs(state.tweens) do
                pcall(function()
                    tween:Cancel()
                end)
            end
            for _, connection in ipairs(state.connections) do
                pcall(function()
                    connection:Disconnect()
                end)
            end

            camera.CameraType = originalCameraType
            camera.CameraSubject = originalCameraSubject
            camera.CFrame = originalCameraCFrame
            camera.FieldOfView = originalFOV

            for property, value in pairs(oldSky) do
                if sky and sky.Parent then
                    pcall(function()
                        sky[property] = value
                    end)
                end
            end
            if createdSky and sky then
                sky:Destroy()
            end
            if atmosphere then
                atmosphere:Destroy()
            end

            for screenGui, enabled in pairs(state.screenStates) do
                if screenGui.Parent then
                    screenGui.Enabled = enabled
                end
            end
            for coreType, enabled in pairs(state.coreStates) do
                pcall(function()
                    starterGui:SetCoreGuiEnabled(coreType, enabled)
                end)
            end

            for _, instance in ipairs(state.instances) do
                if instance and instance.Parent then
                    pcall(function()
                        instance:Destroy()
                    end)
                end
            end
            for _, sound in ipairs(sounds) do
                if sound and sound.Parent then
                    sound:Destroy()
                end
            end

            controller.IsPlaying = false
            if self._ActiveGargantuanAnimation == controller then
                self._ActiveGargantuanAnimation = nil
            end
        end

        task.spawn(function()
            local success, failure = xpcall(function()
                tempFolder = Instance.new("Folder")
                tempFolder.Name = "PlantVsCoinsGargantuanAnimation"
                tempFolder.Parent = workspace
                rememberInstance(tempFolder)

                overlay, overlayFrame = createGargantuanOverlay(playerGui)
                rememberInstance(overlay)

                if hideUI then
                    for _, child in ipairs(playerGui:GetChildren()) do
                        if child:IsA("ScreenGui") and child ~= overlay then
                            state.screenStates[child] = child.Enabled
                            child.Enabled = false
                        end
                    end
                    if self.Screen and self.Screen:IsA("ScreenGui") and self.Screen ~= overlay then
                        state.screenStates[self.Screen] = self.Screen.Enabled
                        self.Screen.Enabled = false
                    end
                    for _, coreType in ipairs({Enum.CoreGuiType.Chat, Enum.CoreGuiType.PlayerList}) do
                        local ok, enabled = pcall(function()
                            return starterGui:GetCoreGuiEnabled(coreType)
                        end)
                        if ok then
                            state.coreStates[coreType] = enabled
                        end
                        pcall(function()
                            starterGui:SetCoreGuiEnabled(coreType, false)
                        end)
                    end
                end

                if not sky then
                    sky = Instance.new("Sky")
                    sky.Parent = lighting
                    createdSky = true
                end
                for property, value in pairs(GARGANTUAN_SKYBOX) do
                    oldSky[property] = sky[property]
                    sky[property] = value
                end

                local hatchModule = replicatedStorage:FindFirstChild("GargantuanHatch", true)
                local atmosphereSource = hatchModule and hatchModule:FindFirstChild("Atmosphere")
                if atmosphereSource and atmosphereSource:IsA("Atmosphere") then
                    atmosphere = atmosphereSource:Clone()
                else
                    atmosphere = Instance.new("Atmosphere")
                    atmosphere.Color = Color3.fromRGB(199, 199, 199)
                    atmosphere.Decay = Color3.fromRGB(106, 112, 125)
                    atmosphere.Density = 0.25
                    atmosphere.Offset = 0.25
                    atmosphere.Glare = 0
                    atmosphere.Haze = 0
                end
                atmosphere.Parent = lighting
                rememberInstance(atmosphere)

                if useSounds then
                    for _, data in ipairs(GARGANTUAN_SOUND_DATA) do
                        local sound = Instance.new("Sound")
                        sound.SoundId = data[1]
                        sound.Volume = data[2] * soundMultiplier
                        sound.Looped = data[3]
                        sound.Parent = workspace
                        table.insert(sounds, sound)
                    end
                    pcall(function()
                        game:GetService("ContentProvider"):PreloadAsync(sounds)
                    end)
                end

                eggModel = createGargantuanEggProxy(settings, origin)
                eggModel.Parent = tempFolder
                rememberInstance(eggModel)

                petModel = cloneGargantuanModel(petSource)
                assert(petModel, "PlayGargantuanAnimation: Pet model could not be cloned")
                if tonumber(settings.Scale) and tonumber(settings.Scale) ~= 1 then
                    pcall(function()
                        petModel:ScaleTo(math.max(0.01, tonumber(settings.Scale)))
                    end)
                end
                petModel.Parent = tempFolder
                rememberInstance(petModel)

                avatar = createGargantuanAvatar(userId, player, origin)
                assert(avatar, "PlayGargantuanAnimation: Player avatar could not be created")
                avatar.Parent = tempFolder
                rememberInstance(avatar)

                camera.CameraType = Enum.CameraType.Scriptable
                setCamera(eggModel:GetPivot() + Vector3.new(8, 20, -30))
                camera.CFrame = baseCameraCFrame

                addConnection(RunService.RenderStepped:Connect(function()
                    local now = os.clock()
                    local activeShake = sustainedShake
                    if now < shakeEnd then
                        activeShake = math.max(activeShake, shakeMagnitude)
                    else
                        shakeMagnitude = 0
                        shakeRotation = 0
                    end
                    local shake = CFrame.new()
                    if activeShake > 0 then
                        local t = now * 18
                        local positional = activeShake * 0.08
                        local rotational = math.rad((shakeRotation > 0 and shakeRotation or activeShake * 2) * 0.08)
                        shake = CFrame.new(
                            math.noise(t, 0, 0) * positional,
                            math.noise(0, t, 0) * positional,
                            math.noise(0, 0, t) * positional
                        ) * CFrame.Angles(
                            math.noise(t, 10, 0) * rotational,
                            math.noise(0, t, 10) * rotational,
                            math.noise(10, 0, t) * rotational
                        )
                    end
                    camera.CFrame = baseCameraCFrame * shake
                end))

                playSound(1)
                if not waitFor(1) then
                    return
                end
                tweenObject(overlayFrame, {BackgroundTransparency = 1}, 0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.In)

                local followEgg = addConnection(RunService.RenderStepped:Connect(function()
                    if eggModel and eggModel.Parent then
                        setCamera(CFrame.lookAt(baseCameraCFrame.Position, eggModel:GetPivot().Position))
                    end
                end))

                playSound(3)
                task.spawn(function()
                    tweenPivot(eggModel, eggModel:GetPivot() + Vector3.new(0, 400, 0), 2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
                end)
                if not waitFor(1.9) then
                    return
                end
                shakeOnce(2, 3, 1)
                local pulse = cloneParticle("Pulse", eggModel:GetPivot(), 5)
                emitDescendants(pulse)
                playSound(2)
                if not tweenPivot(eggModel, eggModel:GetPivot() + Vector3.new(0, 600, 0), 0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out) then
                    return
                end
                followEgg:Disconnect()

                task.delay(scaledTime(0.4), function()
                    if sky and sky.Parent and not state.stopped then
                        sky.SkyboxUp = GARGANTUAN_SKY_STAGES[1]
                    end
                end)
                if not waitFor(0.5) then
                    return
                end

                playSound(4, 1.2)
                playSound(8)
                if sounds[7] then
                    sounds[7].Volume = 0
                    sounds[7]:Play()
                    tweenObject(sounds[7], {Volume = 0.5 * soundMultiplier}, 0.4, Enum.EasingStyle.Linear, Enum.EasingDirection.In)
                end
                camera.FieldOfView -= 5
                shakeOnce(3.125, 7.5, 1)
                local rift = cloneParticle("Rift", eggModel:GetPivot(), 4)
                emitDescendants(rift, "Small")

                task.delay(scaledTime(1.15), function()
                    if sky and sky.Parent and not state.stopped then
                        sky.SkyboxUp = GARGANTUAN_SKY_STAGES[2]
                    end
                end)
                if not waitFor(1.25) then
                    return
                end

                playSound(4, 1.1)
                playSound(5)
                if sounds[7] then
                    tweenObject(sounds[7], {Volume = 1 * soundMultiplier}, 0.4, Enum.EasingStyle.Linear, Enum.EasingDirection.In)
                end
                camera.FieldOfView -= 5
                shakeOnce(5, 12, 1.3)
                if rift and rift:IsA("Model") then
                    pcall(function()
                        rift:ScaleTo(7)
                    end)
                end
                emitDescendants(rift)

                task.delay(scaledTime(1.4), function()
                    if sky and sky.Parent and not state.stopped then
                        sky.SkyboxUp = GARGANTUAN_SKY_STAGES[3]
                    end
                end)
                if not waitFor(1.5) then
                    return
                end

                playSound(4, 1)
                playSound(5)
                playSound(6)
                if sounds[7] then
                    tweenObject(sounds[7], {Volume = 1.5 * soundMultiplier}, 0.4, Enum.EasingStyle.Linear, Enum.EasingDirection.In)
                end
                camera.FieldOfView -= 10
                shakeOnce(7.8125, 18.75, 2.25)
                if rift and rift:IsA("Model") then
                    pcall(function()
                        rift:ScaleTo(12)
                    end)
                end
                emitDescendants(rift)
                if not waitFor(2) then
                    return
                end
                setSustainedShake(2.5)

                avatar:PivotTo(origin)
                playGargantuanHumanoidAnimation(avatar, 14944748626, false)
                task.delay(scaledTime(1), function()
                    if avatar and avatar.Parent and not state.stopped then
                        playGargantuanHumanoidAnimation(avatar, 14958064526, true)
                    end
                end)

                overlayFrame.BackgroundTransparency = 0
                if not waitFor(0.1) then
                    return
                end
                tweenObject(overlayFrame, {BackgroundTransparency = 1}, 0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.In)

                local humanoid = avatar:FindFirstChildOfClass("Humanoid")
                local root = avatar:FindFirstChild("HumanoidRootPart") or avatar.PrimaryPart
                local feet = root and root.CFrame or avatar:GetPivot()
                if humanoid and root then
                    feet = root.CFrame - Vector3.new(0, humanoid.HipHeight, 0)
                end
                local frontPoint = feet.Position + feet.LookVector * 10
                local cameraPosition = Vector3.new(frontPoint.X, feet.Position.Y + (humanoid and humanoid.HipHeight or 2), frontPoint.Z)
                setCamera(CFrame.lookAt(cameraPosition, avatar:GetPivot().Position))
                playSound(10)
                task.delay(scaledTime(0.8), function()
                    if not state.stopped then
                        playSound(11)
                    end
                end)
                if not waitFor(1) then
                    return
                end
                shakeOnce(3, 5, 1)

                local followAvatar = addConnection(RunService.RenderStepped:Connect(function()
                    if avatar and avatar.Parent then
                        setCamera(CFrame.lookAt(baseCameraCFrame.Position, avatar:GetPivot().Position))
                    end
                end))
                if not tweenPivot(avatar, avatar:GetPivot() + Vector3.new(0, 350, 0), 1.9, Enum.EasingStyle.Linear, Enum.EasingDirection.Out) then
                    return
                end
                if not waitFor(0.1) then
                    return
                end
                overlayFrame.BackgroundTransparency = 0
                followAvatar:Disconnect()

                local oldDensity = atmosphere.Density
                atmosphere.Density = 0.35
                setCamera(CFrame.new(camera.CFrame.Position + Vector3.new(0, 3000, 0)))
                local centerRay = camera:ViewportPointToRay(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2, 100)
                local bottomLeftRay = camera:ViewportPointToRay(0, camera.ViewportSize.Y, 100)
                local topRightRay = camera:ViewportPointToRay(camera.ViewportSize.X, 0, 400)
                local centerPosition = centerRay.Origin
                local avatarStart = CFrame.lookAt(bottomLeftRay.Origin, centerPosition)
                avatarStart += avatarStart.LookVector * -10
                local petStart = CFrame.lookAt(topRightRay.Origin, centerPosition)
                petStart += petStart.LookVector * -100

                avatar:PivotTo(avatarStart)
                playGargantuanHumanoidAnimation(avatar, 17526382412, true)
                petModel:PivotTo(petStart)

                local primary = findGargantuanPrimaryPart(petModel)
                local front = primary:FindFirstChild("front")
                if not front or not front:IsA("Attachment") then
                    front = Instance.new("Attachment")
                    front.Name = "front"
                    front.Position = Vector3.new(0, 0, -primary.Size.Z * 0.5)
                    front.Parent = primary
                end
                local mount = primary:FindFirstChild("mount")
                if not mount or not mount:IsA("Attachment") then
                    mount = Instance.new("Attachment")
                    mount.Name = "mount"
                    mount.Position = Vector3.new(0, primary.Size.Y * 0.5 + 2, 0)
                    mount.Parent = primary
                end
                local center = primary:FindFirstChild("center")
                if not center or not center:IsA("Attachment") then
                    center = Instance.new("Attachment")
                    center.Name = "center"
                    center.Parent = primary
                end

                if useParticles then
                    local assets = replicatedStorage:FindFirstChild("Assets")
                    local particles = assets and assets:FindFirstChild("Particles")
                    local gargantuan = particles and particles:FindFirstChild("Gargantuan")
                    local meteor = gargantuan and gargantuan:FindFirstChild("MeteorParticles")
                    if meteor then
                        for _, child in ipairs(meteor:GetChildren()) do
                            child:Clone().Parent = front
                        end
                    end
                end

                task.spawn(function()
                    tweenPivot(avatar, CFrame.new(centerPosition), 2.4, Enum.EasingStyle.Cubic, Enum.EasingDirection.In)
                end)
                task.spawn(function()
                    tweenPivot(petModel, CFrame.new(centerPosition + petStart.LookVector * -20), 2.4, Enum.EasingStyle.Cubic, Enum.EasingDirection.In)
                end)

                if not waitFor(0.1) then
                    return
                end
                tweenObject(overlayFrame, {BackgroundTransparency = 1}, 0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
                if not waitFor(0.3) then
                    return
                end
                shakeOnce(2, 4, 3)
                playSound(12)
                playSound(9)
                if not waitFor(1.8) then
                    return
                end
                tweenObject(camera, {FieldOfView = 20}, 0.2, Enum.EasingStyle.Exponential, Enum.EasingDirection.In)
                tweenObject(overlayFrame, {BackgroundTransparency = 0}, 0.2, Enum.EasingStyle.Exponential, Enum.EasingDirection.In)
                if not waitFor(0.2) then
                    return
                end
                if sounds[2] then
                    sounds[2].Volume = 4 * soundMultiplier
                end
                playSound(2)
                setSustainedShake(0)
                if not waitFor(0.2) then
                    return
                end

                local landing = origin + Vector3.new(0, 10, 0)
                local highPosition = landing.Position + Vector3.new(0, 300, 500)
                petModel:PivotTo(CFrame.lookAt(highPosition, landing.Position))
                camera.FieldOfView = 70
                playGargantuanHumanoidAnimation(avatar, 11897877992, true)
                avatar.Parent = petModel
                avatar:PivotTo(mount.WorldCFrame + Vector3.new(0, 2, 0))

                local orbitStart = os.clock()
                local orbitDuration = scaledTime(5)
                local orbitConnection = addConnection(RunService.RenderStepped:Connect(function()
                    if not petModel.Parent or not center.Parent then
                        return
                    end
                    local alpha = math.clamp((os.clock() - orbitStart) / orbitDuration, 0, 1)
                    local horizontal = -50 + 100 * alpha
                    local vertical = 25 - 50 * alpha
                    local centerWorld = center.WorldPosition
                    local side = (center.WorldCFrame * CFrame.Angles(0, math.pi / 2, 0)).LookVector
                    local position = centerWorld + side * horizontal + Vector3.new(-25, vertical, 0)
                    setCamera(CFrame.lookAt(position, centerWorld))
                end))

                playSound(14)
                setSustainedShake(3.5)
                task.spawn(function()
                    tweenPivot(petModel, CFrame.new(landing.Position) * (petModel:GetPivot() - petModel:GetPivot().Position), 5, Enum.EasingStyle.Circular, Enum.EasingDirection.In)
                end)
                if not waitFor(0.1) then
                    return
                end
                playSound(13)
                tweenObject(overlayFrame, {BackgroundTransparency = 1}, 0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
                if not waitFor(4.6) then
                    return
                end
                playSound(11)
                if not waitFor(0.3) then
                    return
                end
                orbitConnection:Disconnect()
                atmosphere.Density = oldDensity
            end, debug.traceback)

            local interrupted = state.stopped
            cleanup()
            controller.Success = success and not interrupted
            controller.Error = success and nil or failure
            completedBindable:Fire(controller.Success, controller.Error)
            safeCall(settings.Callback, controller.Success, controller.Error)
            if not success and settings.SuppressErrors ~= true then
                warn("PlayGargantuanAnimation | " .. tostring(failure))
            end
        end)

        return controller
    end

    function Library:StopGargantuanAnimation()
        if self._ActiveGargantuanAnimation then
            self._ActiveGargantuanAnimation:Stop()
            return true
        end
        return false
    end

    function Library:IsGargantuanAnimationPlaying()
        return self._ActiveGargantuanAnimation ~= nil and self._ActiveGargantuanAnimation.IsPlaying == true
    end

    Library.PlayGargantuan = Library.PlayGargantuanAnimation

    local OriginalCreateWindowV8 = Library.CreateWindow
    function Library:CreateWindow(settings)
        settings = settings or {}
        local window = OriginalCreateWindowV8(self, settings)
        window._V8Connections = {}
        window._ActiveSectionByTab = {}
        window.SubTabsByTab = {}
        window.ActiveSubTabByTab = {}
        window.KnownProfiles = window.KnownProfiles or {}
        window.TooltipsEnabled = settings.Tooltips ~= false
        window.TooltipSoundEnabled = settings.TooltipSound ~= false
        window.ItemsFrameOriginalPosition = window.ItemsFrame.Position
        window:_applyContentInsets()
        if window.LauncherButton and window.LauncherSettings and window.LauncherSettings.Tooltip then
            window:AttachTooltip(window.LauncherButton, window.LauncherSettings.Tooltip)
        end
        local responsive = type(settings.Responsive) == "table" and settings.Responsive or {Enabled = settings.Responsive ~= false}
        window:_configureResponsive(responsive)
        local mobile = type(settings.Mobile) == "table" and settings.Mobile or {}
        window:_configureLauncherDrag({Draggable = mobile.LauncherDraggable ~= false})
        local gamepad = type(settings.Gamepad) == "table" and settings.Gamepad or {Enabled = settings.GamepadNavigation ~= false}
        window:_configureGamepad(gamepad)
        window:_configureOutsideClose()
        table.insert(window._V8Connections, UserInputService.InputChanged:Connect(function(inputObject)
            if window.TooltipPanel and window.TooltipPanel.Visible and inputObject.UserInputType == Enum.UserInputType.MouseMovement then
                window:_positionTooltip(window.TooltipTarget)
            end
        end))
        if window.ConfigSettings then
            local saving = settings.ConfigurationSaving or {}
            window.ConfigSettings.BaseFileName = window.ConfigSettings.BaseFileName or window.ConfigSettings.FileName
            window.ConfigSettings.Profile = sanitizeProfileName(saving.Profile or window.ConfigSettings.Profile or "Default")
            window.KnownProfiles[window.ConfigSettings.Profile] = true
            window:SetConfigProfile(window.ConfigSettings.Profile)
        end
        return window
    end

    local OriginalDestroyV8 = Library.Destroy
    function Library:Destroy()
        if self.GamepadActionName then
            ContextActionService:UnbindAction(self.GamepadActionName)
        end
        for _, connection in ipairs(self._V8Connections or {}) do
            pcall(function()
                connection:Disconnect()
            end)
        end
        if self.ActivePrompt and self.ActivePrompt.Close then
            self.ActivePrompt:Close(false)
        end
        if self.ActiveGoal and self.ActiveGoal.Destroy then
            self.ActiveGoal:Destroy()
            self.ActiveGoal = nil
        end
        if self._NativeNotificationHost and self._NativeNotificationHost.Screen then
            self._NativeNotificationHost.Screen:Destroy()
            self._NativeNotificationHost = nil
        end
        return OriginalDestroyV8(self)
    end

    return Library
end)(UIFactory, GUIFX)

return Library

end
