extends SkeletonModifier3D

## A CACADEIRA NAS DUAS MAOS DO MAYCOW NORMAL — PORTE, MIRA E RECARGA QUE DOBRA.
##
## Irmao do `player_gun_hold.gd`, e pelo mesmo motivo dele: o rig do Maycow
## normal tem 24 ossos, NENHUM dedo, e nao ha' .blend fonte no repo. Nao existe
## clipe de "segurar arma longa", nem de mirar, nem de recarregar. Um
## SkeletonModifier3D roda DEPOIS da AnimationTree, no mesmo quadro: as pernas
## continuam andando pela StateMachine de sempre e so' os bracos sao reescritos.
##
## Tudo o que vale la' vale aqui, e nao se repete neste cabecalho: a arma nasce
## filha da MALHA (o esqueleto olha pro +Z e o char1 esta' 180 graus virado), o
## espaco e' o dos OSSOS em CENTIMETROS, e a matematica de braco mora em
## `arma_ik.gd`. O que segue e' so' o que e' DIFERENTE numa arma de dois canos.
##
## ==========================================================================
## 1. A ARMA VAI NA MAO. A MAO NAO VAI NA ARMA.
##
## E' o mesmo contrato da pistola, e a primeira versao disto errou nele.
##
## Ali: calcula-se o destino da mao, o IK leva o braco ate' la', e a arma e'
## POUSADA no osso da mao no fim — `CABO_NO_MODELO` cai exatamente na origem do
## `RightHand`. A consequencia e' que a arma esta' na mao em QUALQUER quadro,
## inclusive quando o modificador nao escreve pose nenhuma: se o braco esta'
## balancando na animacao de andar, a arma balanca com ele.
##
## A primeira versao daqui fazia o contrario — montava a pose da arma a partir
## de um ponto medido na ANCORA (o meio dos ombros) e mandava as maos ate' ela.
## Enquanto ele mirava dava no mesmo; fora da mira, com os bracos entregues a'
## animacao, a arma continuava pendurada no ar na frente do peito. Na tela: uma
## cacadeira flutuando, e o Maycow andando de maos vazias atras dela.
##
## Entao a ordem do quadro e' esta, e importa:
##
##     1. destino da mao DIREITA  (porte ou mira, mais o desvio da recarga)
##     2. IK do braco direito
##     3. a arma pousa NO OSSO da mao direita        <- so' aqui ela tem lugar
##     4. destino da mao ESQUERDA = um ponto DA ARMA ja' posta
##     5. IK do braco esquerdo
##
## ==========================================================================
## 2. AS DUAS MAOS, O TEMPO TODO
##
## A pistola solta os bracos quando ele para de mirar (`_peso` vai a zero e a
## animacao volta a mandar). Uma arma longa nao: ninguem anda com uma cacadeira
## pendurada em uma mao so'. Aqui o peso e' 1 enquanto ela estiver EQUIPADA, e
## o que muda entre "andando" e "mirando" nao e' a forca da pose, e' a POSE:
##
##     PORTE   arma atravessada na frente do corpo, boca pra baixo e pra fora
##     MIRA    arma levantada, o furo do cano apontado pro alvo
##
## `_apontando` faz a viagem entre as duas. Fora isso o gesto e' o mesmo, e as
## duas maos ficam nela do comeco ao fim.
##
## ==========================================================================
## 3. O CANO NAO E' O EIXO X DO MODELO
##
## A pistola podia dizer "X e' o cano". Esta nao: a V3 esta' desenhada com a
## arma inteira inclinada, e o furo dos canos desce 0,137 em 0,900 de X — 8,7
## graus. Alinhar o -X com a mira poe a bala 8,7 graus abaixo da mira.
##
## Por isso o cano aqui e' um EIXO MEDIDO (`BOCA_NO_MODELO` ->
## `CULATRA_NO_MODELO`, os dois tirados dos vertices), e a pose e' montada em
## dois passos: uma base grosseira alinhada com a mira, e o giro minimo que leva
## o eixo do furo ate' a direcao certa. Sem numero magico e sem sinal pra errar.
##
## ==========================================================================
## 4. A ARMA E' DUAS PECAS
##
## `the_negotiator_V3_dobravel.glb` (de `tools/blender/shotgun/`) vem cortado:
##
##     raiz
##     +- corpo        bascula + coronha
##     +- charneira    vazio no pino, em CHARNEIRA_NO_MODELO
##        +- canos     canos + fore-end, com as duas camaras
##
## Abrir a arma e' UM numero: `charneira.rotation.z`. Positivo desce a boca.
##
## Consequencia que custou pensar: todo ponto do modelo que esteja na FRENTE do
## corte (o fore-end e as bocas das camaras) se move quando ela abre. Quem
## converte "ponto do modelo" em "ponto do osso" tem de girar ele em volta do
## pino antes — e' o que `_ponto()` faz, e e' por isso que ela existe em vez de
## uma multiplicacao solta.
##
## ==========================================================================
## 5. O VAO ENTRE AS DUAS MAOS E' O QUE LIMITA O TAMANHO DA ARMA
##
## Medido no rig: o braco tem 49 cm do ombro ao punho e os ombros estao a 38 cm
## um do outro. Com a mao direita na frente (mirando), a mao ESQUERDA — que vem
## do ombro do outro lado, 38 cm de desvio — chega no maximo a uns 40 cm a'
## frente da ancora antes de o IK parar de esticar e largar ela no ar.
##
## Logo: (frente da mao direita) + (vao entre as maos) <= ~41 cm. Com o cabo a
## 13 cm a' frente, sobram ~29 cm de vao — e e' esse vao, e nao o gosto, que
## fixa `ESCALA_ARMA` em 33,5 (64 cm de arma, uma coach gun) com o fore-end em
## `APOIO_NO_MODELO`.
##
## Quiser a arma maior: `ESCALA_ARMA` e `APOIO_NO_MODELO.x` andam JUNTOS. Subir
## a escala sem trazer o apoio pra tras desgruda a mao esquerda, e o sintoma na
## tela e' a mao boiando ao lado do cano. O modo de ajuste (F9) mexe nos dois e
## imprime o vao em centimetros a cada tecla, justamente pra isso.

const IK := preload("res://scripts/player/arma_ik.gd")

const OSSO_BRACO_D := "RightArm"
const OSSO_ANTEBRACO_D := "RightForeArm"
const OSSO_MAO_D := "RightHand"
const OSSO_BRACO_E := "LeftArm"
const OSSO_ANTEBRACO_E := "LeftForeArm"
const OSSO_MAO_E := "LeftHand"

