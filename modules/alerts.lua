local addonName, M = ...

function M:TriggerAlert(msg)
    self:ShowText(msg)

    if self.config.soundEnabled then
        PlaySound(8959)
    end

    C_Timer.After(2, function()
        M:HideText()
    end)
end