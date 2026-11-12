extends RefCounted
# Objetos, recetas y piezas de construcción de Herrumbre.

const ITEMS = {
	"madera": {"n": "Madera", "t": "res", "c": Color(0.6, 0.42, 0.24)},
	"piedra": {"n": "Piedra", "t": "res", "c": Color(0.6, 0.6, 0.6)},
	"mena": {"n": "Mena de hierro", "t": "res", "c": Color(0.62, 0.42, 0.3)},
	"hierro": {"n": "Hierro", "t": "res", "c": Color(0.72, 0.74, 0.78)},
	"fibra": {"n": "Fibra", "t": "res", "c": Color(0.5, 0.7, 0.35)},
	"tela": {"n": "Tela", "t": "res", "c": Color(0.85, 0.8, 0.68)},
	"cuero": {"n": "Cuero", "t": "res", "c": Color(0.5, 0.32, 0.2)},
	"chatarra": {"n": "Chatarra", "t": "res", "c": Color(0.55, 0.36, 0.26)},
	"carne_cruda": {"n": "Carne cruda", "t": "food", "food": 10, "water": 0, "hp": -4, "c": Color(0.8, 0.3, 0.3), "stack": 20},
	"carne_asada": {"n": "Carne asada", "t": "food", "food": 38, "water": 0, "hp": 6, "c": Color(0.55, 0.3, 0.15), "stack": 20},
	"bayas": {"n": "Bayas", "t": "food", "food": 7, "water": 8, "hp": 0, "c": Color(0.8, 0.15, 0.3), "stack": 40},
	"seta": {"n": "Seta", "t": "food", "food": 11, "water": 2, "hp": 0, "c": Color(0.8, 0.6, 0.45), "stack": 40},
	"venda": {"n": "Venda", "t": "med", "heal": 35, "c": Color(0.95, 0.95, 0.9), "stack": 10},
	"roca": {"n": "Roca", "t": "tool", "dmg": 9, "tree": 6, "rock": 5, "cd": 0.55, "c": Color(0.5, 0.5, 0.5), "stack": 1},
	"hacha_piedra": {"n": "Hacha de piedra", "t": "tool", "dmg": 16, "tree": 15, "rock": 3, "cd": 0.6, "c": Color(0.62, 0.55, 0.45), "stack": 1},
	"pico_piedra": {"n": "Pico de piedra", "t": "tool", "dmg": 14, "tree": 4, "rock": 15, "cd": 0.65, "c": Color(0.55, 0.55, 0.5), "stack": 1},
	"hacha_hierro": {"n": "Hacha de hierro", "t": "tool", "dmg": 26, "tree": 28, "rock": 5, "cd": 0.55, "c": Color(0.75, 0.75, 0.82), "stack": 1},
	"pico_hierro": {"n": "Pico de hierro", "t": "tool", "dmg": 22, "tree": 6, "rock": 28, "cd": 0.6, "c": Color(0.7, 0.72, 0.8), "stack": 1},
	"lanza": {"n": "Lanza", "t": "tool", "dmg": 30, "tree": 2, "rock": 1, "cd": 0.8, "range": 3.4, "c": Color(0.65, 0.5, 0.3), "stack": 1},
	"machete": {"n": "Machete", "t": "tool", "dmg": 42, "tree": 8, "rock": 1, "cd": 0.5, "c": Color(0.8, 0.82, 0.85), "stack": 1},
	"arco": {"n": "Arco", "t": "bow", "dmg": 45, "cd": 1.0, "c": Color(0.6, 0.45, 0.25), "stack": 1},
	"flecha": {"n": "Flecha", "t": "res", "c": Color(0.75, 0.65, 0.45)},
	"escopeta": {"n": "Escopeta casera", "t": "gun", "dmg": 15, "cd": 1.3, "c": Color(0.3, 0.3, 0.33), "stack": 1},
	"cartucho": {"n": "Cartucho", "t": "res", "c": Color(0.8, 0.25, 0.2)},
	"martillo": {"n": "Martillo", "t": "hammer", "cd": 0.5, "c": Color(0.5, 0.45, 0.4), "stack": 1},
	"antorcha": {"n": "Antorcha", "t": "tool", "dmg": 10, "tree": 2, "rock": 1, "cd": 0.6, "light": true, "c": Color(1.0, 0.6, 0.15), "stack": 1},
	"ropa_tela": {"n": "Ropa de tela", "t": "wear", "armor": 0.15, "warm": 0.5, "c": Color(0.8, 0.75, 0.6), "stack": 1},
	"armadura_cuero": {"n": "Armadura de cuero", "t": "wear", "armor": 0.35, "warm": 0.75, "c": Color(0.45, 0.28, 0.16), "stack": 1},
	"hoguera": {"n": "Hoguera", "t": "deploy", "c": Color(0.95, 0.45, 0.1), "stack": 5},
	"horno": {"n": "Horno", "t": "deploy", "c": Color(0.5, 0.48, 0.46), "stack": 5},
	"cofre": {"n": "Cofre", "t": "deploy", "c": Color(0.55, 0.38, 0.2), "stack": 5},
	"saco": {"n": "Saco de dormir", "t": "deploy", "c": Color(0.3, 0.5, 0.3), "stack": 5},
	"banco": {"n": "Banco de trabajo", "t": "deploy", "c": Color(0.5, 0.36, 0.22), "stack": 5},
}

