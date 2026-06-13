extends RefCounted

const RESULT_NONE := "none"
const RESULT_CONFIRMED := "confirmed"
const RESULT_ENTER_PLAZA := "enter_plaza"
const RESULT_EXIT_TO_MENU := "exit_to_menu"


static func invoke_confirm(confirmed_callback: Callable) -> String:
	if confirmed_callback.is_valid():
		confirmed_callback.call()
		return RESULT_CONFIRMED
	return RESULT_NONE


static func invoke_enter_plaza(enter_plaza_callback: Callable) -> String:
	if enter_plaza_callback.is_valid():
		enter_plaza_callback.call()
		return RESULT_ENTER_PLAZA
	return RESULT_NONE


static func invoke_exit_to_menu(exit_to_menu_callback: Callable, confirmed_callback: Callable) -> String:
	if exit_to_menu_callback.is_valid():
		exit_to_menu_callback.call()
		return RESULT_EXIT_TO_MENU
	if confirmed_callback.is_valid():
		confirmed_callback.call()
		return RESULT_CONFIRMED
	return RESULT_NONE
