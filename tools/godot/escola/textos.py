"""Tudo o que se LE dentro da escola: lousa, placa, cartaz, aviso, rabisco.

    python3 tools/godot/escola/textos.py        # sincroniza o CSV

Cada texto e' um `Label3D` com a CHAVE no `text`; o Godot traduz sozinho (e
retraduz quando o idioma muda no menu). A chave e as duas linguas moram aqui,
ao lado de quem posiciona o texto, e `sincronizar()` as escreve em
`assets/textos/red_valve_textos_gerais.csv`:

  - chave que ja' existe no CSV e' ATUALIZADA no lugar (a linha nao muda de
    posicao, o diff fica limpo);
  - chave nova entra logo depois do bloco `ESC_` que ja' existe, e nao no fim
    do arquivo — o CSV e' editado por outras frentes ao mesmo tempo, e enfiar
    linha no fim e' onde dois trabalhos se atropelam.

O CSV tem `unescape_translations=true` no .import, entao `\\n` escrito aqui
vira quebra de linha de verdade na lousa.

==============================================================================
O TOM

E' uma escola publica de cidade pequena, fechada as pressas. O que esta' escrito
nas paredes e' o que estava escrito no ultimo dia de aula — tarefa, cardapio,
reuniao de pais — e, por cima, o que alguem escreveu DEPOIS. O medo vem do
contraste: a letra caprichada da professora e, embaixo, a mesma frase repetida
cinquenta vezes.
"""

import csv
import io
import os

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__)))))
CSV = os.path.join(RAIZ, "red-valve", "assets", "textos",
                   "red_valve_textos_gerais.csv")

