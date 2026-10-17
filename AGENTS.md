# AGENTS.md — AppCasal

Referência comum para todos os agentes (Claude, Codex e outros) que trabalham neste projeto. Contém só a arquitetura e as decisões vigentes; decisões substituídas ficam no "Histórico".

## Regras para agentes

1. **Leia este arquivo inteiro antes de iniciar qualquer tarefa.**
2. **Atualize este arquivo ao concluir cada etapa relevante e antes de interromper o trabalho.** Em tarefas longas, registre pontos de retomada em "Última tarefa / ponto de retomada".
3. O documento reflete o estado real do código. Nada é marcado como implementado ou validado sem evidência registrada em "Validações".
4. Separe sempre: **documentado pela Apple**, **hipótese de implementação** e **observado em teste**. Um teste isolado registra um comportamento observado; não o transforma em garantia do framework.
5. **Compartilhamento e avisos só podem ser marcados como validados após teste real em dois aparelhos com contas iCloud distintas** (ver "Testes que dependem de dois aparelhos").
6. Não inclua credenciais, tokens, senhas ou segredos neste arquivo nem no repositório.
7. Não sobrescreva trabalho existente sem inspecionar antes. Mudanças em `project.pbxproj`, entitlements e capabilities só dentro do escopo aprovado.
8. Implemente em incrementos pequenos, na ordem de "Próximos passos". Não comece uma etapa sem aprovação registrada em "Decisões".
9. Não implemente exclusão automática definitiva, expurgo automático, retenção permanente de cópia para quem sai do espaço nem exportação, sem aprovação específica.
10. Não altere as assinaturas (subscriptions) internas do `NSPersistentCloudKitContainer`. Assinaturas próprias usam IDs próprios e APIs documentadas do CloudKit.
11. Swift 6 com verificação estrita de concorrência. Não use `@unchecked Sendable`, `nonisolated(unsafe)`, `@preconcurrency` ou `MainActor.assumeIsolated` para silenciar erros sem justificativa escrita no código e registrada aqui.
12. iOS mínimo 26.0. Não use APIs exclusivas do iOS 27 quando houver alternativa no iOS 26; se usar, proteja com `#available` e registre aqui.
13. Idioma: documentação e comunicação em pt-BR. Código, identificadores e commits em inglês. Todo texto visível vai para `Localizable.xcstrings`; não monte frases traduzíveis por concatenação ou interpolação de palavras.
14. Build por linha de comando: `xcode-select` aponta para as Command Line Tools. Use `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild ...`.

## Resumo atual

- **Etapa 0:** concluída.
- **Etapa 1:** implementada, **aguardando validação entre duas contas iCloud reais** (aparelhos indisponíveis por enquanto).
- **Incremento atual (autorizado em 2026-10-17, ordem do usuário):** design system + navegação + ambiente de demonstração **implementados e validados localmente no simulador**; aguardando revisão das capturas pelo usuário antes do fluxo de memórias.
- **Testes:** 19 testes unitários passando (simulador iOS 26.3), incluindo contraste de 11 pares de cores em claro e escuro.
- **Não validado em aparelhos:** convites, sincronização entre parceiros, notificações e conflitos.
- **Ordem autorizada:** (1) design system, (2) navegação, (3) ambiente de demonstração, (4) fluxo de memórias. Não avançar para memórias antes da revisão das capturas.
- **Última atualização:** 2026-10-17.

## Produto

- **Nome:** AppCasal (**provisório**). Identificadores técnicos não usam o nome provisório.
- **Objetivo:** app iOS privado para um casal guardar memórias, lugares, recadinhos e metas em um espaço compartilhado só entre os dois, sincronizado por iCloud.
- **Vínculo:** exatamente duas pessoas (dono + um participante), contas iCloud distintas, sem compartilhamento público. Um novo relacionamento começa em um novo espaço; um novo parceiro nunca recebe o histórico do casal anterior.
- **Primeira versão:** somente iPhone, somente pt-BR (String Catalog pronto para tradução).

## Configuração do projeto (vigente)

| Item | Valor |
|---|---|
| Xcode / SDK | 27.0 (27A266a) / iPhoneOS 27.0 |
| iOS mínimo | 26.0 |
| Dispositivos | iPhone (`TARGETED_DEVICE_FAMILY = 1`) |
| Swift | 6.0; `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`; approachable concurrency |
| Idioma | `developmentRegion = pt-BR`; `knownRegions = Base, pt-BR`; `AppCasal/Localizable.xcstrings` (fonte pt-BR) |
| Targets | `AppCasal` (app) e `AppCasalTests` (unit, Swift Testing, hospedado no app) |
| Schemes | compartilhados: `AppCasal` (real, CloudKit) e `AppCasal Demo` (DEBUG, `-AppCasalDemo YES`, dados fictícios locais) |
| Bundle IDs | `jc.app.dev.AppCasal`, `jc.app.dev.AppCasalTests` |
| Team | `F44CYBRGC2` (conta paga), assinatura automática |
| Container CloudKit | `iCloud.jc.app.dev.casal` (registrado no time; incluído no perfil "iOS Team Provisioning Profile: jc.app.dev.AppCasal") |
| Entitlements | `AppCasal/AppCasal.entitlements`: CloudKit, container acima, `aps-environment = development` |
| Ícone do app | `AppIcon.appiconset`: `AppIcon.png` (claro, 1024×1024, sem alfa; dois cadeados de coração interligados, arte do usuário) e `AppIcon-Dark.png` (escuro, gerado a partir da arte clara: cadeados recortados com fundo transparente, o iOS desenha o fundo escuro). Variante tingida não fornecida, por decisão do usuário: o sistema gera |
| Info.plist | gerado + parcial `AppCasal/Info.plist` (`CKSharingSupported`, `UIBackgroundModes = remote-notification`, `UILaunchScreen`); excluído dos recursos por exceção da pasta sincronizada |
| Tela de abertura | `UILaunchScreen` com `UIColorName = LaunchBackground` (`#FAF5EE`, igual ao fundo do ícone, sem variante escura) e `UIImageName = LaunchLogo` (cadeados com fundo transparente, 220 pt). `INFOPLIST_KEY_UILaunchScreen_Generation` removido |
| Git | `main`, remoto `git@github.com:jcezart/AppCasal.git` (SSH via Keychain) |
| Limitação | agentes não operam a interface do Xcode; inspeção e build pelo diretório e `xcodebuild` |

