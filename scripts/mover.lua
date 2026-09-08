print("Script de enjambre cargado")

local angle = 0

function update(dt)
    print("update llamado con dt=" .. dt)
    angle = angle + dt * 0.5
    local x = math.cos(angle) * 2.0
    local z = math.sin(angle) * 2.0
    set_position(x, 0.0, z)
    set_rotation(0.0, angle * 10, 0.0)
end

return update