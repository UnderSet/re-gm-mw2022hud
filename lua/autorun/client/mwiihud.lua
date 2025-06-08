--include("TFAKeys.lua") -- include() fuck you why wont you work

local MWIIHUD = {}
local scrw, scrh = 0, 0
local scale = 1

function MWIIHUD.NeededStuff()
    scrw, scrh = ScrW(), ScrH()
    scale = scrh / 1080

    -- render target sizes MUST be power of 2 because dx9 or sum shit
    GetRenderTarget("MWIIWeaponIcon", 1024 * math.Round(scale), 512 * math.Round(scale))
end

MWIIHUD.NeededStuff()

MWIIHUD.Assets = {}
MWIIHUD.Assets.Reference = {{Material("mwii/reference/reference1.png", "noclamp smooth")}} -- dont blame me for le double

function MWIIHUD.MainHook()
    surface.SetMaterial(MWIIHUD.Assets.Reference[1][1])
    surface.SetDrawColor(255,255,255,180)
    surface.DrawTexturedRect(0,0,scrw,scrh)
    surface.DrawRect(100,100,100,100)
end

hook.Add("HUDPaint", "MWIIHUDDraw", MWIIHUD.MainHook)

print("MWII HUD loaded." .. SysTime())
PrintTable(MWIIHUD.Assets.Reference)