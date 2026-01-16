local GameTable = require(game.ServerScriptService:WaitForChild("Modules"):WaitForChild("GameTable"))
NUM_ROWS = 3
NUM_COLS = 5
DX = 15
DZ = 10
Start = Vector3.new(23, 1.5, 18.2)

for row = 0, NUM_ROWS - 1 do
    for col = 0, NUM_COLS - 1 do
        local position = Vector2.new(Start.X + col * DX, Start.Z + row * DZ)
        GameTable.new(position)
    end
end