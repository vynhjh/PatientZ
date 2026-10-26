extends RefCounted
## Shared by the floors: keeps or removes Player2 and turns on the split screen.
## Every floor scene has the nodes Player2 (player.tscn, player_number = 2) and SplitScreen.

## Returns player 2, or null in 1-player games (then Player2 and SplitScreen are removed).
static func setup_players(level: Node) -> CharacterBody3D:
	var player2: CharacterBody3D = level.get_node_or_null("Player2")
	var split: Control = level.get_node_or_null("SplitScreen")
	if GameManager.player_count < 2:
		for n in [player2, split]:
			if n:
				level.remove_child(n)
				n.free()
		return null
	if split and player2:
		split.setup(level.get_node("Player"), player2)
		var hud := level.get_node_or_null("HUD")
		if hud:                                   # each half has its own HUD
			hud.visible = false
			hud.process_mode = Node.PROCESS_MODE_DISABLED
	return player2
