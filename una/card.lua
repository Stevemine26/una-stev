---@diagnostic disable: param-type-mismatch

RandomColorID,RandomIconID=8,29
WildColorID=RandomColorID+1
Wild2ColorID=RandomColorID+2
colorIdxToHex={
   '#d4362b', -- RED
   '#f7cf33', -- YELLOW
   '#57c436', -- GREEN
   '#00d4ff', -- BLUE
   '#ff00ff', -- MISSING
   '#ffffff', -- WHITE
   '#0000ff', -- BSOD
   '#000000', -- RANDOM
   '#2c2d36', -- BLACK
}
cardEmojis={
	wild=':uno_wild:',
	draw2=':uno_draw_2',
	draw4=':uno_draw_4',
	reverse=':uno_reverse',
	skip=':uno_skip',
}
bitFlags = 0

local param = require("una.lib.param")
local Event = require("una.lib.event")

local ROOT_MODEL = models:newPart("cardWorld","WORLD"):scale(16,16,16)
local CARD_MODEL = models.una.models.card:setVisible(false)
CARD_MODEL:setPos(0, 0, 0)
CARD_MODEL.Outline:setPrimaryRenderType("TRANSLUCENT_CULL")

local SCALE = 16
local CARD_DIM = vec(12,16) / 16
local INV_SCALE = 1/SCALE
local OFFSET = vec(0,0.01,0)

local CARD_RADIUS_SQ = CARD_DIM:lengthSquared() / 2
local CARD_DIM_HALF = CARD_DIM / 2

local cards = {} ---@type Card[]

local cardIdsLookup = {} ---@type table<string, Card>
local randomCardList = {}

--[────────────────────────────────────────-< CARD API >-────────────────────────────────────────]--

---@class CardAPI
local CardAPI = {}

CardAPI.ROOT_MODEL = ROOT_MODEL

---@alias CardColor
---| "RED"
---| "YELLOW"
---| "GREEN"
---| "BLUE"
---| "MISSING"
---| "WHITE"
---| "BSOD"
---| "RANDOM"
---| "BLACK"

CardAPI.colorUV = {
	vec( 0, 0), -- RED
	vec(10, 0), -- YELLOW
	vec(20, 0), -- GREEN
	vec(30, 0), -- BLUE
	vec(60, 0), -- MISSING
	vec(50, 0), -- WHITE
	vec(70, 0), -- BSOD
	vec(60, 0), -- RANDOM
	vec(40, 0), -- BLACK
}

CardAPI.iconUV = {
	vec(45, 11), -- EMPTY   
	vec( 0,  0), -- ZERO    
	vec( 9,  0), -- ONE     
	vec(18,  0), -- TWO     
	vec(27,  0), -- THREE   
	vec(36,  0), -- FOUR    
	vec(0,  11), -- FIVE    
	vec(9,  11), -- SIX     
	vec(18, 11), -- SEVEN   
	vec(27, 11), -- EIGHT   
	vec(36, 11), -- NINE    
	vec( 0, 22), -- REVERSE 
	vec(18, 22), -- SKIP    
	vec( 9, 22), -- DRAW2   
	vec(27, 22), -- DRAW4   
	vec(36, 22), -- WILD    
	vec(45,  0), -- UNKNOWN 
	vec(45, 22), -- DRAW12  
	vec(54, 22), -- DROP12  
	vec(36, 33), -- DROP4   
	vec(45, 33), -- DROPCOLOR
	vec(27, 33), -- DROP2
	vec(18, 33), -- DROP1
	vec(18, 44), -- DRAW1
	vec(27, 44), -- DROPSPECIAL
	vec(36, 44), -- DROPSPECIALNEXT
	vec(45, 44), -- DROPCOLORNEXT
--	vec(54,33),
	vec(45,  0), -- RANDOM
}
RandomIconID,RandomColorID,WildColorID,Wild2ColorID,LimboColor,LimboColor2=#CardAPI.iconUV,#CardAPI.colorUV-1,#CardAPI.colorUV,#CardAPI.colorUV+1,#CardAPI.colorUV+2,#CardAPI.colorUV+3
---@alias CardType
---| "EMPTY"
---| "ZERO"
---| "ONE"
---| "TWO"
---| "THREE"
---| "FOUR"
---| "FIVE"
---| "SIX"
---| "SEVEN"
---| "EIGHT"
---| "NINE"
---| "REVERSE"
---| "SKIP"
---| "DRAW2"
---| "DRAW4"
---| "WILD"
---| "UNKNOWN"
---| "DRAW12"
---| "DROP12"
---| "DROP4"
---| "DROPCOLOR"
---| "DROP2"
---| "DROP1"
---| "DRAW1"
---| "DROPSPECIAL"
---| "DROPSPECIALNEXT"
---| "DROPCOLORNEXT"
---| "LIMBO"
---| "RANDOM"

