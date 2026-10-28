"""Escritor de glTF: junta um monte de caixa numa malha so'.

==============================================================================
POR QUE ISTO EXISTE

A primeira versao do hospital emitia uma BoxMesh por peca direto no .tscn, do
jeito que a casa do Jimmy faz. Numa casa de 20 x 14 m aquilo da' 577 nos. Aqui
dava 2.341 SO' DE MOVEL, mais umas 600 de parede — tres mil MeshInstance3D pra
o Godot cular um por um, todo quadro.

Entao a geometria sai daqui como .gltf e entra no Godot ja' fundida:

  - a ESTRUTURA (parede, piso, teto) vira um objeto por SETOR de ~14 m. Setor,
    e nao predio inteiro, por causa do limite de 8 luzes por malha do renderer
    mobile: malha grande demais perde lampada sem avisar.
  - cada MOVEL vira um objeto por GEOMETRIA DISTINTA. Dez camas iguais sao um
    arquivo so', instanciado dez vezes. O gerador agrupa por hash da lista de
    caixas, entao isso acontece sozinho — quem escreve receita de sala nao
    precisa pensar nisso.

==============================================================================
AS UVs

`uv="mundo"` projeta a textura pelas coordenadas de MUNDO da face (x/z pro
chao, x/y ou z/y pra parede). E' o mesmo resultado do `uv1_world_triplanar` que
o resto do projeto usa, mas de graca: triplanar custa tres amostragens por
textura, e aqui a face ja' sabe qual e' o plano dela.

`uv="local"` mapeia 0..1 na face — serve pra movel, que nao tem textura mesmo.

==============================================================================
A CONVENCAO DE EIXO

Tudo aqui ja' esta em coordenadas do JOGO (Y pra cima) e o glTF tambem e'
Y-up, entao nao ha conversao nenhuma no caminho — o que se escreve e' o que
chega no Godot. (Diferente do caminho pelo Blender, onde e' preciso exportar
com `export_yup=False` pra nao deitar tudo.)
"""

import json
import math
import os
import struct

FACES = [
    # (normal, quatro cantos em fracao do tamanho, eixos de UV)
    ((0, -1, 0), [(-1, -1, -1), (1, -1, -1), (1, -1, 1), (-1, -1, 1)], (0, 2)),
    ((0, 1, 0), [(-1, 1, 1), (1, 1, 1), (1, 1, -1), (-1, 1, -1)], (0, 2)),
    ((0, 0, -1), [(1, -1, -1), (-1, -1, -1), (-1, 1, -1), (1, 1, -1)], (0, 1)),
    ((0, 0, 1), [(-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1)], (0, 1)),
    ((-1, 0, 0), [(-1, -1, -1), (-1, -1, 1), (-1, 1, 1), (-1, 1, -1)], (2, 1)),
    ((1, 0, 0), [(1, -1, 1), (1, -1, -1), (1, 1, -1), (1, 1, 1)], (2, 1)),
]


class Material:
    def __init__(self, nome, cor, metal=0.0, rug=0.8, textura=None,
                 uv_escala=1.0, emissivo=None, alpha=1.0, dupla_face=False):
        self.nome = nome
        self.cor = cor
        self.metal = metal
        self.rug = rug
        self.textura = textura          # prefixo polyhaven, ex "dirty_tiles"
        self.uv_escala = uv_escala      # metros por repeticao da textura
        self.emissivo = emissivo
        self.alpha = alpha
        self.dupla_face = dupla_face


