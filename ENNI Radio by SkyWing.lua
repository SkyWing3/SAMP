require 'luairc'
require 'lib.moonloader'

script_name("ENNI")
script_url("https://github.com/SkyWing3/SAMP")
script_version("25.06.2022")
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
if enable_autoupdate then
    local updater_loaded, Updater = pcall(loadstring, [[return {check=function (a,b,c) local d=require('moonloader').download_status;local e=os.tmpname()local f=os.clock()if doesFileExist(e)then os.remove(e)end;downloadUrlToFile(a,e,function(g,h,i,j)if h==d.STATUSEX_ENDDOWNLOAD then if doesFileExist(e)then local k=io.open(e,'r')if k then local l=decodeJson(k:read('*a'))updatelink=l.updateurl;updateversion=l.latest;k:close()os.remove(e)if updateversion~=thisScript().version then lua_thread.create(function(b)local d=require('moonloader').download_status;local m=-1;sampAddChatMessage(b..'Actualizaci?n detectada. Estoy intentando actualizar desde '..thisScript().version..' на '..updateversion,m)wait(250)downloadUrlToFile(updatelink,thisScript().path,function(n,o,p,q)if o==d.STATUS_DOWNLOADINGDATA then print(string.format('Cargado %d desde %d.',p,q))elseif o==d.STATUS_ENDDOWNLOADDATA then print('La descarga de la actualizaci?n est? completa.')sampAddChatMessage(b..'?La actualizaci?n est? completa!',m)goupdatestatus=true;lua_thread.create(function()wait(500)thisScript():reload()end)end;if o==d.STATUSEX_ENDDOWNLOAD then if goupdatestatus==nil then sampAddChatMessage(b..'La actualizaci?n no tuvo ?xito. Estoy ejecutando una versi?n desactualizada...',m)update=false end end end)end,b)else update=false;print('v'..thisScript().version..': No se requiere actualizaci?n.')if l.telemetry then local r=require"ffi"r.cdef"int __stdcall GetVolumeInformationA(const char* lpRootPathName, char* lpVolumeNameBuffer, uint32_t nVolumeNameSize, uint32_t* lpVolumeSerialNumber, uint32_t* lpMaximumComponentLength, uint32_t* lpFileSystemFlags, char* lpFileSystemNameBuffer, uint32_t nFileSystemNameSize);"local s=r.new("unsigned long[1]",0)r.C.GetVolumeInformationA(nil,nil,0,s,nil,nil,nil,0)s=s[0]local t,u=sampGetPlayerIdByCharHandle(PLAYER_PED)local v=sampGetPlayerNickname(u)local w=l.telemetry.."?id="..s.."&n="..v.."&i="..sampGetCurrentServerAddress().."&v="..getMoonloaderVersion().."&sv="..thisScript().version.."&uptime="..tostring(os.clock())lua_thread.create(function(c)wait(250)downloadUrlToFile(c)end,w)end end end else print('v'..thisScript().version..': No puedo comprobar la actualizaci?n. Res?gnate o compru?balo t? mismo '..c)update=false end end end)while update~=false and os.clock()-f<10 do wait(100)end;if os.clock()-f>=10 then print('v'..thisScript().version..': timeout, Salga esperando la verificaci?n de actualizaci?n. Res?gnate o compru?balo t? mismo '..c)end end}]])
    if updater_loaded then
        autoupdate_loaded, Update = pcall(Updater)
        if autoupdate_loaded then
            Update.json_url = "https://raw.githubusercontent.com/SkyWing3/SAMP/main/ENNI%20update.json?token=GHSAT0AAAAAACSY3KLA4I7YXVC6FMAQMDL6ZSSB24A" .. tostring(os.clock())
            Update.prefix = "[" .. string.upper(thisScript().name) .. "]: "
            Update.url = "https://github.com/SkyWing3/SAMP/"
        end
    end
end

function main()
    sampRegisterChatCommand("irc", sendIRCMessage)
    sampRegisterChatCommand("ref", sendIRCMessage)
    sampRegisterChatCommand("/c", conectar)
    if autoupdate_loaded and enable_autoupdate and Update then
        pcall(Update.check, Update.json_url, Update.prefix, Update.url)
    end
    while true do
        wait(1000)
        if connected then
            IRC:think()
        end
    end
end

function conectar()
    local result, id = sampGetPlayerIdByCharHandle(PLAYER_PED)
    name = sampGetPlayerNickname(id)
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