const ITEM_SHOTGUN := "shotgun"
const MODELO_SHOTGUN := "res://assets/3d_model/player/the_negotiator_V3/the_negotiator_V3_dobravel.glb"
## Nome do vazio que carrega os canos dentro do .glb (ver o gerador do Blender).
const NO_CHARNEIRA := "charneira"

## Escala da arma DENTRO do esqueleto (que esta' em centimetros). O .glb tem
## 1,913 unidade de ponta a ponta; 33,5 devolve 64 cm de arma. Ver o item 5 do
## cabecalho antes de mexer neste numero — ele anda junto com APOIO_NO_MODELO.
##
## Afinado no jogo, no F9: o valor subiu ate' 52 (arma de 99 cm) na experiencia e
## voltou pra ca'. 33,5 e' escolha, nao chute.
const ESCALA_ARMA := 33.5

# ==============================================================================
# A GEOMETRIA DA ARMA — tudo em unidades do MODELO, medido nos vertices
# ==============================================================================
## Onde a casca foi cortada, e onde mora o pino da charneira. Os dois TEM de
## bater com o gerador do Blender: mexeu la', muda aqui.
const CORTE_X := -0.030
const CHARNEIRA_NO_MODELO := Vector3(-0.030, 0.057, 0.0)

## O eixo do furo dos canos: a boca (entre os dois canos) e a culatra.
const BOCA_NO_MODELO := Vector3(-0.930, -0.010, 0.0)
const CULATRA_NO_MODELO := Vector3(-0.030, 0.127, 0.0)
## Distancia do centro ate' cada camara, e a altura delas na culatra.
const CAMARA_LADO := 0.060
const CAMARA_ALTURA := 0.127

## Onde a mao DIREITA fecha: o punho da coronha, a parte estreita logo atras do
## guarda-mato (medido: e' em X=+0,48 que a largura cai pra 0,118).
const CABO_NO_MODELO := Vector3(0.500, -0.030, 0.0)
## Onde a mao ESQUERDA fecha: em cima do bloco dos canos.
const APOIO_NO_MODELO := Vector3(-0.350, 0.150, 0.0)

## Quanto a arma abre, em graus. Uma break-action de verdade abre entre 25 e 35;
## abaixo de 25 o cartucho nao passa pela culatra na tela.
const ABERTURA := 32.0

# ==============================================================================
# OS NUMEROS QUE PRECISAM DE OLHO HUMANO
#
# Da' pra acertar todos SEM recompilar: F9 dentro do jogo liga o modo de ajuste
# (ver o fim do arquivo). Tudo em CENTIMETROS e GRAUS.
# ==============================================================================
## Onde a mao DIREITA para MIRANDO, medido da ancora (o meio dos ombros).
##
## Bem mais perto do corpo que os 40 da pistola, e nao por estilo: cada
## centimetro que a direita avanca e' um centimetro que a ESQUERDA tem de
## avancar junto, 29 cm adiante, e ela nao chega (item 5 do cabecalho).
const MAOS_FRENTE := 13.0
## Desvio lateral (+ = pra direita dele). Tambem pequeno, e pelo mesmo motivo:
## desvio pra direita e' distancia a mais pro ombro esquerdo.
const MAOS_LADO := 7.2
## Altura da mao direita em relacao a' linha dos ombros. Bem abaixo delas: a arma
## fica na altura da cintura, e nao encostada no ombro. Alem de ser como ficou
## bom na tela, e' o que deixa a esquerda alcancar o cano.
const MAOS_ALTURA := -20.4

## Retoque fino por cima do cabo, no espaco da ARMA: X ao longo do cano, Y
## altura, Z lateral. Em unidades do MODELO, como na pistola.
const OFFSET_NA_MAO := Vector3(0.0, 0.0, 0.0)

# ---- o porte (arma equipada, sem mirar) ---------------------------------------
## A arma descansa atravessada na frente do corpo. Estes tres sao o quanto a mao
## direita se afasta do lugar de mira pra chegar la'.
const PORTE_RECUA := 6.0
const PORTE_DESCE := 12.0
const PORTE_LADO := 6.0
## E quanto a boca do cano cai abaixo da linha da mira, em graus.
const PORTE_ABAIXA := 26.0
## Quanto a arma atravessa pra esquerda dele no porte, em graus.
const PORTE_ATRAVESSA := 16.0

## Inclinacao da arma em volta do proprio cano (+ = tomba o topo pra direita).
const INCLINACAO_ARMA := 4.0

## O CONJUNTO GIRADO PRA DIREITA, MIRANDO. Mesmo papel do MIRA_GIRO_DIREITA da
## pistola: quem gira e' a MIRA, entao os destinos de mao e o cano vao junto.
## O tiro nao muda — ele sai de um raio da camera. Negativo: o conjunto fica um
## tiquinho pra ESQUERDA dele.
const MIRA_GIRO_DIREITA := -2.0

# ---- o punho por cima do alinhamento com a arma -------------------------------
# Zero em tudo = a mao exatamente como o cano manda. Estes sao o retoque humano,
# e valem nos eixos da ARMA, entao o que se ve' na tela e' o que o nome diz.
## Torce a mao em torno do cano. A direita e a esquerda tem valores proprios:
## uma fecha no punho da coronha por cima, a outra abraca o cano por baixo.
const PUNHO_ROLAGEM_D := 58.0
const PUNHO_ROLAGEM_E := -108.0
const PUNHO_INCLINACAO := -3.0
const PUNHO_DESVIO_D := -26.0
const PUNHO_DESVIO_E := 8.0
## Corre a mao ao longo do cano, em CENTIMETROS (so' a mao, a arma nao vai).
const PUNHO_DESLIZE := -1.0

## Quanto da torcao do punho vai pro antebraco (ver `arma_ik.dividir_torcao`).
const TORCAO_NO_ANTEBRACO := 0.5

# ---- o punho esquerdo durante a recarga ---------------------------------------
## Quanto o punho ESQUERDO roda a cada cartucho, em graus, no sentido HORARIO
## visto de tras do Maycow (que e' de onde o jogador olha).
##
## Sem isto a mao esquerda faz a viagem inteira — cinto, camara, cinto, camara —
## com a mesma orientacao do comeco ao fim, como se o cartucho entrasse sozinho.
## Ninguem enfia cartucho sem virar o pulso.
const RECARGA_GIRO_PUNHO := 60.0
## E o quanto ela ja' roda so' por ter largado o cano e estar carregando.
const RECARGA_GIRO_BASE := 22.0
## O punho esquerdo continua CONDUZIDO enquanto a mao esta' fora da arma.
##
## Antes ele era largado (peso zero) e voltava pra pose da animacao de andar:
## mao aberta, virada pra tras, parada. E' esse o "esquisito" — o gesto some
## justamente no quadro em que a mao e' o assunto.
const RECARGA_PUNHO_FIRME := 0.8

