script_name("Ultimate Anime HUD V2 FULL")
script_author("XZ Fixed + Ultimate Upgrade")

local inicfg = require 'inicfg'
local vkeys = require 'vkeys'
local imgui = require 'imgui'
local sampev = require 'lib.samp.events'

local menu = imgui.ImBool(false)

local ini = inicfg.load({
    pos = { hx = 550, hy = 65, ax = 550, ay = 45, sx = 550, sy = 85 },
    config = { theme = 1 },
    custom = {}
}, "ultimate_anime_hud.ini")

local font = renderCreateFont("Arial", 11, 9)

local function lerp(a,b,t) return a+(b-a)*t end
local function lerpColor(c1,c2,t)
    local a1 = bit.band(bit.rshift(c1,24),0xFF)
    local r1 = bit.band(bit.rshift(c1,16),0xFF)
    local g1 = bit.band(bit.rshift(c1,8),0xFF)
    local b1 = bit.band(c1,0xFF)

    local a2 = bit.band(bit.rshift(c2,24),0xFF)
    local r2 = bit.band(bit.rshift(c2,16),0xFF)
    local g2 = bit.band(bit.rshift(c2,8),0xFF)
    local b2 = bit.band(c2,0xFF)

    return bit.bor(
        bit.lshift(math.floor(lerp(a1,a2,t)),24),
        bit.lshift(math.floor(lerp(r1,r2,t)),16),
        bit.lshift(math.floor(lerp(g1,g2,t)),8),
        math.floor(lerp(b1,b2,t))
    )
end

local themes = {
    { name = "Blue Blood", main = 0xFF4FC3F7, hp1 = 0xFFFF2A2A, hp2 = 0xFF220000, armor = 0xFF888888, armor_flash = 0xFF4488FF, sat = 0xFF663300 },
    { name = "Dark Classic", main = 0xFF00FF00, hp1 = 0xFFAA0000, hp2 = 0xFF111111, armor = 0xFF004444, armor_flash = 0xFF002222, sat = 0xFF663300 },
    { name = "Pastel Soft", main = 0xFFFFB6C1, hp1 = 0xFFFF5252, hp2 = 0xFF4A0000, armor = 0xFFB0BEC5, armor_flash = 0xFF90CAF9, sat = 0xFFFFA726 }
}

local sValue = 100
local edit = 0

local function getShakeSoft(value)
    if value >= 30 then return 0,0 end
    local t = (30-value)/30
    local power = 0.5 + (t*3)
    return math.random(-power,power), math.random(-power,power)
end

local function applyStyle()
    imgui.SwitchContext()
    local style = imgui.GetStyle()
    style.WindowRounding = 12
    style.FrameRounding = 8
    style.ScrollbarRounding = 8
    style.WindowTitleAlign = imgui.ImVec2(0.5,0.5)
    style.Colors[imgui.Col.WindowBg] = imgui.ImVec4(0.08,0.08,0.12,0.95)
    style.Colors[imgui.Col.TitleBg] = imgui.ImVec4(0.15,0.0,0.2,1)
    style.Colors[imgui.Col.TitleBgActive] = imgui.ImVec4(0.4,0.1,0.6,1)
end

function imgui.OnDrawFrame()
    if not menu.v then return end
    applyStyle()
    imgui.SetNextWindowSize(imgui.ImVec2(450,420), imgui.Cond.FirstUseEver)
    imgui.Begin("? Ultimate Anime HUD ?", menu)

    imgui.Text("Выбери тему:")
    imgui.Separator()

    for i=1,#themes do
        if imgui.Selectable(themes[i].name, ini.config.theme==i) then
            ini.config.theme=i
            inicfg.save(ini,"ultimate_anime_hud.ini")
        end
    end

    imgui.Spacing()
    imgui.Separator()
    imgui.Text("Создать новую тему:")

    if imgui.Button("Кастом тема") then
        table.insert(themes,{
            name="Custom "..#themes+1,
            main=0xFFFFFFFF, hp1=0xFFFF0000, hp2=0xFF220000, armor=0xFF888888,
            armor_flash=0xFF4488FF, sat=0xFFFFFF00
        })
    end

    imgui.End()
end

