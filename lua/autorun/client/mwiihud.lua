--include("TFAKeys.lua") -- include() fuck you why wont you work

local MWIIHUD = {}
local scrw, scrh = 0, 0
local scale = 1

MWIIHUD.DebugReference = CreateClientConVar("MWIIHUD_Debug_DrawReference", 0, false, false, "debug: draw reference image, gives no shit about main toggle", 0, 2)
MWIIHUD.Toggle = CreateClientConVar("MWIIHUD_Enable", 1, true, false, "Enables the HUD.", 0, 1)

function MWIIHUD.NeededStuff()
    -- runs on start and every time res is changed
    scrw, scrh = ScrW(), ScrH()
    scale = scrh / 1080

    -- render target sizes MUST be power of 2 because dx9 or sum shit
    GetRenderTarget("MWIIWeaponIcon", 1024 * math.Round(scale), 512 * math.Round(scale))

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

MWIIHUD.Assets = {}
MWIIHUD.Assets.Reference = {{Material("mwii/reference/reference1.png", "noclamp smooth")}, {Material("mwii/reference/reference2.png", "noclamp smooth")}} -- dont blame me for le double

function MWIIHUD.MainHook()
    local dev = GetConVar("developer"):GetBool()
    if dev and MWIIHUD.DebugReference:GetBool() then
        surface.SetMaterial(MWIIHUD.Assets.Reference[MWIIHUD.DebugReference:GetInt()][1])
        surface.SetDrawColor(255,255,255,180)
        surface.DrawTexturedRect(0,0,scrw,scrh)
        surface.DrawRect(100,100,100,100)
    end

    --MWIIHUD.WeaponData()
    --MWIIHUD.Vitals()
    --MWIIHUD.Compass()
    MWIIHUD.Ammo()
end

function MWIIHUD.Ammo()
    draw.NoTexture()
    surface.SetDrawColor(color_white)
    surface.DrawRect(scrw - 150 * scale, scrh - 125 * scale, 3 * scale, 50 * scale)
    draw.DrawText(LocalPlayer():GetActiveWeapon():Clip1(), "MWIIAmmoText", scrw - 160 * scale, scrh - 132 * scale, color_white, TEXT_ALIGN_RIGHT)
    draw.DrawText(LocalPlayer():GetAmmoCount(LocalPlayer():GetActiveWeapon():GetPrimaryAmmoType()), "MWIIAmmoSubText", scrw - 160 * scale, scrh - 89 * scale, color_white, TEXT_ALIGN_RIGHT)
end

hook.Add("HUDPaint", "MWIIHUDDraw", MWIIHUD.MainHook)

print("MWII HUD loaded." .. SysTime())
PrintTable(MWIIHUD.Assets.Reference)