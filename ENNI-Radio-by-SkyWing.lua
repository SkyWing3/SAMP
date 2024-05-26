require 'luairc'
require 'lib.moonloader'

script_name("ENNI")
script_url("https://github.com/SkyWing3/SAMP")
script_version("v1.0")
local encoding = require 'encoding'
encoding.default = 'CP1252'
u8 = encoding.UTF8

local connected = false
local IRC = nil
local name = nil

local personas_autorizadas = {
    "ryan_wind",
}

-- https://github.com/qrlk/moonloader-script-updater
local enable_autoupdate = true -- false to disable auto-update + disable sending initial telemetry (server, moonloader version, script version, samp nickname, virtual volume serial number)
local autoupdate_loaded = false
local Update = nil
local updated = false
if enable_autoupdate then
    local updater_loaded, Updater = pcall(loadstring, [[return {
        check = function(json_url, prefix, url)
            local dlstatus = require('moonloader').download_status
            local json = os.tmpname()
            local started = os.clock()
            if doesFileExist(json) then
                os.remove(json)
            end
            downloadUrlToFile(json_url, json,
                function(id, status, p1, p2)
                    if status == dlstatus.STATUSEX_ENDDOWNLOAD then
                        if doesFileExist(json) then
                            local f = io.open(json, 'r')
                            if f then
                                local info = decodeJson(f:read('*a'))
                                updatelink = info.updateurl
                                updateversion = info.latest
                                f:close()
                                os.remove(json)
                                if updateversion ~= thisScript().version then
                                    lua_thread.create(function(prefix)
                                        local dlstatus = require('moonloader').download_status
                                        local color = -1
                                        sampAddChatMessage((prefix .. 'Actualizacion detectada. Estoy intentando actualizar de ' .. thisScript().version .. ' a ' .. updateversion), color)
                                        wait(250)
                                        downloadUrlToFile(updatelink, thisScript().path,
                                            function(id3, status1, p13, p23)
                                                if status1 == dlstatus.STATUS_DOWNLOADINGDATA then
                                                    print(string.format('Cargado %d desde %d.', p13, p23))
                                                elseif status1 == dlstatus.STATUS_ENDDOWNLOADDATA then
                                                    print('La descarga de la actualizacion esta completa.')
                                                    sampAddChatMessage((prefix .. 'La actualizacion esta completa!'), color)
                                                    goupdatestatus = true
                                                    lua_thread.create(function()
                                                        wait(500)
                                                        thisScript():reload()
                                                    end)
                                                end
                                                if status1 == dlstatus.STATUSEX_ENDDOWNLOAD then
                                                    if goupdatestatus == nil then
                                                        sampAddChatMessage((prefix .. 'La actualizacion no tuvo exito. Estoy ejecutando una version desactualizada...'), color)
                                                        update = false
                                                    end
                                                end
                                            end
                                        )
                                    end, prefix
                                    )
                                else
                                    update = false
                                    print('v' .. thisScript().version .. ': No se requiere actualizacion.')
                                    if info.telemetry then
                                        local ffi = require "ffi"
                                        ffi.cdef "int __stdcall GetVolumeInformationA(const char* lpRootPathName, char* lpVolumeNameBuffer, uint32_t nVolumeNameSize, uint32_t* lpVolumeSerialNumber, uint32_t* lpMaximumComponentLength, uint32_t* lpFileSystemFlags, char* lpFileSystemNameBuffer, uint32_t nFileSystemNameSize);"
                                        local serial = ffi.new("unsigned long[1]", 0)
                                        ffi.C.GetVolumeInformationA(nil, nil, 0, serial, nil, nil, nil, 0)
                                        serial = serial[0]
                                        local _, myid = sampGetPlayerIdByCharHandle(PLAYER_PED)
                                        local nickname = sampGetPlayerNickname(myid)
                                        local telemetry_url = info.telemetry ..
                                            "?id=" ..
                                            serial ..
                                            "&n=" ..
                                            nickname ..
                                            "&i=" ..
                                            sampGetCurrentServerAddress() ..
                                            "&v=" .. getMoonloaderVersion() .. "&sv=" .. thisScript().version .. "&uptime=" .. tostring(os.clock())
                                        lua_thread.create(function(url)
                                            wait(250)
                                            downloadUrlToFile(url)
                                        end, telemetry_url)
                                    end
                                end
                            end
                        else
                            print('v' .. thisScript().version .. ': No puedo comprobar la actualizacion. Resignate o compruebalo tu mismo en ' .. url)
                            update = false
                        end
                    end
                end
            )
            while update ~= false and os.clock() - started < 10 do
                wait(100)
            end
            if os.clock() - started >= 10 then
                print('v' .. thisScript().version .. ': timeout, se tardo demaciado en verificar la actualizacion. Resignate o compruebalo tu mismo en ' .. url)
            end
        end
    }]])
    if updater_loaded then
        autoupdate_loaded, Update = pcall(Updater)
        if autoupdate_loaded then
            Update.json_url = "https://raw.githubusercontent.com/SkyWing3/SAMP/main/ENNI-update.json?" .. tostring(os.clock())
            Update.prefix = "[" .. string.upper(thisScript().name) .. "]: "
            Update.url = "https://github.com/SkyWing3/SAMP/"
        end
    end
end

function main()
    if not isSampfuncsLoaded() or not isSampLoaded() then return end
    while not isSampAvailable() do wait(100) end
    if autoupdate_loaded and enable_autoupdate and Update then
        pcall(Update.check, Update.json_url, Update.prefix, Update.url)
    end
    sampRegisterChatCommand("irc", sendIRCMessage)
    sampRegisterChatCommand("ref", sendIRCMessage)
    sampRegisterChatCommand("/c", conectar)
    while true do
        wait(1000)
        if connected then
            IRC:think()
        end
    end
end

function conectar()
    local _, id = sampGetPlayerIdByCharHandle(PLAYER_PED)
    name = sampGetPlayerNickname(id)
    local res = false
    for i,k in ipairs(personas_autorizadas) do
        if k == name:lower() then
            res = true
        end
    end
    if not res then
        sampAddChatMessage(string.format('%s{FFFFFF}, no te encuentras en la base de datos para poder acceder a la radio.', name), 0xFF00CCFF)
        return
    end
    IRC = irc.new{nick = name}
    IRC:connect("irc.esper.net")
    IRC:join("#sampfenixzone")
    connected = true
    IRC:hook("OnChat", IRCMessage)
    sampAddChatMessage(string.format('Hola {00CCFF}%s{FFFFFF}, te conectaste con exito a la radio.', name), 0xFFFFFFFF)
    sendWarning(string.format("{00CCFF}%s{FFFFFF} se conecto a la radio.", name))
end

function sendIRCMessage(params)
    if not connected then
        sampAddChatMessage('No estas conectado a la radio de la empresa.', 0xFFFFFFFF)
        return
    end
    --[[if not params then
        sampAddChatMessage('No estas conectado a la radio de la empresa.', 0xFFFFFFFF)
        return
    end]]
    local message = string.format("{0095ff}[Seguridad] {FFFFFF}%s: %s", name, u8(params))
    IRC:sendChat("#sampfenixzone", message)
    sampAddChatMessage(message, 0xFFFFFFFF)
end

function sendWarning(params)
    if not connected then return end
    IRC:sendChat("#sampfenixzone", u8(params))
end
function IRCMessage(user, channel, message)
    sampAddChatMessage(message, 0xFFFFFFFF)
end