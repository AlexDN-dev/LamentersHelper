local addonName, M = ...

-- Dépendance optionnelle : LibSharedMedia-3.0 (fournie par BigWigs, DBM, ElvUI…)
-- Si disponible, permet de remplacer les sons via une future interface d'options.
-- Fallback garanti sur PlaySound(SOUNDKIT.X) — aucun fichier externe requis.
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)

-- Sons intégrés à WoW — SOUNDKIT est une table globale Blizzard (WoW 7.0+)
-- Fallback numérique en cas de clé SOUNDKIT absente dans une future version
local SOUND_DEFS = {
    -- Alerte de cast standard (boss prépare quelque chose)
    global    = { kit = SOUNDKIT.ALARM_CLOCK_WARNING_3 or 12867,  lsm = "Alarm Clock Warning 3" },
    -- Changement de phase, mécanique majeure, enrage
    phase     = { kit = SOUNDKIT.RAID_WARNING or 8960,             lsm = "Raid Warning" },
    -- Interruption requise — son le plus urgent
    interrupt = { kit = SOUNDKIT.ALARM_CLOCK_WARNING_1 or 12865,  lsm = "Alarm Clock Warning 1" },
    -- Soak — timing critique
    soak      = { kit = SOUNDKIT.ALARM_CLOCK_WARNING_2 or 12866,  lsm = "Alarm Clock Warning 2" },
    -- Alerte personnelle (debuff sur soi)
    private   = { kit = SOUNDKIT.ALARM_CLOCK_WARNING_3 or 12867,  lsm = "Alarm Clock Warning 3" },
}

-- Joue un son d'alerte du type donné.
-- soundType : "global" | "phase" | "interrupt" | "soak" | "private"
function M:PlayAlertSound(soundType)
    if not M.config or M.config.soundEnabled == false then return end

    local def = SOUND_DEFS[soundType] or SOUND_DEFS.global

    -- Tentative via LibSharedMedia si disponible (sons enregistrés par d'autres addons)
    if LSM then
        local path = LSM:Fetch("sound", def.lsm)
        if path then
            PlaySoundFile(path, "Master")
            return
        end
    end

    -- Fallback direct sur les sons intégrés à WoW
    PlaySound(def.kit, "Master", false)
end
