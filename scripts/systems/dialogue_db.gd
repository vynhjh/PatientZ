extends RefCounted
## All dialogue lines of the game. Load it with:
## const DialogueDB = preload("res://scripts/systems/dialogue_db.gd")

const BOSS_NAME := "Boss"

const BOSS_INTRO := [
	"Welcome, you must be the new assistant! Glad someone finally joined this floor—it gets boring around here.",
	"I need your help before we get started. Go search the first 4 rooms and bring me 5 syringes.",
]

const BOSS_ALARM := [
	"Patient Z has escaped! Take this Keycard and head straight to the Security Guard Room down the hall.",
	"That's where we keep the firearms. Get the rifle and stop the infection before it reaches the upper levels. Good luck!",
]

const BOSS_MISSING_SYRINGES := "You have %d of %d syringes. Check the cabinets in the first 4 rooms."
const BOSS_SURVIVE := "The Security Guard Room is down the hall. Get the rifle and stop Patient Z!"
const BOSS_CLEARED := "You actually did it... The stairs to Floor 2 are open. Go!"