## Em volta de que ponto a mao gira: o meio do punho FECHADO, que e' por onde a
## arma passa. Pelo osso nao da': ele fica no pulso, 10 cm atras.
const PUNHO_PIVO_PALMA := 3.0
const PUNHO_PIVO_DEDOS := 9.7

# ---- a mao em volta da arma ---------------------------------------------------
const MORFO_PUNHO_D := "punho_d"
const MORFO_PUNHO_E := "punho_e"
const FECHA_MAO := 0.18
## Quanto a mao esquerda fica fechada segurando o CARTUCHO, no meio da recarga.
const PUNHO_NO_CARTUCHO := 0.55

# ---- o cotovelo ---------------------------------------------------------------
## Pra onde cada cotovelo aponta. O ESQUERDO sai muito mais pro lado que o da
## pistola: ele esta' esticado pra frente segurando o cano, e apontar ele pra
## baixo como o direito deixava o braco numa linha reta sem junta nenhuma.
const COTOVELO_BAIXO_D := 38.0
const COTOVELO_FORA_D := 20.0
const COTOVELO_BAIXO_E := 26.0
const COTOVELO_FORA_E := 30.0

# ---- quanto do sobe-e-desce do tronco chega nas maos --------------------------
const AMORTECE_TRONCO := 0.85
const AMORTECE_VELOCIDADE := 6.0
const AMORTECE_MAX := 6.0

## Tempo pra ENTRAR e SAIR da pose, quando ela e' equipada e desequipada.
const SUBIDA := 0.14
const DESCIDA := 0.22
## Tempo pra viajar entre o porte e a mira. Mais lento que a pistola de
## proposito: e' uma arma pesada, e levantar ela custa.
const LEVANTA := 0.22
const ABAIXA := 0.30

## Abaixo disto o modificador nao escreve pose nenhuma.
const PESO_MINIMO := 0.002

## Quao rapido o alvo perseguido alcanca o alvo pedido (1/s).
const SUAVIZA_ALVO := 14.0

# ==============================================================================
# A RECARGA — a linha do tempo, em fracao do gesto inteiro
#
# Os mesmos numeros estao em `player_combat.gd` (MOMENTO_*), que e' quem toca os
# sons. Eles TEM de bater: o som de encaixe fora do quadro em que a mao encaixa
# e' a coisa que mais denuncia uma animacao falsa.
#
# O miolo (0,42 a 0,90) e' quase metade do gesto por causa de UMA regra: um
# cartucho por vez, e a mao VOLTA ao cinto entre eles. Na primeira versao os
# dois entravam em 0,58 e 0,76 de um gesto de 2,8 s — 0,5 s de intervalo, e na
# tela isso nao era "um, depois o outro", era um borrao so'.
# ==============================================================================
## A arma vem pra posicao de recarga e volta.
const M_RECOLHE_FIM := 0.08
const M_SOLTA_INICIO := 0.94
## A dobra abre, fica aberta, e fecha no fim.
const M_ABRE_INICIO := 0.08
const M_ABRE_FIM := 0.20
const M_FECHA_INICIO := 0.90
const M_FECHA_FIM := 0.97
## Ela vira de lado pra despejar as capsulas, e volta.
const M_VIRA_INICIO := 0.22
const M_VIRA_FIM := 0.30
const M_DESVIRA_INICIO := 0.34
const M_DESVIRA_FIM := 0.42
## As capsulas caem no pico da virada.
const M_EJETA := 0.31
## A mao esquerda larga o fore-end e volta pra ele.
const M_LARGA := 0.42
const M_VOLTA := 0.90
## Primeiro cartucho: sai do cinto, viaja, entra.
const M_BALA1_PEGA := 0.48
const M_BALA1_ENTRA := 0.60
## E a mao VOLTA ao cinto antes do segundo. E' esta ida e volta no meio que faz
## o gesto ler como dois cartuchos e nao como um movimento so'.
const M_BALA2_PEGA := 0.72
const M_BALA2_ENTRA := 0.84

## Pra onde a arma vai enquanto e' recarregada.
##
## Pra FRENTE, e nao pra tras. A pistola recolhe pro peito porque e' curta e o
## pente entra por baixo, escondido; uma break-action se recarrega com os bracos
## estendidos, onde os olhos alcancam a culatra. E ha' um motivo de geometria
## por cima do motivo de gesto: com o cabo ja' quase no plano do ombro, puxar
## pra tras botava a coronha — que sai 15 cm atras do cabo — atravessando o
## tronco. Na foto de lado dava pra ver o cano saindo pelas costas dele.
const RECARGA_AFASTA := 12.0
## Sobe um tiquinho junto: a culatra tem de ficar na linha dos olhos.
const RECARGA_SOBE := 3.0
## E corre pra ESQUERDA dele (negativo), atravessando o peito. E' onde as duas
## maos se encontram, e tira a coronha de dentro da axila direita.
const RECARGA_LADO := -6.0
## Quanto o cano ABAIXA na posicao de recarga. Positivo desce a boca — o mesmo
## sentido da charneira, e pelo mesmo motivo: nos eixos do modelo, girar no +Z
## leva o -X (a boca) pra baixo. E tem de descer mesmo: cartucho nao sobe
## sozinho pra dentro da camara.
const RECARGA_LEVANTA := 14.0
## Quanto ela vira em torno do cano pra despejar as capsulas. Numero grande de
## proposito: o jogador tem de VER a culatra virando pra baixo.
const RECARGA_VIRA := 72.0

## Onde a mao esquerda vai buscar o cartucho: cintura, do lado dela.
const CINTO_LADO := 17.0
const CINTO_ALTURA := 33.0
const CINTO_FRENTE := 4.0

var _mirando: bool = false
var _alvo := Vector3.ZERO
var _alvo_suave := Vector3.ZERO
var _tem_alvo := false
## Quanto a pose inteira vale (0 = arma guardada, 1 = nas maos).
var _peso := 0.0
## Quanto ela esta' LEVANTADA: 0 = porte, 1 = mira.
var _apontando := 0.0

var _recarregando := false
var _recarga := 0.0
var _recarga_total := 1.0

var _i_braco_d := -1
var _i_ante_d := -1
var _i_mao_d := -1
var _i_braco_e := -1
var _i_ante_e := -1
var _i_mao_e := -1

