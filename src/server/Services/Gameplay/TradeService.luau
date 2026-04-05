--[[
	TradeService - Player-to-player trade system

	Flow:
	  1. Player A sends trade request → invite fires to B
	  2. B accepts → active trade session created for both
	  3. Each player adds brainrots (max 10) and/or a money amount
	  4. Both click Confirm → 3-second timer starts
	  5. Either can cancel during those 3s → trade cancelled
	  6. Timer expires → inventory verification → trade executed

	Tax:
	  valueA = sum(brainrot RevenuePerSecond) + dollars offered by A
	  valueB = same for B
	  The player receiving higher value pays:  floor(difference × TAX_RATE)
	  Equal values → no tax.

	State machine: "active" → "confirming" → "completed" | "cancelled"
]]

local TradeService = {}

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local _PlayerDataService = nil
local _PlacementService  = nil

-- [tradeId]  = { id, playerA, playerB, sideA, sideB, state, timerThread, timerEnd }
local _trades        = {}
-- [userId]   = tradeId
local _playerTrade   = {}
-- [toUserId] = { fromUserId, fromName }
local _pendingInvites = {}

local TAX_RATE     = 0.15
local MAX_ITEMS    = 10
local TIMER_SECS   = 3

-- ─── Helpers ──────────────────────────────────────────────────────────────────

local function events()
	return ReplicatedStorage:WaitForChild("RemoteInterface"):WaitForChild("Events")
end

local function newId()
	return tostring(math.floor(tick() * 1000)) .. tostring(math.random(100, 999))
end

local function getPlayerSide(trade, userId)
	if trade.playerA == userId then return trade.sideA, trade.sideB
	elseif trade.playerB == userId then return trade.sideB, trade.sideA
	end
	return nil, nil
end

-- Returns (taxForA, taxForB) — the player receiving more value pays the tax
local function calcTax(sideA, sideB)
	local vA, vB = sideA.money, sideB.money
	for _, b in ipairs(sideA.brainrots) do vA += (b.RevenuePerSecond or 0) end
	for _, b in ipairs(sideB.brainrots) do vB += (b.RevenuePerSecond or 0) end
	if vB > vA then return math.floor((vB - vA) * TAX_RATE), 0
	elseif vA > vB then return 0, math.floor((vA - vB) * TAX_RATE)
	end
	return 0, 0
end

-- Returns the brainrots in the player's inventory NOT yet in the trade
local function availableBrainrots(userId, mySide)
	local pd = _PlayerDataService.GetPlayerData(userId)
	if not pd then return {} end
	local inTrade = {}
	for _, b in ipairs(mySide.brainrots) do inTrade[b.Name] = true end
	local out = {}
	for _, b in ipairs(pd.brainrotInventory or {}) do
		if not inTrade[b.Name] then
			table.insert(out, {
				Name             = b.Name,
				ModelName        = b.ModelName or "",
				Rarity           = b.Rarity,
				RevenuePerSecond = b.RevenuePerSecond or 0,
			})
		end
	end
	return out
end

-- Send a personalized state packet to each party
local function broadcast(tradeId)
	local t = _trades[tradeId]
	if not t then return end

	local taxA, taxB = calcTax(t.sideA, t.sideB)
	local ev = events()

	local function packet(userId, mySide, theirSide, myTax)
		return {
			tradeId    = tradeId,
			state      = t.state,
			partnerName = (function()
				local partnerId = (userId == t.playerA) and t.playerB or t.playerA
				local p = Players:GetPlayerByUserId(partnerId)
				return p and p.Name or "?"
			end)(),
			mySide     = {
				brainrots = mySide.brainrots,
				money     = mySide.money,
				confirmed = mySide.confirmed,
			},
			theirSide  = {
				brainrots = theirSide.brainrots,
				money     = theirSide.money,
				confirmed = theirSide.confirmed,
			},
			myTax      = myTax,
			timerEnd   = t.timerEnd or 0,
			available  = availableBrainrots(userId, mySide),
		}
	end

	local pA = Players:GetPlayerByUserId(t.playerA)
	local pB = Players:GetPlayerByUserId(t.playerB)
	if pA then ev.TradeStateUpdate:FireClient(pA, packet(t.playerA, t.sideA, t.sideB, taxA)) end
	if pB then ev.TradeStateUpdate:FireClient(pB, packet(t.playerB, t.sideB, t.sideA, taxB)) end
end

local function unconfirm(trade)
	trade.sideA.confirmed = false
	trade.sideB.confirmed = false
	if trade.timerThread then
		task.cancel(trade.timerThread)
		trade.timerThread = nil
		trade.timerEnd    = nil
		trade.state       = "active"
	end
end

