--include("TFAKeys.lua") -- include() is my final boss

local MWIIHUD = {}
MWIIHUD.WepData = {}
MWIIHUD.Colors = {} -- trust me when I say we fill these later
local scrw, scrh = 0, 0
local scale = 1
local ply
local wep

MWIIHUD.DebugReference = CreateClientConVar("MWIIHUD_Debug_DrawReference", 0, false, false, "debug: draw reference image, gives no shit about main toggle", 0, 4)
MWIIHUD.DebugOffsets = CreateClientConVar("MWIIHUD_Debug_PrintOffsets", 0, false, false, "debug: print all weapon icon offsets", 0, 1)
MWIIHUD.DebugCaptionParsing = CreateClientConVar("MWIIHUD_Debug_CaptionDebugText", 0, false, false, "debug: use debug string for captions instead of actual caption content", 0, 1)
MWIIHUD.Toggle = CreateClientConVar("MWIIHUD_Enable", 1, true, false, "Enables the HUD.", 0, 1)
MWIIHUD.ToggleCaptions = CreateClientConVar("MWIIHUD_EnableCaptions", 0, true, false, "Enables the custom captions implementation this HUD has.")

MWIIHUD.HideCElements = {
    ["CHudHealth"] = true,
    ["CHudBattery"] = true,
    ["CHudSuitPower"] = true,
    ["CHudAmmo"] = true,
    ["CHudSecondaryAmmo"] = true
}

MWIIHUD.HL2WeaponIconChara = { -- Stock HL2 gun icons use a FONT.
    weapon_357 = 'e',
    weapon_ar2 = 'l',
    weapon_bugbait = 'j',
    weapon_crossbow = 'g',
    weapon_crowbar = 'c',
    weapon_frag = 'k',
    weapon_physcannon = 'm',
    weapon_physgun = 'm',
    weapon_pistol = 'd',
    weapon_rpg = 'i',
    weapon_shotgun = 'b',
    weapon_slam = 'o',
    weapon_smg1 = 'a',
    weapon_stunstick = 'n',
}

MWIIHUD.WeaponIconOffset = {}

MWIIHUD.IconColorCorrectParam = {
	[ "$pp_colour_addr" ] = 0,
	[ "$pp_colour_addg" ] = 0,
	[ "$pp_colour_addb" ] = 0,
	[ "$pp_colour_brightness" ] = 0.2,
	[ "$pp_colour_contrast" ] = 1.1,
	[ "$pp_colour_colour" ] = 0,
	[ "$pp_colour_mulr" ] = 0,
	[ "$pp_colour_mulg" ] = 0,
	[ "$pp_colour_mulb" ] = 0
}

MWIIHUD.Assets = {}
MWIIHUD.Assets.Reference = {{Material("mwii/reference/reference1.png", "noclamp smooth")}, {Material("mwii/reference/reference2.png", "noclamp smooth")}, {Material("mwii/reference/reference3.png", "noclamp smooth")}, {Material("mwii/reference/reference4.png", "noclamp smooth")}} -- there *has* to be a better fucking way

MWIIHUD.Colors.Preset = {}
MWIIHUD.Colors.Preset.OrangeRed = Color(190,80,42,255)
MWIIHUD.Colors.Preset.Yellow = Color(237,201,16,255)
MWIIHUD.Colors.Preset.Gray = Color(154,163,154,255)

MWIIHUD.CaptionCache = {} -- trust me this is a good idea (watch future me regret this lmao)

function MWIIHUD.NeededStuff()
    -- runs on start and every time res is changed
    scrw, scrh = ScrW(), ScrH()
    scale = scrh / 1080

    -- render target sizes MUST be power of 2 because dx9 or sum shit
    MWIIHUD.WeaponIconRT = GetRenderTarget("MWIIWeaponIcon", 1024 * math.Round(scale), 512 * math.Round(scale))
    MWIIHUD.WeaponIconRTMat = CreateMaterial( 
        "MWIIWeaponIconMat","UnlitGeneric",
        {
            ["$basetexture"] = MWIIHUD.WeaponIconRT:GetName(),
            ["$translucent"] = "1"
        } 
    )
    if file.Exists("mwiiweaponiconoffsets.txt", "DATA") then
        MWIIHUD.WeaponIconOffset = util.JSONToTable(util.Decompress(file.Read("mwiiweaponiconoffsets.txt", "DATA")))
        print("Loaded weapon icon offset data.")
    else
        print("No stored weapon icon offset data found.")
    end

    surface.CreateFont("hl2wepicon", {
        font = 'halflife2',
        size = 160 * math.Round(scale), -- figure this shit out eventually
        weight = 240
    })
    surface.CreateFont( "MWIIAmmoText", {
        font = "Stratum2 BETA Medium", -- Use the font-name which is shown to you by your operating system Font Viewer.
        size = 50 * scale,
        weight = 60,
        shadow = true,
    })
    surface.CreateFont( "MWIIAmmoSubText", {
        font = "Stratum2 BETA Medium", -- Use the font-name which is shown to you by your operating system Font Viewer.
        size = 25 * scale,
        weight = 60,
        shadow = true,
    })
    surface.CreateFont( "MWIISubText", {
        font = "Stratum2 BETA Medium", -- Use the font-name which is shown to you by your operating system Font Viewer.
        size = 28 * scale,
        weight = 60,
        shadow = true,
    })