var _malha: MeshInstance3D = null
var _arma: Node3D = null
var _charneira: Node3D = null
## Pose da arma no ultimo quadro, no espaco da MALHA (centimetros), SEM escala.
var _pose_arma := Transform3D.IDENTITY
## Quanto a arma esta' aberta agora, em radianos. O tiro e a ejecao perguntam.
var _dobra := 0.0
var _ancora_suave := Vector3.ZERO
var _tem_ancora := false

var _morfo_d := -1
var _morfo_e := -1
var _fechada_d := 0.0
var _fechada_e := 0.0

## Valores em uso. Nascem das constantes e so' mudam no modo de ajuste.
var _cabo := CABO_NO_MODELO
var _offset := OFFSET_NA_MAO
var _apoio := APOIO_NO_MODELO
var _escala := ESCALA_ARMA
var _frente := MAOS_FRENTE
var _lado := MAOS_LADO
var _altura := MAOS_ALTURA
var _inclinacao := INCLINACAO_ARMA
var _giro_mira := MIRA_GIRO_DIREITA
var _rolagem_d := PUNHO_ROLAGEM_D
var _rolagem_e := PUNHO_ROLAGEM_E
var _desvio_d := PUNHO_DESVIO_D
var _desvio_e := PUNHO_DESVIO_E


# ==============================================================================
# O QUE O PLAYER CHAMA
# ==============================================================================
## Liga/desliga a pose de MIRA e diz pra onde o cano aponta (mundo).
##
## Desligar NAO solta a arma: ela volta pro porte, que tambem e' com as duas
## maos. Quem tira a arma das maos e' desequipar ela.
func mirar(ativo: bool, ponto: Vector3 = Vector3.ZERO) -> void:
	_mirando = ativo
	if ativo:
		_alvo = ponto
		if not _tem_alvo:
			# Primeiro quadro da mirada: comeca ja' no alvo, senao a arma sobe
			# perseguindo um ponto que ficou pra tras.
			_alvo_suave = ponto
			_tem_alvo = true
	else:
		_tem_alvo = false


## Toca a recarga.
func recarregar(tempo: float) -> void:
	_recarga_total = maxf(0.6, tempo)
	_recarga = 0.0
	_recarregando = true


func esta_recarregando() -> bool:
	return _recarregando


## A arma esta' montada e visivel?
func tem_arma_na_mao() -> bool:
	return is_instance_valid(_arma) and _arma.visible


## Onde fica a boca do cano, em coordenadas de MUNDO.
func boca_do_cano() -> Vector3:
	return _no_mundo(BOCA_NO_MODELO)


## Pra onde o cano aponta, em coordenadas de MUNDO (vetor unitario).
##
## Sai dos DOIS pontos medidos do furo, e nao de um eixo do modelo: a arma esta'
## desenhada inclinada (item 3 do cabecalho).
func direcao_do_cano() -> Vector3:
	var boca := _no_mundo(BOCA_NO_MODELO)
	var culatra := _no_mundo(CULATRA_NO_MODELO)
	var v := boca - culatra
	return v.normalized() if v.length_squared() > 0.0001 else Vector3.FORWARD


## Onde estao as duas bocas de camara AGORA, em MUNDO — ja' contando o quanto a
## arma esta' aberta. E' de onde as capsulas caem.
func bocas_das_camaras() -> Array[Vector3]:
	var pontos: Array[Vector3] = []
	for lado in [-1.0, 1.0]:
		pontos.append(_no_mundo(Vector3(CORTE_X, CAMARA_ALTURA, lado * CAMARA_LADO)))
	return pontos


## Quanto a arma esta' aberta, de 0 (fechada) a 1 (escancarada).
func quanto_aberta() -> float:
	return _dobra / deg_to_rad(ABERTURA) if ABERTURA > 0.0 else 0.0


# ==============================================================================
# O QUADRO
# ==============================================================================
## Roda dentro da fase de modificacao do esqueleto — o unico momento em que a
## pose lida e' a pose que vai pra tela.
##
## A ordem dos cinco passos esta' no item 1 do cabecalho, e nao e' negociavel:
## a mao esquerda so' tem destino DEPOIS que a arma tem lugar, e a arma so' tem
## lugar depois que o osso da mao direita parou de se mexer.
func _process_modification_with_delta(delta: float) -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	# -2 e' "ja' procurei e este rig nao tem os ossos".
	if _i_braco_d == -2:
		return
	if _i_braco_d < 0 and not _procurar_ossos(sk):
		return

	var equipada: bool = SaveManager.is_equipped(ITEM_SHOTGUN)
	_garantir_arma(equipada)

	# O peso e' 1 enquanto ela estiver EQUIPADA: com uma arma longa nao existe
	# quadro de maos soltas (item 2 do cabecalho).
	if equipada:
		_peso = minf(1.0, _peso + delta / SUBIDA)
	else:
		_peso = maxf(0.0, _peso - delta / DESCIDA)
		_recarregando = false
		_dobra = 0.0
		_apontando = 0.0
		if _peso <= PESO_MINIMO:
			# Com a arma guardada as maos NAO sao abertas aqui: quem zera os
			# morfos e' o `player_gun_hold.gd`, que roda no mesmo esqueleto e
			# ja' faz isso. Duas canetas no mesmo papel so' brigariam.
			return

	if _recarregando:
		_recarga += delta / _recarga_total
		if _recarga >= 1.0:
			_recarregando = false
			_recarga = 0.0

	# Recarregar levanta a arma como mirar levanta: e' a mesma pose alta, com
	# desvios por cima.
	var quer_apontar := 1.0 if (_mirando or _recarregando) else 0.0
	var passo := delta / (LEVANTA if quer_apontar > _apontando else ABAIXA)
	_apontando = move_toward(_apontando, quer_apontar, passo)
	if _mirando:
		_alvo_suave = _alvo_suave.lerp(_alvo, minf(1.0, delta * SUAVIZA_ALVO))

	# Suaviza as pontas: sem isto o braco arranca e para em seco.
	var peso := smoothstep(0.0, 1.0, _peso)
	var apontando := smoothstep(0.0, 1.0, _apontando)
	# O alvo chega em MUNDO e tudo aqui dentro e' espaco de OSSO. Converter aqui,
	# uma vez, e' o que mantem as duas contas no mesmo mundo.
	var ctx := _montar_contexto(sk, _para_ossos(sk, _alvo_suave), peso, apontando,
		delta)
	_dobra = float(ctx["dobra"])

	# 1 e 2. A mao direita, e o braco ate' ela.
	IK.braco(sk, _i_braco_d, _i_ante_d, _i_mao_d,
		ctx["mao_d"], ctx["polo_d"], peso)

	# 3. A arma pousa NO OSSO da mao direita — e' este passo que a poe na mao
	#    em vez de no ar (item 1 do cabecalho).
	_pousar_arma(sk, ctx)

	# 4 e 5. So' agora a esquerda tem pra onde ir.
	var mao_e := _destino_da_esquerda(ctx)
	var polo_e: Vector3 = mao_e - Vector3.UP * COTOVELO_BAIXO_E \
		- (ctx["direita"] as Vector3) * COTOVELO_FORA_E
	IK.braco(sk, _i_braco_e, _i_ante_e, _i_mao_e, mao_e, polo_e, peso)

	# Os punhos por ultimo: e' a pose da arma que diz pra onde eles olham.
	var solta: float = ctx["solta"]
	var na_arma := peso * (1.0 - solta)
	# O punho esquerdo NAO e' largado na recarga: fica conduzido (com um pouco
	# menos de forca) e ganha o giro por cima — ver `_giro_do_punho`.
	var punho_e := maxf(na_arma, peso * RECARGA_PUNHO_FIRME * solta)
	_alinhar_punho(sk, _i_mao_d, -1.0, peso, _rolagem_d, _desvio_d)
	_alinhar_punho(sk, _i_mao_e, 1.0, punho_e,
		_rolagem_e + _giro_do_punho(float(ctx["r"]), solta), _desvio_e)
	_fechar_maos(peso, maxf(na_arma, PUNHO_NO_CARTUCHO * solta * peso), delta)