## Tecnologias

- SwiftUI (Liquid Glass do iOS 26).
- Core Data + `NSPersistentCloudKitContainer` (sem SwiftData).
- CloudKit via `NSPersistentCloudKitContainer` (espelhamento e `CKShare`); `CKDatabaseSubscription` própria para o experimento de avisos.
- MapKit, PhotosUI, UserNotifications (etapas futuras).
- Swift Concurrency. Nenhuma dependência externa.

## Arquitetura vigente

**Padrão:** MVVM + Repository, proporcional ao projeto.

- **Views:** SwiftUI; listas leem com `@FetchRequest` filtrado pelo espaço e por `deletedAt`.
- **ViewModels:** `@Observable`, só em telas com lógica real (ainda nenhum: as telas atuais só leem com `@FetchRequest` e escrevem por repositórios).
- **Navegação:** `RootView` decide entre erro do store, carregando, iCloud indisponível, criar espaço, entrar no espaço (participante sem `Member`) e `MainTabView`. `MainTabView` usa `TabView` nativo com 5 abas (`AppTab`), um `NavigationStack` por aba, e abre "Nosso espaço" (`SpaceView`) em sheet pelo avatar do Início.
- **Repositories:** toda escrita passa por eles; atribuem o store do objeto relacionado, preenchem autoria e datas, aplicam exclusão lógica.
- **PersistenceController:** dois stores no mesmo container: `Private.sqlite` (`.private`) e `Shared.sqlite` (`.shared`), com histórico persistente e notificação de mudança remota. Modos `.cloudKit`, `.local(directory:)` (testes de reabertura) e `.inMemory` (testes).
- **ShareService:** cria o share, apresenta `UICloudSharingController` (somente privado + leitura e escrita), aceita convites, aplica `CoupleLimit`.
- **SyncMonitor:** guarda os últimos eventos de `NSPersistentCloudKitContainer.eventChangedNotification`.
- **AccountService:** estado da conta iCloud e `userRecordName`; reage a `CKAccountChanged`. Guarda o `userRecordName` (identificador opaco por container, não é dado pessoal nem segredo) em `UserDefaults` (`account.cachedUserRecordName`): com ele o app abre direto no espaço, sem esperar a rede, e funciona offline. A verificação no iCloud roda depois, sem bloquear. Problemas transitórios (indisponível temporariamente, não determinado, erro) não bloqueiam quem já tem identidade no aparelho; só "sem conta" e "restrito" bloqueiam e apagam a identidade guardada. Troca de conta é detectada quando o `userRecordID()` volta diferente.
- **LaunchLog:** marcas de tempo da abertura (`Logger`, categoria `launch`).
- **AppEnvironment:** grafo de dependências criado uma vez, com `RunMode`:
  - `.production`: stores reais com CloudKit.
  - `.demo` (só DEBUG, só com o argumento `-AppCasalDemo YES`, nunca automático, nunca em resposta a erro do iCloud): stores `.local` em `Application Support/DemoStores/`, sem CloudKit, identidade local fixa (`AccountService(localUserRecordName:)`), dados fictícios gerados por `DemoData.seedIfNeeded` usando os repositórios de produção.
  - `.preview` (só DEBUG): stores em memória com os mesmos dados fictícios, para `#Preview`.
  - `.tests`: stores em memória.
- **Design system:** `DesignSystem/Tokens` (`Palette`, `Spacing`, `Radius`, papéis de fonte, `NavigationAppearance`) e `DesignSystem/Components`.

**Isolamento (Swift 6):** o target tem `MainActor` como padrão. As subclasses de `NSManagedObject` são `nonisolated` porque o espelhamento do CloudKit cria e lê objetos nas próprias filas; o isolamento real é o do contexto. Toda leitura e escrita do app acontece no `viewContext`, no `MainActor`. `CKShare`, `CKShare.Metadata` e `CKShare.Participant` são `Sendable` no iOS 17+ (SDK). O delegate de notificações tem um método `nonisolated` que só devolve opções, sem estado. Nenhuma marcação insegura foi usada.

### Árvore atual

```
AppCasal/
├── AGENTS.md / CLAUDE.md
├── AppCasal.xcodeproj/                      # + xcshareddata/xcschemes/AppCasal.xcscheme
├── AppCasal/
│   ├── App/                                 # AppCasalApp, AppDelegate, SceneDelegate, AppEnvironment, RootView, MainTabView, AppTab
│   ├── DesignSystem/
│   │   ├── Tokens/                          # Palette, Metrics (Spacing, Radius), Typography
│   │   └── Components/                      # SurfaceCard, SectionLabel, Chips, PillSegmentedControl, Buttons, Avatars,
│   │                                        # States (Empty/Loading/Error/SyncStatus), ProgressBar, NoteCards, InfoCard,
│   │                                        # CoupleHeroHeader, SettingsRow, AdaptiveStack
│   ├── Data/
│   │   ├── Model/AppCasal.xcdatamodeld      # CoupleSpace, Member, Note
│   │   ├── Model/Entities/                  # subclasses nonisolated
│   │   ├── Persistence/                     # PersistenceController, SyncMonitor
│   │   ├── Sharing/                         # ShareService, CoupleLimit
│   │   ├── Notifications/                   # NoteAlertSubscription (experimento, só DEBUG)
│   │   ├── Demo/                            # DemoData (só DEBUG)
│   │   └── Repositories/                    # SpaceRepository, NoteRepository
│   ├── Services/                            # AccountService
│   ├── Features/
│   │   ├── Onboarding/                      # CreateSpaceView, JoinSpaceView, AccountUnavailableView
│   │   ├── Home/ Map/ Memories/ Notes/ Goals/
│   │   ├── Space/                           # SpaceView ("Nosso espaço"), editar nome, data de início
│   │   └── SharingSpike/                    # diagnóstico da etapa 1, só DEBUG, aberto em "Nosso espaço"
│   ├── Assets.xcassets, Localizable.xcstrings
│   ├── AppCasal.entitlements, Info.plist
└── AppCasalTests/                           # CoupleLimit, esquema CloudKit, repositórios, reabertura, contraste, design, demo
```