CardAPI.playerUV = {
	vec(6,0), -- TOAST
	vec(6,8), -- GN
	vec(12,8), -- AURIA
	vec(12,0), -- STEVEMINE26
	vec(0,8), -- CLST
	vec(0,16), -- NIKO
	vec(6,16) -- AZURE (Hazzy)
}


CardAPI.index2color = {
	"RED",
	"YELLOW",
	"GREEN",
	"BLUE",
	"MISSING",
	"WHITE",
	"BSOD",
	"BLACK",
}

CardAPI.index2type = {
	"EMPTY",
	"ZERO",
	"ONE",
	"TWO",
	"THREE",
	"FOUR",
	"FIVE",
	"SIX",
	"SEVEN",
	"EIGHT",
	"NINE",
	"REVERSE",
	"SKIP",
	"DRAW2",
	"DRAW4",
	"WILD",
	"UNKNOWN",
	"DRAW12",
	"DROP12",
	"DROP4",
	"DROPCOLOR",
	"DROP2",
	"DROP1",
	"DRAW1",
	"DROPSPECIAL",
	"DROPSPECIALNEXT",
	"DROPCOLORNEXT",
--	"LIMBO",
	"RANDOM",
}

CardAPI.color2index = {}
CardAPI.type2index = {}
for i, color in ipairs(CardAPI.index2color) do
	CardAPI.color2index[color] = i
end
for i, type in ipairs(CardAPI.index2type) do
	CardAPI.type2index[type] = i
end

CardAPI.lastCardId = #CardAPI.index2color * #CardAPI.index2type

---converts full card id to color and type ids
---@param id number
---@return number # type
---@return number # color
function CardAPI.fullIdToTypeAndColor(id)
   id = id - 1
   return id % #CardAPI.index2type + 1, math.floor(id / #CardAPI.index2type) + 1
end

---converts card type and color to full id
---@param cardType number
---@param color number
---@return number
function CardAPI.typeAndColorToFullId(cardType, color)
   return (cardType - 1) + #CardAPI.index2type * (color - 1) + 1
end

