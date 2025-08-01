AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "player_swapper"

ENT.Category    = "Other"
ENT.PrintName   = "Thing Presser"
ENT.Author      = "StrawWagen"
ENT.Purpose     = "Presses stuff."
ENT.Spawnable    = false
ENT.AdminOnly    = game.IsDedicated()
ENT.Category = "Hunter's Glee"
ENT.Model = "models/Items/item_item_crate.mdl"

ENT.HullCheckSize = Vector( 20, 20, 10 )
ENT.PosOffset = Vector( 0, 0, 10 )

ENT.SwapSound = "ui/buttonrollover.wav"
ENT.DrawOriginHint = true

if CLIENT then

    local traitorButtonColor = Color( 100, 255, 255, 255 )
    local traitorNotReadyButtonColor = Color( 255, 100, 100, 220 )

    function ENT:DoHudStuff()
        local screenMiddleW = ScrW() / 2
        local screenMiddleH = ScrH() / 2

        local scoreGained = math.Round( self:GetGivenScore() )
        local scoreGainedAlt = math.Round( self:GetGivenScoreAlt() )

        local stringPt1
        local stringPt2

        local targ = self:GetCurrTarget()
        if IsValid( targ ) and targ:GetClass() == "ttt_traitor_button" then
            stringPt1 = "TTT Button: \"" .. targ:GetDescription() .. " \" \nCost: "

        else
            stringPt1 = "Pressing Cost: "
            stringPt2 = "\nAdded cost for distant pressing: "

        end

        scoreString = stringPt1 .. tostring( scoreGained )

        if stringPt2 and scoreGainedAlt ~= 0 then
            scoreString = scoreString .. stringPt2 .. tostring( scoreGainedAlt )

        end

        surface.drawShadowedTextBetter( scoreString, "scoreGainedOnPlaceFont", color_white, screenMiddleW, screenMiddleH + 20 )

        local allTraitorButtons = ents.FindByClass( "ttt_traitor_button" )
        for _, button in ipairs( allTraitorButtons ) do
            if button:GetLocked() then continue end

            local color = traitorButtonColor
            if not button:IsUsable() then
                color = traitorNotReadyButtonColor

            end

            self:HighlightPoint( button:GetPos(), color )

        end
    end
end

function ENT:GetNearestTarget()
    local nearestTarg = nil
    local nearestDistance = math.huge
    local myPos = self:GetPos()

    -- Find all things within a radius of x units
    local stuff = ents.FindInSphere( myPos, 512 )
    for _, thing in ipairs( stuff ) do
        if not IsValid( thing ) then continue end
        local veryGood
        local class = thing:GetClass()
        local good = string.find( class, "button" ) or string.find( class, "door" ) or thing.Use
        local bad
        if class == "ttt_traitor_button" then
            bad = thing:GetLocked()
            veryGood = true

        else
            bad = thing:IsPlayer() or thing:IsNextBot() or thing == self or string.find( class, "trigger" ) or thing:IsWeapon() or thing.isDoorDamageListener or not thing:IsSolid() or not thing.GetModel or not thing:GetModel()

        end
        if good and not bad then
            -- Calculate the distance between the ply and the entity
            local distance = myPos:DistToSqr( thing:GetPos() )
            if veryGood then
                distance = distance * 0.8 -- Traitor buttons are more important

            end
            if distance < nearestDistance then
                nearestTarg = thing
                nearestDistance = distance

            end
        end
    end

    return nearestTarg
end

function ENT:OnNewTarget( _, newTarg )
    if not GAMEMODE.ISHUNTERSGLEE then return end
    if not IsValid( newTarg ) then return end
    local myPos = self:GetPos()

    local nearestPly = GAMEMODE:nearestAlivePlayer( myPos )

    self.nearestPly = nearestPly

end

function ENT:CalculateCanPlace()
    local targ = self:GetCurrTarget()
    if not IsValid( targ ) then return false, "Nothing to press." end
    if targ.glee_nextPresserPress and targ.glee_nextPresserPress > CurTime() then return false, "That was just pressed!" end
    if targ:GetClass() == "ttt_traitor_button" then
        local usable, reason = targ:IsUsable()
        if not usable then return false, reason end

    end
    if not self:HasEnoughToPurchase() then return false, self:TooPoorString() end
    return true

end

if not SERVER then return end

function ENT:UpdateGivenScore()
    local targ = self:GetCurrTarget()
    if not IsValid( targ ) then return end
    local perUse = 5
    local givenScore = 10
    if targ:GetClass() == "ttt_traitor_button" then
        givenScore = 50
        self:SetGivenScoreAlt( 0 )

    else
        if targ.glee_pressedCount and targ.glee_pressedCount > 0 then
            givenScore = givenScore + ( targ.glee_pressedCount * perUse )

        end

        if IsValid( self.nearestPly ) then
            local closerThanOneHalfk = self.nearestPly:GetPos():Distance( self:GetPos() ) < 1500
            local alt = 0
            if not closerThanOneHalfk then
                alt = givenScore
                givenScore = givenScore * 2

            end
            self:SetGivenScoreAlt( -alt )

        end
    end

    self:SetGivenScore( -givenScore )

end

function ENT:Place()
    local thingToPress = self:GetCurrTarget()

    if not IsValid( thingToPress ) then return end

    local pressedCount = thingToPress.glee_pressedCount or 0
    thingToPress.glee_pressedCount = pressedCount + 1
    thingToPress.glee_nextPresserPress = CurTime() + math.max( pressedCount / 2, 4 )

    if thingToPress:GetClass() == "ttt_traitor_button" then
        thingToPress:TraitorUse( self.player )

    else
        thingToPress:Use( self.player, self.player, USE_ON )

    end


    local score = self:GetGivenScore()

    if self.player.GivePlayerScore and score then
        self.player:GivePlayerScore( score )
        GAMEMODE:sendPurchaseConfirm( self.player, score )

    end
end