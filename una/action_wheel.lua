local Game = require("una.game")
if (silly) then if silly:cheatsEnabled() then silly:setFly(true) end end
local function init()
   models.una.models:setPrimaryRenderType("CUTOUT_EMISSIVE_SOLID")
   local page = action_wheel:getCurrentPage()
   if not page then
      page = action_wheel:newPage()
      action_wheel:setPage(page)
   end
   page:setAction(-1, Game.actionWheelAction)

   events.TICK:remove(init)
end
events.TICK:register(init)