script_name("Авто-Респавн")
script_author("Eduardo (fixed by ChatGPT)")
script_version("2.3-stable")

require "lib.moonloader"
local sampev   = require "lib.samp.events"
local imgui    = require "mimgui"
local ffi      = require "ffi"
local json     = require "json"
local encoding = require 'encoding'

encoding.default = "CP1251"
local u8 = encoding.UTF8

--------------------------------------------------
-- CONFIG (JSON, полный функционал)
--------------------------------------------------
local cfg_dir  = getWorkingDirectory() .. "\\config\\AutoRespawn"
local cfg_file = cfg_dir .. "\\config.json"

local function createFullPath(path)
    local parts = {}
    for part in path:gmatch("[^\\]+") do
        table.insert(parts, part)
    end
    local current = ""
    for i = 1, #parts - 1 do
        current = current .. parts[i] .. "\\"
        createDirectory(current)
    end
end
createFullPath(cfg_dir)

local default_cfg = {
    main = {
        enabled = true,
        delay = 150,
        triggers_enabled = true,
        need_confirm = true
    },
    triggers = {
        "респ кар"
        "sp car"
    },
    hidden_triggers = {
        kd1 = "Заказывать доставку транспорта, можно 1 раз в 10 мин",
        adv = "AutoRespawner",
        cancel1 = "Заказал доставку транспорта",
        cancel2 = "заказал заправку транспорта"
    }
}

local function table_copy(t)
    local copy = {}
    for k,v in pairs(t) do
        if type(v) == "table" then
            copy[k] = table_copy(v)
        else
            copy[k] = v
        end
    end
    return copy
end

local function table_update(t1,t2)
    for k,v in pairs(t2) do
        if type(v) == "table" and type(t1[k]) == "table" then
            table_update(t1[k],v)
        else
            t1[k] = v
        end
    end
    return t1
end

local function saveConfig(config_to_save)
    config_to_save = config_to_save or cfg
    local ok, err = pcall(function()
        local file = io.open(cfg_file,"w")
        if file then
            file:write(json.encode(config_to_save,{indent=true}))
            file:close()
        end
    end)
    if not ok then
        print("Ошибка сохранения конфига: "..tostring(err))
    end
end

local function loadConfig()
    local config = table_copy(default_cfg)
    local file = io.open(cfg_file,"r")
    if file then
        local content = file:read("*all")
        file:close()
        if content and content ~= "" and content ~= "null" then
            local ok, loaded = pcall(json.decode,content)
            if ok and loaded then
                config = table_update(config,loaded)
            else
                saveConfig(default_cfg)
            end
        else
            saveConfig(default_cfg)
        end
    else
        saveConfig(default_cfg)
    end
    return config
end

local cfg = loadConfig()
if not cfg.triggers then cfg.triggers = {} end

--------------------------------------------------
-- STATE
--------------------------------------------------
local active = false
local step = 0
local wait_confirm = false
local respawn_timer = false

--------------------------------------------------
-- IMGUI
--------------------------------------------------
local show_menu = imgui.new.bool(false)
local ui_enabled  = imgui.new.bool(cfg.main.enabled)
local ui_triggers = imgui.new.bool(cfg.main.triggers_enabled)
local ui_confirm  = imgui.new.bool(cfg.main.need_confirm)
local ui_delay    = imgui.new.int(cfg.main.delay)

--------------------------------------------------
-- BUFFERS
--------------------------------------------------
local buffers = {}
local new_trigger_buffer = ffi.new("char[256]")
ffi.fill(new_trigger_buffer,256)

local function getBuffer(id,text,size)
    size = size or 128
    if not buffers[id] then
        local buf = ffi.new("char[?]",size)
        ffi.fill(buf,size)
        if text then ffi.copy(buf,u8(text)) end
        buffers[id] = buf
    end
    return buffers[id]
end

--------------------------------------------------
-- HELPERS
--------------------------------------------------
local function addLog(text)
    print(os.date("%H:%M:%S").." | "..text)
end

local function save()
    cfg.main.enabled = ui_enabled[0]
    cfg.main.triggers_enabled = ui_triggers[0]
    cfg.main.need_confirm = ui_confirm[0]
    cfg.main.delay = ui_delay[0]

    -- обновляем триггеры
    if buffers.triggers then
        for i, buf in pairs(buffers.triggers) do
            local text = u8:decode(ffi.string(buf))
            if text and #text > 0 then cfg.triggers[i] = text end
        end
    end

    local new_text = u8:decode(ffi.string(new_trigger_buffer))
    if new_text and #new_text>0 then
        table.insert(cfg.triggers,new_text)
        ffi.fill(new_trigger_buffer,256)
    end

    saveConfig(cfg)
    addLog("Config saved")
end

--------------------------------------------------
-- RESPAWN
--------------------------------------------------
local function resetRespawn()
    active = false
    step = 0
    wait_confirm = false
    respawn_timer = false
end