Pastas planejadas para etapas futuras: `Services/{Location,PhotoProcessing}`.

### Modelo de dados

**Implementado (etapa 1):**

| Entidade | Campos | Observações |
|---|---|---|
| `CoupleSpace` | `id`, `createdAt`, `createdBy`, `modifiedAt`, `deletedAt`, `relationshipStart`, `sharingEndedAt`, `members`, `notes` | raiz do share; `sharingEndedAt` impede novo compartilhamento |
| `Member` | `id`, `userRecordName`, `displayName`, `role`, `createdAt`, `modifiedAt`, `space` | cada usuário só escreve o próprio |
| `Note` | `id`, `text`, `authorID`, `createdAt`, `modifiedAt`, `modifiedBy`, `deletedAt`, `deletedBy`, `space` | na etapa 1 é editável pelos dois (registro de teste); na etapa 5 passa a ser editável só pelo autor |

Todos os atributos são opcionais, relacionamentos opcionais com inverso, sem unique constraints e sem regra `Deny` (verificado por `CloudKitSchemaTests`).

**Planejado:** `Memory`, `MemoryPhoto`, `Place`, `Goal`, `GoalStep` (compartilhados, com relacionamento para `CoupleSpace`, campos `createdBy`/`modifiedBy`/`deletedAt`/`deletedBy`); `NoteFavorite(noteID)` e `UserPreferences` (pessoais, store privado, zona padrão, sem relacionamento com dados compartilhados). Fotos como binário com armazenamento externo. Progresso e dias juntos calculados, nunca armazenados.

## Compartilhamento

**Documentado pela Apple (SDK/headers):**
- `share(_:to:)` faz uma travessia profunda e compartilha os objetos relacionados; falha sem conta iCloud ou com objetos já compartilhados.
- `acceptShareInvitations(from:into:)` aceita o convite no store compartilhado.
- `CKSharingSupported` é necessário para o sistema entregar convites ao app.
- Opções do share: `publicPermission = .none`; `UICloudSharingController.availablePermissions = [.allowPrivate, .allowReadWrite]`.

**Implementado:**
- Dono cria `CoupleSpace` + `Member` no store privado e gera o share ao tocar em "Convidar parceiro(a)".
- O convite abre `UICloudSharingController` restrito a convite privado com leitura e escrita.
- `SceneDelegate` trata o convite com o app fechado (`connectionOptions.cloudKitShareMetadata`) e aberto (`userDidAcceptCloudKitShareWith`) e chama `ShareService.accept`: implementado para esses cenários, ainda não validado.
- Antes de aceitar, o app recusa: share com mais de um parceiro (`CoupleLimit`) ou usuário que já é dono de um espaço.
- Após a importação, o participante informa o nome e cria o próprio `Member` no store compartilhado.
- Objetos novos são atribuídos ao mesmo store do espaço (`assign(_:to:)`).

**Hipóteses a verificar (S1–S6):** objetos criados pelo dono após o share entram na zona compartilhada por estarem relacionados ao espaço; o limite de dois funciona na prática com `UICloudSharingController`, que não limita sozinho o número de convidados (o app só avisa o dono e recusa na aceitação).

**Cota:** dados e fotos da zona compartilhada usam o iCloud do dono (documentado pela Apple para zonas compartilhadas).

## Conflitos

**Documentado pela Apple:** o `NSPersistentCloudKitContainer` não oferece gancho de merge com o servidor. A política de merge do contexto (`NSMergeByPropertyObjectTrumpMergePolicy`) vale para conflitos locais entre a edição na tela e o que está no store.

**Hipótese de implementação (pior caso, até C1–C4):** entre aparelhos, o último a enviar um registro pode sobrescrever o registro inteiro, independentemente do horário da edição. Edições offline simultâneas no mesmo registro podem perder a edição de um dos dois.

**Estratégia:**
1. Local: `viewContext` com `NSMergeByPropertyObjectTrumpMergePolicy` e `automaticallyMergesChangesFromParent`.
2. Esquema que reduz sobrescritas: registros de um só escritor (`Member`; `Note` a partir da etapa 5), listas como registros separados (`GoalStep`, `MemoryPhoto`), nada de contadores armazenados.
3. Transparência: `modifiedBy` e `modifiedAt` exibidos ("editado por X").
4. **Exclusão lógica** (`deletedAt`, `deletedBy`) com "Excluídos recentemente": facilita a recuperação de exclusões, **mas não elimina sobrescritas concorrentes**. Exclusão e edição simultâneas viram alterações no mesmo registro e seguem a regra de sobrescrita: a exclusão pode ser desfeita por uma edição que chegue depois, ou uma edição pode ser perdida por uma exclusão que chegue depois.
5. Exclusão física só por ação explícita; sem expurgo automático.
6. Sem unique constraints: `Member` é único por `userRecordName` via `ensureMember`; deduplicação após importação fica para a etapa 2.

**Observado em testes:** nada ainda (C1–C4 pendentes).

## Avisos de recadinhos

Requisito: aviso rápido para dono e participante, **sem promessa de entrega imediata garantida**. Notificação local gerada após sincronização não é tratada como garantia.

