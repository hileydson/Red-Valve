"""Escreve os .tres de material do interior da igreja.

    python3 tools/godot/igreja/gerar_materiais_igreja.py

Saida: red-valve/assets/3d_model/stages/igreja/materiais/*.tres

Por que material .tres e nao material embutido no .glb: o modelo e' REGERADO
(basta rodar o gerador do Blender de novo) e qualquer ajuste feito num material
importado se perderia na reimportacao. Aqui o .glb so' carrega o NOME do
material; quem pinta e' o `igreja_materiais.gd`, que casa o sufixo do objeto
com um destes arquivos.

Tudo triplanar: as pecas sao geradas por script, sem UV desdobrado a mao, e
triplanar e' o unico jeito de uma parede de 40 m e um degrau de 30 cm ficarem
com a mesma escala de textura sem ninguem desdobrar nada.
"""

import os

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__)))))
SAIDA = os.path.join(RAIZ, "red-valve", "assets", "3d_model", "stages", "igreja",
                     "materiais")

TEX = {
    "tijolo_cor": "res://AmbientCG/Extracted/Bricks075A_1K-JPG_Color.jpg",
    "tijolo_nor": "res://AmbientCG/Extracted/Bricks075A_1K-JPG_NormalGL.jpg",
    "tijolo_rug": "res://AmbientCG/Extracted/Bricks075A_1K-JPG_Roughness.jpg",
    "rocha": "res://assets/3d_model/texturas/rock023_alb_ht.png",
    "pedras": "res://assets/3d_model/texturas/textura_pedras.jpg",
    "madeira": "res://assets/images/textures/wood_floor.png",
    "madeira_parede": "res://assets/images/textures/wood_wall.png",
    "reboco": "res://assets/3d_model/texturas/textura_casa_prologo/textura_escada.jpg",
}


def recurso(linhas, externos):
    cab = ["[gd_resource type=\"StandardMaterial3D\" format=3]", ""]
    for i, caminho in enumerate(externos):
        cab.append("[ext_resource type=\"Texture2D\" path=\"%s\" id=\"%d_tex\"]"
                   % (caminho, i + 1))
    cab += ["", "[resource]"] + linhas + [""]
    return "\n".join(cab)


MATERIAIS = {
    # --- pedra da estrutura: paredes, pilares, arcos, abobadas
    "mat_pedra.tres": ([TEX["tijolo_cor"], TEX["tijolo_nor"], TEX["tijolo_rug"]], [
        "albedo_color = Color(0.60, 0.585, 0.55, 1)",
        "albedo_texture = ExtResource(\"1_tex\")",
        "roughness = 1.0",
        "roughness_texture = ExtResource(\"3_tex\")",
        "normal_enabled = true",
        "normal_scale = 0.85",
        "normal_texture = ExtResource(\"2_tex\")",
        "ao_enabled = true",
        "ao_light_affect = 0.45",
        "ao_texture = ExtResource(\"3_tex\")",
        "uv1_scale = Vector3(0.34, 0.34, 0.34)",
        "uv1_triplanar = true",
        "uv1_world_triplanar = true",
    ]),
    # --- pedra do chao e dos escombros: mais escura e mais suja
    "mat_pedra_esc.tres": ([TEX["rocha"], TEX["pedras"]], [
        "albedo_color = Color(0.34, 0.33, 0.315, 1)",
        "albedo_texture = ExtResource(\"1_tex\")",
        "roughness = 0.96",
        "uv1_scale = Vector3(0.42, 0.42, 0.42)",
        "uv1_triplanar = true",
        "uv1_world_triplanar = true",
    ]),
    # --- madeira: tabuas da passarela, bancos, vigas
    "mat_madeira.tres": ([TEX["madeira"]], [
        "albedo_color = Color(0.52, 0.42, 0.33, 1)",
        "albedo_texture = ExtResource(\"1_tex\")",
        "roughness = 0.94",
        "uv1_scale = Vector3(0.55, 0.55, 0.55)",
        "uv1_triplanar = true",
        "uv1_world_triplanar = true",
    ]),
    # --- ferro velho: correntes, castiçais, corrimao, gradil
    "mat_metal.tres": ([], [
        "albedo_color = Color(0.16, 0.145, 0.135, 1)",
        "metallic = 0.75",
        "metallic_specular = 0.35",
        "roughness = 0.62",
    ]),
    # --- dourado fosco do retabulo e da cruz
    "mat_ouro.tres": ([], [
        "albedo_color = Color(0.62, 0.47, 0.16, 1)",
        "metallic = 0.85",
        "metallic_specular = 0.5",
        "roughness = 0.42",
    ]),
    # --- panos rasgados
    "mat_pano.tres": ([], [
        "albedo_color = Color(0.28, 0.13, 0.12, 1)",
        "roughness = 0.98",
        "cull_mode = 2",
    ]),
    # --- cacos de vitral no chao
    "mat_vidro.tres": ([], [
        "albedo_color = Color(0.24, 0.16, 0.30, 1)",
        "metallic = 0.2",
        "roughness = 0.12",
        "emission_enabled = true",
        "emission = Color(0.35, 0.22, 0.45, 1)",
        "emission_energy_multiplier = 0.35",
    ]),
}

