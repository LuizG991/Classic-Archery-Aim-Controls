Classic Aim Controls v4.13.1  -  Dragon's Dogma 2 (REFramework script)

WHAT IT DOES (Archer and Magick Archer; Warfarer only while a bow / magick bow is the equipped weapon)
  Hold LT      Aim (vanilla behavior).
  Press RT     Shoot, and keep aiming while LT stays held.
  Release LT   Cancel the aim WITHOUT firing the arrow.

Carried objects and creatures use the same controls: LT aims the throw, RT throws, releasing LT cancels the aim.

REQUIREMENTS
  REFramework for Dragon's Dogma 2 (dinput8.dll in the game folder).

INSTALL
  Fluffy Mod Manager: drag this zip onto Fluffy Mod Manager (Dragon's Dogma 2 selected), then enable the mod.
  Manual: copy reframework/autorun/ClassicAimControls.lua into <game folder>/reframework/autorun/

WARFARER (v4.6)
  The mod only acts while the weapon in hand is a bow or magick bow. With any other weapon the
  Warfarer keeps the vanilla controls. Turn it off with "Also work as Warfarer".

SKILLS (Cloudburst Shot and Cataract Shot)
  Cloudburst Shot and Cataract Shot keep shooting while you tap the aim in vanilla (LT down/up, LT down/up...).
  With this mod, every RT press is one more volley / arrow. Release LT to cancel the skill.
  Cloudburst Shot has a cooldown: the first volley can be released 2.6 s after the skill was activated
  and each following volley 2.5 s after the previous one. RT presses before that are ignored, so you
  can spam RT without ending the skill early. Sliders: "Cloudburst: first volley delay, from activation"
  (default 2.6) and "Cloudburst: delay between volleys" (default 2.5). The two timers are independent:
  the first counts from the activation, the later ones from the previous volley, so the first one can
  be lowered below the second. It cannot go below the time the skill needs to get ready (about 0.3 s).
  Cataract Shot can be shot as soon as it starts preparing, with no minimum.

RECOMMENDED GAME CONTROLS (REFramework menu > Script Generated UI > ClassicAimControls > Recommended game controls)
  "Apply classic aim controls" changes the game's gamepad bindings in memory:
    Vocation Action = LT, Cancel = RB, Light Attack = RT, Grab = X.
  Tick "Apply automatically on startup" (and click "Save settings") to do it every time the game starts.
  If you change the controls in the game's own menu afterwards, click the button again.

SETTINGS (REFramework menu > Script Generated UI > ClassicAimControls > Settings)
  Fire trigger        Action your RT is bound to. "Auto" accepts Grab, AttackS and AttackL.
  Cancel with ActCancel   Cancels a ready aim cleanly (recommended).
  Aim again after the shot   Re-aims if the game leaves the aim after a shot.
  Frames until the bow is ready / RT buffer   Both start at 0. Raise the buffer if you want an
                      early RT press to be remembered until the bow can shoot.
  Show debug / Record trace   For bug reports: enable "Record trace", reproduce the problem,
                      click "Save trace.json" (saved in reframework/data/ClassicAimControls/).
  Save settings       Keeps your settings in reframework/data/ClassicAimControls/config.json; they are
                      loaded every time the game starts. "Enabled", "Show debug" and "Record trace" are
                      never saved. To go back to the defaults, delete config.json.

UNINSTALL
  Disable the mod in Fluffy Mod Manager, or delete reframework/autorun/ClassicAimControls.lua.
