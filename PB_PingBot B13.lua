-- осторожно ! скрипт сделан из говна палок и нейронки, эта версия очередная которую нейронка переписала раз 10 по своему и я тут пару херней подлотал
script_name("PingBot")
script_author("fff (fixed)")
script_version("3.6")

require "lib.moonloader"
local sampev   = require "lib.samp.events"
local imgui    = require "mimgui"
local ffi      = require "ffi"
local requests = require "requests"
local json     = require "json"
local encoding = require 'encoding'

encoding.default = 'CP1251'
local u8 = encoding.UTF8

-- moonloader\config
local cfg_dir = getWorkingDirectory() .. "\\config\\PingBot"
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

local default_config = {
    main = {
        enabled = true,
        tg_token = "",
        tg_chat_id = "",
        username = "",
        mention = false,
        show_time = true,
        template = "Обнаружен триггер: %trigger%\n\nСообщение:\n%message%"
    },
    triggers = {
        "ping"
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
    local success, err = pcall(function()
        local file = io.open(cfg_file,"w")
        if file then
            file:write(json.encode(config_to_save,{indent=true}))
            file:close()
        end
    end)
    if not success then
        chat("Ошибка создания файла конфига: "..tostring(err))
        createFullPath(cfg_dir)
        local file = io.open(cfg_file,"w")
        if file then
            file:write(json.encode(config_to_save,{indent=true}))
            file:close()
        end
    end
end

local function loadConfig()
    local config = table_copy(default_config)
    local file = io.open(cfg_file,"r")
    if file then
        local content = file:read("*all")
        file:close()
        if content and content ~= "" and content ~= "null" then
            local ok, loaded = pcall(json.decode,content)
            if ok and loaded then
                config = table_update(config,loaded)
            else
                saveConfig(default_config)
            end
        else
            saveConfig(default_config)
        end
    else
        saveConfig(default_config)
    end
    return config
end

local cfg = loadConfig()
if not cfg.triggers then cfg.triggers = {} end

local show = imgui.new.bool(false)
local ui_enabled = imgui.new.bool(cfg.main.enabled)
local ui_mention = imgui.new.bool(cfg.main.mention)
local ui_show_time = imgui.new.bool(cfg.main.show_time)

local buffers = {}
local logs = {}
local LOG_LIMIT = 100
local new_trigger_buffer = ffi.new("char[256]")
ffi.fill(new_trigger_buffer,256)

local function getBuffer(id,text,size)
    size = size or 256
    if not buffers[id] then
        local buf = ffi.new("char[?]",size)
        ffi.fill(buf,size)
        if text then ffi.copy(buf,u8(text)) end
        buffers[id] = buf
    end
    return buffers[id],size
end

local function addLog(text)
    table.insert(logs,1,os.date("%H:%M:%S").." | "..text)
    while #logs > LOG_LIMIT do table.remove(logs) end
end

local function chat(text)
    sampAddChatMessage("{66CCFF}[PingBot]{FFFFFF} "..text,-1)
end

local function urlencode(str)
    if not str then return "" end
    str = tostring(str)
    str = str:gsub("\n","\r\n")
    str = str:gsub("([^%w %-%.%~])",function(c) return string.format("%%%02X",string.byte(c)) end)
    str = str:gsub(" ","%%20")
    return str
end

-- TELEGRAM (Осторожно ! Спижено !)
local function sendTelegram(text)
    if cfg.main.tg_token=="" or cfg.main.tg_chat_id=="" then
        chat("Telegram не настроен")
        return
    end
    lua_thread.create(function()
        local clean = text:gsub("{[%dA-Fa-f]+}","")
        local utf8_text = u8(clean)
        if cfg.main.show_time then
            utf8_text = "["..os.date("%d.%m.%Y %H:%M:%S").."]\n"..utf8_text
        end
        if cfg.main.mention and cfg.main.username~="" then
            utf8_text = "@"..cfg.main.username.."\n"..utf8_text
        end
        local url = string.format(
            "https://api.telegram.org/bot%s/sendMessage?chat_id=%s&text=%s",
            cfg.main.tg_token,cfg.main.tg_chat_id,urlencode(utf8_text)
        )
        local ok,res = pcall(requests.get,url)
        if ok and res and res.status_code==200 then
            addLog("Telegram OK")
        else
            local err_msg="Telegram ERROR"
            if res and res.status_code then err_msg=err_msg..": "..res.status_code end
            addLog(err_msg)
        end
    end)
end

local function handleTrigger(trigger,raw_text)
    local message = cfg.main.template
    message = message:gsub("%%trigger%%",trigger)
    message = message:gsub("%%message%%",raw_text)
    sendTelegram(message)
    chat("Сработал триггер: "..trigger)
    addLog("Trigger: "..trigger.." - "..raw_text)
end

function sampev.onServerMessage(color,text)
    if not cfg.main.enabled then return end
    if type(text)~="string" then return end
    local decoded = u8(text)
    for _,trig in ipairs(cfg.triggers) do
        if trig and trig~="" and decoded:find(u8(trig),1,true) then
            handleTrigger(trig,decoded)
            break
        end
    end
end

local function save()
    cfg.main.enabled = ui_enabled[0]
    cfg.main.mention = ui_mention[0]
    cfg.main.show_time = ui_show_time[0]

    if buffers.token then cfg.main.tg_token = u8:decode(ffi.string(buffers.token)) end
    if buffers.chat then cfg.main.tg_chat_id = u8:decode(ffi.string(buffers.chat)) end
    if buffers.user then cfg.main.username = u8:decode(ffi.string(buffers.user)) end
    if buffers.template then cfg.main.template = u8:decode(ffi.string(buffers.template)) end

    for i,buf in ipairs(buffers.triggers or {}) do
        local text = u8:decode(ffi.string(buf))
        if text and #text>0 then cfg.triggers[i]=text end
    end

    local new_text = u8:decode(ffi.string(new_trigger_buffer))
    if new_text and #new_text>0 then
        table.insert(cfg.triggers,new_text)
        ffi.fill(new_trigger_buffer,256)
    end

    saveConfig(cfg)
    chat("Настройки сохранены")
    addLog("Config saved")
end

function main()
    repeat wait(0) until isSampAvailable()

    sampRegisterChatCommand("pb",function() show[0]=not show[0] end)
    sampRegisterChatCommand("pbtest",function() sendTelegram("Тестовое сообщение PingBot") end)
    sampRegisterChatCommand("pblist",function()
        chat("Триггеры ("..#cfg.triggers.." шт.):")
        for i,trig in ipairs(cfg.triggers) do
            sampAddChatMessage("  "..i..". "..trig,-1)
        end
    end)
    sampRegisterChatCommand("pbpath",function() chat("Конфиг: "..cfg_file) end)

    chat("/pb — меню | /pbtest — тест | /pblist — список | /pbpath — путь к конфигу")
    addLog("Script started")
    addLog("Config path: "..cfg_file)
    wait(-1)
end

imgui.OnFrame(function() return show[0] end,function()
    imgui.Begin(u8("PingBot"),show,imgui.WindowFlags.AlwaysAutoResize)

    if imgui.BeginTabBar("tabs") then

        if imgui.BeginTabItem(u8("Настройки")) then
            imgui.Checkbox(u8("Включен"),ui_enabled)
            imgui.Checkbox(u8("Упоминать username"),ui_mention)
            imgui.Checkbox(u8("Показывать дату/время"),ui_show_time)

            local buf,size

            buf,size = getBuffer("token",cfg.main.tg_token,256)
            imgui.InputText(u8("Token"),buf,size)

            buf,size = getBuffer("chat",cfg.main.tg_chat_id,256)
            imgui.InputText(u8("Chat ID"),buf,size)

            buf,size = getBuffer("user",cfg.main.username,256)
            imgui.InputText(u8("Username"),buf,size)

            imgui.TextDisabled(u8("%trigger% - триггер"))
            imgui.TextDisabled(u8("%message% - сообщение"))

            buf,size = getBuffer("template",cfg.main.template,512)
            imgui.InputTextMultiline(u8("Шаблон"),buf,size,imgui.ImVec2(420,120))

            if imgui.Button(u8("Сохранить")) then save() end
            imgui.SameLine()
            if imgui.Button(u8("Тест Telegram")) then sendTelegram("Тестовое сообщение PingBot") end

            imgui.EndTabItem()
        end

        if imgui.BeginTabItem(u8("Триггеры")) then

            if not buffers.triggers then
                buffers.triggers={}
                for i,trig in ipairs(cfg.triggers) do
                    local buf = ffi.new("char[256]")
                    ffi.fill(buf,256)
                    ffi.copy(buf,u8(trig))
                    table.insert(buffers.triggers,buf)
                end
            end

            local to_remove = nil
            for i,buf in ipairs(buffers.triggers) do
                local input_id = "##trigger_input_"..i
                local button_id = u8("Удалить").."##trigger_del_"..i

                imgui.InputText(input_id,buf,256)
                imgui.SameLine()
                if imgui.Button(button_id) then
                    to_remove=i
                end
                imgui.Separator()
            end

            if to_remove then
                table.remove(buffers.triggers,to_remove)
                table.remove(cfg.triggers,to_remove)
            end

            imgui.Text(u8("Новый триггер:"))
            imgui.InputText("##new_trigger",new_trigger_buffer,256)

            if imgui.Button(u8("Сохранить триггеры")) then
                save()
                buffers.triggers=nil
            end

            imgui.EndTabItem()
        end

        if imgui.BeginTabItem(u8("Логи")) then
            imgui.BeginChild("logs",imgui.ImVec2(0,200))
            for i=1,math.min(#logs,20) do
                imgui.Text(u8(logs[i]))
            end
            imgui.EndChild()
            imgui.EndTabItem()
        end

        imgui.EndTabBar()
    end

    imgui.End()
end)