**Documentado pela Apple (`CKSubscription.h`, SDK iOS 27).** A existência e a documentação de uma API no SDK não comprovam o funcionamento no servidor nem neste esquema; só os testes N1–N6 dirão.
- `CKDatabaseSubscription` funciona nos bancos privado e compartilhado; `recordType` restringe a assinatura a um tipo de registro.
- A zona padrão do banco privado não participa de assinaturas de banco (a zona do share do dono é personalizada, então participa).
- `CKQuerySubscription` não funciona no banco compartilhado.
- A assinatura vale para o usuário que a cria; o servidor exclui o aparelho de origem "quando apropriado" (sem garantia).
- O sistema agrupa notificações e pode omitir dados; não devem ser usadas para mudanças específicas.
- Core Data nomeia os tipos espelhados com prefixo `CD_` (tipo `CD_Note`).

**Experimento implementado (não é a solução final):** compilado só em `DEBUG` (`#if DEBUG` em `NoteAlertSubscription.swift` e na seção da tela de teste; ausente do binário Release); a assinatura só é criada quando o usuário toca no botão, nunca automaticamente.
- Dono: `CKDatabaseSubscription` no banco privado, `recordType = "CD_Note"`, alerta visível com som.
- Participante: mesma assinatura no banco compartilhado.
- ID próprio `note-alerts-experiment-v1`; as assinaturas do `NSPersistentCloudKitContainer` não são tocadas.

**Hipóteses e riscos a medir (N1–N6):** o dono também é avisado das próprias notas (a assinatura no banco privado vê as notas dos dois; só o aparelho de origem pode ser excluído, e sem garantia); edições e exclusões lógicas de notas também geram aviso; outros aparelhos do mesmo usuário recebem o aviso das próprias notas; pushes podem atrasar ou ser agrupados; convivência com as notificações silenciosas do framework.

Se o experimento não atender, a limitação será registrada aqui e as alternativas apresentadas ao usuário. Banco público para sinais **não aprovado**.

## Encerramento do vínculo (direção aprovada; implementação em etapa futura)

| Conceito | Regra |
|---|---|
| Encerrar compartilhamento (dono) | Revoga o acesso do participante; os dados permanecem com o dono |
| Sair do espaço (participante) | Participante perde o acesso; os dados do dono não são apagados |
| Apagar definitivamente | Ação separada, explícita, só do dono, com confirmação forte |
| Novo parceiro | Começa em um novo espaço; nunca recebe o histórico do espaço anterior. Reconvidar no mesmo espaço depois de encerrar não é permitido |
| Cache do participante | Removido quando o app detectar a revogação; em aparelho offline isso só acontece após a próxima sincronização (sem promessa de remoção imediata) |
| Exportação | Etapa posterior; não implementar agora |

Estado atual (tela de teste):
- "Parar de compartilhar" no `UICloudSharingController` não apaga nada; marca `CoupleSpace.sharingEndedAt`, e o app recusa criar outro share para esse espaço.
- O dono só vê "Convidar" enquanto nenhum parceiro foi adicionado; participante removido não libera a vaga (`CoupleLimit.canInvite`).
- Hipótese a verificar: o `UICloudSharingController` ainda permite ao dono adicionar pessoas pela tela "Gerenciar"; o app recusa na aceitação, mas isso precisa de teste (S6).
- Criar um novo espaço depois de encerrar o anterior ainda não é possível na tela de teste (só um espaço por usuário); fica para a etapa 4.
- Saída do participante e remoção do cache ao detectar revogação: etapa 4.

## Referência visual e design system (implementado; validado localmente)

**Referência:** imagem "Álbum afetivo de Ana e Lucas" (fora do repositório, em `~/Downloads`). Seis telas: Início, Mapa, Memórias, Recados, Metas, Perfil e conexão. Nomes, fotos e textos são fictícios e não viram conteúdo fixo (aparecem só no modo demonstração e em previews).

**Extraído da imagem:** fundo creme quente; cartões claros quase planos; fotos com cantos arredondados; destaque terracota; títulos em serifada e metadados em sem serifa; subtítulos poéticos; chips de categoria e estado; segmentado em pílula; memórias por mês; 5 abas; perfil pelo avatar; banner de sincronização.

**Tokens implementados** (Asset Catalog, claro e escuro; acesso por `Palette`). Contraste medido por `PaletteContrastTests` (WCAG, ≥ 4,5:1 para todos os pares de texto usados, nos dois modos):

| Token (`Palette`) | Asset | Claro | Escuro | Uso |
|---|---|---|---|---|
| `canvas` | Canvas | `#F7F0E8` | `#1C1614` | fundo |
| `surface` | Surface | `#FCF8F3` | `#272019` | cartões |
| `surfaceMuted` | SurfaceMuted | `#F2E4DA` | `#352A24` | chips, banners, segmentado |
| `accent` | Terracotta | `#B4553F` | `#A9503B` | preenchimentos, seleção, progresso |
| `onAccent` | OnTerracotta | `#FFFFFF` | `#FFFFFF` | texto sobre `accent` |
| `accentText` | TerracottaText | `#9A4433` | `#E39A86` | texto/ícones terracota; também `AccentColor` (tint) |
| `textPrimary` | Ink | `#3D1F1A` | `#F3E7DF` | títulos e corpo |
| `textSecondary` | InkSecondary | `#6E5D55` | `#BFAEA5` | metadados |
| `success` | Leaf | `#356B40` | `#7CBF88` | "Conectados" |
| `hairline` | Hairline | `#E8DAD0` | `#3A302B` | bordas e divisores |

Ajustes em relação à proposta: `textSecondary` (`#76655D` → `#6E5D55`) e `success` (`#4E8B5A` → `#356B40`) escurecidos porque ficavam abaixo de 4,5:1 sobre `surfaceMuted`. Modo escuro é proposta complementar (a imagem só mostra o claro).

