## GERADO por tools/blender/lekrosos/cortar.py — nao editar a mao.
##
## As pecas removiveis do lekroso_1. Espaco do Skeleton3D (metros, frente +Z).
## pedaco: some da carne e cai uma lasca (o corpo continua andando).
## membro: o membro inteiro cai (`pai` = quem esta' acima dele).

const PECAS := {
	"antebraco_l": {"tipo": "membro", "zona": "antebraco_l", "osso": "forearm.L", "centro": Vector3(0.3189, 1.0875, -0.0102), "normal": Vector3(0.3447, -0.9169, 0.2009), "raio": 0.0636, "massa": 1107, "pai": "braco_l", "junta": Vector3(0.286, 1.1614, -0.0238)},
	"antebraco_r": {"tipo": "membro", "zona": "antebraco_r", "osso": "forearm.R", "centro": Vector3(-0.3159, 1.0862, -0.0169), "normal": Vector3(-0.3281, -0.9135, 0.2407), "raio": 0.0691, "massa": 1137, "pai": "braco_r", "junta": Vector3(-0.2947, 1.1603, -0.0312)},
	"barriga": {"tipo": "pedaco", "zona": "tronco", "osso": "spine", "centro": Vector3(-0.0066, 1.1252, 0.1033), "normal": Vector3(0.0, 0.0, 1.0), "raio": 0.0850, "massa": 58},
	"braco_l": {"tipo": "membro", "zona": "braco_l", "osso": "upper_arm.L", "centro": Vector3(0.237, 1.3098, -0.03), "normal": Vector3(0.9838, -0.1785, -0.0133), "raio": 0.1151, "massa": 1443, "pai": "", "junta": Vector3(0.1899, 1.4044, -0.017)},
	"braco_r": {"tipo": "membro", "zona": "braco_r", "osso": "upper_arm.R", "centro": Vector3(-0.2309, 1.3061, -0.0262), "normal": Vector3(-0.9648, -0.2613, 0.0298), "raio": 0.1130, "massa": 1505, "pai": "", "junta": Vector3(-0.1857, 1.4144, -0.0031)},
	"cabeca_nuca": {"tipo": "pedaco", "zona": "cabeca", "osso": "head", "centro": Vector3(0.0072, 1.7504, -0.0184), "normal": Vector3(0.0, 0.1483, -0.9889), "raio": 0.0600, "massa": 1623},
	"cabeca_rosto_l": {"tipo": "pedaco", "zona": "cabeca", "osso": "head", "centro": Vector3(0.0529, 1.7388, 0.1599), "normal": Vector3(0.6541, 0.0503, 0.7547), "raio": 0.0500, "massa": 338},
	"cabeca_rosto_r": {"tipo": "pedaco", "zona": "cabeca", "osso": "head", "centro": Vector3(-0.0759, 1.7299, 0.2024), "normal": Vector3(-0.6541, 0.0503, 0.7547), "raio": 0.0500, "massa": 173},
	"cabeca_topo": {"tipo": "pedaco", "zona": "cabeca", "osso": "head", "centro": Vector3(-0.0003, 1.8511, 0.1215), "normal": Vector3(0.2357, 0.9428, -0.2357), "raio": 0.0580, "massa": 484},
	"canela_l_frente": {"tipo": "pedaco", "zona": "canela_l", "osso": "shin.L", "centro": Vector3(0.1759, 0.3594, -0.0295), "normal": Vector3(0.0, 0.0, 1.0), "raio": 0.0620, "massa": 53},
	"canela_r_frente": {"tipo": "pedaco", "zona": "canela_r", "osso": "shin.R", "centro": Vector3(-0.1666, 0.3525, -0.0278), "normal": Vector3(0.0, 0.0, 1.0), "raio": 0.0620, "massa": 47},
	"costas_l": {"tipo": "pedaco", "zona": "tronco", "osso": "upper_chest", "centro": Vector3(0.0499, 1.4434, -0.1727), "normal": Vector3(0.4104, 0.0, -0.9119), "raio": 0.0900, "massa": 49},
	"costas_r": {"tipo": "pedaco", "zona": "tronco", "osso": "upper_chest", "centro": Vector3(-0.0612, 1.4419, -0.1705), "normal": Vector3(-0.4104, 0.0, -0.9119), "raio": 0.0900, "massa": 302},
	"coxa_l_fora": {"tipo": "pedaco", "zona": "coxa_l", "osso": "thigh.L", "centro": Vector3(0.1801, 0.7574, -0.081), "normal": Vector3(1.0, 0.0, 0.0), "raio": 0.0780, "massa": 39},
	"coxa_l_frente": {"tipo": "pedaco", "zona": "coxa_l", "osso": "thigh.L", "centro": Vector3(0.1289, 0.7122, 0.0404), "normal": Vector3(0.0995, 0.0, 0.995), "raio": 0.0800, "massa": 47},
	"coxa_l_tras": {"tipo": "pedaco", "zona": "coxa_l", "osso": "thigh.L", "centro": Vector3(0.1218, 0.6482, -0.1028), "normal": Vector3(0.0, 0.0, -1.0), "raio": 0.0780, "massa": 74},
	"coxa_r_fora": {"tipo": "pedaco", "zona": "coxa_r", "osso": "thigh.R", "centro": Vector3(-0.1892, 0.766, -0.0727), "normal": Vector3(-1.0, 0.0, 0.0), "raio": 0.0780, "massa": 34},
	"coxa_r_frente": {"tipo": "pedaco", "zona": "coxa_r", "osso": "thigh.R", "centro": Vector3(-0.1243, 0.7104, 0.0404), "normal": Vector3(-0.0995, 0.0, 0.995), "raio": 0.0800, "massa": 41},
	"coxa_r_tras": {"tipo": "pedaco", "zona": "coxa_r", "osso": "thigh.R", "centro": Vector3(-0.1193, 0.6487, -0.1044), "normal": Vector3(0.0, 0.0, -1.0), "raio": 0.0780, "massa": 71},
	"lombar": {"tipo": "pedaco", "zona": "tronco", "osso": "spine", "centro": Vector3(-0.0041, 1.1418, -0.2443), "normal": Vector3(0.0, 0.0, -1.0), "raio": 0.0850, "massa": 125},
	"mao_l": {"tipo": "membro", "zona": "mao_l", "osso": "hand.L", "centro": Vector3(0.3646, 0.8169, 0.0894), "normal": Vector3(0.0981, -0.9505, 0.2949), "raio": 0.0349, "massa": 1225, "pai": "antebraco_l", "junta": Vector3(0.37, 0.9373, 0.0464)},
	"mao_r": {"tipo": "membro", "zona": "mao_r", "osso": "hand.R", "centro": Vector3(-0.3677, 0.816, 0.0904), "normal": Vector3(-0.1491, -0.9411, 0.3034), "raio": 0.0349, "massa": 1300, "pai": "antebraco_r", "junta": Vector3(-0.3727, 0.9398, 0.0456)},
	"nadega_l": {"tipo": "pedaco", "zona": "cintura", "osso": "hips", "centro": Vector3(0.0479, 0.8444, -0.184), "normal": Vector3(0.3909, -0.3041, -0.8687), "raio": 0.0780, "massa": 54},
	"nadega_r": {"tipo": "pedaco", "zona": "cintura", "osso": "hips", "centro": Vector3(-0.0493, 0.8387, -0.1822), "normal": Vector3(-0.3909, -0.3041, -0.8687), "raio": 0.0780, "massa": 60},
	"ombro_l": {"tipo": "pedaco", "zona": "tronco", "osso": "shoulder.L", "centro": Vector3(0.157, 1.5693, -0.0027), "normal": Vector3(0.2414, 0.9656, 0.0966), "raio": 0.0650, "massa": 133},
	"ombro_r": {"tipo": "pedaco", "zona": "tronco", "osso": "shoulder.R", "centro": Vector3(-0.1699, 1.5547, -0.0153), "normal": Vector3(-0.2414, 0.9656, 0.0966), "raio": 0.0650, "massa": 60},
	"panturrilha_l": {"tipo": "pedaco", "zona": "canela_l", "osso": "shin.L", "centro": Vector3(0.1474, 0.3642, -0.1478), "normal": Vector3(0.0, 0.0, -1.0), "raio": 0.0660, "massa": 50},
	"panturrilha_r": {"tipo": "pedaco", "zona": "canela_r", "osso": "shin.R", "centro": Vector3(-0.155, 0.3696, -0.1491), "normal": Vector3(0.0, 0.0, -1.0), "raio": 0.0660, "massa": 40},
	"peito_l": {"tipo": "pedaco", "zona": "tronco", "osso": "upper_chest", "centro": Vector3(0.071, 1.4066, 0.1298), "normal": Vector3(0.4104, 0.0, 0.9119), "raio": 0.0850, "massa": 332},
	"peito_r": {"tipo": "pedaco", "zona": "tronco", "osso": "upper_chest", "centro": Vector3(-0.087, 1.4248, 0.1301), "normal": Vector3(-0.4104, 0.0, 0.9119), "raio": 0.0850, "massa": 347},
	"quadril_l": {"tipo": "pedaco", "zona": "cintura", "osso": "hips", "centro": Vector3(0.1485, 0.9204, 0.0169), "normal": Vector3(0.8838, 0.0, 0.4679), "raio": 0.0750, "massa": 229},
	"quadril_r": {"tipo": "pedaco", "zona": "cintura", "osso": "hips", "centro": Vector3(-0.1337, 0.9567, 0.025), "normal": Vector3(-0.8838, 0.0, 0.4679), "raio": 0.0750, "massa": 150},
}