## Onde tudo e' medido neste quadro: a ancora no tronco, os eixos da mira, o
## destino da mao DIREITA e os numeros da recarga. Espaco dos OSSOS, cm.
func _montar_contexto(sk: Skeleton3D, alvo: Vector3, peso: float,
		apontando: float, delta: float) -> Dictionary:
	var raiz_d := IK.raiz_estavel(sk, _i_braco_d).origin
	var raiz_e := IK.raiz_estavel(sk, _i_braco_e).origin
	var ancora := _amortecer((raiz_d + raiz_e) * 0.5, peso, delta)

	# Eixos da mira. No espaco dos ossos o corpo olha pro +Z e o Y e' cima.
	var mira := alvo if _tem_alvo else ancora + Vector3(0, 0, 500.0)
	mira = IK.para_a_direita(ancora, mira, _giro_mira)
	var dir := (mira - ancora)
	dir = dir.normalized() if dir.length_squared() > 0.0001 else Vector3(0, 0, 1)
	var direita := dir.cross(Vector3.UP)
	if direita.length_squared() < 0.0001:
		direita = Vector3(1, 0, 0)
	direita = direita.normalized()
	var cima := direita.cross(dir).normalized()

	var r := _recarga if _recarregando else 0.0
	var recolhe := 0.0
	var dobra := 0.0
	var vira := 0.0
	var solta := 0.0
	if _recarregando:
		recolhe = smoothstep(0.0, M_RECOLHE_FIM, r) - smoothstep(M_SOLTA_INICIO, 1.0, r)
		dobra = smoothstep(M_ABRE_INICIO, M_ABRE_FIM, r) \
			- smoothstep(M_FECHA_INICIO, M_FECHA_FIM, r)
		vira = smoothstep(M_VIRA_INICIO, M_VIRA_FIM, r) \
			- smoothstep(M_DESVIRA_INICIO, M_DESVIRA_FIM, r)
		solta = smoothstep(M_LARGA, M_BALA1_PEGA, r) \
			- smoothstep(M_BALA2_ENTRA, M_VOLTA, r)

	# ---- onde a mao DIREITA para ------------------------------------------
	# A mira e' o lugar alto; o porte e' ele mesmo, puxado pra tras, pra baixo
	# e pro lado. `apontando` faz a viagem entre os dois.
	var na_mira := ancora + dir * _frente + direita * _lado + cima * _altura
	var no_porte := na_mira - dir * PORTE_RECUA - cima * PORTE_DESCE \
		+ direita * PORTE_LADO
	var mao_d := no_porte.lerp(na_mira, apontando)
	mao_d += (dir * RECARGA_AFASTA + cima * RECARGA_SOBE
		+ direita * RECARGA_LADO) * recolhe

	return {
		"dir": dir, "direita": direita, "cima": cima, "ancora": ancora,
		"apontando": apontando, "recolhe": recolhe, "vira": vira,
		"dobra": deg_to_rad(ABERTURA) * dobra, "solta": solta, "r": r,
		"mao_d": mao_d,
		"polo_d": mao_d - Vector3.UP * COTOVELO_BAIXO_D + direita * COTOVELO_FORA_D,
	}


## Poe a arma na mao direita, segurada PELO CABO.
##
## A posicao sai do OSSO da mao, e nao do destino calculado: sao quase o mesmo
## ponto (o IK acabou de levar um ao outro), mas quase nao basta — e' o osso que
## a pele segue, e um centimetro de diferenca e' a arma flutuando ao lado da
## mao. Mesma escolha da pistola, pelo mesmo motivo.
func _pousar_arma(sk: Skeleton3D, ctx: Dictionary) -> void:
	var g_mao := sk.get_bone_global_pose(_i_mao_d)
	var base := _base_da_arma(ctx)
	var cabo := base * _ponto(_cabo + _offset, 0.0)
	_pose_arma = Transform3D(base, g_mao.origin - cabo)
	_aplicar_arma()


## A orientacao da arma: o EIXO DO FURO apontando pra onde ela deve apontar.
##
## Dois passos de proposito (item 3 do cabecalho). O primeiro monta uma base
## grosseira, alinhada com a direcao pedida, do jeito que a pistola faz. O
## segundo mede pra onde o furo ficou apontando NESSA base e aplica o giro
## minimo que leva ele ate' a direcao certa. Assim a inclinacao com que a arma
## foi desenhada se cancela sozinha, sem constante e sem sinal pra errar.
func _base_da_arma(ctx: Dictionary) -> Basis:
	var dir: Vector3 = ctx["dir"]
	var direita: Vector3 = ctx["direita"]
	var cima: Vector3 = ctx["cima"]
	var apontando: float = ctx["apontando"]

	# No PORTE o cano nao aponta pra mira: cai pra baixo e atravessa pra
	# esquerda dele. E' a diferenca entre "carregando" e "pronto pra atirar".
	var aponta_pra := dir
	if apontando < 0.999:
		var abaixado := dir.rotated(direita, -deg_to_rad(PORTE_ABAIXA))
		abaixado = abaixado.rotated(cima, deg_to_rad(PORTE_ATRAVESSA))
		aponta_pra = abaixado.slerp(dir, apontando).normalized()

	var eixo_x := -aponta_pra
	var alto := cima
	if absf(alto.dot(eixo_x)) > 0.98:
		alto = Vector3.UP
	var eixo_z := eixo_x.cross(alto).normalized()
	var eixo_y := eixo_z.cross(eixo_x).normalized()
	var base := Basis(eixo_x, eixo_y, eixo_z)

	var furo := (BOCA_NO_MODELO - CULATRA_NO_MODELO).normalized()
	var apontado := (base * furo).normalized()
	base = Basis(Quaternion(apontado, aponta_pra)) * base

	# Os retoques giram em volta dos eixos DA ARMA ja' apontada.
	var cano := (base * furo).normalized()
	var lado_da_arma := (base * Vector3(0.0, 0.0, 1.0)).normalized()
	base = base.rotated(cano, deg_to_rad(_inclinacao + RECARGA_VIRA * float(ctx["vira"])))
	var recolhe: float = ctx["recolhe"]
	if recolhe > 0.0:
		base = base.rotated(lado_da_arma, deg_to_rad(RECARGA_LEVANTA * recolhe))
	return base


