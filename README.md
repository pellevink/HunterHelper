# HunterHelper

Adds a large overlay indicating in-range or out of range and allows spammable Auto Shot macros and spells, as well as will engage Auto Shot even if a ranged spell cannot be cast (due to OOM, cooldown, etc.).

In order to measure distance appropriately the Auto Shot spell must be dragged from the spellbook (Marksmanship tab) on to one of the player hotbars.
By default, ALL hunter spells that require ranged weapons will be enabled, EXCEPT Scatter Shot.
Any newly learned ranged spells will have the auto shot activation enabled.

## Slash commands
/hh e[nable]|d[isable]|i[gnore] [Spell Name]

If specified with 'Spell Name', will enable/disable that spell by/from forcefully activating auto shot.
If 'Spell Name' is not specified, the addon will enable/disable the current spell (in spellbook) or action (in action bar) which is mouse-over.
i.e. move the mouse over a spell on the action bar, or in the spellbook, then type: /hh en, for example.

e[nable] : When using this spell, forced auto shot will be attempted, regardless of mana status, etc.

d[isable] : Spells flagged as disabled when used will cause the addon to force stopping of auto shot. 

i[gnore] : Spells used will follow the normal game reaction.
		
/hh resetspells|rs|

Reset all spell configurations to default. All ranged spells will have Auto Shot enforce enabled, except Scatter Shot.		

/hh alpha [in|out|err] <alpha value 0.0 to 1.0>

Set the alpha of the in-range, or out-of-range pane. if pane isn't specified, will set for all panes.