-- Отправка команды /satiety каждые 60 секунд
local lastUpdate = os.time()
function updateSatiety()
    if os.time() - lastUpdate > 60 then
        sampSendChat("/satiety")
        lastUpdate = os.time()
    end
end

function main()
    while not isSampAvailable() do wait(100) end
    math.randomseed(os.time())

    sampAddChatMessage("{AAAAAA}[AnimeHUD] {FFFFFF}Загружен.", -1)
    sampAddChatMessage("{AAAAAA}/ahud {FFFFFF}- открыть меню", -1)
    sampAddChatMessage("{AAAAAA}/sethp /setarmor /setsat {FFFFFF}- переместить элементы", -1)

    sampRegisterChatCommand("ahud", function() menu.v = not menu.v end)
    sampRegisterChatCommand("sethp", function() edit=1; sampSetCursorMode(2) end)
    sampRegisterChatCommand("setarmor", function() edit=2; sampSetCursorMode(2) end)
    sampRegisterChatCommand("setsat", function() edit=3; sampSetCursorMode(2) end)

    while true do
        wait(0)
        if sampIsLocalPlayerSpawned() and not isPauseMenuActive() then
            updateSatiety()

            local now = os.clock()
            local hp = math.floor(getCharHealth(PLAYER_PED))
            local ar = math.floor(getCharArmour(PLAYER_PED))
            local theme = themes[ini.config.theme]

            local t = hp/100
            local hpColor = lerpColor(theme.hp2, theme.hp1, 1-t)
            hpColor = lerpColor(hpColor, theme.main, t)
            if hp < 30 then
                local pulse = (math.sin(now*4)+1)/2
                hpColor = lerpColor(hpColor,0xFFFFFFFF,pulse*0.2)
            end

            local sx,sy = getShakeSoft(hp)
            local sat_sx,sat_sy = getShakeSoft(sValue)

            renderFontDrawText(font,
                string.format("HP [ %s ] %d", hp>60 and "^_^" or hp>30 and ">_<" or "x_x", hp),
                ini.pos.hx+sx, ini.pos.hy+sy, hpColor)

            if ar > 0 then
                local ar_sx,ar_sy = getShakeSoft(ar)
                local arColor = (ar<=30 and math.fmod(now,0.5)<0.25) and theme.armor_flash or theme.armor
                renderFontDrawText(font,
                    string.format("AR [ %s ] %d", ar>80 and "=-_-=" or "=o_o=", ar),
                    ini.pos.ax+ar_sx, ini.pos.ay+ar_sy, arColor)
            else
                renderFontDrawText(font, "AR [ - ] 0", ini.pos.ax, ini.pos.ay, theme.armor)
            end

            local satColor = (sValue<=30 and math.fmod(now,0.6)<0.3) and 0xFF111111 or theme.sat
            renderFontDrawText(font,
                string.format("SAT [ %s ] %d", sValue>70 and "^.^" or sValue>30 and "o_o" or "o.O", sValue),
                ini.pos.sx+sat_sx, ini.pos.sy+sat_sy, satColor)

            if edit>0 then
                local cx,cy = getCursorPos()
                if edit==1 then ini.pos.hx, ini.pos.hy=cx,cy end
                if edit==2 then ini.pos.ax, ini.pos.ay=cx,cy end
                if edit==3 then ini.pos.sx, ini.pos.sy=cx,cy end
                if wasKeyPressed(vkeys.VK_RETURN) then
                    inicfg.save(ini,"ultimate_anime_hud.ini")
                    sampSetCursorMode(0)
                    edit=0
                end
            end
        end
    end
end

function sampev.onServerMessage(color,text)
    local lower=text:lower()
    if lower:find("you are hungry") or lower:find("hungry") then sValue=10 end
    local val = text:match("(%d+)")
    if val and lower:find("сытость") then sValue=tonumber(val) end
end

function sampev.onShowDialog(id, style, title, b1, b2, text)
    local cleanText = text:gsub("{%x%x%x%x%x%x}", "")
    if cleanText:find("Ваша сытость:") or title:find("Сытость") then
        local hungry = cleanText:match("Ваша сытость:%s*(%d+%.?%d*)")
        if hungry then
            local f = io.open("moonloader/get_sat.txt", "w")
            if f then f:write(math.floor(tonumber(hungry))); f:close() end
        end
        sampSendDialogResponse(id, 0, 0, "")
        return false
    end
end