--[[
	Author      : Lopapon
	Module      : Server/Services/CoopService
	Description : Systeme de groupe formel (invitations, acceptation, leader,
	              quitte) independant de la capture par proximite que fait
	              RunService au pad. Sert a preparer un groupe AVANT d'arriver au
	              pad (inviter un ami a distance dans le lobby). RunService reste
	              inchangee pour l'instant (capture par proximite) -- brancher
	              CoopService:GetParty() dans RunService.capturePartyNearPad serait
	              la prochaine etape logique, point d'accroche pret.
	Usage : CoopService:Invite(inviter, invitee)
	        CoopService:AcceptInvite(invitee)
	        CoopService:LeaveParty(player)
]]

local Logger = require(script.Parent.Parent.Core.Logger)
local EventBus = require(script.Parent.Parent.Core.EventBus)

local log = Logger.new("CoopService")

local MAX_PARTY_SIZE = 4
local INVITE_TIMEOUT = 30 -- secondes avant qu'une invitation expire

local CoopService = {}

-- leaderUserId -> { Leader = Player, Members = { Player } }
CoopService._parties = {} :: { [number]: any }

-- inviteeUserId -> { Inviter = Player, ExpiresAt = number }
CoopService._pendingInvites = {} :: { [number]: any }

-- Trouve la party a laquelle appartient un joueur (en tant que leader ou membre)
local function findParty(player: Player): any?
	for _, party in pairs(CoopService._parties) do
		if table.find(party.Members, player) then
			return party
		end
	end
	return nil
end

local function getOrCreateParty(leader: Player): any
	local existing = CoopService._parties[leader.UserId]
	if existing then
		return existing
	end

	local party = {
		Leader = leader,
		Members = { leader },
	}
	CoopService._parties[leader.UserId] = party
	return party
end

-- Retourne les membres de la party du joueur, ou juste lui-meme s'il est solo
function CoopService:GetParty(player: Player): { Player }
	local party = findParty(player)
	return party and party.Members or { player }
end

-- Envoie une invitation. Echoue silencieusement si la party est pleine ou si
-- l'invite appartient deja a une party (la sienne ou une autre)
function CoopService:Invite(inviter: Player, invitee: Player): boolean
	local party = findParty(inviter) or getOrCreateParty(inviter)

	if party.Leader ~= inviter then
		log:Warn(inviter.Name, "a tente d'inviter sans etre leader de sa party")
		return false
	end

	if #party.Members >= MAX_PARTY_SIZE then
		return false
	end

	if findParty(invitee) then
		return false
	end

	CoopService._pendingInvites[invitee.UserId] = {
		Inviter = inviter,
		ExpiresAt = os.clock() + INVITE_TIMEOUT,
	}

	EventBus:Publish("PartyInviteSent", inviter, invitee)
	log:Info(inviter.Name, "invite", invitee.Name, "dans sa party")
	return true
end

-- Accepte l'invitation en attente. Retourne true si succes.
function CoopService:AcceptInvite(invitee: Player): boolean
	local invite = CoopService._pendingInvites[invitee.UserId]
	if not invite then
		return false
	end

	CoopService._pendingInvites[invitee.UserId] = nil

	if os.clock() > invite.ExpiresAt then
		log:Info("Invitation expiree pour", invitee.Name)
		return false
	end

	local party = findParty(invite.Inviter) or getOrCreateParty(invite.Inviter)
	if #party.Members >= MAX_PARTY_SIZE then
		return false
	end

	table.insert(party.Members, invitee)
	EventBus:Publish("PartyJoined", invitee, party.Leader)
	log:Info(invitee.Name, "rejoint la party de", party.Leader.Name)
	return true
end

-- Retire un joueur de sa party (quitte volontairement ou deconnexion). Si c'etait
-- le leader, la party est dissoute (pas de transfert de leadership pour l'instant).
function CoopService:LeaveParty(player: Player)
	local party = findParty(player)
	if not party then
		return
	end

	if party.Leader == player then
		CoopService._parties[party.Leader.UserId] = nil
		EventBus:Publish("PartyDisbanded", party.Leader)
		log:Info("Party de", party.Leader.Name, "dissoute (leader parti)")
		return
	end

	local index = table.find(party.Members, player)
	if index then
		table.remove(party.Members, index)
		EventBus:Publish("PartyLeft", player, party.Leader)
	end
end

function CoopService:Init()
	EventBus:Subscribe("PlayerLeaving", function(player, _entity)
		CoopService:LeaveParty(player)
		CoopService._pendingInvites[player.UserId] = nil
	end)
end

return CoopService