local function startRespawn()
    if respawn_timer then return end
    respawn_timer = true

    lua_thread.create(function()
        sampSendChat("/fb [AutoRespawner] До респавна авто - 10 секунд !")
        wait(10000)

        if not respawn_timer then return end

        active = true
        step = 0

        sampSendChat("/lmenu")
        wait(300)
        sampSendChat("/lmenu") -- фикс бага
    end)
end

local function sendTriggersList()
    local list = {}
    for _, trig in pairs(cfg.triggers) do
        if trig ~= "" then table.insert(list,trig) end
    end
    table.insert(list,"[KD]")
    table.insert(list,"[Cancel: доставка/заправка]")
    sampSendChat("/fb [AutoRespawner] Триггеры: "..table.concat(list,", "))
end

--------------------------------------------------
-- MAIN
--------------------------------------------------
function main()
    repeat wait(0) until isSampAvailable()

    sampRegisterChatCommand("alm", function() show_menu[0] = not show_menu[0] end)
    sampRegisterChatCommand("almy", function()
        if not wait_confirm then return end
        wait_confirm = false
        startRespawn()
    end)

    sampAddChatMessage("{660099}[Авто-Респавн] {FFEFD5}/alm — меню", -1)
    addLog("Script started")
    wait(-1)
end

--------------------------------------------------
-- CHAT
--------------------------------------------------
function sampev.onServerMessage(_, text)
    if not cfg.main.enabled or type(text)~="string" then return end
    local ok, clean = pcall(u8,text)
    if not ok then return end

    if clean:find(cfg.hidden_triggers.kd1,1,true) then
        resetRespawn()
        sampSendChat("/fb [AutoRespawner] КД на респавн еще не прошло (10 минут).")
        return
    end
    if clean:find(cfg.hidden_triggers.adv,1,true) then
        sendTriggersList()
        return
    end
    if clean:find(cfg.hidden_triggers.cancel1,1,true)
    or clean:find(cfg.hidden_triggers.cancel2,1,true) then
        resetRespawn()
        return
    end

    if not cfg.main.triggers_enabled then return end
    for _, trig in pairs(cfg.triggers) do
        if trig ~= "" and clean:find(u8(trig),1,true) then
            if cfg.main.need_confirm then
                wait_confirm = true
                sampAddChatMessage("{660099}[AutoRespawner] {FFEFD5}Триггер: "..trig.." | /almy — подтвердить",-1)
            else
                startRespawn()
            end
            break
        end
    end
end

--------------------------------------------------
-- DIALOG
--------------------------------------------------
function sampev.onShowDialog(id)
    if not active then return true end
    if id ~= 1214 then return true end

    lua_thread.create(function()
        wait(cfg.main.delay)
        if step==0 then
            sampSendDialogResponse(id,1,4,"")
            step=1
        elseif step==1 then
            sampSendDialogResponse(id,1,5,"")
            resetRespawn()
        end
    end)

    return false
end

--------------------------------------------------
-- IMGUI (вкладки как PingBot + кнопка сохранения)
--------------------------------------------------
imgui.OnFrame(function() return show_menu[0] end,function()
    imgui.Begin(u8("Авто-Респавн"),show_menu,imgui.WindowFlags.AlwaysAutoResize)

    if imgui.BeginTabBar("tabs") then

        -- НАСТРОЙКИ
        if imgui.BeginTabItem(u8("Настройки")) then
            imgui.Checkbox(u8("Скрипт включен"), ui_enabled)
            imgui.Checkbox(u8("Поиск триггеров"), ui_triggers)
            imgui.Checkbox(u8("Требовать подтверждение"), ui_confirm)
            imgui.Text(u8("Задержка (мс):"))
            imgui.InputInt("##delay", ui_delay)

            if imgui.Button(u8("Сохранить настройки")) then
                save()
            end

            imgui.EndTabItem()
        end

        -- ТРИГГЕРЫ
        if imgui.BeginTabItem(u8("Триггеры")) then
            if not buffers.triggers then
                buffers.triggers = {}
                for i,trig in ipairs(cfg.triggers) do
                    local buf = ffi.new("char[256]")
                    ffi.fill(buf,256)
                    ffi.copy(buf,u8(trig))
                    table.insert(buffers.triggers,buf)
                end
            end

            local to_remove = nil
            for i, buf in ipairs(buffers.triggers) do
                local input_id = "##trigger_input_"..i
                local button_id = u8("Удалить").."##trigger_del_"..i

                imgui.InputText(input_id, buf, 256)
                imgui.SameLine()
                if imgui.Button(button_id) then
                    to_remove = i
                end
                imgui.Separator()
            end

            if to_remove then
                table.remove(buffers.triggers,to_remove)
                table.remove(cfg.triggers,to_remove)
            end

            imgui.Text(u8("Новый триггер:"))
            imgui.InputText("##new_trigger", new_trigger_buffer, 256)

            if imgui.Button(u8("Сохранить триггеры")) then
                save()
                buffers.triggers = nil
            end

            imgui.EndTabItem()
        end

        imgui.EndTabBar()
    end

    imgui.End()
end)