- **Tipografia:** `Font.displayTitle`, `.sectionTitle`, `.cardTitle`, `.noteQuote` em New York (serifada do sistema); `.metadata`, `.chipLabel` e demais em SF Pro. Todos derivados de estilos de texto (Dynamic Type). Títulos de navegação em serifada via `NavigationAppearance.apply()` (aparência do `UINavigationBar`, único meio para títulos nativos). `navigationSubtitle` (iOS 26) para os subtítulos poéticos.
- **Métricas:** `Spacing` (4–40, margem 20, cartão 16), `Radius` (cartão 20, foto 14, botão 14), sempre `.continuous`.
- **Componentes implementados:** `surfaceCard()`, `canvasBackground()`, `SectionLabel`, `TagChip`, `StatusChip`, `PillSegmentedControl`, `.primary` e `.soft` (estilos de botão), `AvatarView`, `CoupleAvatars`, `EmptyStateView`, `LoadingStateView`, `ErrorBanner`, `SyncStatusBanner` (+ `SyncDisplayState`), `ProgressBar`, `NoteCard`, `NotePreviewCard`, `InfoCard`, `CoupleHeroHeader`, `SettingsRow`, `AdaptiveStack`. Todos com `#Preview`.
- **Componentes ainda não implementados** (entram com cada funcionalidade): `MemoryCard`, `MemoryRow`, `GoalCard`, `GoalSummaryRow`, `StepChecklist`, `PlaceCard`, busca do mapa.
- **Acessibilidade implementada:** estilos de texto em tudo; `AdaptiveStack` troca linhas horizontais por verticais em tamanhos de acessibilidade; segmentado em pílula vira vertical nesses tamanhos; elementos combinados para VoiceOver; ícones decorativos ocultos; `isSelected` em segmentos e filtros; `accessibilityLabel` no avatar ("Nosso espaço"); Reduzir Movimento desliga a animação do segmentado.
- **Abertura e boas-vindas:** tela de abertura do sistema com a marca (fundo creme e cadeados) e `WelcomeView` com a mesma cor, o mesmo logo, no mesmo tamanho e posição, mais "Um espaço só nosso" e indicador de progresso, que só aparecem se a preparação passar de 400 ms. Cores fixas da marca nos dois modos, para não haver salto da abertura para o app. Sem atraso artificial.
- **Estados:** vazio (`EmptyStateView`, `InfoCard`), carregando (`LoadingStateView`), erro (`ErrorBanner`, erro do store na raiz), iCloud indisponível (`AccountUnavailableView`), sincronização (`SyncStatusBanner`: sincronizado, sincronizando, falhou, iCloud indisponível, demonstração). Contagem de alterações pendentes ainda não implementada.

**Navegação implementada:** `TabView` nativo com Início, Mapa, Memórias, Recados, Metas (título "Nossos planos"). "Nosso espaço" pelo avatar no Início (sheet), com perfil (nome), data de início do relacionamento, convite (dono, fora do modo demonstração), estado da conexão e banner de sincronização. Diagnóstico técnico da etapa 1 só em DEBUG, dentro de "Nosso espaço".

**Conteúdo das abas neste incremento:**
- Início: herói (nomes, dias juntos, gradiente quente sem foto), último recadinho real, cartões vazios de metas e memória.
- Mapa: `Map` nativo, filtros em Liquid Glass (só estado visual; sem lugares ainda), cartão vazio.
- Memórias e Metas: estados vazios (funcionalidades nos próximos incrementos).
- Recados: recebidos e enviados reais (leitura); favoritos com estado vazio (favoritos e escrita na etapa de recadinhos).

**Liquid Glass (APIs do iOS 26, sem fallback de versão):**

| Onde | Como | Estado |
|---|---|---|
| Barra de abas | `TabView` nativo | implementado |
| Barras de navegação e botões de toolbar (avatar, "OK") | `ToolbarItem` nativo | implementado |
| Mapa: filtros | `glassEffect(.regular.interactive())` em `GlassEffectContainer`; selecionado com `.tint(accent)` | implementado |
| Mapa: busca, "+", detalhe do lugar | glass / sheet nativa | planejado (incremento do mapa) |
| Ações principais "+" / "Escrever recadinho" | `.glassProminent` | planejado (com cada funcionalidade) |
| Ações sobre fotos | `.buttonStyle(.glass)` | planejado (fotos) |
| Sem glass | cartões, recadinhos, formulários, perfil, banners, segmentado em pílula | implementado assim |

**Ajustes em relação à imagem:** barra de abas nativa flutuante; títulos de navegação nativos em serifada; mapa no estilo nativo; herói desenhado por baixo das barras; linhas horizontais e segmentado viram verticais em Dynamic Type de acessibilidade.

## Estado das funcionalidades

Legenda: **implementado** (código existe e compila); **validado localmente** (build, testes unitários ou conferência visual no simulador); **aguardando duas contas** (só pode ser validado em dois aparelhos com contas iCloud distintas).

| Funcionalidade | Implementado | Validado localmente | Aguardando duas contas |
|---|---|---|---|
| Configuração do projeto (etapa 0) | sim | sim (build, testes, perfil com container) | — |
| Criar espaço, convidar, aceitar, entrar com nome (etapa 1 + onboarding) | sim | parcial (repositórios testados; telas no simulador sem iCloud) | sim (S1–S7, P1) |
| Recadinho de teste criado/editado pelos dois (diagnóstico DEBUG) | sim | parcial (repositório testado) | sim (S3–S5) |
| Experimento de avisos (só DEBUG, manual) | sim | não | sim (N1–N6) |
| Design system (tokens, componentes, estados) | sim | sim (17 testes, capturas claro/escuro/AX) | — |
| Navegação (5 abas, "Nosso espaço" pelo avatar, diagnóstico DEBUG) | sim | sim (capturas no simulador) | — |
| Ambiente de demonstração | sim | sim (testes de separação e seed; capturas) | — |
| "Nosso espaço": editar nome, data de início | sim | parcial (repositório testado; edição pela UI não exercitada) | sincronização entre parceiros |
| Encerrar compartilhamento / sair / apagar espaço | parcial (encerrar marca `sharingEndedAt`) | parcial (`CoupleLimit` testado) | sim (S7) |
| Memórias com fotos e linha do tempo | não | — | — |
| Recadinhos (escrita, favoritos, avisos) | leitura apenas | — | — |
| Metas | não (estado vazio) | — | — |
| Mapa, lugares, busca, rotas | não (mapa e filtros visuais) | — | — |
| Modelo completo, deduplicação, contagem de pendências | não | — | — |