## Pra onde vai a mao ESQUERDA neste quadro.
##
## Fora da recarga ela esta' no fore-end e pronto — e ESTA', em todo quadro em
## que a arma estiver equipada (item 2 do cabecalho). Dentro da recarga o gesto
## e' uma sequencia de trechos, e cada trecho e' um lerp entre dois pontos:
##
##     fore-end -> cinto -> camara 1 -> cinto -> camara 2 -> fore-end
##
## Escrito como sequencia, e nao como soma de envelopes, porque e' assim que se
## le': a mao esta' indo DE um lugar PRA outro. E a volta ao cinto no meio nao
## e' enfeite — e' ela que faz o gesto ler como DOIS cartuchos.
func _destino_da_esquerda(ctx: Dictionary) -> Vector3:
	var dobra: float = ctx["dobra"]
	# O fore-end esta' na peca que DOBRA: com a arma aberta ele desceu junto, e
	# a mao tem de descer com ele — e' ela que esta' empurrando.
	var fore := _pose_arma * _ponto(_apoio, dobra)
	if not _recarregando:
		return fore

	var r: float = ctx["r"]
	var cinto: Vector3 = (ctx["ancora"] as Vector3) \
		- (ctx["direita"] as Vector3) * CINTO_LADO \
		- (ctx["cima"] as Vector3) * CINTO_ALTURA \
		- (ctx["dir"] as Vector3) * CINTO_FRENTE
	var camara_1 := _pose_arma * _ponto(
		Vector3(CORTE_X, CAMARA_ALTURA, -CAMARA_LADO), dobra)
	var camara_2 := _pose_arma * _ponto(
		Vector3(CORTE_X, CAMARA_ALTURA, CAMARA_LADO), dobra)

	var trechos := [
		[M_LARGA, M_BALA1_PEGA, fore, cinto],
		[M_BALA1_PEGA, M_BALA1_ENTRA, cinto, camara_1],
		[M_BALA1_ENTRA, M_BALA2_PEGA, camara_1, cinto],
		[M_BALA2_PEGA, M_BALA2_ENTRA, cinto, camara_2],
		[M_BALA2_ENTRA, M_VOLTA, camara_2, fore],
	]
	for t in trechos:
		if r < float(t[0]):
			break
		if r < float(t[1]):
			return (t[2] as Vector3).lerp(t[3] as Vector3,
				smoothstep(float(t[0]), float(t[1]), r))
	return fore


## Ponto do MODELO no espaco da ARMA (ja' em centimetros), contando a dobra.
##
## Tudo o que esta' na FRENTE do corte viaja com os canos: gira em volta do pino
## antes de virar posicao. Nao ha' atalho aqui — a boca do cano, as duas camaras
## e o fore-end sao todos pontos que se mexem quando ela abre.
func _ponto(p: Vector3, dobra: float) -> Vector3:
	var q := p
	if p.x < CORTE_X and absf(dobra) > 0.0001:
		var rel := p - CHARNEIRA_NO_MODELO
		var c := cos(dobra)
		var s := sin(dobra)
		q = CHARNEIRA_NO_MODELO + Vector3(
			rel.x * c - rel.y * s, rel.x * s + rel.y * c, rel.z)
	return q * _escala


## O mesmo ponto, em coordenadas de MUNDO. A malha e' o espaco em que a arma
## vive (ela e' filha dela), entao e' a global DELA que converte.
func _no_mundo(p: Vector3) -> Vector3:
	if not is_instance_valid(_malha):
		return Vector3.ZERO
	return _malha.global_transform * (_pose_arma * _ponto(p, _dobra))


## Escreve a pose calculada no no' da arma, e a dobra na charneira.
func _aplicar_arma() -> void:
	if not is_instance_valid(_arma) or not _arma.visible:
		return
	_arma.transform = Transform3D(
		_pose_arma.basis.scaled(Vector3.ONE * _escala), _pose_arma.origin)
	if is_instance_valid(_charneira):
		# Positivo desce a boca do cano — conferido no gerador do Blender.
		_charneira.rotation.z = _dobra


## Ponto do MUNDO no espaco dos ossos (centimetros, e girado com o char1).
func _para_ossos(sk: Skeleton3D, ponto: Vector3) -> Vector3:
	var espaco := _malha.global_transform if is_instance_valid(_malha) \
		else sk.global_transform
	return espaco.affine_inverse() * ponto


## Filtra o sobe-e-desce do tronco do ponto de onde as maos sao medidas.
func _amortecer(ancora: Vector3, peso: float, delta: float) -> Vector3:
	if AMORTECE_TRONCO <= 0.0:
		return ancora
	if not _tem_ancora:
		_ancora_suave = ancora
		_tem_ancora = true
	_ancora_suave = _ancora_suave.lerp(ancora, minf(1.0, delta * AMORTECE_VELOCIDADE))

	var desejada := ancora.lerp(_ancora_suave, AMORTECE_TRONCO * peso)
	var desvio := desejada - ancora
	if desvio.length() > AMORTECE_MAX:
		desejada = ancora + desvio.normalized() * AMORTECE_MAX
	return desejada


