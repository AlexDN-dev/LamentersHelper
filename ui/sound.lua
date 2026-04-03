local addonName, M = ...

-- Sons intégrés à WoW — SOUNDKIT est une table globale Blizzard (WoW 7.0+)
-- Note: ALARM_CLOCK_WARNING_1 (12865) n'existe plus dans WoW 12.0 Midnight.
-- Sons confirmés fonctionnels : 12867, 12866, 8960
local SOUND_DEFS = {
    -- Alerte de cast standard
    global    = SOUNDKIT.ALARM_CLOCK_WARNING_3 or 12867,
    -- Changement de phase / mécanique majeure — tick court
    phase     = SOUNDKIT.ALARM_CLOCK_WARNING_2 or 12866,
    -- Interruption requise — son raid le plus urgent/distinct
    interrupt = SOUNDKIT.RAID_WARNING          or 8960,
    -- Soak — timing critique
    soak      = SOUNDKIT.ALARM_CLOCK_WARNING_2 or 12866,
    -- Alerte personnelle (debuff sur soi)
    private   = SOUNDKIT.ALARM_CLOCK_WARNING_3 or 12867,
}

-- soundType : "global" | "phase" | "interrupt" | "soak" | "private"
function M:PlayAlertSound(soundType)
    if not M.config or M.config.soundEnabled == false then return end

    local kit = SOUND_DEFS[soundType] or SOUND_DEFS.global
    PlaySound(kit, "Master", false)
end
