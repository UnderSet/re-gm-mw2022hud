--include("TFAKeys.lua") -- include() fuck you why wont you work

local MWIIHUD = {}
MWIIHUD.WepData = {}
MWIIHUD.Colors = {} -- trust me when I say we fill these later
local scrw, scrh = 0, 0
local scale = 1
local ply
local wep

MWIIHUD.DebugReference = CreateClientConVar("MWIIHUD_Debug_DrawReference", 0, false, false, "debug: draw reference image, gives no shit about main toggle", 0, 3)
MWIIHUD.DebugOffsets = CreateClientConVar("MWIIHUD_Debug_PrintOffsets", 0, false, false, "debug: print all weapon icon offsets", 0, 1)
MWIIHUD.Toggle = CreateClientConVar("MWIIHUD_Enable", 1, true, false, "Enables the HUD.", 0, 1)

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
MWIIHUD.Assets.Reference = {{Material("mwii/reference/reference1.png", "noclamp smooth")}, {Material("mwii/reference/reference2.png", "noclamp smooth")}, {Material("mwii/reference/reference3.png", "noclamp smooth")}} -- dont blame me for le double

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
        size = 160 * scale,
        weight = 240
    })
    surface.CreateFont( "MWIIAmmoText", {
        font = "Stratum2 BETA Medium", -- Use the font-name which is shown to you by your operating system Font Viewer.
        size = 50 * scale,
        weight = 60,
        shadow = true,
    } )
    surface.CreateFont( "MWIIAmmoSubText", {
        font = "Stratum2 BETA Medium", -- Use the font-name which is shown to you by your operating system Font Viewer.
        size = 25 * scale,
        weight = 60,
        shadow = true,
    } )
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

function MWIIHUD.MainHook()
    ply = LocalPlayer()

    if MWIIHUD.Toggle:GetBool() and GetConVar("cl_drawhud"):GetBool() then
        local dev = GetConVar("developer"):GetBool()
        if dev and MWIIHUD.DebugReference:GetBool() then
            surface.SetMaterial(MWIIHUD.Assets.Reference[MWIIHUD.DebugReference:GetInt()][1])
            surface.SetDrawColor(255,255,255,180)
            surface.DrawTexturedRect(0,0,scrw,scrh)
            surface.DrawRect(100,100,100,100)
        end

        MWIIHUD.WeaponData()
        --MWIIHUD.Vitals()
        --MWIIHUD.Compass()
        MWIIHUD.Ammo()
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
    surface.SetDrawColor(color_white)
    surface.DrawRect(scrw - 150 * scale, scrh - 125 * scale, 2 * scale, 49 * scale)
    if MWIIHUD.WepData.Mag1Max != -1 then
        draw.DrawText(MWIIHUD.WepData.Mag1, "MWIIAmmoText", scrw - 160 * scale, scrh - 132 * scale, color_white, TEXT_ALIGN_RIGHT)
        draw.DrawText(MWIIHUD.WepData.Ammo1, "MWIIAmmoSubText", scrw - 160 * scale, scrh - 91 * scale, color_white, TEXT_ALIGN_RIGHT)
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

hook.Add("HUDShouldDraw", "MWIIHideCHud", function(name)
    if MWIIHUD.Toggle:GetBool() and MWIIHUD.HideCElements[name] and GetConVar("cl_drawhud"):GetBool() then return false end
end)
hook.Add("HUDPaint", "MWIIHUDDraw", MWIIHUD.MainHook)
hook.Add("OnScreenSizeChanged", "MWIIHUDResChange", MWIIHUD.NeededStuff)

concommand.Add("MWII_SetIconOffsetForWeapon", function(ply, cmd, args)
    PrintTable(args)
    local x, y, scl = args
    MWIIHUD.WeaponIconOffset[LocalPlayer():GetActiveWeapon():GetClass()] = x, y, scl
    local state = file.Write("mwiiweaponiconoffsets.txt", util.Compress(util.TableToJSON(MWIIHUD.WeaponIconOffset)))
    print(state and "Weapon icon offset data written to disk." or "oh fuck")
end)

print("MWII HUD loaded." .. SysTime())
PrintTable(MWIIHUD.Assets.Reference)