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
        return Frame, Label, 65, 250
    end

    Blocks.Nickname = function(Data)
        local Frame, Label = TextBlock("Nickname", Data[2], 20, 20, Color3.fromRGB(130, 130, 130), false, FONT_ITALIC)
        return Frame, Label, 65, 150
    end

    Blocks.Desc = function(Data)
        local Frame, Label = TextBlock("Desc", Data[2], 20, 20, Data[4] and Color3.fromRGB(210, 210, 210) or Color3.fromRGB(130, 130, 130), true)
        return Frame, Label, 65, 175
    end

    Blocks.Info = function(Data)
        local Frame, Label = TextBlock("Info", Data[2], 20, 20, Data[3] and Color3.new(1, 1, 1) or Color3.fromRGB(130, 130, 130), false)
        return Frame, Label, 65, 150
    end

    Blocks.Message = function(Data)
        local Frame, Label = TextBlock("Message", Data[2], 20, 20, Data[4] and Color3.new(1, 1, 1) or Color3.fromRGB(130, 130, 130), true)
        return Frame, Label, 65, 175
    end

    Blocks.MessageDark = function(Data)
        local Frame, Label = TextBlock("MessageDark", Data[2], 21, 20, Data[4] and Color3.new(1, 1, 1) or Color3.fromRGB(42, 43, 49), true)
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

    Blocks.UpdatingDesc = function(Data)
        local Frame, Label = TextBlock("UpdatingDesc", "", 20, 20, Color3.fromRGB(130, 130, 130), true)
        Label.RichText = true
        return Frame, Label, 65, 175, type(Data[2]) == "function" and Data[2] or nil
    end

    Blocks.Timer = function(Data)
        local Frame, Label = TextBlock("Timer", "", 20, 20, Color3.fromRGB(71, 184, 255), false)
        local Callback = type(Data[2]) == "function" and Data[2] or nil
        local function Update()
            local Value = math.max(0, math.floor(tonumber(Callback and Callback() or 0) or 0))
            if Data[3] then
                Label.Text = tostring(Value) .. "x"
            elseif Value == 0 then
                Label.Text = "EXPIRED"
            else
                local Hours = math.floor(Value / 3600)
                local Minutes = math.floor(Value % 3600 / 60)
                local Seconds = Value % 60
                Label.Text = string.format("%02d:%02d:%02d", Hours, Minutes, Seconds)
            end
        end
        Update()
        return Frame, Label, 65, 200, Update
    end

    local function Add(Window, Target, Data)
        Remove()

        local Overlay, Holder = Base()
        local Metas = {}
        local Height = 12
        local Width = 65

        for Index, BlockData in ipairs(Data or {}) do
            local Builder = type(BlockData) == "table" and Blocks[BlockData[1]]
            if Builder then
                local Frame, Label, MinWidth, MaxWidth, Update = Builder(BlockData)
                Frame.LayoutOrder = Index * 100
                Frame.Parent = Holder

                local BlockHeight = Frame.Size.Y.Offset
                Height += BlockHeight + 3
                if Label then
                    local Bounds = TextService:GetTextSize(Label.Text, Label.TextSize, Enum.Font.Arial, Vector2.new(MaxWidth, 1000))
                    Width = math.max(Width, math.clamp(Bounds.X + 10, MinWidth, MaxWidth))
                    if Label.TextWrapped then
                        Frame.Size = UDim2.new(1, 0, 0, math.max(BlockHeight, Bounds.Y + 1))
                        Height += math.max(0, Bounds.Y + 1 - BlockHeight)
                    end
                end
                table.insert(Metas, {Label = Label, MinWidth = MinWidth, MaxWidth = MaxWidth, Update = Update})
            end
        end

        Overlay.Size = UDim2.fromOffset(Width + 32, math.max(40, Height))
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

            if os.clock() - LastUpdate >= 0.1 then
                LastUpdate = os.clock()
                for _, Meta in ipairs(Metas) do
                    if Meta.Update then
                        Meta.Update()
                    end
                end
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
