# *Modern Warfare II* HUD or something
Attempt at recreating the Call of Duty: Modern Warfare II HUD in Garry's Mod with my limited GLua skills

## (Planned) Features

|Will do|Probably?|Just...*no* (never)|
|---|---|---|
|~~Health and armor display~~|Killfeed|Minimap|
|~~Weapon display~~ *(~~main display~~, ~~firemode and altfire~~ [^1], ~~weapon icon~~)*|Objective elements|Objective notifications *(top-right)*|
|Compass *(~~working~~, gradient BG)*|Calling cards|System info display things *("telemetry")*|
|~~Subtitles~~ *(~~parsing text (basic)~~, ~~drawing~~, ~~multi-tag handling~~)* [^2]|CoDHQ-style notifications?|Player account ID display|

*Crossed out means done unless in 3rd column.*

## License
Code is [*GNU General Public License*, v3](https://github.com/UnderSet/re-gm-mw2022hud/blob/main/LICENSE) due to (future) use of code from DyaMetR's [D-GL4 HUD (aka `holohud2`)](https://github.com/DyaMetR/holohud2).

Might use code from Arctic's ARC9 and ArcCW but those don't have a license literally anywhere. *Arctic please add one.*

Textures (the images) are by me and are public domain or [CC0](https://creativecommons.org/publicdomain/zero/1.0/) **except** for those under `\material\mwii\reference` as they're screenshots of *Modern Warfare II* and thus are copyrighted by Activision.

Font is Stratum 2, and is copyright Eric Olson.

## Credits
- *Infinity Ward* and *Activision* for [*Call of Duty: Modern Warfare II*](https://www.callofduty.com/store/games/modernwarfare2), which was the inspiration and reference for this HUD.

[^1]: Supported weapon bases: ARC9, ArcCW, Modern Warfare Base
[^2]: Obviously won't be identical to MWII due to how Source subtitles are.

Check out [gmcaptions](https://github.com/underset/gmcaptions), an improved standalone version of this addon's subtitle rendering implementation. I likely won't be updating the version here.