local function cancel(tradeId)
	local t = _trades[tradeId]
	if not t then return end
	if t.timerThread then task.cancel(t.timerThread); t.timerThread = nil end
	t.state = "cancelled"
	broadcast(tradeId)
	_playerTrade[t.playerA] = nil
	_playerTrade[t.playerB] = nil
	_trades[tradeId] = nil
end

local function execute(tradeId)
	local t = _trades[tradeId]
	if not t then return end

	local pdA = _PlayerDataService.GetPlayerData(t.playerA)
	local pdB = _PlayerDataService.GetPlayerData(t.playerB)
	if not pdA or not pdB then cancel(tradeId); return end

	local taxA, taxB = calcTax(t.sideA, t.sideB)

	-- ── Verify money ────────────────────────────────────────────────────────
	if pdA.money < t.sideA.money + taxA or pdB.money < t.sideB.money + taxB then
		t.state = "cancelled"
		broadcast(tradeId)
		_playerTrade[t.playerA] = nil
		_playerTrade[t.playerB] = nil
		_trades[tradeId] = nil
		return
	end

	-- ── Verify brainrots still owned ────────────────────────────────────────
	local function ownsBrainrots(pd, list)
		for _, offered in ipairs(list) do
			local found = false
			for _, b in ipairs(pd.brainrotInventory or {}) do
				if b.Name == offered.Name then found = true; break end
			end
			if not found then return false end
		end
		return true
	end
	if not ownsBrainrots(pdA, t.sideA.brainrots) or not ownsBrainrots(pdB, t.sideB.brainrots) then
		cancel(tradeId); return
	end

	-- ── Transfer brainrots ──────────────────────────────────────────────────
	local pA = Players:GetPlayerByUserId(t.playerA)
	local pB = Players:GetPlayerByUserId(t.playerB)

	for _, b in ipairs(t.sideA.brainrots) do
		_PlayerDataService.RemoveBrainrot(t.playerA, b.Name)
		_PlayerDataService.AddBrainrot(t.playerB, b.Name, b.ModelName, b.Rarity, b.RevenuePerSecond)
		if pA then _PlacementService.RemoveBrainrotTool(pA, b.Name) end
		if pB then _PlacementService.GiveBrainrotTool(pB, b.Name, b.ModelName or "", b.Rarity, b.RevenuePerSecond, "Normal") end
	end

	for _, b in ipairs(t.sideB.brainrots) do
		_PlayerDataService.RemoveBrainrot(t.playerB, b.Name)
		_PlayerDataService.AddBrainrot(t.playerA, b.Name, b.ModelName, b.Rarity, b.RevenuePerSecond)
		if pB then _PlacementService.RemoveBrainrotTool(pB, b.Name) end
		if pA then _PlacementService.GiveBrainrotTool(pA, b.Name, b.ModelName or "", b.Rarity, b.RevenuePerSecond, "Normal") end
	end

	-- ── Transfer money (offer + tax) ────────────────────────────────────────
	-- A gives sideA.money + taxA  |  A receives sideB.money
	-- B gives sideB.money + taxB  |  B receives sideA.money
	pdA.money = pdA.money - t.sideA.money - taxA + t.sideB.money
	pdB.money = pdB.money - t.sideB.money - taxB + t.sideA.money

	local moneyEv = events().OnMoneyChanged
	if pA then moneyEv:FireClient(pA, pdA.money) end
	if pB then moneyEv:FireClient(pB, pdB.money) end

	-- ── Save & broadcast ────────────────────────────────────────────────────
	_PlayerDataService.SavePlayer(t.playerA)
	_PlayerDataService.SavePlayer(t.playerB)

	t.state = "completed"
	broadcast(tradeId)

	_playerTrade[t.playerA] = nil
	_playerTrade[t.playerB] = nil
	task.delay(2, function() _trades[tradeId] = nil end)
end

-- ─── Init ─────────────────────────────────────────────────────────────────────

