return function(Library)
    if type(Library) ~= "table" then
        error("infooverlay.lua expected the necker Library table", 2)
    end
    if Library.__NeckerInfoOverlayInstalled then
        return Library
    end
    Library.__NeckerInfoOverlayInstalled = true

    local Players = game:GetService("Players")
    local TextService = game:GetService("TextService")
    local RunService = game:GetService("RunService")
    local GuiService = game:GetService("GuiService")

    local Active
    local Connections = {}
    local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular)
    local FONT_ITALIC = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Italic)

    local Rarities = {
        Basic = {DisplayName = "Basic", Color = Color3.fromRGB(180, 180, 180)},
        Rare = {DisplayName = "Rare", Color = Color3.fromRGB(82, 168, 255)},
        Epic = {DisplayName = "Epic", Color = Color3.fromRGB(185, 90, 255)},
        Legendary = {DisplayName = "Legendary", Color = Color3.fromRGB(255, 188, 54)},
        Mythical = {
            DisplayName = "Mythical",
            Gradient = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 74, 74)),
                ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 88, 229)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(125, 94, 255)),
            }),
        },
        Exclusive = {
            DisplayName = "Exclusive",
            Star = true,
            Animated = true,
            Gradient = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 72, 221)),
                ColorSequenceKeypoint.new(0.5, Color3.fromRGB(117, 95, 255)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(65, 218, 255)),
            }),
        },
        ["Secret Exclusive"] = {
            DisplayName = "Secret Exclusive",
            Star = true,
            Animated = true,
            Gradient = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 227, 92)),
                ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 94, 220)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(104, 112, 255)),
            }),
        },
    }

    local function Disconnect()
        for _, Connection in ipairs(Connections) do
            Connection:Disconnect()
        end
        table.clear(Connections)
    end

    local function Remove()
        Disconnect()
        if Active then
            Active:Destroy()
            Active = nil
        end
    end

    local function TextBlock(Name, Text, Height, TextSize, Color, Wrapped, FontFace)
        local Frame = Instance.new("Frame")
        Frame.Name = Name
        Frame.BackgroundTransparency = 1
        Frame.BorderSizePixel = 0
        Frame.Size = UDim2.new(1, 0, 0, Height)

        local Label = Instance.new("TextLabel")
        Label.Name = "title"
        Label.AnchorPoint = Vector2.new(0.5, 0.5)
        Label.BackgroundTransparency = 1
        Label.FontFace = FontFace or FONT
        Label.Position = UDim2.fromScale(0.5, 0.5)
        Label.Size = UDim2.fromScale(1, 1)
        Label.Text = tostring(Text or "")
        Label.TextColor3 = Color
        Label.TextSize = TextSize
        Label.TextWrapped = Wrapped == true
        Label.TextXAlignment = Enum.TextXAlignment.Center
        Label.TextYAlignment = Enum.TextYAlignment.Center
        Label.Parent = Frame

        return Frame, Label
    end

    local function Stroke(Label)
        local Stroke = Instance.new("UIStroke")
        Stroke.Color = Color3.fromRGB(76, 76, 76)
        Stroke.Thickness = 2
        Stroke.Parent = Label
        return Stroke
    end

    local function ApplyGradient(Label, Gradient)
        if Gradient == nil then
            return nil, nil
        end

        local LabelGradient
        if typeof(Gradient) == "Instance" and Gradient:IsA("UIGradient") then
            LabelGradient = Gradient:Clone()
        elseif typeof(Gradient) == "ColorSequence" then
            LabelGradient = Instance.new("UIGradient")
            LabelGradient.Color = Gradient
        elseif type(Gradient) == "table" and #Gradient > 0 then
            local Keypoints = {}
            for Index, Color in ipairs(Gradient) do
                if typeof(Color) == "Color3" then
                    table.insert(Keypoints, ColorSequenceKeypoint.new((Index - 1) / math.max(1, #Gradient - 1), Color))
                end
            end
            if #Keypoints > 0 then
                LabelGradient = Instance.new("UIGradient")
                LabelGradient.Color = ColorSequence.new(Keypoints)
            end
        end

        if not LabelGradient then
            return nil, nil
        end

        Label.TextColor3 = Color3.new(1, 1, 1)
        LabelGradient.Parent = Label

        local LabelStroke = Label:FindFirstChildOfClass("UIStroke") or Stroke(Label)
        local StrokeGradient = LabelGradient:Clone()
        StrokeGradient.Parent = LabelStroke
        return LabelGradient, StrokeGradient
    end

    local function Base()
        local Base = Instance.new("Frame")
        Base.Name = "InfoOverlay"
        Base.Active = true
        Base.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        Base.BorderSizePixel = 0
        Base.Size = UDim2.fromOffset(180, 60)
        Base.ZIndex = 10000

        local Corner = Instance.new("UICorner")
        Corner.CornerRadius = UDim.new(0, 10)
        Corner.Parent = Base

        local Stroke = Instance.new("UIStroke")
        Stroke.Color = Color3.fromRGB(42, 43, 49)
        Stroke.Thickness = 3
        Stroke.Parent = Base

        local Background = Instance.new("ImageLabel")
        Background.Name = "background"
        Background.BackgroundTransparency = 1
        Background.Image = "rbxassetid://13581793331"
        Background.ImageColor3 = Color3.fromRGB(20, 58, 67)
        Background.ImageTransparency = 0.95
        Background.ScaleType = Enum.ScaleType.Tile
        Background.Size = UDim2.fromScale(1, 1)
        Background.TileSize = UDim2.fromOffset(171, 135)
        Background.ZIndex = 10000
        Background.Parent = Base

        local BackgroundCorner = Corner:Clone()
        BackgroundCorner.Parent = Background

        local Blocks = Instance.new("Frame")
        Blocks.Name = "Blocks"
        Blocks.BackgroundTransparency = 1
        Blocks.Size = UDim2.fromScale(1, 1)
        Blocks.ZIndex = 10001
        Blocks.Parent = Base

        local List = Instance.new("UIListLayout")
        List.HorizontalAlignment = Enum.HorizontalAlignment.Center
        List.VerticalAlignment = Enum.VerticalAlignment.Center
        List.Padding = UDim.new(0, 3)
        List.SortOrder = Enum.SortOrder.LayoutOrder
        List.Parent = Blocks

        local Padding = Instance.new("UIPadding")
        Padding.PaddingBottom = UDim.new(0, 6)
        Padding.PaddingLeft = UDim.new(0, 16)
        Padding.PaddingRight = UDim.new(0, 16)
        Padding.PaddingTop = UDim.new(0, 6)
        Padding.Parent = Blocks

        return Base, Blocks
    end

    local Blocks = {}

    Blocks.Title = function(Data)
        local Frame, Label = TextBlock("Title", Data[2], 32, 32, Data[4] and Color3.new(1, 1, 1) or Color3.fromRGB(42, 43, 49), true)
        if Data[3] and Rarities[Data[3]] then
            local Style = Rarities[Data[3]]
            Label.TextColor3 = Style.Color or Label.TextColor3
            ApplyGradient(Label, Style.Gradient)
        end
        return Frame, Label, 65, 250
    end

    Blocks.Nickname = function(Data)
        local Frame, Label = TextBlock("Nickname", Data[2], 20, 20, Color3.fromRGB(130, 130, 130), false, FONT_ITALIC)
        return Frame, Label, 65, 150
    end

    Blocks.Rarity = function(Data)
        local Value = Data[2]
        local Name = type(Value) == "table" and (Value.Name or Value.Rarity) or tostring(Value or "Basic")
        local RarityTable = type(Data[3]) == "table" and Data[3] or Rarities
        local Style = type(Value) == "table" and Value or RarityTable[Name] or Rarities[Name] or {DisplayName = Name}
        local DisplayName = tostring(Style.DisplayName or Name)
        if Style.Star then
            DisplayName ..= "  ★"
        end

        local Frame, Label = TextBlock("Rarity", DisplayName, 24, 24, Style.Color or Color3.fromRGB(130, 130, 130), false)
        local LabelGradient, StrokeGradient = ApplyGradient(Label, Style.Gradient or Style.Colors)
        local Render
        if Style.Animated and LabelGradient then
            Render = function()
                local Rotation = 100 + os.clock() * 100
                LabelGradient.Rotation = Rotation
                if StrokeGradient then
                    StrokeGradient.Rotation = -Rotation
                end
            end
        end
        return Frame, Label, 65, 200, nil, Render
    end

    Blocks.Rainbow = function(Data)
        local Text = Data[2] == true and "Rainbow" or tostring(Data[2] or "Rainbow")
        local Frame, Label = TextBlock("Rainbow", Text, 22, 22, Color3.new(1, 1, 1), false)
        local Gradient, StrokeGradient = ApplyGradient(Label, ColorSequence.new(Color3.fromRGB(255, 255, 255)))
        local Render = function()
            local Color = Color3.fromHSV(os.clock() % 3 / 3, 0.65, 1)
            Gradient.Color = ColorSequence.new(Color)
            StrokeGradient.Color = ColorSequence.new(Color)
        end
        return Frame, Label, 65, 200, nil, Render
    end

    Blocks.Shiny = function(Data)
        local Text = Data[2] == true and "✨ Shiny" or tostring(Data[2] or "✨ Shiny")
        local Frame, Label = TextBlock("Shiny", Text, 22, 22, Color3.fromRGB(255, 235, 97), false)
        return Frame, Label, 65, 180
    end

    Blocks.Desc = function(Data)
        local Frame, Label = TextBlock("Desc", Data[2], 20, 20, Data[4] and Color3.fromRGB(210, 210, 210) or Color3.fromRGB(130, 130, 130), true)
        return Frame, Label, 65, 175
    end

    Blocks.Div = function(Data)
        local Frame = Instance.new("Frame")
        Frame.Name = "Div"
        Frame.BackgroundTransparency = 1
        Frame.Size = UDim2.new(1, 0, 0, 15)

        local Div = Instance.new("Frame")
        Div.AnchorPoint = Vector2.new(0, 0.5)
        Div.BackgroundColor3 = Data[2] and Color3.new(1, 1, 1) or Color3.new(0, 0, 0)
        Div.BackgroundTransparency = Data[2] and 0 or 0.9
        Div.BorderSizePixel = 0
        Div.Position = UDim2.fromScale(0, 0.5)
        Div.Size = UDim2.new(1, 0, 0, 1)
        Div.Parent = Frame

        local Gradient = Instance.new("UIGradient")
        Gradient.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.5, 0),
            NumberSequenceKeypoint.new(1, 1),
        })
        Gradient.Parent = Div

        return Frame, nil, 65, 175
    end

    Blocks.Info = function(Data)
        local Frame, Label = TextBlock("Info", Data[2], 20, 20, Data[3] and Color3.new(1, 1, 1) or Color3.fromRGB(130, 130, 130), true)
        return Frame, Label, 65, 175
    end

    Blocks.Message = function(Data)
        local Frame, Label = TextBlock("Message", Data[2], 20, 20, Data[4] and Color3.new(1, 1, 1) or Color3.fromRGB(130, 130, 130), true)
        return Frame, Label, 65, 175
    end

    Blocks.MessageDark = function(Data)
        local Frame, Label = TextBlock("MessageDark", Data[2], 21, 20, Data[4] and Color3.new(1, 1, 1) or Color3.fromRGB(42, 43, 49), true)
        return Frame, Label, 65, 175
    end

    Blocks.Hidden = function(Data)
        local Text = Data[2] == true and "⚠️ Hidden" or tostring(Data[2] or "⚠️ Hidden")
        local Frame, Label = TextBlock("Hidden", Text, 22, 20, Color3.fromRGB(255, 82, 82), true)
        return Frame, Label, 65, 200
    end

    Blocks.Tradable = function()
        local Frame, Label = TextBlock("Tradable", "✓ Tradable", 20, 20, Color3.fromRGB(90, 220, 90), false)
        return Frame, Label, 65, 160
    end

    Blocks.NotTradable = function(Data)
        local Text = Data[2] == true and "✗ Not Tradable" or tostring(Data[2] or "✗ Not Tradable")
        local Frame, Label = TextBlock("NotTradable", Text, 20, 20, Color3.fromRGB(255, 91, 91), false)
        return Frame, Label, 65, 170
    end

    Blocks.Deal = function(Data)
        local Value = tonumber(Data[2])
        local Text = "Bad Deal"
        local Color = Color3.fromRGB(254, 79, 82)
        if Value == 1 then
            Text = "Good Deal"
            Color = Color3.fromRGB(129, 253, 255)
        elseif Value == 2 then
            Text = "Great Deal!"
            Color = Color3.fromRGB(113, 255, 62)
        end
        local Frame, Label = TextBlock("Deal", Text, 22, 22, Color, false)
        return Frame, Label, 65, 170
    end

    Blocks.Exists = function(Data)
        local Count = tonumber(Data[2]) or 0
        local Text = tostring(math.floor(Count)) .. (Count == 1 and " Exists" or " Exist")
        local Frame, Label = TextBlock("Exists", Text, 20, 20, Data[3] and Color3.new(1, 1, 1) or Color3.fromRGB(130, 130, 130), false)
        return Frame, Label, 65, 170
    end

    Blocks.Empowered = function(Data)
        local Value = Data[2]
        local Frame, Label = TextBlock("Empowered", "Empowered", 20, 20, Color3.fromRGB(255, 179, 64), false)
        local Update
        if type(Value) == "function" then
            Update = function()
                Label.Text = "Empowered: " .. tostring(math.max(0, math.floor(tonumber(Value()) or 0))) .. "s"
            end
            Update()
        elseif type(Value) == "table" and tonumber(Value.Expires) then
            Update = function()
                Label.Text = "Empowered: " .. tostring(math.max(0, math.floor(Value.Expires - workspace:GetServerTimeNow()))) .. "s"
            end
            Update()
        end
        return Frame, Label, 65, 190, Update
    end

    Blocks.Timer = function(Data)
        local Frame, Label = TextBlock("Timer", "", 20, 20, Color3.fromRGB(71, 184, 255), false)
        local Value = Data[2]
        local function GetValue()
            if type(Value) == "function" then
                return Value()
            end
            return Value
        end
        local function Update()
            local Number = math.max(0, math.floor(tonumber(GetValue()) or 0))
            if Data[3] then
                Label.Text = tostring(Number) .. "x"
            elseif Number == 0 then
                Label.Text = "EXPIRED"
            else
                local Hours = math.floor(Number / 3600)
                local Minutes = math.floor(Number % 3600 / 60)
                local Seconds = Number % 60
                Label.Text = string.format("%02d:%02d:%02d", Hours, Minutes, Seconds)
            end
        end
        Update()
        return Frame, Label, 65, 200, Update
    end

    Blocks.UpdatingDesc = function(Data)
        local Frame, Label = TextBlock("UpdatingDesc", "", 20, 20, Color3.fromRGB(130, 130, 130), true)
        Label.RichText = true
        local Callback = type(Data[2]) == "function" and Data[2] or function()
            return Data[2]
        end
        local Update = function()
            Label.Text = tostring(Callback() or "")
        end
        Update()
        return Frame, Label, 65, 200, Update
    end

    Blocks.GradientText = function(Data)
        local Frame, Label = TextBlock("GradientText", Data[2], 22, 22, Color3.new(1, 1, 1), true)
        Stroke(Label)
        ApplyGradient(Label, Data[3] or ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 91, 229)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(86, 180, 255)),
        }))
        return Frame, Label, 65, 220
    end

    local function Block(Type, Value, Extra)
        if Type == "Title" then
            if type(Value) == "table" then
                return {"Title", Value.Text or Value.Title or "", Value.Rarity, Value.White == true, Value.Magic == true}
            end
            return {"Title", Value}
        elseif Type == "Nickname" then
            return {"Nickname", type(Value) == "table" and (Value.Text or "") or Value}
        elseif Type == "Rarity" then
            return {"Rarity", Value, Extra}
        elseif Type == "Rainbow" or Type == "Shiny" or Type == "Hidden" or Type == "NotTradable" then
            return {Type, Value}
        elseif Type == "Desc" then
            if type(Value) == "table" then
                return {"Desc", Value.Text or "", Value.Rarity, Value.White == true, Value.Magic == true}
            end
            return {"Desc", Value}
        elseif Type == "Div" then
            return {"Div", type(Value) == "table" and Value.White == true or false}
        elseif Type == "Info" then
            if type(Value) == "table" and Value.Text ~= nil then
                return {"Info", Value.Text, Value.White == true, Value.Magic == true}
            end
            return {"Info", Value}
        elseif Type == "Message" or Type == "MessageDark" then
            if type(Value) == "table" then
                return {Type, Value.Text or "", Value.Rarity, Value.White == true}
            end
            return {Type, Value}
        elseif Type == "Tradable" then
            return {"Tradable"}
        elseif Type == "Deal" then
            return {"Deal", Value}
        elseif Type == "Exists" then
            if type(Value) == "table" then
                return {"Exists", Value.Count or Value.Value or 0, Value.White == true}
            end
            return {"Exists", Value}
        elseif Type == "Empowered" then
            return {"Empowered", Value}
        elseif Type == "Timer" then
            if type(Value) == "table" then
                return {"Timer", Value.Value or Value.Callback or 0, Value.Multiplier == true}
            end
            return {"Timer", Value}
        elseif Type == "UpdatingDesc" then
            return {"UpdatingDesc", Value}
        elseif Type == "GradientText" then
            if type(Value) == "table" then
                return {"GradientText", Value.Text or "", Value.Gradient or Value.Colors}
            end
            return {"GradientText", Value}
        end
    end

    local function AddProp(Result, Type, Value, Extra)
        if Value == nil or Value == false then
            return
        end

        if (Type == "Info" or Type == "Message" or Type == "MessageDark") and type(Value) == "table" and Value.Text == nil and Value[1] ~= nil then
            for _, Entry in ipairs(Value) do
                local Item = Block(Type, Entry, Extra)
                if Item then
                    table.insert(Result, Item)
                end
            end
            return
        end

        local Item = Block(Type, Value, Extra)
        if Item then
            table.insert(Result, Item)
        end
    end

    local function Normalize(Data)
        if type(Data) ~= "table" then
            return {}
        end
        if type(Data[1]) == "table" then
            return Data
        end

        local Result = {}
        AddProp(Result, "Title", Data.Title)
        AddProp(Result, "Nickname", Data.Nickname)
        AddProp(Result, "Rarity", Data.Rarity, Data.RarityTable)
        AddProp(Result, "Rainbow", Data.Rainbow)
        AddProp(Result, "Shiny", Data.Shiny)
        AddProp(Result, "Desc", Data.Desc)
        AddProp(Result, "Div", Data.Div)
        AddProp(Result, "Info", Data.Info)
        AddProp(Result, "Message", Data.Message)
        AddProp(Result, "MessageDark", Data.MessageDark)
        AddProp(Result, "Hidden", Data.Hidden)
        AddProp(Result, "Tradable", Data.Tradable)
        AddProp(Result, "NotTradable", Data.NotTradable)
        AddProp(Result, "Deal", Data.Deal)
        AddProp(Result, "Exists", Data.Exists)
        AddProp(Result, "Empowered", Data.Empowered)
        AddProp(Result, "Timer", Data.Timer)
        AddProp(Result, "UpdatingDesc", Data.UpdatingDesc)
        AddProp(Result, "GradientText", Data.GradientText)

        for _, Item in ipairs(Data.Blocks or {}) do
            if type(Item) == "table" and Item[1] then
                table.insert(Result, Item)
            elseif type(Item) == "table" and Item.Type then
                local Parsed = Block(Item.Type, Item.Value ~= nil and Item.Value or Item.Text or Item, Data.RarityTable)
                if Parsed then
                    table.insert(Result, Parsed)
                end
            end
        end

        return Result
    end

    local function Add(Window, Target, Data)
        Remove()
        Data = Normalize(Data)

        local Overlay, Holder = Base()
        local Metas = {}

        local function UpdateSize()
            local Height = 12
            local Width = 65
            local Count = 0
            for _, Meta in ipairs(Metas) do
                Count += 1
                local Frame = Meta.Frame
                local Label = Meta.Label
                local BlockHeight = Meta.Height
                if Label then
                    local Bounds = TextService:GetTextSize(Label.ContentText, Label.TextSize, Enum.Font.Arial, Vector2.new(Meta.MaxWidth, 1000))
                    Width = math.max(Width, math.clamp(Bounds.X + 10, Meta.MinWidth, Meta.MaxWidth))
                    if Label.TextWrapped then
                        BlockHeight = math.max(BlockHeight, Bounds.Y + 1)
                        Frame.Size = UDim2.new(1, 0, 0, BlockHeight)
                    end
                end
                Height += BlockHeight
            end
            Height += math.max(0, Count - 1) * 3
            Overlay.Size = UDim2.fromOffset(Width + 32, math.max(40, Height))
        end

        for Index, BlockData in ipairs(Data) do
            local Builder = type(BlockData) == "table" and Blocks[BlockData[1]]
            if Builder then
                local Frame, Label, MinWidth, MaxWidth, Update, Render = Builder(BlockData)
                Frame.LayoutOrder = Index * 100
                Frame.Parent = Holder
                table.insert(Metas, {
                    Frame = Frame,
                    Label = Label,
                    Height = Frame.Size.Y.Offset,
                    MinWidth = MinWidth or 65,
                    MaxWidth = MaxWidth or 200,
                    Update = Update,
                    Render = Render,
                })
            end
        end

        if #Metas == 0 then
            Overlay:Destroy()
            return nil
        end

        UpdateSize()
        Overlay.Parent = Window.Screen
        Active = Overlay

        table.insert(Connections, Target.MouseLeave:Connect(function()
            if GuiService.SelectedObject ~= Target then
                Remove()
            end
        end))
        table.insert(Connections, Target.SelectionLost:Connect(function()
            Remove()
        end))
        table.insert(Connections, Target.Destroying:Connect(Remove))

        local LastUpdate = 0
        table.insert(Connections, RunService.RenderStepped:Connect(function()
            if Active ~= Overlay or not Overlay.Parent then
                return
            end

            local Resize = false
            for _, Meta in ipairs(Metas) do
                if Meta.Render then
                    Meta.Render()
                end
                if Meta.Update and os.clock() - LastUpdate >= 0.1 then
                    Meta.Update()
                    Resize = true
                end
            end
            if os.clock() - LastUpdate >= 0.1 then
                LastUpdate = os.clock()
            end
            if Resize then
                UpdateSize()
            end

            local Mouse = Players.LocalPlayer:GetMouse()
            local Camera = workspace.CurrentCamera
            if not Camera then
                return
            end

            local X = Mouse.X
            local Y = Mouse.Y
            if GuiService.SelectedObject == Target then
                X = Target.AbsolutePosition.X + Target.AbsoluteSize.X / 2
                Y = Target.AbsolutePosition.Y + Target.AbsoluteSize.Y / 2
            end

            local Size = Overlay.AbsoluteSize
            local Viewport = Camera.ViewportSize
            local Above = Y + Size.Y + 10 >= Viewport.Y and Y - Size.Y - 10 > 0
            Overlay.AnchorPoint = Vector2.new(0, Above and 1 or 0)
            Overlay.Position = UDim2.fromOffset(
                math.clamp(X + 10, 0, math.max(0, Viewport.X - Size.X)),
                math.clamp(Y + (Above and -10 or 10), 0, math.max(0, Viewport.Y - (Above and 0 or Size.Y)))
            )
        end))

        return Overlay
    end

    function Library:InfoOverlay(Target, Data)
        assert(typeof(Target) == "Instance" and Target:IsA("GuiObject"), "InfoOverlay target must be a GuiObject")
        assert(type(Data) == "table", "InfoOverlay data must be a table")

        local MouseEnter = Target.MouseEnter:Connect(function()
            Add(self, Target, Data)
        end)
        local SelectionGained = Target.SelectionGained:Connect(function()
            Add(self, Target, Data)
        end)

        return function()
            MouseEnter:Disconnect()
            SelectionGained:Disconnect()
            if Active then
                Remove()
            end
        end
    end

    function Library:DynamicInfoOverlay(Target, Callback)
        assert(typeof(Target) == "Instance" and Target:IsA("GuiObject"), "DynamicInfoOverlay target must be a GuiObject")
        assert(type(Callback) == "function", "DynamicInfoOverlay callback must be a function")

        local function Show()
            local Data = Callback()
            if type(Data) == "table" and next(Data) then
                Add(self, Target, Data)
            end
        end

        local MouseEnter = Target.MouseEnter:Connect(Show)
        local SelectionGained = Target.SelectionGained:Connect(Show)

        return function()
            MouseEnter:Disconnect()
            SelectionGained:Disconnect()
            if Active then
                Remove()
            end
        end
    end

    function Library:RemoveInfoOverlay()
        Remove()
    end

    function Library:IsInfoOverlayActive()
        return Active ~= nil
    end

    return Library
end
