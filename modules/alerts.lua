local addonName, M = ...

function M:TriggerAlert(msg)
    self:ShowText(msg)

    if self.PlayAlertSound then
        self:PlayAlertSound("global")
    end

    C_Timer.After(2, function()
        M:HideText()
    end)
end