## Persistência, CloudKit e CKShare — configuração atual

- Core Data com `Private.sqlite` (`.private`) e `Shared.sqlite` (`.shared`) em `NSPersistentContainer.defaultDirectoryURL()`; histórico persistente e notificação remota ligados.
- Container `iCloud.jc.app.dev.casal`, ambiente de desenvolvimento. O esquema CloudKit ainda não foi criado: será gerado pelo primeiro envio a partir de um aparelho ou simulador com conta iCloud. `initializeCloudKitSchema` não é chamado.
- CKShare: zona criada pelo framework ao compartilhar o `CoupleSpace`; `publicPermission = .none`.
- Assinatura própria: só a do experimento de avisos, criada sob demanda.

## Etapas de implementação

| # | Etapa | Critério de conclusão | Estado |
|---|---|---|---|
| 0 | Configuração (iOS 26, iPhone, Swift 6, pt-BR, String Catalog, testes, CloudKit, Push, Background Modes, Info.plist) | build sem avisos; testes passam; container no perfil | concluída |
| 1 | Fluxo mínimo: criar espaço, convidar, aceitar, criar/editar registro pelos dois, persistência após reabrir | S1–S7 e P1 em dois aparelhos | implementada; validação pendente |
| 2 | Modelo completo, repositórios, deduplicação, monitor de sincronização | testes em store em memória; modo avião | parcial: entidades entram com cada funcionalidade |
| 3 | Design system, navegação e ambiente de demonstração | previews; Dynamic Type de acessibilidade; modo escuro; contraste ≥ 4,5:1 | implementada e validada localmente; aguardando revisão do usuário |
| 4 | Onboarding e "Nosso espaço" (convite, conexão, encerrar/sair, novo parceiro = novo espaço) | fluxo entre 2 contas | aguardando |
| 5 | Recadinhos + favoritos + avisos | N1–N6 | aguardando |
| 6 | Memórias + fotos + linha do tempo | local: criar, editar, listar, detalhe, fotos, persistência ao reabrir; entre contas: memória com 3 fotos no outro aparelho | próxima, após revisão das capturas |
| 7 | Metas + etapas + histórico | etapas marcadas ao mesmo tempo | aguardando |
| 8 | Mapa + lugares + rotas + converter em memória | busca, rota, memória ligada | aguardando |
| 9 | Início | dados reais e estados vazios | aguardando |
| 10 | Endurecimento e revisão App Store | checklist com evidências | aguardando |

## Testes que dependem de dois aparelhos

Disponibilidade de dois aparelhos com contas iCloud distintas: **não confirmada**. Simulador sem conta iCloud não serve; aceitação de convite e push em simulador não contam como validação.

| ID | Teste | Estado |
|---|---|---|
| S1 | Dono cria espaço e envia convite pela tela de teste | não testado |
| S2 | Participante aceita pelo link (app fechado e aberto) e confirma o nome | não testado |
| S3 | Recadinho criado em A aparece em B e vice-versa | não testado |
| S4 | Edição, exclusão lógica e restauração propagam nos dois sentidos | não testado |
| S5 | Recadinho criado pelo dono após o share chega ao participante | não testado |
| S6 | Convite com segundo parceiro é recusado na aceitação | não testado |
| S7 | "Parar de compartilhar" revoga o acesso do participante, mantém os dados do dono e bloqueia novo convite | não testado |
| P1 | Fechar e reabrir o app nos dois aparelhos mantém espaço e recadinhos (também offline) | não testado em aparelho (coberto localmente por teste unitário) |
| N1 | Participante → dono: aviso com app em primeiro plano, em segundo plano e encerrado | não testado |
| N2 | Dono → participante: mesmos três estados | não testado |
| N3 | Remetente recebe ou não aviso da própria nota | não testado |
| N4 | Edição e exclusão de nota geram aviso? | não testado |
| N5 | Tempo entre envio e aviso | não testado |
| N6 | Avisos duplicados ou agrupados | não testado |
| C1 | Mesmo campo editado offline nos dois: vence o último envio do registro inteiro ou por campo? | não testado |
| C2 | Exclusão lógica em A e edição em B offline, reconexão em ordens diferentes | não testado |
| C3 | Exclusão física em A com edição em B | não testado |
| C4 | Criação offline nos dois aparelhos e reconexão | não testado |

## Decisões vigentes