function TradeService.Init(PlayerDataService, PlacementService)
	_PlayerDataService = PlayerDataService
	_PlacementService  = PlacementService

	local ev = events()

	-- ── A sends invite to B ──────────────────────────────────────────────────
	ev.SendTradeRequest.OnServerEvent:Connect(function(playerA, targetUserId)
		if type(targetUserId) ~= "number"       then return end
		if playerA.UserId == targetUserId        then return end
		if _playerTrade[playerA.UserId]          then return end

		local playerB = Players:GetPlayerByUserId(targetUserId)
		if not playerB                           then return end
		if _playerTrade[targetUserId]            then return end
		if _pendingInvites[targetUserId]         then return end

		_pendingInvites[targetUserId] = { fromUserId = playerA.UserId, fromName = playerA.Name }
		ev.TradeInviteReceived:FireClient(playerB, playerA.UserId, playerA.Name)
	end)

	-- ── B responds ──────────────────────────────────────────────────────────
	ev.TradeInviteResponse.OnServerEvent:Connect(function(playerB, accepted)
		local invite = _pendingInvites[playerB.UserId]
		if not invite then return end
		_pendingInvites[playerB.UserId] = nil

		local playerA = Players:GetPlayerByUserId(invite.fromUserId)

		if not accepted then
			if playerA then ev.TradeInviteDeclined:FireClient(playerA, playerB.Name) end
			return
		end

		if not playerA then return end
		if _playerTrade[invite.fromUserId] or _playerTrade[playerB.UserId] then return end

		local id = newId()
		_trades[id] = {
			id           = id,
			playerA      = invite.fromUserId,
			playerB      = playerB.UserId,
			state        = "active",
			sideA        = { brainrots = {}, money = 0, confirmed = false },
			sideB        = { brainrots = {}, money = 0, confirmed = false },
			timerThread  = nil,
			timerEnd     = nil,
		}
		_playerTrade[invite.fromUserId] = id
		_playerTrade[playerB.UserId]    = id
		broadcast(id)
	end)

	-- ── Add brainrot ────────────────────────────────────────────────────────
	ev.TradeAddBrainrot.OnServerEvent:Connect(function(player, brainrotName)
		local tid = _playerTrade[player.UserId];  if not tid then return end
		local t   = _trades[tid];                 if not t or t.state ~= "active" then return end
		local my  = getPlayerSide(t, player.UserId); if not my then return end
		if #my.brainrots >= MAX_ITEMS then return end
		for _, b in ipairs(my.brainrots) do if b.Name == brainrotName then return end end

		local pd = _PlayerDataService.GetPlayerData(player.UserId)
		if not pd then return end
		local found
		for _, b in ipairs(pd.brainrotInventory or {}) do
			if b.Name == brainrotName then found = b; break end
		end
		if not found then return end

		table.insert(my.brainrots, {
			Name             = found.Name,
			ModelName        = found.ModelName or "",
			Rarity           = found.Rarity,
			RevenuePerSecond = found.RevenuePerSecond or 0,
		})
		unconfirm(t); broadcast(tid)
	end)

	-- ── Remove brainrot ─────────────────────────────────────────────────────
	ev.TradeRemoveBrainrot.OnServerEvent:Connect(function(player, brainrotName)
		local tid = _playerTrade[player.UserId];  if not tid then return end
		local t   = _trades[tid];                 if not t or t.state ~= "active" then return end
		local my  = getPlayerSide(t, player.UserId); if not my then return end
		for i, b in ipairs(my.brainrots) do
			if b.Name == brainrotName then table.remove(my.brainrots, i); break end
		end
		unconfirm(t); broadcast(tid)
	end)

	-- ── Set money ───────────────────────────────────────────────────────────
	ev.TradeSetMoney.OnServerEvent:Connect(function(player, amount)
		local tid = _playerTrade[player.UserId];  if not tid then return end
		local t   = _trades[tid];                 if not t or t.state ~= "active" then return end
		local my  = getPlayerSide(t, player.UserId); if not my then return end

		amount = math.max(0, math.floor(tonumber(amount) or 0))
		local pd = _PlayerDataService.GetPlayerData(player.UserId)
		if pd and amount > pd.money then amount = pd.money end

		my.money = amount
		unconfirm(t); broadcast(tid)
	end)

	-- ── Confirm ─────────────────────────────────────────────────────────────
	ev.TradeConfirm.OnServerEvent:Connect(function(player)
		local tid = _playerTrade[player.UserId];  if not tid then return end
		local t   = _trades[tid];                 if not t or t.state ~= "active" then return end
		local my  = getPlayerSide(t, player.UserId); if not my then return end

		my.confirmed = true

		if t.sideA.confirmed and t.sideB.confirmed then
			t.state      = "confirming"
			t.timerEnd   = os.time() + TIMER_SECS
			broadcast(tid)
			t.timerThread = task.delay(TIMER_SECS, function() execute(tid) end)
		else
			broadcast(tid)
		end
	end)

	-- ── Cancel ──────────────────────────────────────────────────────────────
	ev.TradeCancel.OnServerEvent:Connect(function(player)
		local tid = _playerTrade[player.UserId]
		if tid then cancel(tid) end
	end)

	-- ── Disconnect cleanup ───────────────────────────────────────────────────
	Players.PlayerRemoving:Connect(function(player)
		_pendingInvites[player.UserId] = nil
		local tid = _playerTrade[player.UserId]
		if tid then cancel(tid) end
	end)

	print("TradeService initialized")
end

return TradeService
