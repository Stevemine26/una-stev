local Sync,Card,Game=require('una.sync'),require('una.card'),require('una.game')

local function updateGameState()
   if gameState == 0 then
      Sync.setGameState(1)
   end
end

function nextPlayer(amount,cycle)
    if (not cycle) then
        Sync.setCurrentPlayer(Sync.getCurrentPlayerIndex() + (amount or 1))
    else for _=1,amount,1 do nextPlayer(1,false)end end
end
function prevPlayer(amount,cycle)
    if not cycle then
        if type(amount)=="number" then Sync.setCurrentPlayer(Sync.getCurrentPlayerIndex() - (amount or 1)) else Sync.setCurrentPlayer(Sync.getCurrentPlayerIndex() - 1) end
    else for _=1,amount,1 do prevPlayer(1,false)end end
end
function addPlayer(name,cards)
    if type(name)=="table" then
        if gameState==2 then
            for _,name2 in ipairs(name) do
                if type(name2)=="string" then Sync.addPlayerAndSetCards(name2,cards,false) end
            end
        else
            for _,name2 in ipairs(name) do
                if type(name2)=="string" then Sync.addPlayer(name2,false) end
            end
        end
    elseif type(name)=="string" then
        if name=="!All" then
            for i,v in pairs(world.getPlayers()) do
                if gameState==2 then
                    Sync.addPlayerAndSetCards(v:getName(),cards,false)
                else
                    Sync.addPlayer(v:getName(),false)
                end
            end
        else
            if gameState==2 then
                Sync.addPlayerAndSetCards(name,cards,false)
            else
                Sync.addPlayer(name,false)
            end
        end
    else
        error("name not string or table of strings")
    end
end
function removePlayer(name)
    Sync.removePlayer(name,false)
end
function drawCard(name,id,amount)
    if type(id)=="string" then
        id=Card.type2index(id)
    end
    if name =="!All" then
        for i=1,Sync.getPlayersCount() do
            for _=1,1 or amount do Sync.drawCard(Sync.getPlayersOrder()[i],Card.typeAndColorToFullId(id,1)) end
        end
    else
        for _=1,1 or amount do Sync.drawCard(name,Card.typeAndColorToFullId(id,1)) end
    end
end
function setCard(name,id,idx)
    if type(id)=="string" then
        id=Card.type2index(id)
    end
    Sync.setCard(name,idx,Card.typeAndColorToFullId(id,1),false)
end
function drawRandomCard(name,amount)
    if name == "!All" then
        for i=1,Sync.getPlayersCount() do
            for _=1,1 or amount do Sync.drawCard(Sync.getPlayersOrder()[i],nil) end
        end
    else
        for _=1,1 or amount do Sync.drawCard(name,nil) end
    end
end
function setNext(id)
    Sync.setNextCard(Card.typeAndColorToFullId(id,1))
end
function getNext()
    return Sync.getNextCard()
end
function regenCards()
    Card.regenCards()
end
function setDrawAmount(amount)
    Sync.setDrawCardsCount(amount or 0,false)
end
function setBit(bit,value)
    if value then
        Sync.setBitFlag(bit,1)
    else
        Sync.setBitFlag(bit,0)
    end
end
function setCustom(value)
    if not value then
        Sync.setBitFlag(3,0)
    else
        Sync.setBitFlag(3,1)
    end
    Card.regenCards()
end
function setBlinded(name,turns)Sync.setBlinded(name,turns)end
function repositionPlayer(name)
    local gamePos = Sync.getGamePos()
	local entity = world.getPlayers()[name]
	local offset
	if entity then
		local myOffset = entity:getPos().xz - gamePos.xz
		if myOffset:length() > 0.000001 then
			offset = myOffset
		end
	end
	local rot = offset and math.deg(math.atan2(offset.y, offset.x)) or math.random() * 360
	rot = rot % 360
	Sync.setPlayerRot(name, -rot,true)
    if not host:isHost() then
		return
	end
	local oldPlayersOrder = Sync.getPlayersOrder()
	local playersOrderData = {}
	for i, name in ipairs(oldPlayersOrder) do
		local rot = Sync.getPlayerRot(name)
		table.insert(playersOrderData, math.floor(rot * 256) * 256 + i)
	end
	table.sort(playersOrderData)
	local playersOrder = {}
	for i, v in ipairs(playersOrderData) do
		local k = v % 256
		playersOrder[i] = oldPlayersOrder[k]
	end
	Sync.setPlayersOrder(playersOrder)
    local new = Sync.getPlayersCount() * 0.25 + 2
	if new == cardsRadius then
		return
	end
	cardsRadius = new
	for _, name in pairs(Sync.getPlayersOrder()) do
		requestCardUpdate(name)
	end
end

events.ENTITY_INIT:register(function()
    nameplate.ALL:setText(":uno_card:"..player:getName().." ${badges}")
    events.tick:register(function()
        local cardStack=Sync.getRawCards("!")
        local topCard=cardStack[#cardStack]
        --[[if topCard~=nil then
            local type,color=Card.fullIdToTypeAndColor(topCard)
            avatar:setColor(colorIdxToHex[color])
            nameplate.ALL:setText(toJson({
                {text=":uno_card:"..player:getName().." ${badges}",color=colorIdxToHex[color]}
            }))
        else
            avatar:setColor(nil)
            nameplate.ALL:setText(toJson({
                {text=":uno_card:"..player:getName().." ${badges}"}
            }))
        end]]
    end,"commandUtil")
end,"commandUtil")