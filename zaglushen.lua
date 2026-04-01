local hook = require 'lib.samp.events'
local hook = require 'samp.events'
local sukazaebalmutit = 0
function main() --this function will start when script load
    while not isSampAvailable() do wait(0) end --wait for samp load
    --code (register command, add load message, etc.)
    while true do
        wait(0)
        --code
    end
end

function hook.onServerMessage(color, text)
    local sec = string.match(text, '^¬ы заглушены. ќставшеес€ врем€ заглушки (%d+) секунд') -- вылавливаем секунды из строки
    if sec ~= nil then -- провер€ем получили ли мы секунды
        local end_mute = os.time() + tonumber(sec) -- получаем UNIX врем€ окончани€ заглушки
        local get = function(count) -- функци€ перевода секундного числа в удобоваримый нам формат
            local normal = count + (86400 - os.date('%H', 0) * 3600)
            if count < 3600 then -- если значение меньше часа
                return os.date('%M:%S', normal)
            else
                return os.date('%H:%M:%S', normal)
            end
        end
        text = text:gsub('%d+ секунд', get(end_mute - os.time()) .. ' (ƒо ' .. os.date('%H:%M:%S', end_mute) .. ')')
        return { color, text } -- лучше делать так, чем добавл€ть sampAddChatMessage(), просто запомни, в будущем пригодитьс€
    end
end

-- »спользовать main() в скрипте где используетс€ чисто один хук не нужно, он может работать без него.