# ==============================================================================
# A MAO EM VOLTA DA ARMA
# ==============================================================================
## Vira o punho pra mao ficar EM VOLTA da arma, e nao ao lado dela.
##
## No espaco do osso da mao, +Y aponta pras pontas dos dedos e X e' a normal da
## palma (+X na direita, -X na esquerda, que e' espelhada). Entao: os dedos
## apontam pra onde o CANO aponta, e a palma olha pra arma.
##
## A rolagem e o desvio entram por PARAMETRO, e nao por constante como na
## pistola: ali as duas maos fecham no mesmo cabo e o mesmo numero serve; aqui
## uma fecha no punho da coronha por cima e a outra abraca o cano por baixo, do
## lado oposto, e obrigar as duas ao mesmo valor torce uma das duas.
func _alinhar_punho(sk: Skeleton3D, i_mao: int, palma: float, peso: float,
		rolagem: float, desvio: float) -> void:
	if i_mao < 0 or peso <= 0.001:
		return
	var dedos := -_pose_arma.basis.x
	var normal := _pose_arma.basis.y * palma
	if dedos.length_squared() < 0.0001:
		return
	var alvo := Basis(normal, dedos, normal.cross(dedos)).orthonormalized()
	var g := sk.get_bone_global_pose(i_mao)
	var pivo := Vector3(PUNHO_PIVO_PALMA * -palma, PUNHO_PIVO_DEDOS, 0.0)
	var na_arma := g.origin + alvo * pivo

	alvo = alvo.rotated(dedos, deg_to_rad(rolagem))
	alvo = alvo.rotated(_pose_arma.basis.z, deg_to_rad(PUNHO_INCLINACAO))
	alvo = alvo.rotated(_pose_arma.basis.y, deg_to_rad(desvio))

	var origem := na_arma - alvo * pivo + dedos * PUNHO_DESLIZE
	var final_basis := g.basis.slerp(alvo, peso)
	IK.dividir_torcao(sk, i_mao, final_basis, TORCAO_NO_ANTEBRACO)
	sk.set_bone_global_pose(i_mao, Transform3D(final_basis,
		g.origin.lerp(origem, peso)))


## O GIRO DO PUNHO ESQUERDO NA RECARGA, em graus.
##
## Positivo e' horario visto de tras do Maycow: o eixo do giro e' o dedo
## apontado pra boca do cano, ou seja, apontado PRA LONGE da camera, e giro
## positivo em volta de um eixo que se afasta aparece horario.
##
## Duas coisas somadas:
##
##     base    entra junto com o largar do cano e sai junto com o pegar de volta
##     pulso   um por cartucho: sobe indo pra camara e desce voltando
##
## O pulso e' zero nos dois extremos de proposito — e' o "gira e volta". Se ele
## ficasse em pe' entre um cartucho e outro, o segundo nao teria giro nenhum
## pra fazer e a mao chegaria na camara ja' torcida.
func _giro_do_punho(r: float, solta: float) -> float:
	if not _recarregando:
		return 0.0
	var pulso := _pulso(r, M_BALA1_PEGA, M_BALA1_ENTRA, M_BALA2_PEGA) \
		+ _pulso(r, M_BALA2_PEGA, M_BALA2_ENTRA, M_VOLTA)
	return RECARGA_GIRO_BASE * solta + RECARGA_GIRO_PUNHO * pulso


## Sobe de `ini` ate' `pico` e volta a zero em `fim`. Fora disso, zero.
static func _pulso(r: float, ini: float, pico: float, fim: float) -> float:
	if r <= ini or r >= fim:
		return 0.0
	if r < pico:
		return smoothstep(ini, pico, r)
	return 1.0 - smoothstep(pico, fim, r)


## Fecha a mao pelo morph target (ver `tools/modelos/gerar_punho_maycow.py`).
func _fechar_maos(alvo_d: float, alvo_e: float, delta: float) -> void:
	if _morfo_d == -2 or not is_instance_valid(_malha):
		return
	if _morfo_d < 0:
		_morfo_d = _malha.find_blend_shape_by_name(MORFO_PUNHO_D)
		_morfo_e = _malha.find_blend_shape_by_name(MORFO_PUNHO_E)
		if _morfo_d < 0 or _morfo_e < 0:
			push_warning("player_shotgun_hold: o modelo nao tem os morphs de "
				+ "mao fechada — rode tools/modelos/gerar_punho_maycow.py")
			_morfo_d = -2
			return
	var passo := delta / FECHA_MAO
	_fechada_d = move_toward(_fechada_d, alvo_d, passo)
	_fechada_e = move_toward(_fechada_e, alvo_e, passo)
	_malha.set_blend_shape_value(_morfo_d, _fechada_d)
	_malha.set_blend_shape_value(_morfo_e, _fechada_e)


## Monta (uma vez) ou esconde o modelo da arma.
##
## Ela e' filha da MALHA e nao deste no': este no' e' filho do Skeleton3D, e o
## espaco do esqueleto esta' 180 graus virado do corpo que se ve'.
func _garantir_arma(equipada: bool) -> void:
	if not is_instance_valid(_arma):
		if not equipada or not is_instance_valid(_malha):
			return
		var pacote: PackedScene = load(MODELO_SHOTGUN)
		if pacote == null:
			push_warning("player_shotgun_hold: nao achei %s" % MODELO_SHOTGUN)
			_i_braco_d = -2
			return
		_arma = pacote.instantiate()
		_arma.name = "ShotgunNaMao"
		# Nada de colisao vinda do .glb: a arma anda colada no corpo e um corpo
		# fisico ali dentro brigaria com a capsula do jogador.
		for col in _arma.find_children("*", "CollisionObject3D", true, false):
			col.collision_layer = 0
			col.collision_mask = 0
		_malha.add_child(_arma)
		_charneira = _arma.find_child(NO_CHARNEIRA, true, false) as Node3D
		if _charneira == null:
			push_warning("player_shotgun_hold: o .glb nao tem o no' '%s' — a "
				% NO_CHARNEIRA + "arma nao vai dobrar. Rode "
				+ "tools/blender/shotgun/gerar_shotgun.py")
	_arma.visible = equipada


func _procurar_ossos(sk: Skeleton3D) -> bool:
	for filho in sk.get_children():
		if filho is MeshInstance3D:
			_malha = filho
			break
	_i_braco_d = sk.find_bone(OSSO_BRACO_D)
	_i_ante_d = sk.find_bone(OSSO_ANTEBRACO_D)
	_i_mao_d = sk.find_bone(OSSO_MAO_D)
	_i_braco_e = sk.find_bone(OSSO_BRACO_E)
	_i_ante_e = sk.find_bone(OSSO_ANTEBRACO_E)
	_i_mao_e = sk.find_bone(OSSO_MAO_E)
	if mini(mini(_i_braco_d, _i_ante_d), mini(_i_mao_d, _i_braco_e)) < 0 \
			or mini(_i_ante_e, _i_mao_e) < 0:
		push_warning("player_shotgun_hold: rig sem os ossos de braco — a arma "
			+ "nao vai pra mao")
		_i_braco_d = -2
		return false
	return true


