extends RexbotAction

class_name NPCActionBase

var npc: NPCBase:
	get:
		return brain.actor as NPCBase
