require 'moonloader'
enabled = true

function main()
    while not isSampAvailable() do wait(0) end
    sampRegisterChatCommand('roller', function() 
        enabled = not enabled 
        sampAddChatMessage(enabled and 'RollerFIX: Enabled' or 'RollerFIX: Disabled', -1)
    end)
    while true do
        wait(0)
        if enabled then
            if isKeyDown(VK_W) or isKeyDown(VK_A) or isKeyDown(VK_S) or isKeyDown(VK_D) then
                setCharAnimSpeed(PLAYER_PED, 'skate_idle', 1000)
                wait(0)
            end
            if isKeyDown(VK_UP) or isKeyDown(VK_LEFT) or isKeyDown(VK_DOWN) or isKeyDown(VK_RIGHT) then
                setCharAnimSpeed(PLAYER_PED, 'skate_idle', 1000)
                wait(0)
            end
        end
    end
end