class Objeto:
    def __init__(self, nome):
        self.nome = nome
        self.grupos = {}                # material -> (verts, normals, uvs, idx)

    def _grupo(self, mat):
        if mat not in self.grupos:
            self.grupos[mat] = ([], [], [], [])
        return self.grupos[mat]

    def caixa(self, mat, centro, tamanho, giro=0.0, uv="mundo", uv_escala=2.0):
        v, n, uvs, idx = self._grupo(mat)
        cx, cy, cz = centro
        hx, hy, hz = tamanho[0] * 0.5, tamanho[1] * 0.5, tamanho[2] * 0.5
        cg, sg = math.cos(giro), math.sin(giro)

        def mundo(px, py, pz):
            return (cx + px * cg + pz * sg, cy + py, cz - px * sg + pz * cg)

        for (normal, cantos, (eu, ev)) in FACES:
            base = len(v)
            nx, ny, nz = normal
            nmundo = (nx * cg + nz * sg, ny, -nx * sg + nz * cg)
            for (sx, sy, sz) in cantos:
                px, py, pz = sx * hx, sy * hy, sz * hz
                p = mundo(px, py, pz)
                v.append(p)
                n.append(nmundo)
                if uv == "mundo":
                    uvs.append((p[eu] / uv_escala, p[ev] / uv_escala))
                else:
                    loc = (px, py, pz)
                    tam = (tamanho[0], tamanho[1], tamanho[2])
                    uvs.append(((loc[eu] / tam[eu] + 0.5),
                                (loc[ev] / tam[ev] + 0.5)))
            idx.extend([base, base + 1, base + 2, base, base + 2, base + 3])

    def vazio(self):
        return not self.grupos

    def tris(self):
        return sum(len(g[3]) // 3 for g in self.grupos.values())

    def aabb(self):
        """Caixa real da malha — e' esta que o Godot usa pra culling de luz."""
        mn = [1e9] * 3
        mx = [-1e9] * 3
        for (v, _n, _u, _i) in self.grupos.values():
            for p in v:
                for k in range(3):
                    mn[k] = min(mn[k], p[k])
                    mx[k] = max(mx[k], p[k])
        return mn, mx


class Cena:
    """Um arquivo .gltf com varios objetos."""

    def __init__(self, prefixo_texturas="../../../images/textures/polyhaven"):
        self.objetos = []
        self.materiais = {}
        self.prefixo = prefixo_texturas

    def material(self, m):
        self.materiais[m.nome] = m
        return m.nome

    def objeto(self, nome):
        o = Objeto(nome)
        self.objetos.append(o)
        return o

    # ----------------------------------------------------------------------

    def salvar(self, caminho):
        os.makedirs(os.path.dirname(caminho), exist_ok=True)
        nome_bin = os.path.basename(caminho).replace(".gltf", ".bin")

        buf = bytearray()
        views = []
        accs = []

        def vista(dados, alvo):
            while len(buf) % 4:
                buf.append(0)
            deslocamento = len(buf)
            buf.extend(dados)
            views.append({"buffer": 0, "byteOffset": deslocamento,
                          "byteLength": len(dados), "target": alvo})
            return len(views) - 1

        def acessor_vec(pontos, dim):
            dados = b"".join(struct.pack("<%df" % dim, *p) for p in pontos)
            iv = vista(dados, 34962)
            mn = [min(p[i] for p in pontos) for i in range(dim)]
            mx = [max(p[i] for p in pontos) for i in range(dim)]
            accs.append({"bufferView": iv, "componentType": 5126,
                         "count": len(pontos),
                         "type": {2: "VEC2", 3: "VEC3"}[dim],
                         "min": mn, "max": mx})
            return len(accs) - 1

        def acessor_indices(idx):
            dados = struct.pack("<%dI" % len(idx), *idx)
            iv = vista(dados, 34963)
            accs.append({"bufferView": iv, "componentType": 5125,
                         "count": len(idx), "type": "SCALAR"})
            return len(accs) - 1

        # --- materiais e as imagens que eles usam
        imagens = []
        texturas = []
        mapa_img = {}

        def img(arquivo):
            if arquivo not in mapa_img:
                imagens.append({"uri": "%s/%s" % (self.prefixo, arquivo)})
                texturas.append({"source": len(imagens) - 1})
                mapa_img[arquivo] = len(texturas) - 1
            return mapa_img[arquivo]

        ordem_mat = sorted(self.materiais)
        mat_idx = {nome: i for i, nome in enumerate(ordem_mat)}
        materiais_json = []
        for nome in ordem_mat:
            m = self.materiais[nome]
            pbr = {"baseColorFactor": list(m.cor) + [m.alpha],
                   "metallicFactor": m.metal,
                   "roughnessFactor": m.rug}
            j = {"name": nome, "pbrMetallicRoughness": pbr,
                 "doubleSided": m.dupla_face}
            if m.textura:
                pbr["baseColorTexture"] = {"index": img(m.textura + "_diff.jpg")}
                # O `_arm` do Poly Haven ja' esta' no layout do glTF: R = oclusao,
                # G = rugosidade, B = metalico. Da' pra apontar as duas coisas
                # pro mesmo arquivo, e o importador do Godot monta o ORM sozinho.
                pbr["metallicRoughnessTexture"] = {"index": img(m.textura + "_arm.jpg")}
                j["occlusionTexture"] = {"index": img(m.textura + "_arm.jpg")}
                j["normalTexture"] = {"index": img(m.textura + "_nor_gl.jpg")}
            if m.emissivo:
                j["emissiveFactor"] = list(m.emissivo)
            if m.alpha < 1.0:
                j["alphaMode"] = "BLEND"
            materiais_json.append(j)

        # --- malhas
        malhas = []
        nos = []
        for o in self.objetos:
            if o.vazio():
                continue
            prims = []
            for mat in sorted(o.grupos):
                v, n, uvs, idx = o.grupos[mat]
                prims.append({
                    "attributes": {"POSITION": acessor_vec(v, 3),
                                   "NORMAL": acessor_vec(n, 3),
                                   "TEXCOORD_0": acessor_vec(uvs, 2)},
                    "indices": acessor_indices(idx),
                    "material": mat_idx[mat],
                })
            malhas.append({"name": o.nome, "primitives": prims})
            nos.append({"name": o.nome, "mesh": len(malhas) - 1})

        doc = {
            "asset": {"version": "2.0", "generator": "red-valve/hospital"},
            "scene": 0,
            "scenes": [{"nodes": list(range(len(nos)))}],
            "nodes": nos,
            "meshes": malhas,
            "materials": materiais_json,
            "accessors": accs,
            "bufferViews": views,
            "buffers": [{"uri": nome_bin, "byteLength": len(buf)}],
        }
        if imagens:
            doc["images"] = imagens
            doc["textures"] = texturas

        with open(caminho, "w") as fp:
            json.dump(doc, fp, separators=(",", ":"))
        with open(os.path.join(os.path.dirname(caminho), nome_bin), "wb") as fp:
            fp.write(bytes(buf))
        return sum(o.tris() for o in self.objetos)
