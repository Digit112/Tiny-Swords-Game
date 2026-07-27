extends Node


enum ClassColor {
	BLACK,
	BLUE,
	PURPLE,
	RED,
	YELLOW
}

enum Tool {
	AXE,
	HAMMER,
	KNIFE,
	PICKAXE
}

func get_class_color_name(class_color : ClassColor) -> String:
	var key : String = ClassColor.keys()[class_color]
	return key.to_lower()

func get_tool_name(tool : Tool) -> String:
	var key : String = Tool.keys()[tool]
	return key.to_lower()
	