---@param id integer?
---@return string
function CardAPI.indexToType(id)
	if not id then
		id = math.random(1, #CardAPI.index2type)
	end
	return CardAPI.index2type[id]
end


---@param id integer?
function CardAPI.indexToColor(id)
	if not id then
		id = math.random(1, #CardAPI.index2color)
	end
	return CardAPI.index2color[id]
end


---@param clr CardColor
---@return integer
function CardAPI.colorToIndex(clr)
	return CardAPI.color2index[clr]
end

---@param type CardType
---@return integer
function CardAPI.typeToIndex(type)
	return CardAPI.type2index[type]
end

function CardAPI.regenCards()
	randomCardList={}
	if not bit32.btest(bitFlags, 2 ^ 4) then
		for color = 1, RandomColorID-1 do
			for cardType = 2, 11 do
				local id = CardAPI.typeAndColorToFullId(cardType, color)
				table.insert(randomCardList, id)
				table.insert(randomCardList, id)
				table.insert(randomCardList, id)
				table.insert(randomCardList, id) -- give higher chance to number cards
			end
			for cardType = 12, 14 do
				local id = CardAPI.typeAndColorToFullId(cardType, color)
				table.insert(randomCardList, id)
				table.insert(randomCardList, id) -- give higher chance to colorful cards
			end
			for cardType = 20,21 do
				local id = CardAPI.typeAndColorToFullId(cardType, color)
				table.insert(randomCardList, id)
			end
			for cardType = 22, 27 do
				local id = CardAPI.typeAndColorToFullId(cardType, color)
				if (cardType==26 or cardType==27)  then
					if bit32.btest(bitFlags, 2 ^ 2) then
						table.insert(randomCardList, id)
					end
				else
					table.insert(randomCardList, id)
					table.insert(randomCardList, id) -- give higher chance to colorful cards
				end
			end
			--table.insert(randomCardList, CardAPI.typeAndColorToFullId(RandomIconID,RandomColorID))
			table.insert(randomCardList, CardAPI.typeAndColorToFullId(25, WildColorID))
			if bit32.btest(bitFlags, 2 ^ 2) then table.insert(randomCardList, CardAPI.typeAndColorToFullId(26, WildColorID)) end
			local id = CardAPI.typeAndColorToFullId(20, color)
			table.insert(randomCardList, id)
			table.insert(randomCardList, CardAPI.typeAndColorToFullId(15, WildColorID))
			table.insert(randomCardList, CardAPI.typeAndColorToFullId(16, WildColorID))
		end
		if bit32.btest(bitFlags, 2 ^ 2) then
			table.insert(randomCardList, CardAPI.typeAndColorToFullId(18, WildColorID))
			table.insert(randomCardList, CardAPI.typeAndColorToFullId(19, WildColorID))
		end
	else
		for color = 1, 4 do
			for cardType = 2, 14 do
				local id = CardAPI.typeAndColorToFullId(cardType, color)
				table.insert(randomCardList, id)
				table.insert(randomCardList, id) -- give higher chance to colorful cards
			end
			table.insert(randomCardList, CardAPI.typeAndColorToFullId(15, WildColorID))
			table.insert(randomCardList, CardAPI.typeAndColorToFullId(16, WildColorID))
		end
	end
end
CardAPI.regenCards()

---@return number
function CardAPI.getRandomCard()
	return randomCardList[math.random(#randomCardList)]
end

---@param id integer
---@return boolean
function CardAPI.isValidCardId(id)
	return id >= 1 and id <= CardAPI.lastCardId
end

function CardAPI.getCardIdsLookup()
	return cardIdsLookup
end

CardAPI.CARD_PRESSED = Event.new()
CardAPI.CARD_HOVER = Event.new()


--[────────────────────────────────────────-< CARD OBJECT >-────────────────────────────────────────]--


---@class Card
---@field color integer
---@field type integer
---@field owner string?
---@field animMatrix Matrix4
---@field matrix Matrix4
---@field invMatrix Matrix4
---@field pos Vector3
---@field dir Vector3
---@field rot Vector3
---@field offset Vector3
---@field scale Vector3
---@field model ModelPart
---@field model2 ModelPart
---@field tag string?
---@field idx integer
---@field id string?
---@field PRESSED Event
---@field [any] any
---@field CARD_HOVER Event
local Card = {}
Card.__index = Card


local nextFree = 0
---@param parent ModelPart?
---@return Card
function CardAPI.new(parent)
	nextFree = nextFree + 1
	local model = (parent or ROOT_MODEL):newPart("card" .. nextFree)
	local model2 = model:newPart('')

	---@type Card
	local new = {
		idx = nextFree, -- index
		color = 1,
		type = 1,
		dir = vec(0,1,0),

		pos = vec(0,0,0),
		rot = vec(0,0,0),
		scale = vec(1,1,1),
		offset = vec(0,0,0),

		animPos = vec(0,0,0),
		animRot = vec(0,0,0),
		animScale = vec(1,1,1),

		animMatrix = matrices.mat4(),
		matrix = matrices.mat4(),
		invMatrix = matrices.mat4(),
		model = model,
		model2 = model2,
		
		PRESSED = Event.new(),
		CARD_HOVER = Event.new(),
	}
	for key, original in pairs(CARD_MODEL:getChildren()) do
		local part = original:copy(original:getName()):scale(INV_SCALE):setPos(original:getPos()+OFFSET):setRot(original:getRot())
		model2:addChild(part)
	end
	setmetatable(new, Card)
	new:matrixApply()
	cards[nextFree] = new
	new.model2.Icon:setUV(CardAPI.playerUV[math.random(#CardAPI.playerUV)] / 81)
	return new
end


---```
---
--- 1 RED  
--- 2 YELLOW  
--- 3 GREEN  
--- 4 BLUE  
--- 5 MISSING
--- 6 WHITE  
--- 7 BLACK  
---```
---@param color integer
---@return Card
function Card:setColor(color)
	if not CardAPI.colorUV[color] then
		error('card color "' .. color .. '" dosent exist', 1)
	end
	self.color = color
	self.model2.Background:setUV(CardAPI.colorUV[color] / 81)
	return self
end

---```
---
---1 EMPTY  6 FOUR   11 NINE     16 WILD     21 DROPCOLOR
---2 ZERO   7 FIVE   12 REVERSE  17 UNKNOWN  22 DROP2
---3 ONE    8 SIX    13 SKIP     18 DRAW12   23 DROP1
---4 TWO    9 SEVEN  14 DRAW2    19 DROP12   24 DRAW1
---5 THREE  10 EIGHT 15 DRAW4    20 DROP4    25 DROPSPECIAL
---```
---@param type integer
---@return Card
function Card:setType(type)
	if not CardAPI.iconUV[type] then
		error('card type "' .. type .. '" dosent exist', 1)
	end
	self.type = type
	self.model2.numbers:setUV(CardAPI.iconUV[type] / 81)
	--self.model.TopNumber:setUV(CardAPI.iconUV[type] / 81)
	--self.model.BottomNumber:setUV(CardAPI.iconUV[type] / 81)
	return self
end


--- snippet by @PenguinEncounter
---@param mat Matrix4|Matrix3
---@return Vector3
local function mat2eulerZYX(mat)
	---@type number, number, number
	local x, y, z
	local query = mat.v31 -- are we in Gimbal Lock?
	if math.abs(query) < 0.9999 then
		y = math.asin(-mat.v31)
		z = math.atan2(mat.v21, mat.v11)
		x = math.atan2(mat.v32, mat.v33)
	elseif query < 0 then -- approx -1, gimbal lock
		y = math.pi / 2
		z = -math.atan2(-mat.v23, mat.v22)
		x = 0
	else -- approx 1, gimbal lock
		y = -math.pi / 2
		z = math.atan2(-mat.v23, mat.v22)
		x = 0
	end
	return vec(x, y, z):toDeg()
end


---Updates the Matrix from the pos,rot,scale data.
---@return Card
function Card:matrixApply()
	self.matrix = matrices.mat4()
	:rotateX(self.rot.x)
	:rotateY(self.rot.y)
	:rotateZ(self.rot.z)
	:scale(self.scale)
	:translate(self.pos + self.offset)
	self.invMatrix = self.matrix:inverted()
	self.dir = self.matrix.c2.xyz:normalize()
	self.model:setMatrix(self.matrix)
	self.model2:setMatrix(self.animMatrix)
	return self
end


function Card:animMatrixApply()
	self.animMatrix = matrices.mat4()
	:rotateZ(self.animRot.z)
	:rotateY(self.animRot.y)
	:rotateX(self.animRot.x)
	:scale(self.animScale)
	:translate(self.animPos)
	self:matrixApply()
	return self
end

---Updates the pos,rot,scale data from the Matrix.
---@return Card
function Card:matrixUnfold()
	self.pos = self.matrix.c4.xyz
	self.dir = self.matrix.c2.xyz:normalize()
	self.rot = mat2eulerZYX(self.matrix)
	self.offset = vec(0,0,0)
	return self
end


---@overload fun(self:Card,pos:Vector3):Card
---@param x number
---@param y number
---@param z number
---@return Card
function Card:setPos(x, y, z)
	self.pos = param.vec3(x, y, z)
	self:matrixApply()
	return self
end

---@overload fun(self:Card,pos:Vector3):Card
---@param x number
---@param y number
---@param z number
---@return Card
function Card:setOffset(x, y, z)
	self.offset = param.vec3(x, y, z)
	self:matrixApply()
	return self
end

---@overload fun(pos:Vector3):Card
---@param x number
---@param y number
---@param z number
---@return Card
function Card:setRot(x, y, z)
	self.rot = param.vec3(x, y, z)
	self:matrixApply()
	return self
end


---@overload fun(scale:Vector3):Card
---@param x number
---@param y number
---@param z number
---@return Card
function Card:setScale(x, y, z)
	self.scale = param.vec3(x, y, z)
	self:matrixApply()
	return self
end


---@overload fun(pos:Vector3):Card
---@param x number
---@param y number
---@param z number
---@return Card
function Card:setAnimPos(x,y,z)
	self.animPos = param.vec3(x,y,z)
	self:animMatrixApply()
	return self
end


---@overload fun(pos:Vector3):Card
---@param x number
---@param y number
---@param z number
---@return Card
function Card:setAnimRot(x,y,z)
	self.animRot = param.vec3(x,y,z)
	self:animMatrixApply()
	return self
end


---@overload fun(pos:Vector3):Card
---@param x number
---@param y number
---@param z number
---@return Card
function Card:setAnimScale(x,y,z)
	self.animScale = param.vec3(x,y,z)
	self:animMatrixApply()
	return self
end


---The given name will be the only one able to click the card
---@param name string?
---@return Card
function Card:setOwner(name)
	self.owner = name
	return self
end


---@param text string?
---@param scale number?
---@return Card
function Card:setLabel(text,scale)
	self.model:removeTask("subLabel")
	if text then
		local S = INV_SCALE*(scale or 1)
		self.model2:newText("subLabel")
		:setLight(15,15)
		:setScale(S)
		:setText(text)
		:setRot(90,0,0)
		:setAlignment("CENTER")
		:setOutline(true)
		:setPos(-0.5*S,0.3*INV_SCALE,(client.getTextHeight(text)*0.5-1)*S)
	end
	return self
end

---@param text string?
---@param scale number?
---@return Card
function Card:setSubLabel(text,scale)
	self.model:removeTask("label")
	if text then
		local S = INV_SCALE*(scale or 1)
		self.model2:newText("label")
		:setLight(15,15)
		:setScale(S/2)
		:setText(text)
		:setRot(90,0,0)
		:setAlignment("CENTER")
		:setOutline(true)
		:setPos(-0.5*S,0.3*INV_SCALE,(client.getTextHeight(text)*-0.9-1)*S)
	end
	return self
end

---@param icon number?
---@return Card
function Card:setIcon(icon)
	if icon then
		self.model2.Icon:setUV(CardAPI.playerUV[icon]/80)
	else
		self.model2.Icon:setUV(CardAPI.playerUV[math.random(#CardAPI.playerUV)]/80)
	end
	return self
end


---Returns the position of the card in global space
---@overload fun(self: Card ,pos : Vector3): Vector3
---@param x number
---@param y number
---@param z number
---@return Vector3
function Card:toGlobal(x,y,z)
	local pos = param.vec3(x,y,z)
	return self.matrix:apply(pos*CARD_DIM_HALF.x_y)
end


---Returns the position of the card in local space
---@overload fun(self: Card ,pos : Vector3): Vector3
---@param x number
---@param y number
---@param z number
---@return Vector3
function Card:toLocal(x,y,z)
	local pos = param.vec3(x,y,z)
	return self.invMatrix:apply(pos*CARD_DIM_HALF.x_y)
end


---@param tag string?
---@return Card
function Card:setTag(tag)
	self.tag = tag
	return self
end

---sets card id, only one card with same id can exist
---@param id string?
---@return Card
function Card:setId(id)
	if id == self.id then
		return self
	end
	if self.id then -- unregister old id
		cardIdsLookup[self.id] = nil
	end
	if cardIdsLookup[id] then -- unregister card with same id
		cardIdsLookup[id].id = nil
		cardIdsLookup[id] = nil
	end
	-- set id
	self.id = id
	if id then
		cardIdsLookup[id] = self
	end
	return self
end

function Card:free()
	cards[self.idx] = nil
	self.model:remove()
	if self.id then
		cardIdsLookup[self.id] = nil
	end
end


--- Clears all the cards
function CardAPI.clearAll()
	for key, value in pairs(cards) do
		value:free()
	end
	cards = {}
	cardIdsLookup = {}
end

---@param id string
---@return Card?
function CardAPI.getCardById(id)
	return cardIdsLookup[id]
end

---runs the given function to all the cards with the given tag
---@param tag string?
---@param func fun(card:Card)
function CardAPI.applyToCardWithTag(tag, func)
	if tag then
		for key, value in pairs(cards) do
			if value.tag and value.tag == tag then
				func(value)
			end
		end
	else
		for key, value in pairs(cards) do
			func(value)
		end
	end
end




---@param pos Vector3
---@param dir Vector3
---@param planeDir Vector3
---@param planePos Vector3
---@return Vector3?
local function ray2PlaneIntersection(pos,dir,planePos,planeDir)
	local dn = dir:normalized()
	local pdn = planeDir:normalized()

	local dot = dn:dot(pdn)
	if math.abs(dot) < 1e-6 then return nil end
	local dtp = pdn:dot(planePos - pos) / dot
	local ip = pos + dn * dtp
	return ip
end


--[────────────────────────────────────────-< CARD SERVICE >-────────────────────────────────────────]--

---@param pos Vector3
---@param dir Vector3
---@param name string
---@return Card?
---@return Vector3?
local function raycastCard(pos,dir,name)
	local closest = math.huge
	local chosenHitPos
	local hitCard
	
	for _, card in pairs(cards) do
		local cardMat = card.model:partToWorldMatrix()
		local cardPos = cardMat:apply()
		local hitPos = ray2PlaneIntersection(pos, dir, cardPos, cardMat:applyDir(0,1,0))
		if hitPos then
			local distToCam = (hitPos-pos):lengthSquared()
				
			if closest > distToCam and (hitPos-cardPos):lengthSquared() < CARD_RADIUS_SQ then
				local lpos = cardMat:invert():apply(hitPos)
				
				if math.abs(lpos.x) < CARD_DIM_HALF.x and math.abs(lpos.z) < CARD_DIM_HALF.y then
					hitCard = card
					card.hitPos = lpos.xz
					closest = distToCam
					chosenHitPos = hitPos
				end
			end
		end
	end
	return hitCard, chosenHitPos
end

---@param entity Entity.any
---@return Vector3
---@return Vector3
local function getEntityEyePosAndDir(entity)
	return entity:getPos():add(0, entity:getEyeHeight()), entity:getLookDir()
end

local lastSelectedCard = {}

---@type {card: Card, pos: Vector3, dir: Vector3, lastCard: Card}?
local forcedCard = nil
---@param card Card
function CardAPI.forceSelectedCard(card)
	local viewer = client.getViewer()
	if not viewer:isLoaded() then return end
	local pos, dir = getEntityEyePosAndDir(viewer)
	forcedCard = {
		card = card,
		pos = pos,
		dir = dir,
		lastCard = lastSelectedCard[viewer:getName()]
	}
end

---@param entity Player
---@param isViewer boolean?
local function updateHoverAndClick(entity, isViewer)
	local name = entity:getName()
	local ppos, pdir = getEntityEyePosAndDir(entity)
	local hitCard, hitPos = raycastCard(ppos, pdir, name)
	if hitCard and hitCard.owner and hitCard.owner ~= name then
		hitCard = nil
	end
	if isViewer and forcedCard then
		if (forcedCard.pos - ppos):length() > 0.05 or
			(forcedCard.dir - pdir):length() > 0.05 or
			forcedCard.lastCard ~= hitCard
		then
			forcedCard = nil
		else
			hitCard = forcedCard.card
		end
	end
	if lastSelectedCard[name] ~= hitCard then
		if lastSelectedCard[name] then lastSelectedCard[name].CARD_HOVER:invoke(false, name) end
		if hitCard then hitCard.CARD_HOVER:invoke(true, name) end
		CardAPI.CARD_HOVER:invoke(hitCard, lastSelectedCard[name], name)
		lastSelectedCard[name] = hitCard
	end
	if entity:getSwingTime() == 0 and entity:getSwingArm() and hitCard then
		CardAPI.CARD_PRESSED:invoke(hitCard, name)
		hitCard.PRESSED:invoke(name)
	end
end

if host:isHost() then
	events.TICK:register(function()
		local myName = player:getName()
		for name, entity in pairs(world.getPlayers()) do
			updateHoverAndClick(entity, name == myName)
		end
	end)
else
	events.TICK:register(function()
		local viewer = client:getViewer()
		if viewer:isLoaded() then
			updateHoverAndClick(viewer, true)
		end
	end)
end

return CardAPI