# Os vitrais: albedo + emissao com a MESMA textura, recorte por alfa e sem
# cull. A emissao e' o que faz a janela "acender" num interior onde quase nao
# ha' luz — sem ela o vitral vira um retangulo preto, que e' exatamente o que
# se ve' numa igreja escura quando nao ha' sol do lado de fora.
# A energia e' BAIXA (1,0 a 1,6). Parece pouco no papel, mas o interior roda
# com `tonemap_exposure` 0.92 e glow ligado a partir de 0.92 de brilho: com os
# 2,6 que estavam aqui antes, toda janela virava um recorte branco sem desenho
# nenhum — o vitral existia e nao dava pra ver.
VITRAIS = {
    "mat_vitral_lanceta.tres": ("vitral_lanceta.png", 1.15),
    "mat_vitral_lanceta_roto.tres": ("vitral_lanceta_roto.png", 1.15),
    "mat_vitral_larga.tres": ("vitral_abside.png", 1.3),
    "mat_vitral_larga_roto.tres": ("vitral_abside.png", 1.0),
    "mat_vitral_rosacea.tres": ("vitral_rosacea.png", 1.6),
}

for nome, (tex, energia) in VITRAIS.items():
    caminho = "res://assets/images/textures/igreja/" + tex
    MATERIAIS[nome] = ([caminho], [
        "transparency = 2",
        "alpha_scissor_threshold = 0.45",
        "cull_mode = 2",
        # UNSHADED de proposito. O feixe que entra pela janela nasce do lado de
        # FORA da parede e passa exatamente por cima do vidro: com sombreamento
        # normal, esse spot batia no vitral a meio metro de distancia e o
        # estourava — todas as janelas viravam um recorte branco liso. Sem
        # receber luz, o vitral mostra o desenho dele e mais nada, que e' o
        # comportamento certo pra um vidro com luz atras.
        "shading_mode = 0",
        "albedo_color = Color(1.6, 1.5, 1.45, 1)",
        "albedo_texture = ExtResource(\"1_tex\")",
        "roughness = 0.35",
        "emission_enabled = true",
        "emission = Color(1, 0.92, 0.86, 1)",
        "emission_energy_multiplier = %.2f" % (energia * 0.55),
        "emission_texture = ExtResource(\"1_tex\")",
        "backlight = Color(0.25, 0.2, 0.18, 1)",
    ])


def main():
    os.makedirs(SAIDA, exist_ok=True)
    for nome, (externos, linhas) in sorted(MATERIAIS.items()):
        with open(os.path.join(SAIDA, nome), "w") as fp:
            fp.write(recurso(linhas, externos))
        print("  ", nome)


if __name__ == "__main__":
    main()
