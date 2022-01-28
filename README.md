# HunterHelper

Adds a large overlay indicating in-range or out of range and allows spammable Auto Shot macros and spells, as well as will engage Auto Shot even if a ranged spell cannot be cast (due to OOM, cooldown, etc.).

In order to measure distance appropriately the Auto Shot spell must be dragged from the spellbook (Marksmanship tab) on to one of the player hotbars.
By default, ALL hunter spells that require ranged weapons will be enabled, EXCEPT Scatter Shot.
Any newly learned ranged spells will have the auto shot activation enabled.

## Recommended Add Ons
For maximum enjoyment, also consider using https://github.com/pellevink/ToastMaster with this Addon.

## Features

### Spammable Auto Shot - Prevent Auto Shot Off Toggle
Whenever the player casts the Auto Shot spell (e.g. /cast Auto Shot, clicks the action button, etc.) the addon will ensure Auto Shot is cast. The original 1.12 client will treat auto shot as a toggle.

In order to stop auto shot, press `escape` for example.

### Auto Shot Auto Activation
Whenever the player fires any ranged ability (e.g. Arcane Shot, Multi-Shot) the addon will enforce auto shot to commence. On the 1.12 cient, if the player is not in Auto Shot mode, and has low mana, or the ability is on cooldown, Auto Shot will not start - this addon enforces this activation.

### Range Checker
If the currently targetted enemy is inside minimum or outside maximum range for Auto Shot, a red pane will appear in the center of the screen. This feature requires Auto Shot to be dragged onto any Action Bar.

### Ammo Counter
A movable pane with the currently equipped ammo type and count is displayed on screen. It can be moved after unlocking it with /huh unlock. Lock it in place with /huh lock.

### Pet Happiness Alert
When your currently active pet loses a happiness level (Happy->Content, Content->Angry) the addon will alert with a "toast pane" on screen.

### Prevent Aspect Toggling Off
A hook has been placed in the Blizzard API to prevent aspects from being toggled off. i.e. when you cast Aspect of the Hawk twice in a row, the first cast enables it, the second cast does nothing.

### Aspect Rotation Macro
Use the macro `/huh aspect` to rotate between aspects, or specify a single aspect. Also allows modifier alternate input.

The user can use a `smart` option to swap aspect to Aaspect of the Monkey if the player was recently dazed. 

## Slash commands

### Auto Shot Activation
`/huh e[nable]|d[isable]|i[gnore] [Spell Name]`

If specified with 'Spell Name', will enable/disable that spell by/from forcefully activating auto shot.
If 'Spell Name' is not specified, the addon will enable/disable the current spell (in spellbook) or action (in action bar) which is mouse-over.
i.e. move the mouse over a spell on the action bar, or in the spellbook, then type: /huh en, for example.

`e[nable]` : When using this spell, forced auto shot will be attempted, regardless of mana status, etc.

`d[isable]` : Spells flagged as disabled when used will cause the addon to force stopping of auto shot. 

`i[gnore]` : Spells used will follow the normal game reaction.

### Reset Spell Configuration
`/huh resetspells|rs`

Reset all spell configurations to default. All ranged spells will have Auto Shot enforce enabled, except Scatter Shot.		

### Reset Frame Positioning
`/huh  resetframes|rf`

Reset all frame configurations in case something gets lost

### Set Frame Alpha
`/huh alpha [in|out] <alpha value 0.0 to 1.0>`

Set the alpha of the in-range, or out-of-range pane. if pane isn't specified, will set for all panes.

### Frame Repositioning
`/huh unlock | lock`

Unlock or lock frames for repositioning on the screen.

### Aspect Rotation
`/huh aspect [<option list>] <aspect list> {<mod key list> [<option list>] <aspect list>}`

Where

`<option list>` (optional) a list of options for the aspect rotation:
- `smart`: Will override the current rotation perform a **smart cast**

`<aspect list>` a list of hunter aspects to rotate through.
- `beast` : Aspect of the Beast
- `hawk` : Aspect of the Hawk
- `cheetah` : Aspect of the Cheetah
- `monkey` : Aspect of the Monkey
- `wild` : Aspect of the Wild
- `pack` : Aspect of the Pack

`<mod key list>` a list of modifier keys
- `alt` : Any "Alt" key
- `shift` : Any "Shift" key
- `ctrl` : Any "Control" key


This command will rotate through the aspects in `<aspect list>` from left to right, then starting over from the leftmost.

e.g. `/huh aspect cheetah hawk` will go back and forth between Aspect of the Cheetah and Aspect of the Hawk.

The user may specify any or no option flags preceding the list of aspects to invoke special behavior.

e.g. `/huh aspect smart cheetah` will smart-cast Aspect of the Cheetah.

The user may specify a list of modifiers followed by a list of aspects to invoke alternative behavior when a modifier key combination is pressed

e.g. `/huh aspect hawk alt smart cheetah` will always cast Aspect of the Hawk normally, but when activated with the "Alt" key depressed, will smart-cast Aspect of the Cheetah.

#### Smart Casting
If the user specifies the `smart` option before a list of aspects, the addon will override the rotation under the following circumstances:
- If the player is, or was dazed within the last 3 seconds, the macro will cast Aspect of the Monkey.

Otherwise, the normal aspect rotation will be followed. 

**Note:** Each list of aspects (such as when a modifier key list is given) must also be flagged with the `smart` option. e.g. `/huh aspect smart cheetah alt smart hawk`
