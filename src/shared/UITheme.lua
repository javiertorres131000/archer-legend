-- UITheme (ModuleScript)
-- Ubicación: ReplicatedStorage > Shared > UITheme
-- Estilo visual común de las interfaces: fantasía oscura con detalles dorados.
-- Colores, tipografías, íconos y constructores de piezas reutilizables, para que el lobby
-- y el HUD se vean como parte del mismo juego.

local TweenService = game:GetService("TweenService")

local C = Color3.fromRGB

local Theme = {}

Theme.Colors = {
	Background = C(14, 12, 20), -- fondo de pantalla completa
	Panel = C(24, 21, 33), -- paneles
	PanelLight = C(36, 32, 48), -- tarjetas dentro de paneles
	Gold = C(212, 168, 70),
	GoldBright = C(246, 208, 122),
	GoldDark = C(120, 90, 36),
	Text = C(238, 229, 210),
	TextMuted = C(160, 150, 132),
	Success = C(96, 196, 120),
	Danger = C(214, 82, 82),
	Locked = C(90, 84, 100),
}

Theme.Fonts = {
	Title = Enum.Font.Fondamento, -- caligrafía de fantasía (títulos grandes)
	Heading = Enum.Font.Merriweather, -- encabezados de panel
	Body = Enum.Font.BuilderSansMedium, -- texto general (moderno y legible en móvil)
	Bold = Enum.Font.BuilderSansBold,
}

-- Íconos: un solo juego de glifos para todo el juego
Theme.Icons = {
	Play = "⚔",
	Ready = "✔",
	NotReady = "…",
	Leader = "👑",
	Locked = "🔒",
	Inventory = "🎒",
	Equipment = "🛡",
	Shop = "💰",
	Team = "👥",
	Chapter = "📜",
}

-- Crea una instancia con propiedades e hijos. (Parent se asigna al final, como recomienda Roblox.)
function Theme.make(className: string, props: { [string]: any }, children: { Instance }?): any
	local inst = Instance.new(className)
	for k, v in props do
		if k ~= "Parent" then
			(inst :: any)[k] = v
		end
	end
	for _, child in (children or {}) :: { Instance } do
		child.Parent = inst
	end
	inst.Parent = props.Parent
	return inst
end

function Theme.corner(radius: number): UICorner
	return Theme.make("UICorner", { CornerRadius = UDim.new(0, radius) })
end

function Theme.stroke(color: Color3?, thickness: number?, transparency: number?): UIStroke
	return Theme.make("UIStroke", {
		Color = color or Theme.Colors.Gold,
		Thickness = thickness or 1.5,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Theme.padding(px: number): UIPadding
	return Theme.make("UIPadding", {
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
	})
end

-- Degradé vertical sutil (de arriba más claro a abajo más oscuro)
function Theme.gradient(top: Color3, bottom: Color3): UIGradient
	return Theme.make("UIGradient", {
		Color = ColorSequence.new(top, bottom),
		Rotation = 90,
	})
end

function Theme.text(props: { [string]: any }): TextLabel
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font = props.Font or Theme.Fonts.Body
	props.TextColor3 = props.TextColor3 or Theme.Colors.Text
	props.TextSize = props.TextSize or 18
	return Theme.make("TextLabel", props)
end

-- Panel oscuro con borde dorado
function Theme.panel(props: { [string]: any }): Frame
	props.BackgroundColor3 = props.BackgroundColor3 or Theme.Colors.Panel
	props.BackgroundTransparency = props.BackgroundTransparency or 0.08
	props.BorderSizePixel = 0
	local frame = Theme.make("Frame", props)
	Theme.corner(12).Parent = frame
	Theme.stroke(Theme.Colors.GoldDark, 1.5).Parent = frame
	Theme.gradient(Color3.new(1, 1, 1), C(200, 195, 210)).Parent = frame
	return frame
end

-- Botón grande dorado. Devuelve el botón; el texto se cambia con button.Text.
function Theme.button(props: { [string]: any }): TextButton
	props.BackgroundColor3 = props.BackgroundColor3 or Theme.Colors.Gold
	props.Font = props.Font or Theme.Fonts.Bold
	props.TextColor3 = props.TextColor3 or C(30, 22, 10)
	props.TextSize = props.TextSize or 24
	props.AutoButtonColor = false
	props.BorderSizePixel = 0
	local button = Theme.make("TextButton", props)
	Theme.corner(10).Parent = button
	Theme.stroke(Theme.Colors.GoldBright, 2).Parent = button
	Theme.gradient(Color3.new(1, 1, 1), C(185, 170, 150)).Parent = button
	local scale = Theme.make("UIScale", { Parent = button })

	-- Animación suave al pasar el mouse y al tocar
	local info = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	button.MouseEnter:Connect(function()
		if button.Active then
			TweenService:Create(scale, info, { Scale = 1.04 }):Play()
		end
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(scale, info, { Scale = 1 }):Play()
	end)
	button.MouseButton1Down:Connect(function()
		if button.Active then
			TweenService:Create(scale, info, { Scale = 0.97 }):Play()
		end
	end)
	button.MouseButton1Up:Connect(function()
		TweenService:Create(scale, info, { Scale = 1 }):Play()
	end)
	return button
end

-- Aparece con un leve fundido y crecimiento
function Theme.popIn(frame: GuiObject)
	local scale = frame:FindFirstChildOfClass("UIScale") or Theme.make("UIScale", { Parent = frame })
	scale.Scale = 0.94
	TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

return Theme
