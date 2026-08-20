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
    local TweenService = game:GetService("TweenService")
    local SoundService = game:GetService("SoundService")
    local Debris = game:GetService("Debris")

    local Active
    local Connections = {}
    local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular)
    local FONT_ITALIC = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Italic)
    local FONT_BOLD = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Bold)
    local FONT_HEAVY = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Heavy)

    local function New(Class, Props, Parent)
        local Object = Instance.new(Class)
        for Key, Value in pairs(Props or {}) do
            Object[Key] = Value
        end
        Object.Parent = Parent
        return Object
    end

    local function Seq(Values)
        local Points = {}
        for Index = 1, #Values, 4 do
            table.insert(Points, ColorSequenceKeypoint.new(Values[Index], Color3.new(Values[Index + 1], Values[Index + 2], Values[Index + 3])))
        end
        return ColorSequence.new(Points)
    end

    local Rarities = {
        Basic = {DisplayName = "Basic", Gradient = Seq({0,.760784,.752941,.862745,1,.580392,.568627,.654902}), Rotation = 100},
        Rare = {DisplayName = "Rare", Gradient = Seq({0,.443137,1,.243137,1,.443137,1,.243137}), Rotation = 100},
        Epic = {DisplayName = "Epic", Gradient = Seq({0,.160784,.847059,1,1,.160784,.886275,1}), Rotation = 100},
        Legendary = {DisplayName = "Legendary", Gradient = Seq({0,1,.788235,.294118,1,1,.521569,.133333}), Rotation = 100},
        Mythical = {DisplayName = "Mythical", Gradient = Seq({0,1,.431373,.431373,1,1,.168627,.392157}), Rotation = 100},
        Exotic = {DisplayName = "Exotic", Gradient = Seq({0,1,.6,1,1,1,.113725,.984314}), Rotation = 100},
        Divine = {DisplayName = "Divine", Gradient = Seq({0,1,1,.6,1,1,.85098,.0980392}), Rotation = 100},
        Superior = {DisplayName = "Superior", Gradient = Seq({0,.784314,1,1,.5,.862745,1,1,1,.72549,1,1}), Rotation = 100},
        Celestial = {DisplayName = "Celestial", Gradient = Seq({0,.760784,1,.717647,.318339,.619608,.898039,1,.747405,1,.721569,.984314,1,1,.545098,.952941}), Rotation = -90},
        Secret = {DisplayName = "Secret", Gradient = Seq({0,.176471,.188235,.372549,.0155709,.176471,.188235,.372549,.0570934,.364706,.133333,.568627,.221453,.827451,.243137,.721569,.268166,1,.411765,.941176,.313149,.827451,.243137,.721569,.370242,.686275,.286275,.784314,1,.176471,.188235,.372549}), Rotation = -92, Offset = Vector2.new(0,-.1)},
        Exclusive = {DisplayName = "Exclusive", Gradient = Seq({0,.65098,.545098,1,1,.678431,.309804,1}), Rotation = 100, Star = true, Animated = true},
        ["Secret Exclusive"] = {DisplayName = "Secret Exclusive", Gradient = Seq({0,.176471,.188235,.372549,.0155709,.176471,.188235,.372549,.0570934,.364706,.133333,.568627,.221453,.827451,.243137,.721569,.268166,1,.411765,.941176,.313149,.827451,.243137,.721569,.370242,.686275,.286275,.784314,1,.176471,.188235,.372549}), Rotation = -92, Offset = Vector2.new(0,-.1), Star = true, Animated = true},
    }

    local SHINY = Seq({0,1,.945098,.717647,.202422,1,.87451,.698039,.479239,1,.835294,.933333,.754325,.756863,.85098,1,1,.980392,.690196,1})
    local EXCLUSIVE_SHINE = Seq({0,.972549,.960784,1,.250432,.972549,.960784,1,.411765,.996078,1,.968627,.595156,.909804,.988235,.992157,.768166,.972549,.960784,1,1,.972549,.960784,1})
    local EXCLUSIVE_OUTLINE = Seq({0,.411765,.227451,.623529,.141869,.411765,.227451,.623529,.247405,.552941,.317647,.866667,.358131,.411765,.227451,.623529,.455017,.411765,.227451,.623529,.544983,.552941,.317647,.866667,.638408,.411765,.227451,.623529,.757785,.411765,.227451,.623529,.8391,.552941,.317647,.866667,.923875,.411765,.227451,.623529,1,.411765,.227451,.623529})
    local SECRET_SHINE = Seq({0,.0941176,.101961,.196078,.0155709,.0941176,.101961,.196078,.0570934,.141176,.054902,.227451,.221453,.329412,.0941176,.290196,.268166,.4,.164706,.376471,.313149,.329412,.0941176,.290196,.370242,.27451,.117647,.313726,1,.0941176,.101961,.196078})
    local SECRET_OUTLINE = Seq({0,.176471,.188235,.372549,.112263,.364706,.133333,.568627,.34715,.827451,.243137,.721569,.614853,.686275,.286275,.784314,1,.176471,.188235,.372549})

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

    local function Gradient(Parent, Value, Rotation, Offset, Name)
        local Object
        if typeof(Value) == "Instance" and Value:IsA("UIGradient") then
            Object = Value:Clone()
        else
            Object = Instance.new("UIGradient")
            if typeof(Value) == "ColorSequence" then
                Object.Color = Value
            elseif type(Value) == "table" then
                local Points = {}
                for Index, Color in ipairs(Value) do
                    if typeof(Color) == "Color3" then
                        table.insert(Points, ColorSequenceKeypoint.new((Index - 1) / math.max(1, #Value - 1), Color))
                    end
                end
                if #Points > 0 then
                    Object.Color = ColorSequence.new(Points)
                end
            end
        end
        if Name then Object.Name = Name end
        if Rotation ~= nil then Object.Rotation = Rotation end
        if typeof(Offset) == "Vector2" then Object.Offset = Offset end
        Object.Parent = Parent
        return Object
    end

    local function Stroke(Label, Color)
        return New("UIStroke", {Color = Color or Color3.fromRGB(76,76,76), LineJoinMode = Enum.LineJoinMode.Round, Thickness = 2}, Label)
    end

    local function ApplyGradient(Label, Value, Rotation, Offset, StrokeToo, Name)
        Label.TextColor3 = Color3.new(1,1,1)
        local Main = Gradient(Label, Value, Rotation, Offset, Name)
        local Outline
        if StrokeToo then
            Outline = Gradient(Label:FindFirstChildOfClass("UIStroke") or Stroke(Label), Value, Rotation, Offset, Name)
        end
        return Main, Outline
    end

    local function TextBlock(Name, Text, Height, Size, Color, Wrapped, Font)
        local Frame = New("Frame", {Name = Name, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1,0,0,Height), ZIndex = 1})
        local Label = New("TextLabel", {
            Name = Name == "Timer" and "timer" or "title",
            AnchorPoint = Vector2.new(.5,.5), BackgroundTransparency = 1, BorderSizePixel = 0,
            FontFace = Font or FONT, LineHeight = 1, Position = UDim2.fromScale(.5,.5), Size = UDim2.fromScale(1,1),
            Text = tostring(Text or ""), TextColor3 = Color, TextSize = Size, TextStrokeTransparency = 1,
            TextWrapped = Wrapped == true, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 1,
        }, Frame)
        return Frame, Label
    end

    local function Base()
        local Base = New("Frame", {Name = "Base", BackgroundTransparency = 1, BorderColor3 = Color3.fromRGB(27,42,53), BorderSizePixel = 1, Size = UDim2.fromOffset(150,300), Visible = false, ZIndex = 1})
        local Pointer = New("ImageLabel", {Name = "pointer", AnchorPoint = Vector2.new(1,1), BackgroundTransparency = 1, BorderSizePixel = 0, Image = "rbxassetid://7160794204", Position = UDim2.fromOffset(30,30), Size = UDim2.fromOffset(40,40), Visible = false, ZIndex = 1}, Base)
        New("ImageLabel", {Name = "pointer", AnchorPoint = Vector2.new(.5,.5), BackgroundTransparency = 1, BorderSizePixel = 0, Image = "rbxassetid://7160794204", ImageColor3 = Color3.fromRGB(59,177,252), Position = UDim2.fromScale(.5,.5), Size = UDim2.new(1,15,1,15), ZIndex = -1}, Pointer)
        local Scale = New("UIScale", {Name = "UIScale", Scale = 1}, Base)
        local Frame = New("Frame", {Name = "Frame", BackgroundColor3 = Color3.new(1,1,1), BorderSizePixel = 0, Size = UDim2.fromScale(1,1), ZIndex = 0}, Base)
        local FrameStroke = New("UIStroke", {Name = "UIStroke", Color = Color3.fromRGB(42,43,49), Thickness = 3}, Frame)
        local Holder = New("Frame", {Name = "Blocks", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1,1), ZIndex = 1}, Frame)
        New("UIListLayout", {FillDirection = Enum.FillDirection.Vertical, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0,3), SortOrder = Enum.SortOrder.LayoutOrder}, Holder)
        New("UIPadding", {PaddingBottom = UDim.new(0,6), PaddingLeft = UDim.new(0,16), PaddingRight = UDim.new(0,16), PaddingTop = UDim.new(0,6)}, Holder)
        local Corner = New("UICorner", {CornerRadius = UDim.new(.05,0)}, Frame)
        local Background = New("ImageLabel", {Name = "background", AnchorPoint = Vector2.new(0,1), BackgroundTransparency = 1, BorderSizePixel = 0, Image = "rbxassetid://13581793331", ImageColor3 = Color3.fromRGB(20,58,67), ImageTransparency = .95, Position = UDim2.fromScale(0,1), ScaleType = Enum.ScaleType.Tile, Size = UDim2.fromScale(1,1), TileSize = UDim2.fromOffset(171,135), ZIndex = 0}, Frame)
        New("UIGradient", {Rotation = -90, Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(.310087,.39375),NumberSequenceKeypoint.new(.495641,.59375),NumberSequenceKeypoint.new(.738481,.825),NumberSequenceKeypoint.new(1,1)})}, Background)
        New("UICorner", {CornerRadius = UDim.new(.035,0)}, Background)
        New("ImageLabel", {Name = "shadow", AnchorPoint = Vector2.new(.5,.5), BackgroundTransparency = 1, BorderColor3 = Color3.new(0,0,0), BorderSizePixel = 0, Image = "rbxassetid://14001321443", ImageColor3 = Color3.new(0,0,0), ImageTransparency = .85, Position = UDim2.fromScale(.5,.5), ScaleType = Enum.ScaleType.Slice, SliceCenter = Rect.new(50,50,150,150), SliceScale = .8, Size = UDim2.new(1,35,1,35), ZIndex = -1}, Base)
        return Base, Frame, Holder, Corner, Scale, FrameStroke
    end

    local Blocks = {}

    Blocks.Title = function(Data)
        local Frame, Label = TextBlock("Title", Data[2], 32, 32, Color3.fromRGB(42,43,49), true, FONT)
        if Data[3] == "Mythical" then ApplyGradient(Label, Rarities.Mythical.Gradient, 100) end
        if Data[4] then Label.TextColor3 = Color3.new(1,1,1) end
        if Data[5] then Label.AutoLocalize = false Label.Text = Label.Text:gsub("%S", "?") end
        return Frame, Label, 65, 250
    end

    Blocks.Nickname = function(Data)
        local Frame, Label = TextBlock("Nickname", Data[2], 20, 20, Color3.fromRGB(130,130,130), false, FONT_ITALIC)
        return Frame, Label, 65, 150
    end

    Blocks.Rarity = function(Data)
        local Value = Data[2]
        local Table = type(Data[3]) == "table" and Data[3] or Rarities
        local Name = type(Value) == "table" and tostring(Value.Name or Value.Rarity or "Basic") or tostring(Value or "Basic")
        local Style = type(Value) == "table" and Value or Table[Name] or Rarities[Name] or {DisplayName = Name}
        local Text = tostring(Style.DisplayName or Name)
        if Style.Star == true or Name == "Exclusive" or Name == "Secret Exclusive" then Text ..= "  ★" end
        local Frame, Label = TextBlock("Rarity", Text, 22, 22, Color3.new(1,1,1), true, FONT_HEAVY)
        Stroke(Label)
        local Main, Outline
        if Style.Gradient or Style.Colors then
            Main, Outline = ApplyGradient(Label, Style.Gradient or Style.Colors, Style.Rotation, Style.Offset, true, "Tier Gradient")
        elseif typeof(Style.Color) == "Color3" then
            Label.TextColor3 = Style.Color
        end
        local Started = os.clock()
        local Render = Style.Animated and Main and function()
            local Time = os.clock() - Started
            Main.Rotation = 100 + Time * 100
            if Outline then Outline.Rotation = 100 - Time * 100 end
        end or nil
        return Frame, Label, 65, 300, nil, Render
    end

    Blocks.Rainbow = function()
        local Frame, Label = TextBlock("Rainbow", "Rainbow", 22, 22, Color3.new(1,1,1), true, FONT_HEAVY)
        Stroke(Label)
        local Main, Outline = ApplyGradient(Label, Seq({0,1,.890196,.0745098,1,.945098,1,.458824}), 0, nil, true, "Gradient")
        return Frame, Label, 65, 200, nil, function()
            local Color = Color3.fromHSV(os.clock() % 3 / 3, .65, 1)
            Main.Color = ColorSequence.new(Color)
            Outline.Color = ColorSequence.new(Color)
        end
    end

    Blocks.Shiny = function()
        local Frame, Label = TextBlock("Shiny", "Shiny", 22, 22, Color3.new(1,1,1), true, FONT_HEAVY)
        Stroke(Label)
        ApplyGradient(Label, SHINY, 105, nil, false, "ShinyGradient")
        return Frame, Label, 65, 300
    end

    Blocks.Desc = function(Data)
        local Frame, Label = TextBlock("Desc", Data[2], 20, 20, Color3.fromRGB(130,130,130), true, FONT)
        if Data[3] == "Mythical" then ApplyGradient(Label, Rarities.Mythical.Gradient, 100) end
        if Data[4] then Label.TextColor3 = Color3.fromRGB(210,210,210) end
        if Data[5] then Label.AutoLocalize = false Label.Text = Label.Text:gsub("%S", "?") end
        return Frame, Label, 65, 175
    end

    Blocks.Div = function(Data)
        local Frame = New("Frame", {Name = "Div", BackgroundTransparency = 1, BorderSizePixel = 1, Size = UDim2.new(1,0,0,15), ZIndex = 1})
        local Div = New("Frame", {Name = "Frame", AnchorPoint = Vector2.new(0,.5), BackgroundColor3 = Data[2] and Color3.new(1,1,1) or Color3.new(0,0,0), BackgroundTransparency = Data[2] and 0 or .9, BorderColor3 = Data[2] and Color3.fromRGB(210,210,210) or Color3.fromRGB(27,42,53), BorderSizePixel = 1, Position = UDim2.fromScale(0,.5), Size = UDim2.new(1,0,0,1), ZIndex = 2}, Frame)
        New("UIGradient", {Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.190535,.3875),NumberSequenceKeypoint.new(.501868,0),NumberSequenceKeypoint.new(.789539,.36875),NumberSequenceKeypoint.new(1,1)})}, Div)
        return Frame
    end

    Blocks.Info = function(Data)
        local Frame, Label = TextBlock("Info", Data[2], 20, 20, Color3.fromRGB(130,130,130), false, FONT)
        if Data[3] then Label.TextColor3 = Color3.new(1,1,1) end
        if Data[4] then Label.AutoLocalize = false Label.Text = Label.Text:gsub("%S", "?") end
        return Frame, Label, 65, 150
    end

    local function MessageBlock(Name, Data, Color, Height)
        local Frame, Label = TextBlock(Name, Data[2], Height, 20, Color, true, FONT)
        if Data[3] == "Mythical" or Data[3] == "Exclusive" then
            local Style = Rarities[Data[3]]
            ApplyGradient(Label, Style.Gradient, Style.Rotation, Style.Offset)
        end
        if Data[4] then Label.TextColor3 = Color3.new(1,1,1) end
        return Frame, Label, 65, 175
    end

    Blocks.Message = function(Data) return MessageBlock("Message", Data, Color3.fromRGB(130,130,130), 20) end
    Blocks.MessageDark = function(Data) return MessageBlock("MessageDark", Data, Color3.fromRGB(42,43,49), 21) end

    Blocks.Hidden = function(Data)
        local Frame, Label = TextBlock("Hidden", Data[2] == true and "Hidden" or tostring(Data[2] or "Hidden"), 20, 20, Color3.fromRGB(221,20,20), false, FONT_BOLD)
        return Frame, Label, 65, 150
    end

    local function TradeBlock(Name, Text, Color, Image)
        local Frame = New("Frame", {Name = Name, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1,0,0,25), ZIndex = 1})
        New("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0,5), SortOrder = Enum.SortOrder.LayoutOrder}, Frame)
        local Icon = New("ImageLabel", {Name = "ImageLabel", BackgroundTransparency = 1, BorderSizePixel = 0, Image = Image, ImageColor3 = Color, LayoutOrder = 1, ScaleType = Enum.ScaleType.Fit, Size = UDim2.fromOffset(25,25), ZIndex = 1}, Frame)
        New("UIAspectRatioConstraint", {AspectRatio = 1}, Icon)
        local Label = New("TextLabel", {Name = "title", AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, BorderSizePixel = 0, FontFace = FONT, LayoutOrder = 2, Size = UDim2.new(0,0,1,0), Text = Text, TextColor3 = Color, TextSize = 23, TextStrokeTransparency = 1, TextWrapped = false, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 2}, Frame)
        return Frame, Label, 149, 150
    end

    Blocks.Tradable = function() return TradeBlock("Tradable", "Tradable", Color3.fromRGB(42,221,102), "rbxassetid://9883445072") end
    Blocks.NotTradable = function() return TradeBlock("NotTradable", "Untradable", Color3.fromRGB(221,42,42), "rbxassetid://15331642883") end

    Blocks.Deal = function(Data)
        local Value = tonumber(Data[2]) or 0
        local Text, Color = "Bad Deal", Color3.fromRGB(254,79,82)
        if Value == 1 then Text, Color = "Good Deal", Color3.fromRGB(129,253,255) elseif Value == 2 then Text, Color = "Great Deal!", Color3.fromRGB(113,255,62) end
        local Frame, Label = TextBlock("Deal", Text, 20, 16, Color, true, FONT)
        Stroke(Label, Color3.new(0,0,0))
        return Frame, Label, 65, 200
    end

    local function NumberShorten(Value)
        Value = tonumber(Value) or 0
        for _, Entry in ipairs({{1e15,"q"},{1e12,"t"},{1e9,"b"},{1e6,"m"},{1e3,"k"}}) do
            if math.abs(Value) >= Entry[1] then
                local Number = Value / Entry[1]
                return string.format(Number >= 100 and "%.0f" or Number >= 10 and "%.1f" or "%.2f", Number):gsub("%.?0+$", "") .. Entry[2]
            end
        end
        return tostring(math.floor(Value))
    end

    Blocks.Exists = function(Data)
        local Count = tonumber(Data[2]) or 0
        local Frame, Label = TextBlock("Exists", NumberShorten(Count) .. (Count == 1 and " Exists" or " Exist"), 20, 20, (Data[4] or Data[3]) and Color3.new(1,1,1) or Color3.fromRGB(42,43,49), false, FONT)
        Label.AutomaticSize = Enum.AutomaticSize.X
        return Frame, Label, 65, 200
    end

    Blocks.Empowered = function(Data)
        local Frame, Label = TextBlock("Empowered", "Empowered", 22, 22, Color3.fromRGB(253,194,255), false, FONT_HEAVY)
        Stroke(Label)
        ApplyGradient(Label, Seq({0,1,.890196,.0745098,1,.945098,1,.458824}), 0, nil, true, "Gradient")
        local Value = Data[2]
        local function Update()
            local Remaining
            if type(Value) == "function" then
                Remaining = tonumber(Value()) or 0
            elseif type(Value) == "table" and tonumber(Value.Expires) then
                Remaining = Value.Expires - workspace:GetServerTimeNow()
            elseif tonumber(Value) then
                local Number = tonumber(Value)
                if Number > 100000000000 then Remaining = math.huge elseif Number > workspace:GetServerTimeNow() then Remaining = Number - workspace:GetServerTimeNow() else Remaining = Number end
            else
                Remaining = math.huge
            end
            if Remaining == math.huge or Remaining > 100000000000 then
                Label.Text = "Empowered"
            else
                Remaining = math.max(0, math.floor(Remaining))
                Label.Text = string.format("Empowered: %02d:%02d:%02d", math.floor(Remaining / 3600), math.floor(Remaining % 3600 / 60), Remaining % 60)
            end
        end
        Update()
        return Frame, Label, 65, 200, Update
    end

    Blocks.Timer = function(Data)
        local Frame, Label = TextBlock("Timer", "", 20, 20, Color3.fromRGB(71,184,255), false, FONT)
        local Value = Data[2]
        local function Update()
            local Number = math.max(0, math.floor(tonumber(type(Value) == "function" and Value() or Value) or 0))
            if Number == 0 then
                Label.Text = "EXPIRED"
            elseif Data[3] then
                local Text = tostring(Number)
                Label.Text = Text:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "") .. "x"
            elseif Number < 86400 then
                Label.Text = os.date("!%X", Number)
            else
                Label.Text = string.format("%dd %02d:%02d:%02d", math.floor(Number / 86400), math.floor(Number % 86400 / 3600), math.floor(Number % 3600 / 60), Number % 60)
            end
        end
        Update()
        return Frame, Label, 65, 200, Update
    end

    Blocks.UpdatingDesc = function(Data)
        local Frame, Label = TextBlock("UpdatingDesc", "", 20, 20, Color3.fromRGB(130,130,130), true, FONT)
        Label.RichText = true
        local Callback = type(Data[2]) == "function" and Data[2] or function() return Data[2] end
        local Update = function() Label.Text = tostring(Callback() or "") end
        Update()
        return Frame, Label, 65, 175, Update
    end

    Blocks.GradientText = function(Data)
        local Frame, Label = TextBlock("GradientText", Data[2], 22, 22, Color3.new(1,1,1), true, FONT_HEAVY)
        Stroke(Label)
        if Data[3] then ApplyGradient(Label, Data[3], nil, nil, true) end
        return Frame, Label, 65, 200
    end

    local function Block(Type, Value, Extra)
        if Type == "Title" then
            return type(Value) == "table" and {"Title", Value.Text or Value.Title or "", Value.Rarity, Value.White == true, Value.Magic == true} or {"Title", Value}
        elseif Type == "Nickname" then
            return {"Nickname", type(Value) == "table" and (Value.Text or "") or Value}
        elseif Type == "Rarity" then
            return {"Rarity", Value, Extra}
        elseif Type == "Rainbow" or Type == "Shiny" or Type == "Hidden" then
            return {Type, Value}
        elseif Type == "Desc" then
            return type(Value) == "table" and {"Desc", Value.Text or "", Value.Rarity, Value.White == true, Value.Magic == true} or {"Desc", Value}
        elseif Type == "Div" then
            return {"Div", type(Value) == "table" and Value.White == true or false}
        elseif Type == "Info" then
            return type(Value) == "table" and Value.Text ~= nil and {"Info", Value.Text, Value.White == true, Value.Magic == true} or {"Info", Value}
        elseif Type == "Message" or Type == "MessageDark" then
            return type(Value) == "table" and {Type, Value.Text or "", Value.Rarity, Value.White == true} or {Type, Value}
        elseif Type == "Tradable" then
            return {"Tradable"}
        elseif Type == "NotTradable" then
            return {"NotTradable"}
        elseif Type == "Deal" then
            return {"Deal", Value}
        elseif Type == "Exists" then
            return type(Value) == "table" and {"Exists", Value.Count or Value.Value or 0, nil, Value.White == true} or {"Exists", Value}
        elseif Type == "Empowered" then
            return {"Empowered", Value}
        elseif Type == "Timer" then
            return type(Value) == "table" and {"Timer", Value.Value or Value.Callback or 0, Value.Multiplier == true} or {"Timer", Value}
        elseif Type == "UpdatingDesc" then
            return {"UpdatingDesc", Value}
        elseif Type == "GradientText" then
            return type(Value) == "table" and {"GradientText", Value.Text or "", Value.Gradient or Value.Colors} or {"GradientText", Value}
        end
    end

    local function AddProp(Result, Type, Value, Extra)
        if Value == nil or Value == false then return end
        if (Type == "Info" or Type == "Message" or Type == "MessageDark") and type(Value) == "table" and Value.Text == nil and Value[1] ~= nil then
            for _, Entry in ipairs(Value) do
                local Item = Block(Type, Entry, Extra)
                if Item then table.insert(Result, Item) end
            end
            return
        end
        local Item = Block(Type, Value, Extra)
        if Item then table.insert(Result, Item) end
    end

    local function Normalize(Data)
        if type(Data) ~= "table" then return {} end
        if type(Data[1]) == "table" then return Data end
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
                if Parsed then table.insert(Result, Parsed) end
            end
        end
        return Result
    end

    local function GetScreen(Window)
        if Window._InfoOverlayScreen and Window._InfoOverlayScreen.Parent then return Window._InfoOverlayScreen end
        local Screen = New("ScreenGui", {Name = "InfoOverlay", DisplayOrder = 10000, ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Global}, Window.Screen and Window.Screen.Parent or Players.LocalPlayer:WaitForChild("PlayerGui"))
        Window._InfoOverlayScreen = Screen
        if Window.Screen then
            Window._InfoOverlayScreenConnection = Window.Screen.Destroying:Connect(function()
                if Screen.Parent then Screen:Destroy() end
            end)
        end
        return Screen
    end

    local function AddShine(Frame, FrameStroke, RarityName, Metas)
        if RarityName ~= "Exclusive" and RarityName ~= "Secret Exclusive" then return end
        FrameStroke.Color = Color3.new(1,1,1)
        local Shine, Outline, Speed
        if RarityName == "Secret Exclusive" then
            Shine = Gradient(Frame, SECRET_SHINE, -45, Vector2.new(0,-1.25), "SecretExclusiveShine")
            Outline = Gradient(FrameStroke, SECRET_OUTLINE, -92, Vector2.new(0,-.1), "SecretExclusiveShineOutline")
            Speed = 50
        else
            Shine = Gradient(Frame, EXCLUSIVE_SHINE, 45, Vector2.new(0,-1.25), "ExclusiveShine")
            Outline = Gradient(FrameStroke, EXCLUSIVE_OUTLINE, 50, nil, "ExclusiveShineOutline")
            Speed = 100
        end
        TweenService:Create(Shine, TweenInfo.new(.75, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Offset = Vector2.new(0,2)}):Play()
        local Started = os.clock()
        table.insert(Metas, {Render = function() Outline.Rotation = 100 + (os.clock() - Started) * Speed end})
    end

    local function Add(Window, Target, Data)
        Remove()
        Data = Normalize(Data)
        local Overlay, MainFrame, Holder, Corner, Scale, FrameStroke = Base()
        local Metas = {}
        local RarityName

        local function UpdateSize()
            local Width, Height, Count = 0, 12, 0
            for _, Meta in ipairs(Metas) do
                if Meta.Frame then
                    Count += 1
                    local BlockHeight = Meta.Height or Meta.Frame.Size.Y.Offset
                    if Meta.Label then
                        local Bounds = TextService:GetTextSize(Meta.Label.ContentText, Meta.Label.TextSize, Enum.Font.Arial, Vector2.new(Meta.MaxWidth or 200, 1000))
                        local TextWidth, TextHeight = Bounds.X + 10, Bounds.Y + 1
                        local LabelStroke = Meta.Label:FindFirstChildOfClass("UIStroke")
                        local StrokeSize = LabelStroke and LabelStroke.Thickness * 2 or 0
                        Width = math.max(Width, math.clamp(TextWidth + StrokeSize, Meta.MinWidth or 0, Meta.MaxWidth or math.huge))
                        BlockHeight = math.max(BlockHeight, TextHeight) + StrokeSize
                        if Meta.Label.AutomaticSize ~= Enum.AutomaticSize.X then Meta.Label.Size = UDim2.fromOffset(TextWidth, TextHeight) end
                        Meta.Frame.Size = UDim2.new(1,0,0,BlockHeight)
                    elseif Meta.MinWidth then
                        Width = math.max(Width, Meta.MinWidth)
                    end
                    Height += BlockHeight
                end
            end
            Height += math.max(0, Count - 1) * 3
            Overlay.Size = UDim2.fromOffset(Width + 32, math.max(12, Height))
            Corner.CornerRadius = UDim.new(Count == 1 and .15 or .05, 0)
            local Camera = workspace.CurrentCamera
            if Camera then
                local ResolutionScale = math.clamp(Camera.ViewportSize.Y / 1080, .33, 2)
                Scale.Scale = 1 - (1 - math.min(ResolutionScale, 1)) / 1.5
            end
        end

        for Index, BlockData in ipairs(Data) do
            local Builder = type(BlockData) == "table" and Blocks[BlockData[1]]
            if Builder then
                local Frame, Label, MinWidth, MaxWidth, Update, Render = Builder(BlockData)
                Frame.LayoutOrder = Index * 100
                Frame.Parent = Holder
                table.insert(Metas, {Frame = Frame, Label = Label, Height = Frame.Size.Y.Offset, MinWidth = MinWidth, MaxWidth = MaxWidth, Update = Update, Render = Render})
                if BlockData[1] == "Rarity" then
                    RarityName = type(BlockData[2]) == "table" and tostring(BlockData[2].Name or BlockData[2].Rarity or "") or tostring(BlockData[2] or "")
                end
            end
        end
        if #Metas == 0 then Overlay:Destroy() return nil end

        AddShine(MainFrame, FrameStroke, RarityName, Metas)
        UpdateSize()
        Overlay.Parent = GetScreen(Window)
        Active = Overlay

        local Sound = New("Sound", {SoundId = "rbxassetid://6907626084", Volume = .2}, SoundService)
        Sound:Play()
        Debris:AddItem(Sound, 3)

        table.insert(Connections, Target.MouseLeave:Connect(function() if GuiService.SelectedObject ~= Target then Remove() end end))
        table.insert(Connections, Target.SelectionLost:Connect(Remove))
        table.insert(Connections, Target.Destroying:Connect(Remove))

        local LastUpdate = 0
        table.insert(Connections, RunService.RenderStepped:Connect(function()
            if Active ~= Overlay or not Overlay.Parent then return end
            local Now, Resize = os.clock(), false
            for _, Meta in ipairs(Metas) do
                if Meta.Render then Meta.Render() end
                if Meta.Update and Now - LastUpdate >= .1 then Meta.Update() Resize = true end
            end
            if Now - LastUpdate >= .1 then LastUpdate = Now end
            if Resize then UpdateSize() end

            local Camera = workspace.CurrentCamera
            if not Camera then return end
            local Mouse = Players.LocalPlayer:GetMouse()
            local X, Y = Mouse.X, Mouse.Y
            if GuiService.SelectedObject == Target then
                X = Target.AbsolutePosition.X + Target.AbsoluteSize.X * .5
                Y = Target.AbsolutePosition.Y + Target.AbsoluteSize.Y * .5
            end
            local GuiInset = GuiService:GetGuiInset()
            local Size = Overlay.AbsoluteSize
            local MaxY = Camera.ViewportSize.Y - GuiInset.Y
            local Up = Y + Size.Y + 10 >= MaxY and Y - Size.Y - 10 > 0
            Overlay.AnchorPoint = Vector2.new(0, Up and 1 or 0)
            Overlay.Position = UDim2.fromOffset(
                math.clamp(X + 10, 0, math.max(0, Camera.ViewportSize.X - GuiInset.X - Size.X)),
                math.clamp(Y + (Up and -10 or 10), 0, math.max(0, MaxY + (Up and Size.Y or -Size.Y)))
            )
            if not Overlay.Visible then Overlay.Visible = true end
        end))
        return Overlay
    end

    function Library:InfoOverlay(Target, Data)
        assert(typeof(Target) == "Instance" and Target:IsA("GuiObject"), "InfoOverlay target must be a GuiObject")
        assert(type(Data) == "table", "InfoOverlay data must be a table")
        local MouseEnter = Target.MouseEnter:Connect(function() Add(self, Target, Data) end)
        local SelectionGained = Target.SelectionGained:Connect(function() Add(self, Target, Data) end)
        return function()
            MouseEnter:Disconnect()
            SelectionGained:Disconnect()
            if Active then Remove() end
        end
    end

    function Library:DynamicInfoOverlay(Target, Callback)
        assert(typeof(Target) == "Instance" and Target:IsA("GuiObject"), "DynamicInfoOverlay target must be a GuiObject")
        assert(type(Callback) == "function", "DynamicInfoOverlay callback must be a function")
        local function Show()
            local Data = Callback()
            if type(Data) == "table" and next(Data) then Add(self, Target, Data) end
        end
        local MouseEnter = Target.MouseEnter:Connect(Show)
        local SelectionGained = Target.SelectionGained:Connect(Show)
        return function()
            MouseEnter:Disconnect()
            SelectionGained:Disconnect()
            if Active then Remove() end
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
