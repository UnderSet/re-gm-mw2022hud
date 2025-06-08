include("TFAKeys.lua")

local MWIIHUD = {}
local scrw, scrh = 0, 0
local scale = 1

function MWIIHUD.NeededStuff()
    scrw, scrh = ScrW(), ScrH()
    scale = scrh / 1080

    -- render target sizes MUST be power of 2 because dx9 or sum shit
    GetRenderTarget("MWIIWeaponIcon", 1024 * math.Round(scale), 512 * math.Round(scale))
end

MWIIHUD.Assets = {}
MWIIHUD.Assets.Reference = {Material("mwii/reference/reference1.png")}