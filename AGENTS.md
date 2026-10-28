# Diretrizes Obrigatórias de Desenvolvimento

Projeto de jogo desenvolvido na **Godot**.
Siga rigorosamente estas diretrizes em todas as interações e alterações de código.

## 1. Como responder a cada pedido

O padrão é executar: explique brevemente o que fará e prossiga sem esperar autorização.

As palavras-chave abaixo, escritas em caixa alta, mudam esse comportamento:

| Palavra-chave | Comportamento |
| :--- | :--- |
| **ANALISE** | Não execute nem altere nada; apenas analise e relate |
| **PLANO** | Não execute nem altere nada; apresente um plano e aguarde aprovação |
| **ATENCAO** | Não execute nem altere nada; pergunte antes de prosseguir |
| *(nenhuma)* | Execute normalmente |

## 2. Regras de código

1. **Isolamento de escopo:** não altere nem interfira em fluxos que não estejam diretamente envolvidos na tarefa atual.
2. **Logs estratégicos:** adicione logs de depuração apenas quando forem necessários para o diagnóstico e para facilitar o reenvio de dados.
3. **Consistência de padrões:** siga a nomenclatura, a arquitetura, a organização e os padrões já estabelecidos no projeto.
4. **Preservação de formatação:** não refaça a indentação nem reformate código existente sem necessidade. Mantenha a formatação original intacta.
5. **Ferramentas existentes:** use bibliotecas, utilitários, frameworks e recursos já presentes no projeto; não reinvente funcionalidades existentes.
6. **Banco de dados:** não modifique banco de dados sem apresentar primeiro um plano de mudança.
7. **Imports Java:** não use imports com curinga (`pacote.*`); importe cada classe individualmente.
8. **Dependências:** não altere versões de dependências sem perguntar antes.
9. **Diagnóstico:** se ficar preso no mesmo problema, adicione logs úteis e peça o resultado em vez de insistir repetidamente.

## 3. Proteção de arquivos e pastas

Nunca apague a pasta `.godot` nem qualquer outra pasta sem permissão. Essas pastas podem guardar configurações difíceis de reconstruir.

## 4. Organização do projeto

- `assets/` contém os recursos do jogo.
- `scenes/` contém as cenas e os objetos personalizados.
- `scripts/` contém os scripts do jogo.
- Shaders devem permanecer na organização já adotada pelo projeto, inclusive quando estiverem dentro de addons ou recursos específicos.
- **Sempre que precisar criar um novo shader, verificar primeiro se existe um equivalente bom em <https://godotshaders.com/>; reutilizar é preferível a recriar.**
- Preserve sempre a estrutura atual do projeto.

## 5. Textos e tradução

Qualquer texto novo do jogo deve ser incluído nos arquivos CSV de localização disponíveis e também traduzido para o inglês. Se ainda não existir um CSV apropriado, não invente um caminho: identifique a estratégia de localização existente antes de alterar textos.

## 6. Ferramentas disponíveis

- **MCP do Godot:** sempre considere seu uso no desenvolvimento e na validação.
- **MCPs em geral:** use qualquer MCP disponível quando ele for a melhor ferramenta para a tarefa e puder gerar um resultado superior. Caso um MCP necessário não esteja acessível ou falhe, informe o usuário e peça que reinicie ou configure o respectivo servidor MCP antes de prosseguir.
- **MCP do GIMP:** pode ser usado a qualquer momento para tarefas de imagem quando for a ferramenta mais adequada.
- **Blender:** use quando necessário; se a integração não estiver disponível, peça ao usuário para abrir ou configurar o Blender.
- **Poly Haven:** downloads de modelos e texturas estão liberados em <https://polyhaven.com/models> e <https://polyhaven.com/textures>.
- **Kenney:** texturas estão disponíveis em <https://kenney.nl/assets/category:Textures>.
- **Sketchfab:** quando necessário, é permitido pesquisar e baixar modelos gratuitos em <https://sketchfab.com/features/free-3d-models>, desde que a licença específica do modelo seja compatível com o uso no jogo e sejam cumpridos os requisitos de atribuição.
- **sfxr.me:** somente é permitido usar essa plataforma (<https://sfxr.me/>) para gerar e baixar sons voltados exclusivamente para menus e interface, e NÃO para o jogo em si (gameplay). Para os sons do game em si, utilize as outras fontes disponíveis na lista próprias para sons diversos (como o Pixabay).
- **Pixabay:** downloads de efeitos sonoros gratuitos para qualquer necessidade do jogo estão liberados em <https://pixabay.com/pt/sound-effects/search/>.