# ==============================================================================
# MODO DE AJUSTE — acertar a POSE sem recompilar
# ==============================================================================
## As MESMAS teclas do modo de ajuste da pistola (F9 liga, G troca o alvo, P
## imprime), de proposito: sao a mesma tarefa e a mao ja' sabe onde fica.
##
## Os dois modificadores vivem no mesmo esqueleto e ouvem o mesmo teclado, entao
## cada um so' responde quando a SUA arma esta' equipada — senao um F9 ligava os
## dois e cada tecla imprimia dois blocos.
##
##     G       troca entre ARMA, MAO D e MAO E (o P mostra qual esta' ligado)
##
##   com a ARMA ligada (as maos acompanham, porque elas seguem a arma):
##     I / K   arma pra frente / pra tras
##     U / O   sobe / desce
##     J / L   pra dentro / pra fora (lateral)
##     N / M   inclina a arma em volta do proprio cano
##     V / B   gira o conjunto pra esquerda / pra direita (so' mirando)
##     T / Y   ENCOLHE / AUMENTA a arma inteira
##     R / F   corre o ponto da MAO ESQUERDA pra tras / pra frente no cano
##
##   com uma MAO ligada (gira em volta da arma, a arma nao se mexe):
##     U / O   torce a mao em torno do cano (rolagem)
##     J / L   gira a mao pra um lado e pro outro (desvio)
##
##     P       imprime as linhas prontas pra colar
##     F9      sai do modo
##
## O T/Y e o R/F sao os unicos que a pistola nao tem, e existem porque aqui eles
## sao AMARRADOS: crescer a arma sem trazer o apoio pra tras desgruda a mao
## esquerda (item 5 do cabecalho). Por isso o print mostra o VAO entre as duas
## maos em centimetros — e' esse numero, e nao a escala, que tem de caber no
## braco. Acima de uns 30 cm a mao esquerda comeca a nao alcancar.
const AJUSTE_PASSO := 0.2       # centimetros por toque
const AJUSTE_PASSO_ANG := 1.0   # graus por toque
const AJUSTE_PASSO_ESCALA := 0.5

var _ajustando := false
## 0 = arma, 1 = mao direita, 2 = mao esquerda.
var _ajustando_o_que := 0


func _input(event: InputEvent) -> void:
	if not OS.is_debug_build() or not (event is InputEventKey):
		return
	if not SaveManager.is_equipped(ITEM_SHOTGUN):
		return
	var tecla := event as InputEventKey
	if not tecla.pressed:
		return

	if tecla.keycode == KEY_F9 and not tecla.echo:
		_ajustando = not _ajustando
		if _ajustando:
			print("ajuste da CACADEIRA ligado — G troca alvo, P imprime, F9 sai")
			_imprimir_ajuste()
		else:
			print("ajuste da cacadeira desligado")
		return

	if not _ajustando:
		return

	if tecla.keycode == KEY_G and not tecla.echo:
		_ajustando_o_que = (_ajustando_o_que + 1) % 3
		get_viewport().set_input_as_handled()
		_imprimir_ajuste()
		return

	if _ajustando_o_que == 0:
		match tecla.keycode:
			KEY_I: _frente += AJUSTE_PASSO
			KEY_K: _frente -= AJUSTE_PASSO
			KEY_U: _altura += AJUSTE_PASSO
			KEY_O: _altura -= AJUSTE_PASSO
			KEY_J: _lado -= AJUSTE_PASSO
			KEY_L: _lado += AJUSTE_PASSO
			KEY_N: _inclinacao -= AJUSTE_PASSO_ANG
			KEY_M: _inclinacao += AJUSTE_PASSO_ANG
			KEY_V: _giro_mira -= AJUSTE_PASSO_ANG
			KEY_B: _giro_mira += AJUSTE_PASSO_ANG
			KEY_T: _escala = maxf(5.0, _escala - AJUSTE_PASSO_ESCALA)
			KEY_Y: _escala += AJUSTE_PASSO_ESCALA
			KEY_R: _apoio.x += AJUSTE_PASSO / _escala
			KEY_F: _apoio.x -= AJUSTE_PASSO / _escala
			KEY_P: _imprimir_ajuste()
			_: return
	elif _ajustando_o_que == 1:
		match tecla.keycode:
			KEY_U: _rolagem_d -= AJUSTE_PASSO_ANG
			KEY_O: _rolagem_d += AJUSTE_PASSO_ANG
			KEY_J: _desvio_d -= AJUSTE_PASSO_ANG
			KEY_L: _desvio_d += AJUSTE_PASSO_ANG
			KEY_P: _imprimir_ajuste()
			_: return
	else:
		match tecla.keycode:
			KEY_U: _rolagem_e -= AJUSTE_PASSO_ANG
			KEY_O: _rolagem_e += AJUSTE_PASSO_ANG
			KEY_J: _desvio_e -= AJUSTE_PASSO_ANG
			KEY_L: _desvio_e += AJUSTE_PASSO_ANG
			KEY_P: _imprimir_ajuste()
			_: return
	get_viewport().set_input_as_handled()
	if tecla.keycode != KEY_P:
		_imprimir_ajuste()


## Imprime os tres conjuntos, com uma seta no que as teclas estao mexendo.
func _imprimir_ajuste() -> void:
	var setas := [" ", " ", " "]
	setas[_ajustando_o_que] = ">"
	var vao := (_cabo - _apoio).length() * _escala
	print("%s [arma]  const MAOS_FRENTE := %.1f   |   const MAOS_LADO := %.1f"
		% [setas[0], _frente, _lado]
		+ "   |   const MAOS_ALTURA := %.1f" % _altura
		+ "   |   const INCLINACAO_ARMA := %.1f" % _inclinacao
		+ "   |   const MIRA_GIRO_DIREITA := %.1f" % _giro_mira)
	print("         const ESCALA_ARMA := %.1f" % _escala
		+ "   |   const APOIO_NO_MODELO := Vector3(%.3f, %.3f, %.3f)"
		% [_apoio.x, _apoio.y, _apoio.z]
		+ "   [arma %.0f cm, vao entre as maos %.0f cm]"
		% [1.913 * _escala, vao])
	print("%s [mao D] const PUNHO_ROLAGEM_D := %.1f   |   const PUNHO_DESVIO_D := %.1f"
		% [setas[1], _rolagem_d, _desvio_d])
	print("%s [mao E] const PUNHO_ROLAGEM_E := %.1f   |   const PUNHO_DESVIO_E := %.1f"
		% [setas[2], _rolagem_e, _desvio_e])
