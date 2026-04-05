local addonName, M = ...

-- ─── Sons vocaux SharedMedia_Causese (chemins directs) ───────────────────────
local SM = "Interface\\Addons\\SharedMedia_Causese\\sound\\"

local SOUND_FILES = {
    global    = SM .. "Soon.ogg",
    phase     = SM .. "Transition.ogg",
    interrupt = SM .. "Interrupt.ogg",
    soak      = SM .. "Soak.ogg",
    private   = SM .. "Targeted.ogg",
    dispel    = SM .. "Dispell.ogg",
}

-- Fallback SOUNDKIT si SharedMedia_Causese absent
local function SoundKitFallback(soundType)
    local kits = {
        global    = 12867,  -- ALARM_CLOCK_WARNING_3
        phase     = 12866,  -- ALARM_CLOCK_WARNING_2
        interrupt = 8960,   -- RAID_WARNING
        soak      = 12866,
        private   = 12867,
        dispel    = 8960,
    }
    PlaySound(kits[soundType] or kits.global, "Master", false)
end

local smLoaded = nil  -- évalué au premier appel (après PLAYER_LOGIN)

local function PlayType(soundType)
    if smLoaded == nil then
        smLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded("SharedMedia_Causese")) or false
    end

    if smLoaded then
        PlaySoundFile(SOUND_FILES[soundType] or SOUND_FILES.global, "Master")
    else
        SoundKitFallback(soundType)
    end
end

-- soundType : "global" | "phase" | "interrupt" | "soak" | "private" | "dispel"
function M:PlayAlertSound(soundType)
    if not M.config or M.config.soundEnabled == false then return end

    PlayType(soundType)

    -- Double ping pour les dispels : 2ème son 0.3s après
    if soundType == "dispel" then
        C_Timer.After(0.3, function()
            PlayType(soundType)
        end)
    end
end