# chave: (ingles, portugues)
TEXTOS = {
    # ------------------------------------------------------------------
    # LOUSAS — uma por sala, o que ficou escrito no ultimo dia
    # ------------------------------------------------------------------
    "ESC_LOUSA_101": (
        "Monday\\nHOMEWORK: pages 32 to 35\\nBring the signed\\nfield trip permission slip!",
        "Segunda-feira\\nTAREFA: páginas 32 a 35\\nTrazer a autorização\\nda excursão assinada!"),
    "ESC_LOUSA_102": (
        "7 x 8 = 56\\n9 x 6 = 54\\n12 ÷ 4 = 3\\n30 - 1 = 29\\n29 - 1 = 28\\n28 - 1 = ...\\nhow many of us are left?",
        "7 x 8 = 56\\n9 x 6 = 54\\n12 ÷ 4 = 3\\n30 - 1 = 29\\n29 - 1 = 28\\n28 - 1 = ...\\nquantos de nós sobraram?"),
    "ESC_LOUSA_103": (
        "TOWN HISTORY\\nWhy is the valve red?\\nAsk your grandparents.\\nDue: Friday",
        "HISTÓRIA DA CIDADE\\nPor que a válvula é vermelha?\\nPerguntar aos avós.\\nEntrega: sexta"),
    "ESC_LOUSA_104": (
        "I will not go down to the basement.\\nI will not go down to the basement.\\n"
        "I will not go down to the basement.\\nI will not go down to the basement.\\n"
        "I will not go down to the basement.\\nI will not go down to the basement.\\n"
        "I will not go down to the",
        "Eu não vou descer ao porão.\\nEu não vou descer ao porão.\\n"
        "Eu não vou descer ao porão.\\nEu não vou descer ao porão.\\n"
        "Eu não vou descer ao porão.\\nEu não vou descer ao porão.\\n"
        "Eu não vou descer ao"),
    "ESC_LOUSA_105": (
        "TERM EXAM — 4TH GRADE\\n1) Complete the sentences.\\n2) Draw your family.\\n3) Who is standing behind you?",
        "PROVA BIMESTRAL — 4ª SÉRIE\\n1) Complete as frases.\\n2) Desenhe a sua família.\\n3) Quem está atrás de você?"),
    "ESC_LOUSA_106": (
        "DICTATION\\nhouse · door · window\\nstairs · basement · dark\\nmom · come back · soon",
        "DITADO\\ncasa · porta · janela\\nescada · porão · escuro\\nmãe · volta · logo"),
    "ESC_LOUSA_107": (
        "Good morning, class!\\nToday: science\\n\\n...nobody leaves before the bell",
        "Bom dia, turma!\\nHoje: ciências\\n\\n...ninguém sai antes do sinal"),
    "ESC_LOUSA_LAB": (
        "EXPERIMENT 4: GERMINATION\\nDo NOT touch the jars\\non the top shelf.",
        "EXPERIÊNCIA 4: GERMINAÇÃO\\nNÃO mexer nos frascos\\nda prateleira de cima."),
    "ESC_LOUSA_CARDAPIO": (
        "MENU OF THE WEEK\\nMON — rice, beans and egg\\nTUE — vegetable soup\\nWED — pasta\\nTHU — \\nFRI — ",
        "CARDÁPIO DA SEMANA\\nSEG — arroz, feijão e ovo\\nTER — sopa de legumes\\nQUA — macarrão\\nQUI — \\nSEX — "),

    # ------------------------------------------------------------------
    # PLACAS — sinalizacao de predio publico
    # ------------------------------------------------------------------
    "ESC_PLACA_SAIDA": ("EXIT", "SAÍDA"),
    "ESC_PLACA_BLOCO_A": ("WING A — ROOMS 101 TO 104", "BLOCO A — SALAS 101 A 104"),
    "ESC_PLACA_BLOCO_B": ("WING B — ROOMS 105 TO 107", "BLOCO B — SALAS 105 A 107"),
    "ESC_PLACA_LESTE": ("CAFETERIA · SCIENCE LAB", "REFEITÓRIO · LABORATÓRIO"),
    "ESC_PLACA_PATIO": ("RECESS YARD", "PÁTIO"),
    "ESC_PLACA_INTERDITADO": ("NO ENTRY\\nBY ORDER OF\\nTHE PRINCIPAL", "PASSAGEM\\nINTERDITADA\\nPOR ORDEM DA DIREÇÃO"),
    "ESC_PLACA_SILENCIO": ("QUIET", "SILÊNCIO"),
    "ESC_PLACA_PROIBIDO_FUMAR": ("NO SMOKING", "PROIBIDO FUMAR"),
    "ESC_PLACA_RESTRITO": ("STAFF ONLY", "SOMENTE FUNCIONÁRIOS"),
    "ESC_PLACA_LAVE_MAOS": ("WASH YOUR HANDS\\nBEFORE MEALS", "LAVE AS MÃOS\\nANTES DAS REFEIÇÕES"),
    "ESC_PLACA_OCULOS": ("SAFETY GOGGLES\\nREQUIRED", "USO OBRIGATÓRIO\\nDE ÓCULOS"),
    "ESC_PLACA_DIRETORIA": ("PRINCIPAL", "DIRETORIA"),
    "ESC_PLACA_ATENDIMENTO": ("OPEN 7 AM TO 11 AM", "ATENDIMENTO: 7H ÀS 11H"),
    "ESC_PLACA_DEVOLUCAO": ("RETURN BOOKS ON TIME", "DEVOLVA OS LIVROS NO PRAZO"),
    "ESC_PINTURA_NOME": ("RED VALVE\\nPUBLIC SCHOOL", "ESCOLA MUNICIPAL\\nRED VALVE"),
    "ESC_PINTURA_LEMA": ("EDUCATION IS THE WAY", "EDUCAR É O CAMINHO"),

    # ------------------------------------------------------------------
    # CARTAZES DIDATICOS — o titulo na faixa colorida
    # ------------------------------------------------------------------
    "ESC_CARTAZ_ALFABETO": ("ALPHABET", "ALFABETO"),
    "ESC_CARTAZ_TABUADA": ("TIMES TABLES", "TABUADA"),
    "ESC_CARTAZ_CORPO": ("THE HUMAN BODY", "CORPO HUMANO"),
    "ESC_CARTAZ_PLANETAS": ("SOLAR SYSTEM", "SISTEMA SOLAR"),
    "ESC_CARTAZ_TABELA": ("PERIODIC TABLE", "TABELA PERIÓDICA"),
    "ESC_CARTAZ_MAPA": ("MAP OF THE COUNTY", "MAPA DO MUNICÍPIO"),

    # ------------------------------------------------------------------
    # MURAL — avisos pregados no corredor
    # ------------------------------------------------------------------
    "ESC_MURAL_TITULO": ("NOTICE BOARD", "MURAL DE AVISOS"),
    "ESC_AVISO_REUNIAO": ("PARENT MEETING\\nFRIDAY, 7 PM", "REUNIÃO DE PAIS\\nSEXTA, 19H"),
    "ESC_AVISO_VACINA": ("VACCINATION DAY\\nIN THE YARD", "VACINAÇÃO\\nNA QUADRA"),
    "ESC_AVISO_ACHADOS": ("LOST AND FOUND", "ACHADOS E PERDIDOS"),
    "ESC_AVISO_FESTA": ("JUNE FESTIVAL\\nBRING A DISH!", "FESTA JUNINA\\nTRAGA UM PRATO!"),
    "ESC_AVISO_FECHADO": ("SCHOOL CLOSED\\nUNTIL FURTHER NOTICE", "ESCOLA FECHADA\\nATÉ SEGUNDA ORDEM"),
    "ESC_CARTAZ_DESAPARECIDO": ("MISSING", "DESAPARECIDO"),
    "ESC_CARTAZ_DESAPARECIDO_TEXTO": (
        "Last seen in the school yard.\\nAny information: front office.",
        "Visto pela última vez no pátio.\\nInformações na secretaria."),

    # ------------------------------------------------------------------
    # RABISCOS — o que escreveram DEPOIS
    # ------------------------------------------------------------------
    "ESC_RABISCO_CONTE": ("COUNT THE LIGHTS.\\nIF ONE IS MISSING, RUN.", "CONTE AS LÂMPADAS.\\nSE FALTAR UMA, CORRA."),
    "ESC_RABISCO_CANOS": ("IT LISTENS THROUGH THE PIPES", "ELE ESCUTA PELOS CANOS"),
    "ESC_RABISCO_PROFESSORA": ("THE TEACHER NEVER CAME BACK", "A PROFESSORA NÃO VOLTOU"),
    "ESC_RABISCO_FUNDO": ("THERE IS SOMEONE\\nAT THE BACK OF THE ROOM", "TEM ALGUÉM\\nNO FUNDO DA SALA"),
    "ESC_RABISCO_NAO_DESCA": ("DON'T GO DOWN", "NÃO DESÇA"),
    "ESC_RABISCO_EMBAIXO": ("HE LIVES UNDERNEATH", "ELE MORA EMBAIXO"),
    "ESC_RABISCO_SEM_CAMINHO": ("THERE IS NO WAY", "NÃO HÁ CAMINHO"),
    "ESC_RABISCO_DESCULPA": ("sorry sorry sorry sorry\\nsorry sorry sorry sorry\\nsorry sorry sorry",
                             "desculpa desculpa desculpa\\ndesculpa desculpa desculpa\\ndesculpa desculpa"),
    "ESC_RABISCO_NOMES": ("LUCAS + BIA\\nRAFA WAS HERE\\n4TH GRADE RULES", "LUCAS + BIA\\nRAFA ESTEVE AQUI\\n4ª SÉRIE MANDA"),
    "ESC_RABISCO_VOLTA": ("GO HOME", "VOLTA PRA CASA"),
}


