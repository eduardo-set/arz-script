script_author("Royan_Millans and YarikVL")
require 'lib.moonloader'
local sampev = require "lib.samp.events"
local inicfg = require 'inicfg'
local directIni = 'Money Separator.ini'
local ini = inicfg.load(inicfg.load({
	main = {
    	tochka = false,
		activeChat = true,
    	activeDialogs = true,
		activeTextdraws = true,
		activeAb = true,
		activeDisplay = true
	},
}, directIni))
inicfg.save(ini, directIni)
local listItems = { 'tochka', 'activeChat', 'activeDialogs', 'activeTextdraws', 'activeAb', 'activeDisplay' }

function main()
	while not isSampAvailable() do wait(0) end

	sampRegisterChatCommand('mscr', function()
		Dialog()
	end)

	while true do wait(0)
		local result, button, list, input = sampHasDialogRespond(6789)
        if result then
            if button == 1 then
				if listItems[list + 1] then
					ini.main[listItems[list + 1]] = not ini.main[listItems[list + 1]] -- спасибо Чапе
				end
                Dialog()
            end
        end
	end
end

function Dialog()
	inicfg.save(ini, directIni)
    sampShowDialog(6789, 'Money Separator v4 by YarikVL', "Разделение денег точками, вместо запятых:"..(ini.main.tochka and "{00FF00}Включено" or "{ff004d}Выключено").."\nРазделение денег в чате: "..(ini.main.activeChat and "{00FF00}Включено" or "{ff004d}Выключено")..'\nРазделение денег в диалогах: '..(ini.main.activeDialogs and '{00FF00}Включено' or '{ff004d}Выключено')..'\nРазделение денег в текстдравах ( в trade или в лавке): '..(ini.main.activeTextdraws and '{00FF00}Включено' or '{ff004d}Выключено')..'\nРазделение денег в табличках ( например на Автобазаре ): '..(ini.main.activeAb and '{00FF00}Включено' or '{ff004d}Выключено')..'\nРазделение денег на экране: '..(ini.main.activeDisplay and '{00FF00}Включено' or '{ff004d}Выключено'), 'Выбрать', 'Закрыть', 4)
end

function comma_value(n)
	local left,num,right = string.match(n,'^([^%d]*%d)(%d*)(.-)$')
	if not ini.main.tochka then
		return left..(num:reverse():gsub('(%d%d%d)','%1,'):reverse())..right
	else
		return left..(num:reverse():gsub('(%d%d%d)','%1.'):reverse())..right
	end
end

--[[INCOMING_RPCS[RPC.SETOBJECTMATERIAL]          = {{'onSetObjectMaterial', 'onSetObjectMaterialText'}, handler.rpc_set_object_material_reader, handler.rpc_set_object_material_writer}]]
function separator(text) -- by Royan_Millans
	if text:find("$") then 
	    for S in string.gmatch(text, "%$%d+") do
	    	local replace = comma_value(S)
	    	text = string.gsub(text, S, replace)
	    end
	    for S in string.gmatch(text, "%d+%$") do
	    	S = string.sub(S, 0, #S-1)
	    	local replace = comma_value(S)
	    	text = string.gsub(text, S, replace)
	    end
	end
	return text
end

function sampev.onSetObjectMaterialText(objectId, data)
	if ini.main.activeAb then
		local object = sampGetObjectHandleBySampId(objectId)
		if object and doesObjectExist(object) then
			if getObjectModel(object) == 18663 then
				data.text = separator(data.text)
			end
		end
		return {objectId, data}
	end
end
function sampev.onShowDialog(dialogId, style, title, button1, button2, text)
	if ini.main.activeDialogs then
		text = separator(text)
		title = separator(title)
		return {dialogId, style, title, button1, button2, text}
	end
end
function sampev.onServerMessage(color, text)
	if ini.main.activeChat then
		text = separator(text)
		return {color, text}
	end
end
function sampev.onCreate3DText(id, color, position, distance, testLOS, attachedPlayerId, attachedVehicleId, text)
	if ini.main.activeAb then
		text = separator(text)
		return {id, color, position, distance, testLOS, attachedPlayerId, attachedVehicleId, text}
	end
end
function sampev.onTextDrawSetString(id, text)
	if ini.main.activeTextdraws then
		text = separator(text)
		return {id, text}
	end
end
function sampev.onDisplayGameText(style,time,text)
	if ini.main.activeDisplay then
    	text = separator(text)
    	return {style,time,text}
	end
end
function sampev.onShowTextDraw(id, data)
    if ini.main.activeTextdraws then
		if id == 2070 or id == 2077  then -- разделение цен в трейде
			if tonumber(data.text) then
				data.text = comma_value(data.text)
			end
		else
			data.text = separator(data.text)
		end
		return {id,data}
	end
end