| Data | Decisão | Justificativa | Estado |
|---|---|---|---|
| 2026-10-17 | Core Data + `NSPersistentCloudKitContainer`, sem SwiftData | menos código próprio de sincronização; CKShare, offline e fotos nativos | aprovada |
| 2026-10-17 | Container `iCloud.jc.app.dev.casal` | neutro, segue `jc.app.dev.*` | aprovada e registrada |
| 2026-10-17 | iOS 26.0; Swift 6; somente iPhone; pt-BR com String Catalog | alcance, segurança de concorrência, foco | aprovada |
| 2026-10-17 | Direção visual da imagem; Liquid Glass só em navegação, controles flutuantes e ações sobre fotos | identidade da referência e legibilidade | aprovada |
| 2026-10-17 | Exclusão lógica com "Excluídos recentemente", sem expurgo automático | recuperação de exclusões (não evita sobrescritas) | aprovada |
| 2026-10-17 | Vínculo de exatamente duas pessoas, sem compartilhamento público; novo parceiro = novo espaço | privacidade | aprovada |
| 2026-10-17 | Encerramento: dono encerra e mantém dados; participante sai sem apagar dados do dono; exclusão definitiva separada | separar vínculo, acesso e exclusão | direção aprovada |
| 2026-10-17 | Favoritos de recadinhos pessoais; Memórias = linha do tempo; metas concluídas no histórico de Metas | — | aprovada |
| 2026-10-17 | Avisos: experimentar `CKDatabaseSubscription` com `recordType` nos bancos privado e compartilhado, só em DEBUG e com ativação manual | API documentada, sem banco público; não entra na distribuição | em teste |
| 2026-10-17 | Convite via `UICloudSharingController` (não `ShareLink`) | permite restringir a privado + leitura e escrita e gerenciar participantes | implementada |
| 2026-10-17 | Subclasses de `NSManagedObject` `nonisolated`; acesso do app só pelo `viewContext` no `MainActor` | isolamento correto com MainActor padrão e espelhamento em filas próprias | implementada |
| 2026-10-17 | Sem aparelhos: avançar design system → navegação → demonstração → memórias | não bloquear o que não depende de CloudKit | aprovada pelo usuário |
| 2026-10-17 | Modo demonstração só em DEBUG, por argumento explícito, stores próprios, repositórios de produção | sem implementação paralela; nunca misturar com dados reais | implementada |
| 2026-10-17 | `Palette` isolada no `MainActor` | os símbolos de cor gerados pelo Asset Catalog herdam o isolamento padrão; uso só em views | implementada |

## Pendências do usuário

- Confirmar dois aparelhos com contas iCloud distintas e executar S/N/C/P (roteiro em "Testes que dependem de dois aparelhos").
- Em cada aparelho (iOS 26+): conta iCloud ativa em Ajustes > [seu nome]; Modo de Desenvolvedor em Ajustes > Privacidade e Segurança > Modo de Desenvolvedor (o aparelho reinicia); conectar ao Mac, selecionar no Xcode e rodar (⌘R, Debug). O Xcode registra o aparelho no time automaticamente. Se pedir, confiar no desenvolvedor em Ajustes > Geral > VPN e Gerenciamento de Dispositivo.
- CloudKit Console: nada a configurar para o primeiro teste; no ambiente de desenvolvimento o esquema é criado no primeiro envio.
- Antes do TestFlight: publicar o esquema em Production no CloudKit Console.

## Problemas conhecidos e bloqueios

- Validação de compartilhamento e avisos bloqueada até haver dois aparelhos.
- Comportamento de conflito do framework não documentado (C1–C4).
- `UICloudSharingController` não limita o número de convidados; o limite é aplicado pelo app na aceitação e sinalizado ao dono.
- `xcode-select` aponta para Command Line Tools (regra 14).
- Abertura num iPhone real não medida. Em build Debug iniciado pelo Xcode (com depurador) a abertura é bem mais lenta que pelo ícone; medir abrindo pela tela inicial, de preferência em Release. Na primeira abertura (sem identidade guardada) e com iCloud, o app ainda espera `userRecordID()`; a tela de boas-vindas cobre essa espera.
- `navigationSubtitle` é truncado pelo sistema em tamanhos de acessibilidade (controle nativo).
- Contraste do texto sobre os filtros em Liquid Glass do mapa não é medido (depende do mapa por trás); conferido só visualmente.
- Reduzir Transparência e Aumentar Contraste não foram conferidos (o `simctl` não alterna Reduzir Transparência); conferir no Xcode (Environment Overrides) ou em aparelho.
- Ícone escuro gerado por recorte automático (saturação/luminância + preenchimento de reflexos internos + borda suavizada); conferido em 1024 px sobre fundo escuro, mas o estilo de ícone escuro da tela inicial não foi visto no simulador (o `simctl` não alterna esse ajuste). Conferir num iPhone: Ajustes > Tela de Início e Biblioteca de Apps > Personalizar > Escuro. O conjunto `Messages Icon.stickersiconset` recebido não se aplica (o app não tem extensão do iMessage).
- `Localizable.xcstrings` é sincronizado pelo Xcode (hoje com 56 chaves, da etapa 1). As chaves deste incremento entram na próxima sincronização feita pelo Xcode; não editar o catálogo à mão para "completar".
- O modo demonstração não oferece convite (sem CloudKit); o banner mostra "Modo demonstração".

## Validações

| Data | O quê | Resultado |
|---|---|---|
| 2026-10-17 | Build do template para iOS Simulator | BUILD SUCCEEDED |
| 2026-10-17 | Build Swift 6, iPhone 17 (iOS 26.3) Simulator | BUILD SUCCEEDED, sem avisos de compilação |
| 2026-10-17 | `xcodebuild test`, iPhone 17 (iOS 26.3) Simulator | 11 testes em 3 suítes passaram (`CoupleLimitTests`, `CloudKitSchemaTests`, `RepositoryTests`, incluindo reabertura do store em disco); repetido após a regra de não reconvidar |
| 2026-10-17 | Build para aparelho com `-allowProvisioningUpdates` | BUILD SUCCEEDED; perfil inclui `iCloud.jc.app.dev.casal`, CloudKit e `aps-environment = development`; Info.plist final com `CKSharingSupported`, `remote-notification`, `pt-BR`, família 1 |
| 2026-10-17 | App aberto no simulador iOS 26.3 sem conta iCloud | abre sem falhas; mostra "Entre no iCloud nos Ajustes…" |
| 2026-10-17 | Build Release para aparelho | BUILD SUCCEEDED; ID `note-alerts-experiment-v1` ausente do binário Release (presente no Debug) |
| 2026-10-17 | `xcodebuild test` após design system | 17 testes em 5 suítes passaram (+ `PaletteContrastTests` com 22 casos, `DesignSupportTests`: dias juntos, parceiro, estado de sync, separação e seed da demonstração) |
| 2026-10-17 | Build Release após design system | BUILD SUCCEEDED; textos `DemoStores`, `demo.owner`, `AppCasalDemo`, `AppCasalInitialTab`, `Diagnóstico de compartilhamento`, `note-alerts-experiment` ausentes do binário |
| 2026-10-17 | Tempo de abertura (simulador iPhone 17, iOS 26.3, Debug, sem depurador) | bancos locais em ~10 ms; ambiente pronto em ~35 ms; primeira tela do espaço em ~120 ms após `init` do app (identidade local). Antes da correção, a tela de abertura gerada era vazia (preta em modo escuro) |
| 2026-10-17 | Tela de abertura e boas-vindas (modo escuro do sistema) | fundo `#FAF5EE` idêntico dentro e fora do logo (amostragem de pixels da captura); sem tela preta; 19 testes passaram (+ `AccountServiceTests`); `AppCasalHoldWelcome` ausente do binário Release |
| 2026-10-17 | Ícone escuro | `Assets.car` contém `AppIcon` com `UIAppearanceDark` (1024, não opaco) além da clara |
| 2026-10-17 | Ícone do app | build OK; `CFBundleIconName = AppIcon` no Info.plist final; ícone visível na tela inicial do simulador |
| 2026-10-17 | Capturas no simulador iPhone 17 (iOS 26.3), modo demonstração | Início, Mapa, Memórias, Recados, Metas, Nosso espaço (claro); Início e Recados (escuro); Início e Recados (acessibilidade XL); produção sem iCloud. Corrigidos durante a conferência: faixa sem gradiente sob a barra no Início, herói alto demais e cartões/segmentado truncados em acessibilidade |

