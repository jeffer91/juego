extends Node

enum Team {
	NEUTRAL,
	PLAYER,
	ENEMY
}

const TEAM_DATA := {
	Team.NEUTRAL: {
		"id": "neutral",
		"name": "Neutral",
		"color": Color(0.55, 0.55, 0.55)
	},
	Team.PLAYER: {
		"id": "player",
		"name": "Jugador",
		"color": Color(0.12, 0.45, 1.0)
	},
	Team.ENEMY: {
		"id": "enemy",
		"name": "Enemigo",
		"color": Color(1.0, 0.15, 0.12)
	}
}

func get_team_id(team: Team) -> String:
	return TEAM_DATA.get(team, TEAM_DATA[Team.NEUTRAL])["id"]

func get_team_name(team: Team) -> String:
	return TEAM_DATA.get(team, TEAM_DATA[Team.NEUTRAL])["name"]

func get_team_color(team: Team) -> Color:
	return TEAM_DATA.get(team, TEAM_DATA[Team.NEUTRAL])["color"]

func is_enemy(team_a: Team, team_b: Team) -> bool:
	if team_a == Team.NEUTRAL or team_b == Team.NEUTRAL:
		return false
	return team_a != team_b