end

MWIIHUD.NeededStuff()

local function doNothing() end

function MWIIHUD.DrawWeaponIconToRT(Weapon, x, y, width, h)
    local scale = math.Round(scale)
    local class = Weapon:GetClass()
    if MWIIHUD.WeaponIconOffset[class] then
        local scalemod = MWIIHUD.WeaponIconOffset[class][3]
        x = x + MWIIHUD.WeaponIconOffset[class][1] * scale + (width / 2 * (1 - scalemod))
        y = y - MWIIHUD.WeaponIconOffset[class][2] * scale + (h / 2 * (1 - scalemod))
        width = width * scalemod
        h = h * scalemod
    end

    if GetConVar("developer"):GetBool() and MWIIHUD.DebugOffsets:GetBool() then 
        PrintTable(MWIIHUD.WeaponIconOffset) 
        print(" ")
    end

    render.PushRenderTarget(MWIIHUD.WeaponIconRT)
    cam.Start2D()
    render.Clear(0,0,0,0,true,true)
    if Weapon.DrawWeaponSelection then
        local oldDrawInfo = Weapon.PrintWeaponInfo
        Weapon.PrintWeaponInfo = doNothing
        Weapon:DrawWeaponSelection(x, y, width, h, 255)
        Weapon.PrintWeaponInfo = oldDrawInfo
    else
        local iconChar = MWIIHUD.HL2WeaponIconChara[Weapon:GetClass()]
        if iconChar then
            draw.SimpleText(iconChar,"hl2wepicon",x + width / 2,y + h / 2,headerTextColor,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
        end
    end
    DrawColorModify(MWIIHUD.IconColorCorrectParam)
    cam.End2D()
    render.PopRenderTarget()
end

function MWIIHUD.ParseCaption(soundscript, duration, fromplayer, text)
    -- beware: might induce sleep loss and insanity
    local outtable = {}
    local counter = 0
    local color = color_white
    
    if (text != nil and !string.match(text, "*pain!%*")) and MWIIHUD.ToggleCaptions:GetBool() then
        local debugtext = "<clr:128,255,127>HELLO THERE<clr:126,217,255>COLOR SWITCH<clr:255,255,255>really stupid long line why am I trying to fabricate a stupid long line what the hell is wrong with me why do I need such a long line, why do I still need a much longer line what is wrong with glua today"
        if GetConVar("developer"):GetBool() and MWIIHUD.DebugCaptionParsing:GetBool() then text = debugtext end

        if !string.match(text, "<.->") then
            outtable[1] = {text, color}
        else
            actualtext = string.Explode("<", text, false)
            --PrintTable(actualtext)
            for i=1,#actualtext do
                if string.StartsWith(actualtext[i], "clr:") then
                    local colorstr = string.Explode(">",string.Replace(actualtext[i], "clr:", ""))[1]
                    local outtext = string.Replace(actualtext[i], "clr:"..colorstr..">", "")
                    color = string.Explode(",", colorstr, false)
                    color = Color(color[1], color[2], color[3], 255) -- this is stupid

                    outtable[i] = {outtext, color}
                elseif string.StartsWith(actualtext[i], "sfx>") then return
                else
                    local outtext = string.Explode(">", actualtext[i], false)[2]
                    outtable[i] = {outtext, color}
                end
            end
        end

        for i = #outtable, 1, -1 do
            if outtable[i][1] == "" or !outtable[i][1] then
                table.remove(outtable, i)
            end
        end

        MWIIHUD.CaptionCache[#MWIIHUD.CaptionCache + 1] = {outtable, CurTime() + duration}
    end
end

function MWIIHUD.MainHook()
    ply = LocalPlayer()

    local dev = GetConVar("developer"):GetBool()
    if dev and MWIIHUD.DebugReference:GetBool() then
        surface.SetMaterial(MWIIHUD.Assets.Reference[MWIIHUD.DebugReference:GetInt()][1])
        surface.SetDrawColor(255,255,255,180)
        surface.DrawTexturedRect(0,0,scrw,scrh)
        surface.DrawRect(100,100,100,100)
    end

    if MWIIHUD.Toggle:GetBool() and GetConVar("cl_drawhud"):GetBool() then
        MWIIHUD.WeaponData()
        --MWIIHUD.Vitals()
        --MWIIHUD.Compass()
        MWIIHUD.Ammo()

        MWIIHUD.Captions()
    end
end

function MWIIHUD.WeaponData()
    wep = ply:GetActiveWeapon()

    if !IsValid(wep) then return end

    MWIIHUD.WepData.Mag1 = wep:Clip1()
    MWIIHUD.WepData.Mag1Max = wep:GetMaxClip1()
    MWIIHUD.WepData.Mag2 = wep:Clip2()
    MWIIHUD.WepData.Mag2Max = wep:GetMaxClip2()
    MWIIHUD.WepData.Ammo1 = ply:GetAmmoCount(wep:GetPrimaryAmmoType())
    MWIIHUD.WepData.Ammo2 = ply:GetAmmoCount(wep:GetSecondaryAmmoType())
end

function MWIIHUD.Ammo()
    if !IsValid(wep) then return end
    draw.NoTexture()
    surface.SetDrawColor(MWIIHUD.Colors.Preset.Gray)
    surface.DrawRect(scrw - 150 * scale, scrh - 125 * scale, 2 * scale, 49 * scale)
    if MWIIHUD.WepData.Mag1Max != -1 then
        draw.DrawText(MWIIHUD.WepData.Mag1, "MWIIAmmoText", scrw - 160 * scale, scrh - 132 * scale, (MWIIHUD.WepData.Mag1 < MWIIHUD.WepData.Mag1Max / 3) and MWIIHUD.Colors.Preset.OrangeRed or color_white, TEXT_ALIGN_RIGHT)
        draw.DrawText(MWIIHUD.WepData.Ammo1, "MWIIAmmoSubText", scrw - 160 * scale, scrh - 91 * scale, MWIIHUD.WepData.Ammo1 == 0 and MWIIHUD.Colors.Preset.OrangeRed or MWIIHUD.Colors.Preset.Gray, TEXT_ALIGN_RIGHT)

        if MWIIHUD.WepData.Mag1 == 0 and MWIIHUD.WepData.Ammo1 == 0 then
            draw.DrawText("NO AMMO","MWIISubText",scrw * 0.5,scrh - 463 * scale,MWIIHUD.Colors.Preset.OrangeRed,TEXT_ALIGN_CENTER)
        elseif MWIIHUD.WepData.Mag1 < MWIIHUD.WepData.Mag1Max / 3 and MWIIHUD.WepData.Ammo1 == 0 then
            draw.DrawText("LOW AMMO","MWIISubText",scrw * 0.5,scrh - 463 * scale,MWIIHUD.Colors.Preset.Yellow,TEXT_ALIGN_CENTER)
        end
    end

    MWIIHUD.DrawWeaponIconToRT(wep,0, 0,1024 * math.Round(scale),512 * math.Round(scale))
    surface.SetMaterial(MWIIHUD.WeaponIconRTMat)
    surface.SetDrawColor(color_white)
    surface.DrawTexturedRect(scrw - 550 * scale,scrh - 190 * scale,360 * scale, 180 * scale)
    if GetConVar("developer"):GetBool() then
        surface.SetDrawColor(color_white)
        surface.DrawOutlinedRect(scrw - 550 * scale,scrh - 190 * scale,360 * scale, 180 * scale)
        surface.SetDrawColor(0,255,0,255)
        surface.DrawOutlinedRect(scrw - 550 * scale,scrh - 160 * scale,360 * scale, 120 * scale)
    end
end


function MWIIHUD.Captions()
    surface.SetFont("MWIISubText")
    local h = select(2, surface.GetTextSize("TESTING"))
    if MWIIHUD.ToggleCaptions:GetBool() then
        local linecount = 0
        for i=1,#MWIIHUD.CaptionCache do
            if #MWIIHUD.CaptionCache[i][1] == 1 then
                local drawtxt = ""
                local drawtbl = {}
                local texttbl = string.Explode(" ", MWIIHUD.CaptionCache[i][1][1][1], false)

                for f=1,#texttbl do
                    if surface.GetTextSize(drawtxt .. " " .. texttbl[f]) < scrw * 0.6 then
                        drawtxt = drawtxt .. " " .. texttbl[f]
                        if f == #texttbl then
                            drawtbl[#drawtbl + 1] = drawtxt
                        end
                    else
                        drawtbl[#drawtbl + 1] = drawtxt
                        drawtxt = texttbl[f]
                    end
                end

                drawtxt = ""
                for f=1,#drawtbl do
                    drawtxt = drawtxt .. drawtbl[f] .. "\n"
                end
                draw.DrawText(drawtxt, "MWIISubText", scrw * 0.5, scrh * 0.7 + h * (i - 1), MWIIHUD.CaptionCache[i][1][1][2] or color_white, TEXT_ALIGN_CENTER)
                linecount = linecount + 1
            else
                local drawtbl = {}
                drawtbl[1] = {} -- thanks lua
                local drawtbli = 1
                for e=1,#MWIIHUD.CaptionCache[i][1] do
                    surface.SetFont("MWIISubText")
                    local texttbl = string.Explode(" ", MWIIHUD.CaptionCache[i][1][e][1], false)
                    local teststring = ""

                    -- surface.GetTextSize() isn't cooperating with select() here so wasted memory :sadge:
                    for f=1,#texttbl do
                        if surface.GetTextSize(teststring .. " " .. texttbl[f]) < scrw * 0.6 then
                            teststring = teststring .. " " .. texttbl[f]
                            if f == #texttbl then
                                drawtbl[drawtbli][#drawtbl[drawtbli] + 1] = {teststring, MWIIHUD.CaptionCache[i][1][e][2], surface.GetTextSize(teststring)}    
                            end
                        else
                            drawtbl[drawtbli][#drawtbl[drawtbli] + 1] = {teststring, MWIIHUD.CaptionCache[i][1][e][2], surface.GetTextSize(teststring)}
                            teststring = texttbl[f]
                            drawtbl[#drawtbl + 1] = {}
                            drawtbli = #drawtbl
                        end
                    end
                end

                for i=1,#drawtbl do
                    local linelen = 0
                    for e=1,#drawtbl[i] do
                        linelen = linelen + drawtbl[i][e][3]
                    end
                    surface.SetTextPos(scrw * 0.5 - linelen * 0.5, scrh * 0.7 + h * linecount)
                    for e=1,#drawtbl[i] do
                        surface.SetTextColor(drawtbl[i][e][2].r,drawtbl[i][e][2].g,drawtbl[i][e][2].b,255)
                        surface.DrawText(drawtbl[i][e][1])
                    end
                    linecount = linecount + 1
                end

            end
        end

        for i = #MWIIHUD.CaptionCache, 1, -1 do
            if MWIIHUD.CaptionCache[i][2] < CurTime() then table.remove(MWIIHUD.CaptionCache, i) end
        end
    end
end

hook.Add("OnCloseCaptionEmit", "MWIIGrabCaption", MWIIHUD.ParseCaption)
hook.Add("HUDShouldDraw", "MWIIHideCHud", function(name)
    if MWIIHUD.Toggle:GetBool() and MWIIHUD.ToggleCaptions:GetBool() and GetConVar("cl_drawhud"):GetBool() and name == "CHudCloseCaption" then return false
    elseif MWIIHUD.Toggle:GetBool() and MWIIHUD.HideCElements[name] and GetConVar("cl_drawhud"):GetBool() then return false end
end)
hook.Add("HUDPaint", "MWIIHUDDraw", MWIIHUD.MainHook)
hook.Add("OnScreenSizeChanged", "MWIIHUDResChange", MWIIHUD.NeededStuff)

concommand.Add("MWII_SetIconOffsetForWeapon", function(ply, cmd, args)
    --PrintTable(args)
    local x, y, scl = args
    MWIIHUD.WeaponIconOffset[LocalPlayer():GetActiveWeapon():GetClass()] = x, y, scl
    local state = file.Write("mwiiweaponiconoffsets.txt", util.Compress(util.TableToJSON(MWIIHUD.WeaponIconOffset)))
    print(state and "Weapon icon offset data written to disk." or "oh fuck")
end)

print("MWII HUD loaded. " .. SysTime())