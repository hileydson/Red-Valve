## GERADO por tools/blender/lekrosos/cortar.py — nao editar a mao.
##
## As pecas removiveis do lekroso_2. Espaco do Skeleton3D (metros, frente +Z).
## pedaco: some da carne e cai uma lasca (o corpo continua andando).
## membro: o membro inteiro cai (`pai` = quem esta' acima dele).

const PECAS := {
	"antebraco_l": {"tipo": "membro", "zona": "antebraco_l", "osso": "forearm.L", "centro": Vector3(0.2763, 1.0938, -0.0648), "normal": Vector3(0.3523, -0.9359, -0.0042), "raio": 0.0545, "massa": 524, "pai": "braco_l", "junta": Vector3(0.2485, 1.1734, -0.0925)},
	"antebraco_r": {"tipo": "membro", "zona": "antebraco_r", "osso": "forearm.R", "centro": Vector3(-0.2878, 1.0898, -0.0548), "normal": Vector3(-0.2563, -0.9666, 0.0082), "raio": 0.0549, "massa": 546, "pai": "braco_r", "junta": Vector3(-0.256, 1.1795, -0.0804)},
	"barriga": {"tipo": "pedaco", "zona": "tronco", "osso": "spine", "centro": Vector3(-0.0293, 1.1266, 0.1619), "normal": Vector3(0.0, 0.0, 1.0), "raio": 0.0850, "massa": 41},
	"braco_l": {"tipo": "membro", "zona": "braco_l", "osso": "upper_arm.L", "centro": Vector3(0.1838, 1.3395, -0.0709), "normal": Vector3(0.9193, -0.2151, -0.3294), "raio": 0.1299, "massa": 1771, "pai": "", "junta": Vector3(0.1463, 1.392, -0.0457)},
	"braco_r": {"tipo": "membro", "zona": "braco_r", "osso": "upper_arm.R", "centro": Vector3(-0.2087, 1.2969, -0.0643), "normal": Vector3(-0.9465, -0.1131, -0.3021), "raio": 0.1368, "massa": 956, "pai": "", "junta": Vector3(-0.1558, 1.3729, -0.0342)},
	"cabeca_nuca": {"tipo": "pedaco", "zona": "cabeca", "osso": "head", "centro": Vector3(-0.0022, 1.739, -0.127), "normal": Vector3(0.0, 0.1483, -0.9889), "raio": 0.0600, "massa": 564},
	"cabeca_rosto_l": {"tipo": "pedaco", "zona": "cabeca", "osso": "head", "centro": Vector3(0.0918, 1.7371, 0.0785), "normal": Vector3(0.6541, 0.0503, 0.7547), "raio": 0.0500, "massa": 235},
	"cabeca_rosto_r": {"tipo": "pedaco", "zona": "cabeca", "osso": "head", "centro": Vector3(-0.123, 1.7566, 0.1214), "normal": Vector3(-0.6541, 0.0503, 0.7547), "raio": 0.0500, "massa": 196},
	"cabeca_topo": {"tipo": "pedaco", "zona": "cabeca", "osso": "head", "centro": Vector3(0.0221, 1.8652, 0.0058), "normal": Vector3(0.2357, 0.9428, -0.2357), "raio": 0.0580, "massa": 256},
	"canela_l_frente": {"tipo": "pedaco", "zona": "canela_l", "osso": "shin.L", "centro": Vector3(0.1511, 0.3452, -0.0331), "normal": Vector3(0.0, 0.0, 1.0), "raio": 0.0620, "massa": 19},
	"canela_r_frente": {"tipo": "pedaco", "zona": "canela_r", "osso": "shin.R", "centro": Vector3(-0.1626, 0.3543, -0.0357), "normal": Vector3(0.0, 0.0, 1.0), "raio": 0.0620, "massa": 14},
	"costas_l": {"tipo": "pedaco", "zona": "tronco", "osso": "upper_chest", "centro": Vector3(-0.0689, 1.5006, 0.0472), "normal": Vector3(0.4104, 0.0, -0.9119), "raio": 0.0900, "massa": 45},
	"costas_r": {"tipo": "pedaco", "zona": "tronco", "osso": "upper_chest", "centro": Vector3(-0.0393, 1.4469, -0.123), "normal": Vector3(-0.4104, 0.0, -0.9119), "raio": 0.0900, "massa": 34},
	"coxa_l_fora": {"tipo": "pedaco", "zona": "coxa_l", "osso": "thigh.L", "centro": Vector3(0.1898, 0.7815, -0.0391), "normal": Vector3(1.0, 0.0, 0.0), "raio": 0.0780, "massa": 270},
	"coxa_l_frente": {"tipo": "pedaco", "zona": "coxa_l", "osso": "thigh.L", "centro": Vector3(0.1284, 0.7212, 0.0725), "normal": Vector3(0.0995, 0.0, 0.995), "raio": 0.0800, "massa": 174},
	"coxa_l_tras": {"tipo": "pedaco", "zona": "coxa_l", "osso": "thigh.L", "centro": Vector3(0.1112, 0.6714, -0.0869), "normal": Vector3(0.0, 0.0, -1.0), "raio": 0.0780, "massa": 54},
	"coxa_r_fora": {"tipo": "pedaco", "zona": "coxa_r", "osso": "thigh.R", "centro": Vector3(-0.2169, 0.7602, -0.0252), "normal": Vector3(-1.0, 0.0, 0.0), "raio": 0.0780, "massa": 242},
	"coxa_r_frente": {"tipo": "pedaco", "zona": "coxa_r", "osso": "thigh.R", "centro": Vector3(-0.1203, 0.7245, 0.0895), "normal": Vector3(-0.0995, 0.0, 0.995), "raio": 0.0800, "massa": 152},
	"coxa_r_tras": {"tipo": "pedaco", "zona": "coxa_r", "osso": "thigh.R", "centro": Vector3(-0.1335, 0.6718, -0.0796), "normal": Vector3(0.0, 0.0, -1.0), "raio": 0.0780, "massa": 90},
	"lombar": {"tipo": "pedaco", "zona": "tronco", "osso": "spine", "centro": Vector3(0.0062, 1.1474, -0.1035), "normal": Vector3(0.0, 0.0, -1.0), "raio": 0.0850, "massa": 48},
	"mao_l": {"tipo": "membro", "zona": "mao_l", "osso": "hand.L", "centro": Vector3(0.3282, 0.8388, 0.011), "normal": Vector3(0.1563, -0.9566, 0.246), "raio": 0.0311, "massa": 761, "pai": "antebraco_l", "junta": Vector3(0.3305, 0.9545, -0.0066)},
	"mao_r": {"tipo": "membro", "zona": "mao_r", "osso": "hand.R", "centro": Vector3(-0.3322, 0.8403, 0.0118), "normal": Vector3(-0.1528, -0.9717, 0.1801), "raio": 0.0325, "massa": 807, "pai": "antebraco_r", "junta": Vector3(-0.3315, 0.9539, -0.0042)},
	"nadega_l": {"tipo": "pedaco", "zona": "cintura", "osso": "hips", "centro": Vector3(0.0618, 0.8757, -0.111), "normal": Vector3(0.3909, -0.3041, -0.8687), "raio": 0.0780, "massa": 449},
	"nadega_r": {"tipo": "pedaco", "zona": "cintura", "osso": "hips", "centro": Vector3(-0.0797, 0.8658, -0.1021), "normal": Vector3(-0.3909, -0.3041, -0.8687), "raio": 0.0780, "massa": 235},
	"panturrilha_l": {"tipo": "pedaco", "zona": "canela_l", "osso": "shin.L", "centro": Vector3(0.1497, 0.3728, -0.128), "normal": Vector3(0.0, 0.0, -1.0), "raio": 0.0660, "massa": 41},
	"panturrilha_r": {"tipo": "pedaco", "zona": "canela_r", "osso": "shin.R", "centro": Vector3(-0.1498, 0.3702, -0.1324), "normal": Vector3(0.0, 0.0, -1.0), "raio": 0.0660, "massa": 42},
	"peito_l": {"tipo": "pedaco", "zona": "tronco", "osso": "upper_chest", "centro": Vector3(0.0042, 1.4195, 0.0932), "normal": Vector3(0.4104, 0.0, 0.9119), "raio": 0.0850, "massa": 168},
	"peito_r": {"tipo": "pedaco", "zona": "tronco", "osso": "upper_chest", "centro": Vector3(-0.0513, 1.42, 0.1124), "normal": Vector3(-0.4104, 0.0, 0.9119), "raio": 0.0850, "massa": 255},
	"quadril_l": {"tipo": "pedaco", "zona": "cintura", "osso": "hips", "centro": Vector3(0.1313, 0.9293, 0.079), "normal": Vector3(0.8838, 0.0, 0.4679), "raio": 0.0750, "massa": 692},
	"quadril_r": {"tipo": "pedaco", "zona": "cintura", "osso": "hips", "centro": Vector3(-0.1732, 0.926, 0.0819), "normal": Vector3(-0.8838, 0.0, 0.4679), "raio": 0.0750, "massa": 543},
}

## Metros por ciclo de cada clipe de andar (animar.py).
const PASSADA := {"andar": 0.322, "vagar": 0.688}
