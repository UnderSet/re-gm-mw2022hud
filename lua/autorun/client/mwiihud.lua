--include("TFAKeys.lua") -- include() on clientside from autorun/client is my final boss

MWIIHUD = {}
MWIIHUD.WepData = {}
MWIIHUD.Colors = {} -- trust me when I say we fill these later
local scrw, scrh = 0, 0
local scale = 1
local ply
local wep
local lastframewep
local lastubstate
local firetype, firemode, inubwep, safe = 0, "", false, false
local framerate = 0

MWIIHUD.DebugReference = CreateClientConVar("MWIIHUD_Debug_DrawReference", 0, false, false, "debug: draw reference image, gives no shit about main toggle", 0, 4)
MWIIHUD.DebugOffsets = CreateClientConVar("MWIIHUD_Debug_PrintOffsets", 0, false, false, "debug: print all weapon icon offsets", 0, 1)
MWIIHUD.DebugCaptionParsing = CreateClientConVar("MWIIHUD_Debug_CaptionDebugText", 0, false, false, "debug: use debug string for captions instead of actual caption content", 0, 1)
MWIIHUD.Toggle = CreateClientConVar("MWIIHUD_Enable", 1, true, false, "Enables the HUD.", 0, 1)
MWIIHUD.ToggleCaptions = CreateClientConVar("MWIIHUD_EnableCaptions", 0, true, false, "Enables the custom captions implementation this HUD has.")
MWIIHUD.ToggleCaptionAesthetics = CreateClientConVar("MWIIHUD_EnableCaptionAestheticEdits", 0, true, false, "Allows extra formatting captions during parsing to look nicer. (only affects stuff like e.g replacing double spaces with single spaces)", 0, 1)
MWIIHUD.ToggleArmorOnly = CreateClientConVar("MWIIHUD_EnableArmorOnly", 1, true, false, "Only displays armor bar on the health & armor element if enabled.", 0, 1)
MWIIHUD.CaptionsShowSFX = CreateClientConVar("MWIIHUD_EnableCaptionsSFX", 0, true, false, "Show SFX on captions. Looks really ugly, keep this off most of the time please.")

MWIIHUD.MWBaseFiretypes = {
    ["AUTOMATIC"] = 4, 
	["FULL AUTO"] = 4,
	["SEMI AUTO"] = 1,
	["SEMI AUTOMATIC"] = 1,
	["3RND BURST"] = 3
}

