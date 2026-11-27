## GERADO por tools/blender/lekrosos/cortar.py — nao editar a mao.
##
## As pecas removiveis do lekroso_3. Espaco do Skeleton3D (metros, frente +Z).
## pedaco: some da carne e cai uma lasca (o corpo continua andando).
## membro: o membro inteiro cai (`pai` = quem esta' acima dele).

const PECAS := {
	"antebraco_l": {"tipo": "membro", "zona": "antebraco_l", "osso": "forearm.L", "centro": Vector3(0.2625, 1.0727, -0.0664), "normal": Vector3(0.2674, -0.9635, 0.0127), "raio": 0.0646, "massa": 805, "pai": "braco_l", "junta": Vector3(0.2389, 1.1755, -0.0988)},
	"antebraco_r": {"tipo": "membro", "zona": "antebraco_r", "osso": "forearm.R", "centro": Vector3(-0.2847, 1.08, -0.0688), "normal": Vector3(-0.2437, -0.9691, 0.0385), "raio": 0.0638, "massa": 532, "pai": "braco_r", "junta": Vector3(-0.2536, 1.1794, -0.0934)},
	"barriga": {"tipo": "pedaco", "zona": "tronco", "osso": "spine", "centro": Vector3(-0.0058, 1.1262, 0.1402), "normal": Vector3(0.0, 0.0, 1.0), "raio": 0.0850, "massa": 39},
	"braco_l": {"tipo": "membro", "zona": "braco_l", "osso": "upper_arm.L", "centro": Vector3(0.2123, 1.3305, -0.0814), "normal": Vector3(0.9414, -0.1261, -0.3129), "raio": 0.1518, "massa": 1065, "pai": "", "junta": Vector3(0.1543, 1.3751, -0.0782)},
	"braco_r": {"tipo": "membro", "zona": "braco_r", "osso": "upper_arm.R", "centro": Vector3(-0.2135, 1.3122, -0.057), "normal": Vector3(-0.9672, -0.0423, -0.2506), "raio": 0.1579, "massa": 1191, "pai": "", "junta": Vector3(-0.1562, 1.3509, -0.0535)},
	"cabeca_nuca": {"tipo": "pedaco", "zona": "cabeca", "osso": "head", "centro": Vector3(-0.0026, 1.7484, -0.0881), "normal": Vector3(0.0, 0.1483, -0.9889), "raio": 0.0600, "massa": 836},
	"cabeca_rosto_l": {"tipo": "pedaco", "zona": "cabeca", "osso": "head", "centro": Vector3(0.0817, 1.7278, 0.1248), "normal": Vector3(0.6541, 0.0503, 0.7547), "raio": 0.0500, "massa": 787},
	"cabeca_rosto_r": {"tipo": "pedaco", "zona": "cabeca", "osso": "head", "centro": Vector3(-0.0807, 1.7487, 0.1186), "normal": Vector3(-0.6541, 0.0503, 0.7547), "raio": 0.0500, "massa": 356},
	"cabeca_topo": {"tipo": "pedaco", "zona": "cabeca", "osso": "head", "centro": Vector3(0.0129, 1.8667, 0.0254), "normal": Vector3(0.2357, 0.9428, -0.2357), "raio": 0.0580, "massa": 282},
	"canela_l_frente": {"tipo": "pedaco", "zona": "canela_l", "osso": "shin.L", "centro": Vector3(0.1456, 0.3451, 0.0337), "normal": Vector3(0.0, 0.0, 1.0), "raio": 0.0620, "massa": 48},
	"canela_r_frente": {"tipo": "pedaco", "zona": "canela_r", "osso": "shin.R", "centro": Vector3(-0.1476, 0.346, 0.03), "normal": Vector3(0.0, 0.0, 1.0), "raio": 0.0620, "massa": 79},
	"costas_l": {"tipo": "pedaco", "zona": "tronco", "osso": "upper_chest", "centro": Vector3(0.0556, 1.4341, -0.1764), "normal": Vector3(0.4104, 0.0, -0.9119), "raio": 0.0900, "massa": 89},
	"costas_r": {"tipo": "pedaco", "zona": "tronco", "osso": "upper_chest", "centro": Vector3(-0.0665, 1.4457, -0.169), "normal": Vector3(-0.4104, 0.0, -0.9119), "raio": 0.0900, "massa": 55},
	"coxa_l_fora": {"tipo": "pedaco", "zona": "coxa_l", "osso": "thigh.L", "centro": Vector3(0.1962, 0.7453, -0.021), "normal": Vector3(1.0, 0.0, 0.0), "raio": 0.0780, "massa": 62},
	"coxa_l_frente": {"tipo": "pedaco", "zona": "coxa_l", "osso": "thigh.L", "centro": Vector3(0.1222, 0.7148, 0.0885), "normal": Vector3(0.0995, 0.0, 0.995), "raio": 0.0800, "massa": 81},
	"coxa_l_tras": {"tipo": "pedaco", "zona": "coxa_l", "osso": "thigh.L", "centro": Vector3(0.1328, 0.6539, -0.1057), "normal": Vector3(0.0, 0.0, -1.0), "raio": 0.0780, "massa": 97},
	"coxa_r_fora": {"tipo": "pedaco", "zona": "coxa_r", "osso": "thigh.R", "centro": Vector3(-0.2044, 0.7304, -0.017), "normal": Vector3(-1.0, 0.0, 0.0), "raio": 0.0780, "massa": 57},
	"coxa_r_frente": {"tipo": "pedaco", "zona": "coxa_r", "osso": "thigh.R", "centro": Vector3(-0.1269, 0.7034, 0.0845), "normal": Vector3(-0.0995, 0.0, 0.995), "raio": 0.0800, "massa": 74},
	"coxa_r_tras": {"tipo": "pedaco", "zona": "coxa_r", "osso": "thigh.R", "centro": Vector3(-0.1358, 0.6574, -0.1075), "normal": Vector3(0.0, 0.0, -1.0), "raio": 0.0780, "massa": 103},
	"lombar": {"tipo": "pedaco", "zona": "tronco", "osso": "spine", "centro": Vector3(0.0043, 1.1335, -0.1716), "normal": Vector3(0.0, 0.0, -1.0), "raio": 0.0850, "massa": 38},
	"mao_l": {"tipo": "membro", "zona": "mao_l", "osso": "hand.L", "centro": Vector3(0.3149, 0.8503, -0.0031), "normal": Vector3(0.3867, -0.9042, 0.1813), "raio": 0.0534, "massa": 1320, "pai": "antebraco_l", "junta": Vector3(0.3109, 0.9554, -0.0412)},
	"mao_r": {"tipo": "membro", "zona": "mao_r", "osso": "hand.R", "centro": Vector3(-0.3215, 0.8574, -0.0009), "normal": Vector3(-0.1021, -0.9623, 0.252), "raio": 0.0562, "massa": 1454, "pai": "antebraco_r", "junta": Vector3(-0.3107, 0.952, -0.0397)},
	"nadega_l": {"tipo": "pedaco", "zona": "cintura", "osso": "hips", "centro": Vector3(0.0742, 0.8413, -0.1417), "normal": Vector3(0.3909, -0.3041, -0.8687), "raio": 0.0780, "massa": 127},
	"nadega_r": {"tipo": "pedaco", "zona": "cintura", "osso": "hips", "centro": Vector3(-0.0786, 0.849, -0.1452), "normal": Vector3(-0.3909, -0.3041, -0.8687), "raio": 0.0780, "massa": 205},
	"ombro_l": {"tipo": "pedaco", "zona": "tronco", "osso": "shoulder.L", "centro": Vector3(0.1642, 1.5512, -0.0104), "normal": Vector3(0.2414, 0.9656, 0.0966), "raio": 0.0650, "massa": 125},
	"ombro_r": {"tipo": "pedaco", "zona": "tronco", "osso": "shoulder.R", "centro": Vector3(-0.1499, 1.563, -0.015), "normal": Vector3(-0.2414, 0.9656, 0.0966), "raio": 0.0650, "massa": 68},
	"panturrilha_l": {"tipo": "pedaco", "zona": "canela_l", "osso": "shin.L", "centro": Vector3(0.1419, 0.3774, -0.1209), "normal": Vector3(0.0, 0.0, -1.0), "raio": 0.0660, "massa": 50},
	"panturrilha_r": {"tipo": "pedaco", "zona": "canela_r", "osso": "shin.R", "centro": Vector3(-0.1444, 0.371, -0.1244), "normal": Vector3(0.0, 0.0, -1.0), "raio": 0.0660, "massa": 47},
	"peito_l": {"tipo": "pedaco", "zona": "tronco", "osso": "upper_chest", "centro": Vector3(0.0525, 1.4305, 0.1003), "normal": Vector3(0.4104, 0.0, 0.9119), "raio": 0.0850, "massa": 362},
	"peito_r": {"tipo": "pedaco", "zona": "tronco", "osso": "upper_chest", "centro": Vector3(-0.0777, 1.4191, 0.0976), "normal": Vector3(-0.4104, 0.0, 0.9119), "raio": 0.0850, "massa": 236},
	"quadril_l": {"tipo": "pedaco", "zona": "cintura", "osso": "hips", "centro": Vector3(0.1505, 0.9149, 0.0879), "normal": Vector3(0.8838, 0.0, 0.4679), "raio": 0.0750, "massa": 497},
	"quadril_r": {"tipo": "pedaco", "zona": "cintura", "osso": "hips", "centro": Vector3(-0.1615, 0.9054, 0.0923), "normal": Vector3(-0.8838, 0.0, 0.4679), "raio": 0.0750, "massa": 147},
}

## Metros por ciclo de cada clipe de andar (animar.py).
const PASSADA := {"andar": 0.323, "vagar": 0.693}
