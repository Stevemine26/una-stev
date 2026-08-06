---@diagnostic disable: param-type-mismatch

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
bitFlags=0

--[────────────────────────────────────────-< CARD API >-────────────────────────────────────────]--

---@class CardAPI
local CardAPI = {}

CardAPI.ROOT_MODEL = ROOT_MODEL

---@alias CardColor
---| "BLACK"

CardAPI.colorUV = {
	vec(0, 0), -- BLACK
}

CardAPI.iconUV = {
	vec( 0, 22), -- EMPTY 
	vec( 9, 22), -- UNKNOWN 
	vec( 0,  0), -- WILD    
	vec( 9,  0), -- DRAW4   
	vec(18,  0), -- DRAW2   
	vec(27,  0), -- REVERSE 
	vec(36,  0), -- SKIP    
	vec(45,  0), -- SKIP2   
	vec( 0, 11), -- DRAW2TARGET 
	vec( 9, 11), -- SWAPPLR
	--CUSTOM (not in the game)
	vec(18, 11), -- SKIPBACK
	vec(27, 11), -- SKIPTO
}
---@alias CardType
---| "EMPTY"
---| "UNKNOWN"
---| "WILD"
---| "DRAW4"
---| "DRAW2"
---| "REVERSE"
---| "SKIP"
---| "SKIP2"
---| "DRAW2TARGET"
---| "SWAPPLR"
---| "SKIPBACK"
---| "SKIPTO"

CardAPI.index2color = {
	"BLACK",
}

CardAPI.index2type = {
	"EMPTY",
	"UNKNOWN",
	"WILD",
	"DRAW4",
	"DRAW2",
	"REVERSE",
	"SKIP",
	"SKIP2",
	"DRAW2TARGET",
	"SWAPPLR",
	--CUSTOM (not in the game)
	"SKIPBACK",
	"SKIPTO",
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

CardAPI.randomCardList = {}
function CardAPI.regenCards()
	--table.insert(CardAPI.randomCardList, CardAPI.typeAndColorToFullId(3, 1))
	table.insert(CardAPI.randomCardList, CardAPI.typeAndColorToFullId(3, 1))
	table.insert(CardAPI.randomCardList, CardAPI.typeAndColorToFullId(3, 1))
	for cardType = 4, 10 do
		local id = CardAPI.typeAndColorToFullId(cardType, 1)
		table.insert(CardAPI.randomCardList, id)
	end
	if bit32.btest(bitFlags, 2 ^ 3) then
		for cardType = 11, #CardAPI.iconUV do
			local id = CardAPI.typeAndColorToFullId(cardType, 1)
			table.insert(CardAPI.randomCardList, id)
		end
	end
end
CardAPI.regenCards()

---@return number
function CardAPI.getRandomCard()
	return CardAPI.randomCardList[math.random(#CardAPI.randomCardList)]
end

---@param id integer
---@return boolean
function CardAPI.isValidCardId(id)
	return id >= 1 and id <= CardAPI.lastCardId
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
---@field label string?
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
	new.model2.Icon:setUVPixels(math.random(1,4)*6,0)
	return new
end


---```
---
--- 1 BLACK  
---```
---@param color integer
---@return Card
function Card:setColor(color)
	if not CardAPI.colorUV[color] then
		error('card color "' .. color .. '" dosent exist', 1)
	end
	self.color = color
	self.model2.Background:setUVPixels(CardAPI.colorUV[color])
	return self
end
---@param uv Vector2|integer
---@param v integer
---@return Card
function Card:overrideColorUV(uv,v)
	if v then
		self.model2.Background:setUVPixels(uv,v)
	else
		self.model2.Background:setUVPixels(uv)
	end
	return self
end

---```
---
---1 EMPTY    6 SKIP
---2 UNKNOWN  7 SKIP2
---3 WILD     8 DRAW2TARGET
---4 DRAW4    9 SWAPPLR
---5 DRAW2    
---```
---@param type integer
---@return Card
function Card:setType(type)
	if not CardAPI.iconUV[type] then
		error('card type "' .. type .. '" dosent exist', 1)
	end
	self.type = type
	self.model2.numbers:setUVPixels(CardAPI.iconUV[type])
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
	self.label=nil
	self.model:removeTask("label")
	if text then
		self.label=text
		local S = INV_SCALE*(scale or 1)
		self.model2:newText("label")
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