MWIIHUD.HideCElements = {
    ["CHudHealth"] = true,
    ["CHudBattery"] = true,
    ["CHudSuitPower"] = true,
    ["CHudAmmo"] = true,
    ["CHudSecondaryAmmo"] = true,
    ["CHudCloseCaption"] = true
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

MWIIHUD.DefaultAutomatics = {
    ["weapon_smg1"] = true,
	["weapon_ar2"] = true,
	["weapon_mp5_hl1"] = true,
	["weapon_gauss"] = true,
	["weapon_egon"] = true
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
MWIIHUD.Assets.Reference = {{Material("mwii/reference/reference1.png", "noclamp smooth")}, {Material("mwii/reference/reference2.png", "noclamp smooth")},
    {Material("mwii/reference/reference3.png", "noclamp smooth")}, {Material("mwii/reference/reference4.png", "noclamp smooth")}} -- there *has* to be a better fucking way
MWIIHUD.Assets.Firemodes = { -- lua tables start on 1 lmao
    [0] = {Material("mwii/assets/firemodes/safe.png", "noclamp smooth")},
    [1] = {Material("mwii/assets/firemodes/single.png", "noclamp smooth")},
    [2] = {Material("mwii/assets/firemodes/burst2.png", "noclamp smooth")},
    [3] = {Material("mwii/assets/firemodes/burst3.png", "noclamp smooth")},
    [4] = {Material("mwii/assets/firemodes/auto.png", "noclamp smooth")} -- surely nobody uses a 4-burst firemode?
}
MWIIHUD.Assets.ArmorPlate = Material("mwii/assets/armorplate.png", "noclamp smooth")
MWIIHUD.Assets.Gradients = {{Material("gui/gradient_up")}, {Material("gui/center_gradient")}}

MWIIHUD.Colors.Preset = {}
MWIIHUD.Colors.Preset.OrangeRed = Color(190,80,42,255)
MWIIHUD.Colors.Preset.Yellow = Color(237,201,16,255)
MWIIHUD.Colors.Preset.Gray = Color(154,163,154,255)

MWIIHUD.Colors.WeaponName = Color(255,255,255,255)
MWIIHUD.Colors.AmmoName = Color(144,144,144)

MWIIHUD.Colors.CompassColor = Color(255,255,255,255) -- color = color_white breaks loads of shit lmfao

MWIIHUD.CaptionCache = {} -- trust me this is a good idea (watch future me regret this lmao)

MWIIHUD.Times = {} -- stores time variables ok
MWIIHUD.Times.WepChangeTimeOut = 0
MWIIHUD.Times.AmmoTypeFade = 0
MWIIHUD.Times.FRCacheTime = 0

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
        size = 120 * scale, -- figure this shit out eventually
        weight = 240
    })
    surface.CreateFont( "MWIIAmmoText", {
        font = "Stratum2 BETA Medium",
        size = 50 * scale,
        weight = 60,
        shadow = true,
    })
    surface.CreateFont( "MWIIFrameText", {
        font = "Stratum2 BETA Medium",
        size = 44 * scale,
        weight = 32,
        shadow = true,
    })
    surface.CreateFont( "MWIIAmmoSubText", {
        font = "Stratum2 BETA Medium",
        size = 25 * scale,
        weight = 60,
        shadow = true,
    })
    surface.CreateFont( "MWIISubText", {
        font = "Stratum2 BETA Medium",
        size = 28 * scale,
        weight = 60,
        shadow = true,
    })
    surface.CreateFont( "MWIICompassText", {
        font = "Stratum2 BETA Medium",
        size = 24 * scale,
        weight = 60,
        shadow = true,
    })
    surface.CreateFont( "MWIICompassSubText", {
        font = "Stratum2 BETA Medium",
        size = 18 * scale,
        weight = 60,
        shadow = true,
    })
    surface.CreateFont( "MWIINickText", {
        font = "Roboto",
        size = 20 * scale,
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
    
    if text != nil and MWIIHUD.ToggleCaptions:GetBool() then
        if MWIIHUD.ToggleCaptionAesthetics:GetBool() then
            text = string.Replace(text, "  ", " ")
            text = string.Replace(text, "---", "—")
            text = string.Replace(text, "--", "—")
        end
        local debugtext = "<clr:128,255,127>HELLO THERE<clr:126,217,255>COLOR SWITCH<clr:255,255,255>really stupid long line why am I trying to fabricate a stupid long line what the hell is wrong with me why do I need such a long line, why do I still need a much longer line what is wrong with glua today"
        if GetConVar("developer"):GetBool() and MWIIHUD.DebugCaptionParsing:GetBool() then text = debugtext end

        if !string.match(text, "<.->") then
            outtable[1] = {text, color}
        else
            actualtext = string.Explode("<", text, false)
            --PrintTable(actualtext)
            for i=1,#actualtext do
                if string.StartsWith(actualtext[i], "cr>") then
                    outtable[i] = {"<"..actualtext[i], color} -- handle carriage returns in rendering code
                elseif string.StartsWith(actualtext[i], "clr:") then
                    local colorstr = string.Explode(">",string.Replace(actualtext[i], "clr:", ""))[1]
                    local outtext = string.Replace(actualtext[i], "clr:"..colorstr..">", "")
                    color = string.Explode(",", colorstr, false)
                    color = Color(color[1], color[2], color[3], 255) -- this is stupid

                    outtable[i] = {outtext, color}
                elseif string.StartsWith(actualtext[i], "sfx>") and !MWIIHUD.CaptionsShowSFX:GetBool() then
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

        for i = #MWIIHUD.CaptionCache, 1, -1 do
            for e=1,#MWIIHUD.CaptionCache[i][1] do
                MWIIHUD.CaptionCache[i][1][e][1] = string.Trim(MWIIHUD.CaptionCache[i][1][e][1])
            end
        end
    end
end

function MWIIHUD.GetFiremode(Weapon, SeparateAltfire)
    -- fuck this code I don't wanna touch any of this
	if Weapon.ARC9 then
		local arc9_mode = Weapon:GetCurrentFiremodeTable()
        local altmode, altstate = Weapon:GetProcessedValue("UBGLFiremodeName"), false
		
		if Weapon:GetUBGL() then
            if SeparateAltfire then
                altstate = true
            else
                return Weapon:GetCurrentFiremode(), Weapon:GetProcessedValue("UBGLFiremodeName"), true, false
            end
		end

        local FiremodeText = ""
        if arc9_mode.PrintName then
            FiremodeText = arc9_mode.PrintName
        else
		    if arc9_mode.Mode == 1 then
		    	FiremodeText = "Single"
		    elseif arc9_mode.Mode == 0 then
		    	FiremodeText = "Safety"
		    elseif arc9_mode.Mode < 0 then
		    	FiremodeText = "Full Auto"
		    elseif arc9_mode.Mode > 1 then
		    	FiremodeText = tostring(arc9_mode.Mode) .. "-Burst"
		    end
        end

        -- I do not have assets for bursts > 3
        if SeparateAltfire then
            return arc9_mode.Mode >= 4 and 3 or arc9_mode.Mode >= 0 and arc9_mode.Mode or 4, FiremodeText, altstate, Weapon:GetSafe(), altmode
        else
            return arc9_mode.Mode >= 4 and 3 or arc9_mode.Mode >= 0 and arc9_mode.Mode or 4, FiremodeText, altstate, Weapon:GetSafe()
        end
	elseif Weapon.ArcCW then
		local arccw_mode = Weapon:GetCurrentFiremode()

        local FiremodeText = ""
		local AltFiremodeText = Weapon:GetBuff_Override("UBGL_PrintName") and Weapon:GetBuff_Override("UBGL_PrintName") or ArcCW.GetTranslation("fcg.ubgl")
		
        local AltfireState = false

		if Weapon:GetInUBGL() then
			AltfireState = true
        end
        if arccw_mode.PrintName then
            FiremodeText = ArcCW.GetPhraseFromString(arccw_mode.PrintName) and ArcCW.GetTranslation(phrase) or ArcCW.TryTranslation(arccw_mode.PrintName)
        else
            if arccw_mode.Mode == 0 then FiremodeText = "Safety"
            elseif arccw_mode.Mode == 1 then FiremodeText = "Single"
            elseif arccw_mode.Mode >= 2 then FiremodeText = "Full Auto"
            elseif arccw_mode.Mode < 0 then FiremodeText = tostring(-arccw_mode.Mode) .. "-Burst"
            end
        end

        if string.match(FiremodeText, "-ROUND BURST") then
            string.Replace(FiremodeText, "-ROUND BURST", "-BURST")
        end

        return arccw_mode.Mode >= 2 and 4 or arccw_mode.Mode >= 0 and arccw_mode.Mode or 3, FiremodeText, AltfireState, arccw_mode.Mode == 0 and true or false, AltFiremodeText
	elseif weapons.IsBasedOn(Weapon:GetClass(), "mg_base") then -- biggest oversight in my life here
		local FiremodeText = string.upper(Weapon.Firemodes[Weapon:GetFiremode()].Name)

        if !Weapon:HasFlag("Lowered") then
            return MWIIHUD.MWBaseFiretypes[FiremodeText], FiremodeText, false, false, "Altfire"
        else
            return 0, "Lowered", false, true, "Altfire"
		end
	--[[elseif istfabase then -- unsupported for now
		FiremodeText = Weapon:GetFireModeName()
		for k,v in pairs(TFAFiremodes) do
			if k == FiremodeText then
				FiremodeText = v
			end
		end]]
	elseif Weapon:IsScripted() then
		if !Weapon.Primary.Automatic then
            return 1, "Semi-Auto", false, false, "Altfire"
		elseif Weapon.ThreeRoundBurst then
            return 3, "3-Burst", false, false, "Altfire"
		elseif Weapon.TwoRoundBurst then
            return 2, "2-Burst", false, false, "Altfire"
		elseif Weapon.GetSafe then
			if Weapon:GetSafe() then
                return 0, "Safety", true, false, "Altfire"
            else
                return 1, "[Unreadable]", false, false, "Altfire"
			end
		elseif isfunction(Weapon.Safe) then
			if Weapon:Safe() then
                return 0, "Safety", true, false, "Altfire"
            else
                return 1, "[Unreadable]", false, false, "Altfire"
			end
		elseif isfunction(Weapon.Safety) then
			if Weapon:Safety() then
                return 0, "Safety", true, false, "Altfire"
            else
                return 1, "[Unreadable]", false, false, "Altfire"
			end
        else
            return 4, "Full Auto", false, false, "Altfire"
		end
	elseif !MWIIHUD.DefaultAutomatics[Weapon:GetClass()] then
		return 1, "Semi-Auto", false, false, "Altfire"
    else
        return 4, "Full Auto", false, false, "Altfire"
	end
end


-- real shit begins here

function MWIIHUD.MainHook()
    ply = LocalPlayer()
    local starttime = SysTime()

    local dev = GetConVar("developer"):GetBool()
    if dev and MWIIHUD.DebugReference:GetBool() then
        surface.SetMaterial(MWIIHUD.Assets.Reference[MWIIHUD.DebugReference:GetInt()][1])
        surface.SetDrawColor(255,255,255,180)
        surface.DrawTexturedRect(0,0,scrw,scrh)
        surface.DrawRect(100,100,100,100)
    end

    -- replica of funny dev feature in the CoD games
    if dev then
        if MWIIHUD.Times.FRCacheTime < CurTime() then
            framerate = math.floor(1 / RealFrameTime())
            MWIIHUD.Times.FRCacheTime = CurTime() + (1 / 24)
        end
        draw.DrawText(framerate, "MWIIFrameText", scrw - 12 * scale, 3 * scale,
            MWIIHUD.Colors.Preset.Yellow, TEXT_ALIGN_RIGHT)
    end

    if MWIIHUD.Toggle:GetBool() and GetConVar("cl_drawhud"):GetBool() then
        MWIIHUD.WeaponData()
        MWIIHUD.Vitals()
        MWIIHUD.Compass()
        MWIIHUD.Ammo()

        MWIIHUD.Captions()
    end
end

function MWIIHUD.WeaponData()
    lastframewep = wep
    wep = ply:GetActiveWeapon()

    if !IsValid(wep) then return end

    MWIIHUD.WepData.Class = wep:GetClass()
    MWIIHUD.WepData.PrintName = wep:GetPrintName()
    MWIIHUD.WepData.Mag1 = math.max(0, wep:Clip1())
    MWIIHUD.WepData.Mag1Max = wep:GetMaxClip1()
    MWIIHUD.WepData.Mag2 = math.max(0, wep:Clip2())
    MWIIHUD.WepData.Mag2Max = wep:GetMaxClip2()
    MWIIHUD.WepData.Ammo1 = math.max(0, ply:GetAmmoCount(wep:GetPrimaryAmmoType()))
    MWIIHUD.WepData.Ammo2 = math.max(0, ply:GetAmmoCount(wep:GetSecondaryAmmoType()))
    MWIIHUD.WepData.AmmoType1 = wep:GetPrimaryAmmoType()
    MWIIHUD.WepData.AmmoType2 = wep:GetSecondaryAmmoType()
    MWIIHUD.WepData.TotalAmmo1 = MWIIHUD.WepData.Mag1 + MWIIHUD.WepData.Ammo1
    MWIIHUD.WepData.TotalAmmo2 = MWIIHUD.WepData.Mag2 + MWIIHUD.WepData.Ammo2

    lastframeammotype1 = wep:GetPrimaryAmmoType()-- hardcoded for now, alt ammo handling not available *yet*
end

function MWIIHUD.Vitals()
    if ply:Alive() then
        if !MWIIHUD.ToggleArmorOnly:GetBool() then
            surface.SetDrawColor(59,59,59,128)
            surface.DrawRect(63 * scale, scrh - 57 * scale, 172 * scale, 7 * scale)
            surface.SetDrawColor(255,255,255,255)
            surface.DrawRect(65 * scale, scrh - 55 * scale, 168 * scale * math.Clamp(ply:Health() / 100, 0, 1), 3 * scale)

            draw.DrawText(ply:Nick(), "MWIINickText", 66 * scale, scrh - 90 * scale, Color(131,161,226))

            if ply:Health() > 100 then draw.DrawText(ply:Health(), "MWIISubText", 245 * scale, scrh - 60 * scale, color_white) end
        end

        surface.SetDrawColor(59,59,59,128)
        surface.DrawRect(63 * scale, scrh - 66 * scale, 56 * scale, 7 * scale)
        surface.DrawRect(121 * scale, scrh - 66 * scale, 56 * scale, 7 * scale)
        surface.DrawRect(179 * scale, scrh - 66 * scale, 56 * scale, 7 * scale)
        if ply:Armor() <= 100 then surface.SetDrawColor(131,161,226)
        else surface.SetDrawColor(238,208,59) end
        surface.DrawRect(65 * scale, scrh - 64 * scale, 52 * scale * math.Clamp(ply:Armor() / 100 / (1 / 3), 0, 1), 3 * scale)
        surface.DrawRect(123 * scale, scrh - 64 * scale, 52 * scale * math.Clamp(ply:Armor() / 100 / (1 / 3) - 1, 0, 1), 3 * scale)
        surface.DrawRect(181 * scale, scrh - 64 * scale, 52 * scale * math.Clamp(ply:Armor() / 100 / (1 / 3) - 2, 0, 1), 3 * scale)
        if ply:Armor() > 100 then draw.DrawText(ply:Armor(), "MWIISubText", 245 * scale, scrh - 82 * scale, MWIIHUD.Colors.Preset.Yellow) end

        if GetConVar("sv_armorplates_spawnamount") then
            surface.SetMaterial(MWIIHUD.Assets.ArmorPlate)
            surface.SetDrawColor(255,255,255,255)
            surface.DrawTexturedRect(328 * scale,scrh - 75 * scale,30 * scale,30 * scale)
            draw.DrawText(ply:GetArmorPlates() or GetConVar("sv_armorplates_spawnamount"):GetInt(), "MWIISubText", 360 * scale, scrh - 72 * scale, color_white)
        elseif GetConVar("wz_armorsys_armorplates_maxcarry") then
            surface.SetMaterial(MWIIHUD.Assets.ArmorPlate)
            surface.SetDrawColor(255,255,255,255)
            surface.DrawTexturedRect(264 * scale,scrh - 80 * scale,36 * scale,36 * scale)
            draw.DrawText(ply:GetAmmoCount("WZ_ARMORPLATE"), "MWIISubText", 310 * scale, scrh - 72 * scale, color_white)   
        end
    end
end

function MWIIHUD.Ammo()
    if !IsValid(wep) then return end
    lastubstate = inubwep

    draw.NoTexture()
    surface.SetDrawColor(MWIIHUD.Colors.Preset.Gray)
    surface.DrawRect(scrw - 150 * scale, scrh - 125 * scale, 2 * scale, 49 * scale)
    if MWIIHUD.WepData.AmmoType1 != -1 then -- not a melee weapon
        firetype, firemode, inubwep, safe = MWIIHUD.GetFiremode(wep, false)
        firetype = firetype and math.Clamp(firetype, 0, 4) or 1
        if firetype == -1 then firetype = 0 end
        if inubwep then
            if MWIIHUD.WepData.Mag2Max < 0 then
                draw.DrawText(MWIIHUD.WepData.Mag2 + MWIIHUD.WepData.Ammo2, "MWIIAmmoText", scrw - 160 * scale, scrh - 132 * scale,
                    (MWIIHUD.WepData.Mag2 + MWIIHUD.WepData.Ammo2 == 0) and MWIIHUD.Colors.Preset.OrangeRed or color_white, TEXT_ALIGN_RIGHT)
            else
                draw.DrawText(MWIIHUD.WepData.Mag2, "MWIIAmmoText", scrw - 160 * scale, scrh - 132 * scale,
                    (MWIIHUD.WepData.Mag2 < MWIIHUD.WepData.Mag2Max / 3) and MWIIHUD.Colors.Preset.OrangeRed or color_white, TEXT_ALIGN_RIGHT)
                draw.DrawText(MWIIHUD.WepData.Ammo2, "MWIIAmmoSubText", scrw - 160 * scale, scrh - 91 * scale,
                    MWIIHUD.WepData.Ammo2 == 0 and MWIIHUD.Colors.Preset.OrangeRed or MWIIHUD.Colors.Preset.Gray, TEXT_ALIGN_RIGHT)
            end
            if MWIIHUD.WepData.Mag2 == 0 and MWIIHUD.WepData.Ammo2 == 0 then
                draw.DrawText("NO AMMO","MWIISubText",scrw * 0.5,scrh - 463 * scale,MWIIHUD.Colors.Preset.OrangeRed,TEXT_ALIGN_CENTER)
            elseif MWIIHUD.WepData.Mag2 < MWIIHUD.WepData.Mag2Max / 3 and MWIIHUD.WepData.Ammo1 == 0 then
                draw.DrawText("LOW AMMO","MWIISubText",scrw * 0.5,scrh - 463 * scale,MWIIHUD.Colors.Preset.Yellow,TEXT_ALIGN_CENTER)
            elseif MWIIHUD.WepData.Mag2 < MWIIHUD.WepData.Mag2Max / 3 then
                surface.SetFont("MWIISubText")
                local w2, h = surface.GetTextSize(string.upper(input.LookupBinding("+reload")))
                local w = w2 + select(1, surface.GetTextSize("RELOAD")) + 16 * scale
                surface.SetDrawColor(255,255,255,255)
                draw.RoundedBox(6, scrw * 0.5 - w * 0.5 - 6 * scale, scrh - 465 * scale, w2 + 12 * scale, h + 2 * scale, color_white)
                draw.DrawText(string.upper(input.LookupBinding("+reload")), "MWIISubText", scrw * 0.5 - w * 0.5, scrh - 463 * scale, color_black)
                draw.DrawText("RELOAD", "MWIISubText", scrw * 0.5 - w * 0.5 + w2 + 16 * scale, scrh - 463 * scale, color_white)
            end
        else
            if MWIIHUD.WepData.Mag1Max < 0 then
                draw.DrawText(MWIIHUD.WepData.Mag1 + MWIIHUD.WepData.Ammo1, "MWIIAmmoText", scrw - 160 * scale, scrh - 132 * scale,
                    (MWIIHUD.WepData.Mag1 + MWIIHUD.WepData.Ammo1 == 0) and MWIIHUD.Colors.Preset.OrangeRed or color_white, TEXT_ALIGN_RIGHT)
            else
                draw.DrawText(MWIIHUD.WepData.Mag1, "MWIIAmmoText", scrw - 160 * scale, scrh - 132 * scale,
                    (MWIIHUD.WepData.Mag1 < MWIIHUD.WepData.Mag1Max / 3) and MWIIHUD.Colors.Preset.OrangeRed or color_white, TEXT_ALIGN_RIGHT)
                draw.DrawText(MWIIHUD.WepData.Ammo1, "MWIIAmmoSubText", scrw - 160 * scale, scrh - 91 * scale,
                    MWIIHUD.WepData.Ammo1 == 0 and MWIIHUD.Colors.Preset.OrangeRed or MWIIHUD.Colors.Preset.Gray, TEXT_ALIGN_RIGHT)
            end
            if MWIIHUD.WepData.Mag1 == 0 and MWIIHUD.WepData.Ammo1 == 0 then
                draw.DrawText("NO AMMO","MWIISubText",scrw * 0.5,scrh - 463 * scale,MWIIHUD.Colors.Preset.OrangeRed,TEXT_ALIGN_CENTER)
            elseif MWIIHUD.WepData.Mag1 < MWIIHUD.WepData.Mag1Max / 3 and MWIIHUD.WepData.Ammo1 == 0 then
                draw.DrawText("LOW AMMO","MWIISubText",scrw * 0.5,scrh - 463 * scale,MWIIHUD.Colors.Preset.Yellow,TEXT_ALIGN_CENTER)
            elseif MWIIHUD.WepData.Mag1 < MWIIHUD.WepData.Mag1Max / 3 then
                surface.SetFont("MWIISubText")
                local w2, h = surface.GetTextSize(string.upper(input.LookupBinding("+reload")))
                local w = w2 + select(1, surface.GetTextSize("RELOAD")) + 16 * scale
                surface.SetDrawColor(255,255,255,255)
                draw.RoundedBox(6, scrw * 0.5 - w * 0.5 - 6 * scale, scrh - 465 * scale, w2 + 12 * scale, h + 2 * scale, color_white)
                draw.DrawText(string.upper(input.LookupBinding("+reload")), "MWIISubText", scrw * 0.5 - w * 0.5, scrh - 463 * scale, color_black)
                draw.DrawText("RELOAD", "MWIISubText", scrw * 0.5 - w * 0.5 + w2 + 16 * scale, scrh - 463 * scale, color_white)
            end
        end

        surface.SetMaterial(safe and MWIIHUD.Assets.Firemodes[0][1] or MWIIHUD.Assets.Firemodes[firetype][1])
        surface.SetDrawColor(color_white)
        surface.DrawTexturedRect(scrw - 325 * scale,scrh - 65 * scale,27 * scale,27 * scale)
        draw.DrawText(safe and "Safety" or (firemode .. (GetConVar("developer"):GetBool() and " | " .. firetype or "")), "MWIIAmmoSubText",
            scrw - 285 * scale,scrh - 63 * scale, color_white)
        if MWIIHUD.WepData.AmmoType2 != -1 and !wep.ArcticTacRP then -- TacRP is kinda fuckin weird
            local altfirename = "Altfire"
            if wep:IsScripted() then
                if wep.ARC9 then altfirename = wep:GetUBGL() and wep:GetProcessedValue("UBGLFiremodeName") or "Altfire"
                elseif wep.ArcCW then altfirename = wep:GetBuff_Override("UBGL_PrintName") and wep:GetBuff_Override("UBGL_PrintName") or ArcCW.GetTranslation("fcg.ubgl") end
            end
            draw.DrawText(!inubwep and altfirename .. " [ " .. MWIIHUD.WepData.TotalAmmo2 .. " ]  | " or wep:GetPrintName() .. " [ " .. MWIIHUD.WepData.TotalAmmo1 .. " ]  | ",
                "MWIIAmmoSubText", scrw - 330 * scale,scrh - 63 * scale, color_white, TEXT_ALIGN_RIGHT)
        end
    end
    
    if IsValid(wep) and (!MWIIHUD.WeaponIconOffset[MWIIHUD.WepData.Class] or MWIIHUD.WeaponIconOffset[MWIIHUD.WepData.Class][3] != "0") and wep.DrawWeaponSelection then
        MWIIHUD.DrawWeaponIconToRT(wep,0, 0,1024 * math.Round(scale),512 * math.Round(scale))
        surface.SetMaterial(MWIIHUD.WeaponIconRTMat)
        surface.SetDrawColor(color_white)
        surface.DrawTexturedRect(scrw - 540 * scale,scrh - 180 * scale,320 * scale, 160 * scale)
        if GetConVar("developer"):GetBool() then
            surface.SetDrawColor(color_white)
            surface.DrawOutlinedRect(scrw - 540 * scale,scrh - 180 * scale,320 * scale, 160 * scale)
            surface.SetDrawColor(0,255,0,255)
            surface.DrawOutlinedRect(scrw - 540 * scale,scrh - 150 * scale,320 * scale, 100 * scale)
        end

        if lastframewep != wep then
            MWIIHUD.Times.WepChangeTimeOut = CurTime() + 1.6
            MWIIHUD.Times.AmmoTypeFade = CurTime() + 1.6
        elseif lastframeammotype1 != MWIIHUD.WepData.AmmoType1 or lastubstate != inubwep then MWIIHUD.Times.AmmoTypeFade = CurTime() + 1.6 end

        MWIIHUD.Colors.AmmoName.a = 255 * (math.min(MWIIHUD.Times.AmmoTypeFade - CurTime(), 0) * 4 + 1)
        draw.DrawText(inubwep and (MWIIHUD.WepData.AmmoType2 != -1 and language.GetPhrase(game.GetAmmoName(MWIIHUD.WepData.AmmoType2)) or "Melee/Tool") or
            (MWIIHUD.WepData.AmmoType1 != -1 and language.GetPhrase(game.GetAmmoName(MWIIHUD.WepData.AmmoType1)) or "Melee/Tool"),
            "MWIIAmmoSubText", scrw - 400 * scale, scrh - 177 * scale, MWIIHUD.Colors.AmmoName)

        MWIIHUD.Colors.WeaponName.a = 255 * (math.min(MWIIHUD.Times.WepChangeTimeOut - CurTime(), 0) * 4 + 1)
        draw.DrawText(MWIIHUD.WepData.PrintName, "MWIIAmmoSubText", scrw - 400 * scale, scrh - 200 * scale, MWIIHUD.Colors.WeaponName)
    elseif IsValid(wep) then
        local iconChar = MWIIHUD.HL2WeaponIconChara[wep:GetClass()]
        if iconChar then
            draw.SimpleText(iconChar,"hl2wepicon",scrw - 360 * scale,scrh - 110 * scale,headerTextColor,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
            
            if lastframewep != wep then
                MWIIHUD.Times.WepChangeTimeOut = CurTime() + 1.6
                MWIIHUD.Times.AmmoTypeFade = CurTime() + 1.6
            elseif lastframeammotype1 != MWIIHUD.WepData.AmmoType1 or lastubstate != inubwep then MWIIHUD.Times.AmmoTypeFade = CurTime() + 1.6 end
            
            MWIIHUD.Colors.AmmoName.a = 255 * (math.min(MWIIHUD.Times.AmmoTypeFade - CurTime(), 0) * 4 + 1)
            draw.DrawText(inubwep and (MWIIHUD.WepData.AmmoType2 != -1 and language.GetPhrase(game.GetAmmoName(MWIIHUD.WepData.AmmoType2)) or "Melee/Tool") or
            (MWIIHUD.WepData.AmmoType1 != -1 and language.GetPhrase(game.GetAmmoName(MWIIHUD.WepData.AmmoType1)) or "Melee/Tool"),
            "MWIIAmmoSubText", scrw - 400 * scale, scrh - 177 * scale, MWIIHUD.Colors.AmmoName)
            
            MWIIHUD.Colors.WeaponName.a = 255 * (math.min(MWIIHUD.Times.WepChangeTimeOut - CurTime(), 0) * 4 + 1)
            draw.DrawText(MWIIHUD.WepData.PrintName, "MWIIAmmoSubText", scrw - 400 * scale, scrh - 200 * scale, MWIIHUD.Colors.WeaponName)
        end
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
                    if string.StartsWith(texttbl[f], "<cr>") then
                        drawtbl[#drawtbl + 1] = drawtxt
                        drawtxt = string.Right(texttbl[f], 3)
                    elseif surface.GetTextSize(drawtxt .. " " .. texttbl[f]) < scrw * 0.55 then
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

                draw.DrawText(drawtxt, "MWIISubText", scrw * 0.5, scrh * 0.76 + h * linecount, MWIIHUD.CaptionCache[i][1][1][2] or color_white, TEXT_ALIGN_CENTER)
                linecount = linecount + #drawtbl
            else
                local drawtbl = {}
                drawtbl[1] = {} -- thanks lua
                local drawtbli = 1
                local teststringlen = 0
                for e=1,#MWIIHUD.CaptionCache[i][1] do
                    surface.SetFont("MWIISubText")
                    local texttbl = string.Explode(" ", MWIIHUD.CaptionCache[i][1][e][1], false)
                    local teststring = ""

                    -- surface.GetTextSize() isn't cooperating with select() here so wasted memory :sadge:
                    for f=1,#texttbl do
                        if string.StartsWith(texttbl[f], "<cr>") then -- force a line break
                            drawtbl[drawtbli][#drawtbl[drawtbli] + 1] = {teststring, MWIIHUD.CaptionCache[i][1][e][2], surface.GetTextSize(teststring)}
                            teststring = string.Right(texttbl[f], string.len(texttbl[f]) - 4)
                            teststringlen = 0
                            drawtbl[#drawtbl + 1] = {}
                            drawtbli = #drawtbl
                        elseif (select(1, surface.GetTextSize(teststring .. " " .. texttbl[f])) + teststringlen) < scrw * 0.55 then
                            teststring = teststring .. " " .. texttbl[f]
                            if f == #texttbl then
                                teststringlen = teststringlen + select(1, surface.GetTextSize(teststring))
                                drawtbl[drawtbli][#drawtbl[drawtbli] + 1] = {teststring, MWIIHUD.CaptionCache[i][1][e][2], surface.GetTextSize(teststring)}    
                            end
                        else
                            drawtbl[drawtbli][#drawtbl[drawtbli] + 1] = {teststring, MWIIHUD.CaptionCache[i][1][e][2], surface.GetTextSize(teststring)}
                            teststring = texttbl[f]
                            teststringlen = 0
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
                    surface.SetTextPos(scrw * 0.5 - linelen * 0.5, scrh * 0.76 + h * linecount)
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

function MWIIHUD.Compass()
    local startcmptime = SysTime()
    -- fuck this shit fuck this shit fuck this shit
    local eyeangle = math.Remap(EyeAngles().y, -180, 180, -360, 0)
    local cardinaltext = ""
    
    for i=1,#MWIIHUD.CompassAngles do
        MWIIHUD.Colors.CompassColor.a = 255 * (math.max(1 - (math.max(math.abs(math.AngleDifference(-eyeangle, MWIIHUD.CompassAngles[i])) - 25, 0)) * 0.25, 0))
        draw.DrawText(MWIIHUD.CompassAngles[i], "MWIICompassSubText",
        scrw / 2 - math.floor(math.AngleDifference(-eyeangle, MWIIHUD.CompassAngles[i]) * scale * 13.5),
        15 * scale, MWIIHUD.Colors.CompassColor, TEXT_ALIGN_CENTER)
    end

    -- 67.5 is 135 / 2 is 45 * 3 / 2 (lmao)
    if (math.abs(math.AngleDifference(-eyeangle, 0))) < 67.5 then cardinaltext = cardinaltext .. "N"
    elseif (math.abs(math.AngleDifference(-eyeangle, 180))) < 67.5 then cardinaltext = cardinaltext .. "S" end
    if (math.abs(math.AngleDifference(-eyeangle, 90))) < 67.5 then cardinaltext = cardinaltext .. "E"
    elseif (math.abs(math.AngleDifference(-eyeangle, 270))) < 67.5 then cardinaltext = cardinaltext .. "W" end

    
    surface.SetDrawColor(color_white)
    surface.DrawRect(scrw / 2 - 1 * scale, 40 * scale, 2 * scale, 20 * scale)
    surface.SetMaterial(MWIIHUD.Assets.Gradients[1][1])
    surface.DrawTexturedRect(scrw / 2 - 1 * scale, 20 * scale, 2 * scale, 20 * scale)
    surface.SetMaterial(MWIIHUD.Assets.Gradients[2][1])
    surface.DrawTexturedRect(scrw / 2 - 320 * scale, 40 * scale, 640 * scale, 2 * scale)

    draw.DrawText(math.floor(-eyeangle), "MWIICompassText", scrw / 2 + 4 * scale, 43 * scale, color_white, TEXT_ALIGN_LEFT)
    draw.DrawText(cardinaltext, "MWIICompassText", scrw / 2 - 4 * scale, 43 * scale, color_white, TEXT_ALIGN_RIGHT)
end

MWIIHUD.CompassAngles = {0,15,30,45,60,75,90,105,120,135,150,165,180,195,210,225,240,255,270,285,300,315,330,345} 

hook.Add("OnCloseCaptionEmit", "MWIIGrabCaption", MWIIHUD.ParseCaption)
hook.Add("HUDShouldDraw", "MWIIHideCHud", function(name)
    if MWIIHUD.HideCElements[name] and GetConVar("cl_drawhud"):GetBool() and MWIIHUD.Toggle:GetBool() then return false end
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