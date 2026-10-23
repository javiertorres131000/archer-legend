local M = require("./mocks")
local Energy = require("./ArrowEnergyFx")
local Styles = require("./FxStyles")
for _, style in { Styles.get("Celestial"), Styles.get("Void") } do
	for _, low in { false, true } do
		local root = M.Instance.new("Part")
		root.Size = M.Vector3.new(0.1, 0.1, 2.2)
		root.CFrame = M.CFrame.new(0, 0, 0)
		root.Parent = M.workspace
		local existing = M.Instance.new("Trail")
		existing.Parent = root
		local fx = Energy.new(root, style, low)
		local points, beams, motes = {}, {}, {}
		local emitter
		for _, item in root:GetChildren() do
			if item:IsA("Attachment") then table.insert(points, item) end
			if item:IsA("Beam") then table.insert(beams, item) end
			if item:IsA("Part") then table.insert(motes, item) end
			if item:IsA("ParticleEmitter") then emitter = item end
		end
		assert(#points == (if low then 4 else 6) and #motes == (if low then 1 else 2))
		fx.Update(0, true)
		local position = points[2].Position
		local children = #root:GetChildren()
		fx.Update(0.13, true)
		assert((points[2].Position - position).Magnitude > 0.01, "la energía se anima alrededor de la flecha")
		for _, beam in beams do assert(beam.Enabled) end
		assert(emitter.Enabled)
		for i = 1, 60 do fx.Update(i / 60, true) end
		assert(#root:GetChildren() == children, "sin crear nuevas piezas por cuadro")
		fx.Update(1, false)
		assert(not emitter.Enabled, "se apaga cuando sale la flecha cargada")
		for _, beam in beams do assert(not beam.Enabled) end
		for _, mote in motes do assert(mote.Transparency == 1 and not mote.CanCollide) end
		fx.Destroy()
		assert(#root:GetChildren() == 1 and existing.Parent == root, "limpia efectos sin dañar la flecha reutilizada")
	end
end
print("Flechas: animación elemental, calidad baja, visibilidad, coste estable y limpieza OK")