def _linha(chave, en, pt):
    buf = io.StringIO()
    csv.writer(buf, lineterminator="").writerow([chave, en, pt])
    return buf.getvalue()


def sincronizar(caminho=CSV):
    """Escreve as chaves no CSV. Devolve (novas, atualizadas)."""
    with open(caminho, encoding="utf-8", newline="") as fp:
        linhas = fp.read().split("\n")
    fim_com_quebra = linhas and linhas[-1] == ""
    if fim_com_quebra:
        linhas = linhas[:-1]

    def chave_de(linha):
        return linha.split(",", 1)[0].strip('"')

    pos = {chave_de(l): i for (i, l) in enumerate(linhas) if l}
    novas = atualizadas = 0
    pendentes = []
    for chave, (en, pt) in TEXTOS.items():
        nova = _linha(chave, en, pt)
        if chave in pos:
            if linhas[pos[chave]] != nova:
                linhas[pos[chave]] = nova
                atualizadas += 1
        else:
            pendentes.append(nova)
    if pendentes:
        # logo depois da ultima linha ESC_ que ja' existe
        ultima = max((i for (i, l) in enumerate(linhas) if chave_de(l).startswith("ESC_")),
                     default=len(linhas) - 1)
        linhas[ultima + 1:ultima + 1] = pendentes
        novas = len(pendentes)
    if novas or atualizadas:
        with open(caminho, "w", encoding="utf-8", newline="") as fp:
            fp.write("\n".join(linhas) + ("\n" if fim_com_quebra else ""))
    return novas, atualizadas


if __name__ == "__main__":
    n, a = sincronizar()
    print("textos da escola: %d chaves novas, %d atualizadas" % (n, a))
