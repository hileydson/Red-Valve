# Diretrizes Obrigatórias de Desenvolvimento

Projeto de jogo desenvolvido na **Godot**.
Siga rigorosamente estas diretrizes em todas as interações e alterações de código.

---

## 1. Como responder a cada pedido

**O padrão é executar.** Explique o que vai fazer e já faça — não fique esperando autorização.

As palavras-chave abaixo, escritas **em caixa alta**, mudam esse comportamento:

| Palavra-chave | Comportamento |
| :--- | :--- |
| **ANALISE** | **Não execute nada.** Apenas analise e relate |
| **PLANO** | **Não execute nada.** Apresente um plano e aguarde aprovação |
| **ATENCAO** | **Não execute.** Pergunte antes de qualquer coisa |
| *(nenhuma)* | Execute normalmente |

---

## 2. Regras de código

**1. Isolamento de escopo**
Não altere nem interfira em nenhum fluxo de código que não esteja diretamente envolvido na tarefa atual. Nunca mexa em coisas não relacionadas ao que foi pedido — somente se tiver ligação direta.

**2. Logs estratégicos**
Adicione logs de depuração apenas quando estritamente necessário para diagnóstico, facilitando o reenvio de dados.

**3. Consistência de padrões**
Ao implementar algo novo, siga rigidamente os padrões já estabelecidos na aplicação: nomenclatura, arquitetura e design patterns.

**4. Indentação**
Nunca indente o código.

**5. Use logs para destravar**
Sempre que ficar preso no mesmo problema, coloque logs e peça o resultado, em vez de insistir muito tempo na mesma coisa.

---

## 3. Proteção — exige permissão

> **Nunca apague a pasta `.godot`**, nem nenhuma outra pasta, sem permissão.
> Essas pastas guardam configurações difíceis de reajustar.

---

## 4. Textos e tradução

Qualquer texto adicionado ao jogo deve ser incluído nos arquivos **CSV** disponíveis e **sempre traduzido para o inglês** também.

**Arquivos:**
- `red-valve/assets/textos/red_valve_textos_gerais.csv`
- `red-valve/assets/textos/cutscene_prologo_textos.csv`

**Formato das colunas:** `keys,en,pt`

---

## 5. Ferramentas disponíveis

**MCP do Godot**
Sempre considere usar — está configurado para ajudar no desenvolvimento.

**Blender**
Use quando necessário, ou peça para o usuário abrir o Blender para ajustar algo.

**Poly Haven** — download liberado
- Modelos 3D: https://polyhaven.com/models
- Texturas: https://polyhaven.com/textures
