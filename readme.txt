Classic Aim Controls v4.5.0  -  Dragon's Dogma 2 (REFramework script)

WHAT IT DOES (Archer and Magick Archer only)
  Hold LT      Aim (vanilla behavior).
  Press RT     Shoot, and keep aiming while LT stays held.
  Release LT   Cancel the aim WITHOUT firing the arrow.

REQUIREMENTS
  REFramework for Dragon's Dogma 2 (dinput8.dll in the game folder).

INSTALL
  Fluffy Mod Manager: drag this zip onto Fluffy Mod Manager (Dragon's Dogma 2 selected), then enable the mod.
  Manual: copy reframework/autorun/ClassicAimControls.lua into <game folder>/reframework/autorun/

SETTINGS (REFramework menu > Script Generated UI > ClassicAimControls)
  Fire trigger        Action your RT is bound to. "Auto" accepts Grab, AttackS and AttackL.
  Cancel with ActCancel   Cancels a ready aim cleanly (recommended).
  Aim again after the shot   Re-aims if the game leaves the aim after a shot.
  Frames until the bow is ready / RT buffer   Both start at 0. Raise the buffer if you want an
                      early RT press to be remembered until the bow can shoot.
  Show debug / Record trace   For bug reports: enable "Record trace", reproduce the problem,
                      click "Save trace.json" (saved in reframework/data/ArcherAimLT/).
  Settings are not saved between sessions; the defaults are used every launch.

UNINSTALL
  Disable the mod in Fluffy Mod Manager, or delete reframework/autorun/ClassicAimControls.lua.