const FISTS = {"n": "Puños", "t": "tool", "dmg": 5, "tree": 2, "rock": 1, "cd": 0.5}

# q = cantidad producida, st = estación necesaria cerca
const RECIPES = [
	{"id": "hacha_piedra", "q": 1, "cost": {"madera": 10, "piedra": 5}},
	{"id": "pico_piedra", "q": 1, "cost": {"madera": 10, "piedra": 8}},
	{"id": "lanza", "q": 1, "cost": {"madera": 15, "piedra": 3}},
	{"id": "antorcha", "q": 1, "cost": {"madera": 5, "fibra": 2}},
	{"id": "martillo", "q": 1, "cost": {"madera": 10, "piedra": 5}},
	{"id": "hoguera", "q": 1, "cost": {"madera": 15, "piedra": 5}},
	{"id": "tela", "q": 1, "cost": {"fibra": 4}},
	{"id": "venda", "q": 1, "cost": {"tela": 3}},
	{"id": "saco", "q": 1, "cost": {"tela": 10, "fibra": 5}},
	{"id": "ropa_tela", "q": 1, "cost": {"tela": 12}},
	{"id": "arco", "q": 1, "cost": {"madera": 20, "fibra": 10}},
	{"id": "flecha", "q": 5, "cost": {"madera": 5, "piedra": 2}},
	{"id": "cofre", "q": 1, "cost": {"madera": 30}},
	{"id": "banco", "q": 1, "cost": {"madera": 40, "piedra": 20}},
	{"id": "armadura_cuero", "q": 1, "cost": {"cuero": 8, "tela": 4}},
	{"id": "horno", "q": 1, "cost": {"piedra": 40, "madera": 10}, "st": "banco"},
	{"id": "hacha_hierro", "q": 1, "cost": {"madera": 10, "hierro": 8}, "st": "banco"},
	{"id": "pico_hierro", "q": 1, "cost": {"madera": 10, "hierro": 10}, "st": "banco"},
	{"id": "machete", "q": 1, "cost": {"madera": 5, "hierro": 12}, "st": "banco"},
	{"id": "escopeta", "q": 1, "cost": {"chatarra": 25, "hierro": 15, "madera": 10}, "st": "banco"},
	{"id": "cartucho", "q": 4, "cost": {"chatarra": 4, "hierro": 2}, "st": "banco"},
]

const BUILD_ORDER = ["foundation", "wall", "doorway", "window", "floor", "stairs", "door"]
const BUILD = {
	"foundation": {"n": "Cimiento", "cost": {"madera": 20}},
	"wall": {"n": "Muro", "cost": {"madera": 15}},
	"doorway": {"n": "Marco", "cost": {"madera": 12}},
	"window": {"n": "Ventana", "cost": {"madera": 12}},
	"floor": {"n": "Suelo", "cost": {"madera": 12}},
	"stairs": {"n": "Escalera", "cost": {"madera": 15}},
	"door": {"n": "Puerta", "cost": {"madera": 10}},
}
const TIER_NAME = ["madera", "piedra", "hierro"]
const TIER_HP = [120, 350, 700]
const TIER_COST = [{}, {"piedra": 15}, {"hierro": 8}]

const CREATURES = {
	"ciervo": {"n": "Ciervo", "hp": 50, "sp": 5.6, "r": 0.8, "h": 1.4, "mode": "flee", "dmg": 0, "sight": 15.0, "leg": 0.78,
		"loot": {"carne_cruda": 3, "cuero": 2}},
	"jabali": {"n": "Jabalí", "hp": 70, "sp": 4.6, "r": 0.75, "h": 0.9, "mode": "neutral", "dmg": 10, "sight": 0.0, "leg": 0.42,
		"loot": {"carne_cruda": 4, "cuero": 1}},
	"lobo": {"n": "Lobo", "hp": 60, "sp": 4.9, "r": 0.7, "h": 0.9, "mode": "hostile", "dmg": 9, "sight": 20.0, "leg": 0.55,
		"loot": {"carne_cruda": 2, "cuero": 2}},
	"oso": {"n": "Oso", "hp": 190, "sp": 4.5, "r": 1.1, "h": 1.5, "mode": "hostile", "dmg": 22, "sight": 15.0, "leg": 0.62,
		"loot": {"carne_cruda": 6, "cuero": 4}},
	"saqueador": {"n": "Saqueador", "hp": 90, "sp": 4.3, "r": 0.6, "h": 1.8, "mode": "hostile", "dmg": 12, "sight": 24.0, "leg": 0.88,
		"loot": {"tela": 3, "chatarra": 4}},
}
const POP = {"ciervo": 16, "jabali": 11, "lobo": 9, "oso": 3}
