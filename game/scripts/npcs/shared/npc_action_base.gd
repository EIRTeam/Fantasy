extends RexbotAction

class_name NPCActionBase

var npc: NPCBase:
	get:
		return brain.actor as NPCBase

## Used for making an NPC "talk" for debugging without assets
func debug_npc_talk(text: String):
	npc._npc_talk(text)

func can_we_see_the_player() -> bool:
	var player_visible_query_result := request_query(&"can_we_see_the_player")
	return player_visible_query_result == QueryResponse.ANSWER_YES

func are_we_dead() -> bool:
	var are_we_dead_query_result := request_query(&"are_we_dead")
	return are_we_dead_query_result == QueryResponse.ANSWER_YES
	