Não testado: fluxo com conta iCloud real, criação do esquema CloudKit, convite, aceitação, sincronização entre aparelhos, avisos, conflitos.

## Última tarefa / ponto de retomada

- **2026-10-17:** etapas 0 e 1 implementadas. Arquivos principais: `AppCasal.xcodeproj/project.pbxproj`, `AppCasal/AppCasal.entitlements`, `AppCasal/Info.plist`, `AppCasal/App/*`, `AppCasal/Data/**`, `AppCasal/Services/AccountService.swift`, `AppCasal/Features/SharingSpike/SharingSpikeView.swift`, `AppCasalTests/*`. Template `ContentView.swift` removido.
- Experimento de avisos restrito a DEBUG; commit local da etapa (sem push).
- **2026-10-17:** design system, navegação e ambiente de demonstração implementados. Arquivos principais: `AppCasal/DesignSystem/**`, `AppCasal/App/{RootView,MainTabView,AppTab,AppEnvironment,AppCasalApp}.swift`, `AppCasal/Features/{Onboarding,Home,Map,Memories,Notes,Goals,Space}/*`, `AppCasal/Data/Demo/DemoData.swift`, `AppCasal/Assets.xcassets/*.colorset`, scheme `AppCasal Demo`, `AppCasalTests/{PaletteContrastTests,DesignSupportTests}.swift`. Sem commit ainda.
- **2026-10-17:** ícone do app aplicado a partir de `~/Downloads/Dois cadeados de coração interligados/apple-devices` (arte iOS 1024×1024).
- **2026-10-17:** tela preta na abertura corrigida: `UILaunchScreen` com a marca, `WelcomeView`, identidade iCloud guardada no aparelho para abrir sem rede, marcas de tempo `LaunchLog`. DEBUG: `-AppCasalHoldWelcome YES` mantém a tela de boas-vindas para revisão. Arquivos: `AppCasal/Info.plist`, `Assets.xcassets/{LaunchLogo.imageset,LaunchBackground.colorset}`, `Features/Onboarding/WelcomeView.swift`, `App/RootView.swift`, `Services/{AccountService,LaunchLog}.swift`, `AppCasalTests/AccountServiceTests.swift`, `project.pbxproj`.
- **2026-10-17:** usuário aprovou visual, paleta escura, commit e início do fluxo de memórias; ícone escuro gerado e aplicado.
- **Retomar em:** revisão das capturas pelo usuário → fluxo de memórias (entidades `Memory`/`MemoryPhoto` compatíveis com CloudKit, repositório, criação, edição, linha do tempo, detalhe, fotos, teste de reabertura). Testes S/N/C/P continuam pendentes até haver aparelhos.

## Próximos passos (em ordem)

1. Usuário revisa as capturas do design system e da navegação.
2. Fluxo de memórias (local, no modo demonstração e em produção sem sincronização validada).
3. Quando houver aparelhos: fluxo básico S1–S5 e P1; depois C1–C4, S6–S7, N1–N6, separadamente.
4. Registrar resultados; decidir solução de avisos com base em N1–N6.

## Histórico

- **2026-10-17:** projeto criado a partir do template; GitHub conectado; `.gitignore`; `AGENTS.md` e `CLAUDE.md` criados com diagnóstico e plano.
- **2026-10-17 (substituído):** plano inicial com SwiftData + `CKSyncEngine` e merge por campo próprio. Substituído por Core Data + `NSPersistentCloudKitContainer` para reduzir código de sincronização.
- **2026-10-17 (substituído):** proposta de iOS 27, iPhone + iPad, Swift 5, idioma `en`. Substituída por iOS 26, somente iPhone, Swift 6, pt-BR.
- **2026-10-17 (rejeitado):** avisos por `NoteSignal` no banco público. Não aprovado; substituído pelo experimento com `CKDatabaseSubscription` + `recordType`.
- **2026-10-17 (corrigido):** afirmação de que a exclusão lógica "nunca perde dados". Corrigida: facilita recuperação, não elimina sobrescritas.
- **2026-10-17 (substituído):** proposta de "Exportar uma cópia" ao sair e reconvite no mesmo espaço. Exportação adiada; novo parceiro passa a exigir novo espaço.
- **2026-10-17:** etapa 0 concluída e etapa 1 implementada (validação real pendente).
- **2026-10-17:** sem aparelhos disponíveis, usuário autorizou avançar em design system, navegação, demonstração e memórias. Implementados design system, navegação e modo demonstração; tela de teste da etapa 1 passou a ser diagnóstico só em DEBUG (antes era a tela inicial).
