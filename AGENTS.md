# AGENTS.md — AppCasal

Referência comum para todos os agentes (Claude, Codex e outros) que trabalham neste projeto. Contém só a arquitetura e as decisões vigentes; decisões substituídas ficam no "Histórico".

## Regras para agentes

1. **Leia este arquivo inteiro antes de iniciar qualquer tarefa.**
2. **Atualize este arquivo ao concluir cada etapa relevante e antes de interromper o trabalho.** Em tarefas longas, registre pontos de retomada em "Última tarefa / ponto de retomada".
3. O documento reflete o estado real do código. Nada é marcado como implementado ou validado sem evidência registrada em "Validações".
4. Separe sempre: **documentado pela Apple**, **hipótese de implementação** e **observado em teste**. Um teste isolado registra um comportamento observado; não o transforma em garantia do framework.
5. **Compartilhamento, sincronização entre parceiros, avisos e conflitos só podem ser marcados como validados após teste real em dois aparelhos com contas iCloud distintas** (ver "Testes que dependem de dois aparelhos").
6. Não inclua credenciais, tokens, senhas ou segredos neste arquivo nem no repositório.
7. Não sobrescreva trabalho existente sem inspecionar antes.
8. Não implemente expurgo automático, retenção permanente de cópia para quem sai do espaço nem exportação sem aprovação específica. Exclusão definitiva só por ação explícita do dono ("Apagar o espaço").
9. Não altere as assinaturas (subscriptions) internas do `NSPersistentCloudKitContainer`. Assinaturas próprias usam IDs próprios e APIs documentadas do CloudKit.
10. Swift 6 com verificação estrita de concorrência. Não use `@unchecked Sendable`, `nonisolated(unsafe)`, `@preconcurrency` ou `MainActor.assumeIsolated` para silenciar erros sem justificativa escrita no código e registrada aqui.
11. iOS mínimo 26.0. Não use APIs exclusivas do iOS 27 quando houver alternativa no iOS 26; se usar, proteja com `#available` e registre aqui.
12. Idioma: documentação e comunicação em pt-BR. Código, identificadores e commits em inglês. Todo texto visível vai para `Localizable.xcstrings`; não monte frases traduzíveis por concatenação de palavras.
13. Build por linha de comando: `xcode-select` aponta para as Command Line Tools. Use `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild ...`.
14. **Preferências do usuário:** não mexer nas cores aprovadas; não gerar capturas de tela para conferência (o usuário testa no próprio iPhone); validar com build e testes automatizados.

## Resumo atual

- **App completo em uso local:** todas as funcionalidades previstas, mais Lembretes (anuais e mensais) e notificações (permissão, tela de Notificações, push de recadinho), estão implementadas e validadas localmente (build, 60 testes unitários, 4 testes de UI de ponta a ponta).
- **Primeiro teste com dois iPhones (2026-10-18, relato do usuário):** convite pelo WhatsApp chegou e foi aceito, mas o WhatsApp demorou a abrir, a folha de compartilhamento mostrava um ícone de documento e a participante só viu o espaço após reabrir o app. Os três problemas foram corrigidos e **precisam ser revalidados** (S1, S2).
- **Hoje, nós dois (branch `feature/hoje-nos-dois`, commits locais, sem push):** pergunta do dia com revelação, histórico, Escolhe por nós (catálogo, Queremos ir, ideias próprias, planos e convites internos), Pequeno gesto, Vamos reviver?, Quem conhece melhor?, lembretes locais opcionais e rotas diretas. Validado localmente (101 testes unitários, 6 de UI, Debug e Release); nada validado entre duas contas (H1–H10).
- **Pendente:** apenas o que exige o segundo celular (convite, aceitação, sincronização entre parceiros, avisos, conflitos, sair/encerrar/apagar com o parceiro conectado).
- **Commits:** `71bfd68` (design system, navegação, demonstração, ícone, abertura). Memórias e o restante das funcionalidades estão **sem commit** (aguardando autorização do usuário).
- **Última atualização:** 2026-10-18.

## Produto

- **Nome:** AppCasal (**provisório**). Identificadores técnicos não usam o nome provisório.
- **Objetivo:** app iOS privado para um casal guardar memórias, lugares, recadinhos e metas em um espaço compartilhado só entre os dois, sincronizado por iCloud.
- **Vínculo:** exatamente duas pessoas (dono + um participante), contas iCloud distintas, sem compartilhamento público. Um novo relacionamento começa em um novo espaço; um novo parceiro nunca recebe o histórico do casal anterior.
- **Primeira versão:** somente iPhone, somente pt-BR (String Catalog pronto para tradução).

## Configuração do projeto

| Item | Valor |
|---|---|
| Xcode / SDK | 27.0 (27A266a) / iPhoneOS 27.0 |
| iOS mínimo | 26.0 |
| Dispositivos | iPhone (`TARGETED_DEVICE_FAMILY = 1`) |
| Modelo Core Data | `AppCasal 2` (atual, aditiva) + `AppCasal` (v1, mantida para migração leve automática) |
| Swift | 6.0; `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` no app e nos testes unitários; approachable concurrency |
| Idioma | `developmentRegion = pt-BR`; `Localizable.xcstrings` (fonte pt-BR, sincronizado pelo Xcode) |
| Targets | `AppCasal`, `AppCasalTests` (Swift Testing, hospedado), `AppCasalUITests` (XCTest UI; sem isolamento padrão, métodos `@MainActor`), `NoteNotificationService` (Notification Service Extension embutida no app; `jc.app.dev.AppCasal.NoteNotificationService`; entitlements próprios com o container CloudKit; sem isolamento padrão; compila também `AppCasal/Data/Notifications/NoteAlertContent.swift` e `NoteTimestamp.swift` por exceção de pasta sincronizada) |
| Schemes | compartilhados: `AppCasal` (real, CloudKit) e `AppCasal Demo` (DEBUG, `-AppCasalDemo YES`) |
| Bundle IDs | `jc.app.dev.AppCasal`, `jc.app.dev.AppCasalTests`, `jc.app.dev.AppCasalUITests` |
| Team | `F44CYBRGC2` (conta paga), assinatura automática |
| Container CloudKit | `iCloud.jc.app.dev.casal` (registrado no time; no perfil de provisionamento) |
| Entitlements | `AppCasal/AppCasal.entitlements`: CloudKit, container, `aps-environment = development` |
| Info.plist | gerado + parcial `AppCasal/Info.plist` (`CKSharingSupported`, `UIBackgroundModes = remote-notification`, `UILaunchScreen`); `INFOPLIST_KEY_NSLocationWhenInUseUsageDescription` no projeto |
| Tela de abertura | `LaunchBackground` `#FAF5EE` (fixa) + `LaunchLogo` (cadeados, fundo transparente, 220 pt) |
| Ícone | `AppIcon.png` (claro, arte do usuário) e `AppIcon-Dark.png` (escuro, gerado por recorte da arte clara); tingido gerado pelo sistema |
| Git | `main`, remoto `git@github.com:jcezart/AppCasal.git` (SSH via Keychain) |

## Tecnologias

SwiftUI (Liquid Glass do iOS 26), Core Data + `NSPersistentCloudKitContainer` (sem SwiftData), CloudKit (espelhamento e `CKShare` pelo framework), MapKit (iOS 26: `MKMapItem.location`/`address`), CoreLocation (`CLLocationUpdate`), PhotosUI, ImageIO, Network (`NWPathMonitor`), UserNotifications (lembretes locais; push de recadinho por `CKDatabaseSubscription`), LinkPresentation (prévia do convite na folha de compartilhamento). Nenhuma dependência externa.

## Arquitetura

**Padrão:** MVVM + Repository, proporcional. Views leem com `@FetchRequest`; toda escrita passa por repositórios; ViewModels só se surgir lógica que justifique (hoje nenhum).

- **RootView:** erro do store → boas-vindas (carregando) → iCloud indisponível → convite aceito aguardando o espaço (`AcceptingInvitationView`, sem formulário; recarrega a cada 2 s e a cada mudança remota) → criar espaço → entrar no espaço (participante sem `Member`) → `MainTabView`. A participação (`isMember`) fica em `@State` e é recalculada em `reload()`: o objeto do espaço é o mesmo antes e depois de entrar, então ler no `body` não atualizava a tela (causa do "Entrar no espaço" que não avançava).
- **MainTabView:** `TabView` nativo com Início, Mapa, Memórias, Recados, Metas; um `NavigationStack` por aba; "Nosso espaço" em sheet pelo avatar; abre a aba pedida por `AppEnvironment.pendingTab` (toque em aviso de recadinho → Recados); logo após "Criar nosso espaço" (`AppEnvironment.offersInvitation`) abre `InvitePartnerPromptView` ("Convidar seu par" salva o share com progresso e, ao fechar, abre a folha de compartilhamento; "Agora não"); depois oferece uma vez, só em produção, `NotificationPromptView` antes do pedido de permissão do sistema.
- **AppEnvironment** (`RunMode`): `.production` (CloudKit), `.demo` (só DEBUG, `-AppCasalDemo YES`, stores em `Application Support/DemoStores/`, sem CloudKit, identidade local, dados fictícios por `DemoData` usando os repositórios de produção; `-AppCasalDemoReset YES` e `-AppCasalDemoEmpty YES` para testes de UI), `.preview` (só DEBUG, em memória), `.tests` (em memória). Nunca ativado automaticamente.
- **PersistenceController:** `Private.sqlite` (`.private`) e `Shared.sqlite` (`.shared`) no mesmo container; histórico persistente e notificação remota; `viewContext` com `NSMergeByPropertyObjectTrumpMergePolicy`, `automaticallyMergesChangesFromParent`, `transactionAuthor = "app"`.
- **Hoje, nós dois:** `MomentsRepository` (pergunta do dia, respostas, jogo, planos, ideias próprias), `MomentsCatalog` (JSONs do bundle, validados, carregados no primeiro uso), regras puras em `Data/Moments` (`DailyQuestionPlanner`, `MomentsCalendar`, `Canonical`, `DateDraw`/`DateFilters`, `GameRules`, `GestureRules`, `ReviveRules`), `MomentsLocalStore` (rascunhos e históricos pessoais em `UserDefaults`, por espaço), `MomentNotifications` + `MomentReminderPlanner` (lembretes locais). Telas em `Features/Moments`, empilhadas no `NavigationStack(path:)` do Início por `MomentsRoute` (também alvo dos toques em notificações via `AppEnvironment.pendingRoute`). `MomentsObserver` redesenha quando registros da área mudam no contexto (inclusive vindos do par). `AppEnvironment.prepareMoments()` (dono) e `syncMomentNotifications()` rodam ao abrir e a cada mudança remota.
- **Repositórios:** `SpaceRepository` (espaço, membros, fotos, data, arquivar), `NoteRepository` (só o autor edita/exclui), `FavoriteRepository` (favoritos pessoais), `MemoryRepository` (+ `MemoryDraft`, `PlaceLink`), `GoalRepository` (+ `GoalDraft`), `PlaceRepository` (+ `PlaceDraft`), `ReminderRepository` (+ `ReminderDraft`). Atribuem o store do objeto relacionado; preenchem autoria e datas; exclusão lógica.
- **ShareService:** cria share (com título e miniatura: foto do casal ou logo), convite por `presentInvitation` (salva o share antes, se ainda não existe, com indicador de progresso; depois abre `UIActivityViewController` com `NSItemProvider.registerCKShare`, `specifiedRecipientsOnly` + `readWrite`, e `LPLinkMetadata` com título e miniatura; `ShareThumbnail` em `SpaceInvitation.swift`), `UICloudSharingController` só para gerenciar (participantes, parar de compartilhar; `itemThumbnailData` com a miniatura), aceita convites com `CoupleLimit`, marca `sharingEndedAt` ao parar de compartilhar, `leave` (participante) e `deletePermanently` (dono).
- **Serviços:** `AccountService` (estado iCloud; `userRecordName` guardado em `UserDefaults` para abrir sem rede; só "sem conta"/"restrito" bloqueiam), `SyncMonitor` (eventos de espelhamento + contagem de alterações pendentes pelo histórico persistente após o último envio bem-sucedido da sessão), `NetworkMonitor`, `LocationService` (permissão "durante o uso", pedida ao abrir o Mapa; uma leitura para distâncias), `PhotoProcessing` (ImageIO, ≤ 2048 px + miniatura 600 px, HEIC, sem metadados), `PlaceSearch` (`MKLocalSearch`), `Directions` (Mapas), `ReminderNotifications` (notificações locais dos lembretes: refaz todo o conjunto `reminder-<id>` a cada sincronização — ao abrir o app, após editar e a cada mudança no store, inclusive vinda do parceiro; até 60 pedidos pendentes, mais próximos primeiro; anual = gatilho repetido; mensal = próximas 6 ocorrências avulsas, renovadas a cada sincronização; `isAllowed` é a permissão do app), `NoteAlerts` (push de recadinho, ver "Avisos de recadinhos"), `LaunchLog`.
- **Isolamento (Swift 6):** `MainActor` padrão. Única marcação insegura: `Delivery` na extensão é `@unchecked Sendable` (handler e conteúdo do sistema não são `Sendable`; todo acesso sob `NSLock`, entregue uma única vez; justificativa no código). Subclasses de `NSManagedObject` são `nonisolated` (o espelhamento usa filas próprias; o isolamento real é o do contexto). Todo acesso do app é no `viewContext`. Trabalho pesado (`PhotoProcessing`, `ImageDecoder`, `PlaceSearch`) é `@concurrent` e só troca tipos `Sendable`. Contagem de histórico em contexto de fundo com `perform`.

### Árvore

```
AppCasal/
├── AGENTS.md / CLAUDE.md
├── AppCasal/
│   ├── App/                 # AppCasalApp, AppDelegate, SceneDelegate, AppEnvironment, RootView, MainTabView, AppTab
│   ├── DesignSystem/
│   │   ├── Tokens/          # Palette, Metrics, Typography
│   │   └── Components/      # cartões, chips, segmentado, botões, avatares, estados, progresso, NoteCards, MemoryCards,
│   │                        # GoalCard, GoalSummaryRow, InfoCard, CoupleHeroHeader, SettingsRow, AdaptiveStack,
│   │                        # PhotoView, PhotoPickerButton (+ DecodedImage, ImageDecoder; `crop:` abre PhotoCropView), PromptScaffold (telas de pedido), PhotoCropView (arrastar e pinça antes de salvar; quadro circular para perfil, quadrado para foto do casal), GoalStepsObserver
│   ├── Data/
│   │   ├── Model/           # AppCasal.xcdatamodeld, Entities/*, MemoryCategory, Categories (PlaceStatus, GoalCategory)
│   │   ├── Persistence/     # PersistenceController, SyncMonitor
│   │   ├── Sharing/         # ShareService, CoupleLimit, SpaceInvitation (+ ShareThumbnail)
│   │   ├── Moments/         # MomentsCatalog, DailyQuestionPlanner (+ MomentsCalendar, Canonical), DateIdeas (filtros e sorteio), MomentsRules (jogo, gestos, reviver), MomentsLocalStore
│   │   ├── Repositories/    # Space, Note, Favorite, Memory, Goal, Place, Reminder, Moments
│   │   ├── Notifications/   # NoteAlerts (push de recadinho), NoteAlertContent e NoteTimestamp (compartilhados com a extensão)
│   │   └── Demo/            # DemoData (só DEBUG)
│   ├── Services/            # Account, Network, Location, PhotoProcessing, ReminderNotifications, MomentNotifications, LaunchLog
│   ├── Resources/Moments/   # perguntas.json, dates.json, gestos.json, jogo.json (catálogo embarcado)
│   ├── Features/
│   │   ├── Onboarding/      # WelcomeView, CreateSpaceView, AcceptingInvitationView, JoinSpaceView, AccountUnavailableView; InvitePartnerViews (tela "Convide seu par" e cartão do Início)
│   │   ├── Home/            # HomeView
│   │   ├── Map/             # MapTabView, PlaceDetailView, PlaceSearch(+View)
│   │   ├── Memories/        # MemoriesView, MemoryDetailView, MemoryEditorView (+ seletor de lugar)
│   │   ├── Notes/           # NotesView, NoteComposerView
│   │   ├── Goals/           # GoalsView, GoalEditorView
│   │   ├── Moments/         # MomentsSupport (rotas, observador, contexto), MomentsDestination, ExploreMomentsView, DailyQuestionViews (cartão do Início, pergunta, descoberta, histórico), DatesViews (sorteio, planos, ideias), GestureAndReviveViews, GameViews
│   │   ├── Notifications/   # NotificationPromptView, NotificationSettingsView
│   │   ├── Space/           # SpaceView (perfil, foto do casal, data, lembretes, notificações, compartilhamento, apagar), RemindersView (+ editor), DeletedItemsView
│   │   └── SharingSpike/    # diagnóstico da etapa 1, só DEBUG
│   ├── Assets.xcassets, Localizable.xcstrings, AppCasal.entitlements, Info.plist
├── NoteNotificationService/ # NotificationService, PartnerNoteFetcher, Info.plist, entitlements
├── AppCasalTests/           # 101 testes (Swift Testing)
└── AppCasalUITests/         # MemoryFlowUITests, NotesAndGoalsUITests, RemindersUITests, MomentsUITests
```

### Modelo de dados

Todos os atributos opcionais ou com padrão, relacionamentos opcionais com inverso, sem unique constraints, sem `Deny` (verificado por `CloudKitSchemaTests`). Binários com armazenamento externo (viram `CKAsset`). Exclusão lógica (`deletedAt`, `deletedBy`) em tudo que é compartilhado. Progresso e dias juntos são calculados.

| Entidade | Zona | Campos principais | Quem escreve |
|---|---|---|---|
| `CoupleSpace` | casal | `relationshipStart`, `coverPhotoData`, `sharingEndedAt`, `deletedAt` (arquivado) | ambos (`sharingEndedAt`/arquivar: dono) |
| `Member` | casal | `userRecordName`, `displayName`, `role`, `avatarData` | só o próprio |
| `Note` | casal | `text`, `authorID`, `recipientID`, autoria, `deletedAt` | só o autor |
| `NoteFavorite` | **privada, zona padrão** | `noteID`, `userRecordName` | só o dono do favorito; remoção física (dado pessoal) |
| `Memory` | casal | `title`, `details`, `date`, `category`, `placeID`, `locationName`, `latitude`, `longitude` | ambos |
| `MemoryPhoto` | casal | `imageData`, `thumbnailData`, dimensões, `sortIndex` | ambos; remoção lógica |
| `Place` | casal | `name`, `address`, `category`, `latitude`, `longitude`, `status`, `note`, `visitedAt`, `memoryID` | ambos |
| `Goal` | casal | `title`, `category`, `dueDate`, `completedAt`, `completedBy`, `coverPhotoData` | ambos |
| `GoalStep` | casal | `title`, `sortIndex`, `doneAt`, `doneBy` | ambos; um registro por etapa |
| `DailyQuestion` (v2) | casal | `dayKey`, `questionID`, `questionText`, `category`, `catalogVersion`, `cycle`, `memoryID` | dono cria; `memoryID` qualquer um (primeiro vence) |
| `DailyAnswer` (v2) | casal | `dayKey`, `questionID`, `questionText`, `text`, `authorID`, `submittedAt`, `reaction` | só o autor; texto imutável após envio |
| `GameRound` (v2) | casal | `questionsJSON` (snapshot com alternativas), `catalogVersion`, `createdBy`, `cancelledAt` | quem cria |
| `GameAnswer` (v2) | casal | `roundID`, `authorID`, `entriesJSON` (escolha + palpite por pergunta) | só o autor; uma vez |
| `DatePlan` (v2) | casal | `sourceKind`, `sourceID`, `title`, `details`, `invitation`, `completedAt`, `memoryID`, exclusão lógica | ambos; convite respondido pelo par |
| `DateIdea` (v2) | casal | `title`, `details`, `location`, `costTier`, `durationMinutes`, `remoteFriendly`, `authorID`, exclusão lógica | só o autor |
| `Reminder` | casal | `title`, `date`, `daysBefore` (0–60; mensal 0–27), `notifies`, `repeatInterval` (`none`/`monthly`/`yearly`), `repeatsYearly` (legado, ainda gravado; usado quando `repeatInterval` é nulo) | ambos; `notifies` vale para os dois aparelhos |

Também na v2: `CoupleSpace.momentsTimeZone` (fuso do dia da pergunta) e `Memory.revisitOfMemoryID` (memória revivida).

Categorias: memória/lugar (Encontro, Viagem, Praia, Restaurante, Comemoração, Especial, Dia a dia, Outro); meta (Viagem, Relacionamento, Casa, Finanças, Saúde, Comemoração, Outro); situação do lugar (Queremos ir, Visitado).

## Funcionalidades (estado)

Legenda: **validado localmente** = build + testes automatizados (unitários e/ou UI) no simulador; **aguardando duas contas** = só validável com dois aparelhos.

| Funcionalidade | Implementado | Validado localmente | Aguardando duas contas |
|---|---|---|---|
| Abertura com marca, boas-vindas, abertura sem rede | sim | sim (medição ~120 ms; testes de conta) | — |
| Onboarding: criar espaço, entrar como participante, iCloud indisponível | sim | parcial (repositórios testados) | aceitar convite (S2) |
| Início: foto do casal, nomes (na linha da barra, ao lado do avatar), dias juntos, cartão "Seu par ainda não está aqui" com "Convidar seu par" enquanto o dono está sem par (`InvitePartner.isPending`, testado), último recadinho, meta em andamento (com miniatura da foto da meta), última memória, nova memória | sim | sim (testes de repositório; fluxos de UI relacionados) | ver dados do parceiro |
| Nosso espaço: perfil com foto e foto do casal (ambas ajustáveis antes de salvar: arrastar e pinça; recorte quadrado, `PhotoProcessing.process(_:cropping:)` testado), data de início, lembretes, notificações, excluídos recentemente, banner de sincronização | sim | sim (repositórios testados) | — |
| Convite, gerenciar/parar de compartilhar, sair do espaço, começar novo espaço, apagar o espaço | sim | parcial (`CoupleLimit`, arquivar testados) | S1–S8 |
| Memórias: criar, editar, linha do tempo por mês, detalhe, até 10 fotos, lugar, excluir/restaurar | sim | sim (unitários + UI: criar, editar, reabrir) | M1–M2 |
| Recados: escrever, recebidos/enviados, editar/excluir os próprios, favoritos pessoais | sim | sim (unitários + UI: escrever, reabrir) | S3–S5, N1–N6 |
| Metas: criar/editar com etapas e foto, marcar etapas, progresso, prazo, concluir/reabrir, histórico, excluir/restaurar | sim | sim (unitários + UI: criar, marcar/desmarcar etapa com progresso atualizado na hora, reabrir) | G1 |
| Mapa: busca, salvar lugar, marcadores, filtros, distância, como chegar, registrar visita → memória, editar/excluir | sim | parcial (repositório testado; busca e mapa dependem de rede/GPS, não automatizados) | — |
| Lembretes: título, data, repetir (não, todo mês, todo ano), dias antes, notificação local; sugestão de aniversário de namoro a partir da data de início | sim | sim (11 testes: cálculo de datas, anual, mensal, dia 31 em meses curtos, virada de mês, lembrete único passado, legado, repositório; UI: criar, fechar e reabrir) | notificação no aparelho do parceiro (R1) |
| Excluídos recentemente (memórias, metas, recados próprios, lugares, lembretes) | sim | sim (restauração testada nos repositórios) | — |
| Rede e alterações pendentes ("Sem conexão · N alterações aguardando envio") | sim | parcial (estado offline testado; contagem depende de envio real) | sim |
| Notificações: explicação + pedido de permissão uma vez; tela Nosso espaço > Notificações (estado, ativar, abrir Ajustes, preferência "Recadinhos do seu par") | sim | parcial (preferência testada; pedido do sistema não automatizado) | — |
| Hoje, nós dois: cartão no Início, Explorar momentos, pergunta do dia (rascunho local, envio com confirmação, espera, revelação, reação, guardar como memória), histórico | sim | sim (unitários: planejador, fuso, horário de verão, revelação, idempotência, duplicatas, isolamento; UI: responder, reabrir) | H1–H4 |
| Escolhe por nós (filtros, três fontes, sem repetir), ideias próprias, planos e convites internos, guardar memória do date | sim | sim (unitários: filtros, sorteio, deduplicação, planos, convites, lugar não vira visitado; UI: sortear e combinar) | H5–H6 |
| Pequeno gesto, Vamos reviver?, Quem conhece melhor? | sim | sim (unitários: gestos recentes, aniversários com 29/2, rodada, pontuação com pulos) | H7–H8 |
| Lembretes locais de Hoje, nós dois (opt-in; um por dia; rotas diretas) | sim | sim (planejador e rotas testados; entrega só no aparelho) | H9 |
| Push de recadinho com o texto do recado (`CKDatabaseSubscription` + `recordType` + `NoteNotificationService`) | sim | parcial (assinatura, banco por papel, escolha do recado e texto testados) | N1–N9 |

## Compartilhamento

**Documentado pela Apple (headers do SDK):** `share(_:to:)` compartilha o grafo relacionado; `acceptShareInvitations(from:into:)` aceita no store compartilhado; `purgeObjectsAndRecordsInZone(with:in:)` "remove a zona do banco associado ao store"; `CKSharingSupported` necessário para receber convites; `publicPermission = .none`; `UICloudSharingController.availablePermissions = [.allowPrivate, .allowReadWrite]`.

**Implementado:** dono convida pela folha de compartilhamento do sistema (título e miniatura); o share é salvo antes de abrir a folha (ou reaproveitado), para o app escolhido abrir no primeiro toque. No primeiro teste, com o share preparado pela própria folha (`.prepareShare`), o WhatsApp mostrava um aviso com "Continuar", voltava à folha, exigia tocar de novo no WhatsApp e demorava; gerencia pelo `UICloudSharingController`; aceitação a frio e com app aberto (`SceneDelegate`); recusa de convite com mais de um parceiro e de quem já é dono de um espaço; participante cria o próprio `Member`; objetos novos no store do espaço.

**Hipóteses a verificar com dois aparelhos:** objetos criados depois do share entram na zona compartilhada (S5); "Sair do espaço" com `purge` no store compartilhado remove o participante do share sem apagar os dados do dono (S8); "Apagar o espaço" com `purge` no store privado remove tudo para os dois; o participante perde a cópia local quando o share é encerrado (sem promessa para aparelho offline).

**Cota:** dados e fotos da zona compartilhada usam o iCloud do dono.

## Encerramento do vínculo (implementado conforme direção aprovada)

| Ação | Quem | Efeito |
|---|---|---|
| Parar de compartilhar (`UICloudSharingController` > Gerenciar) | dono | revoga o acesso do participante; dados ficam com o dono; marca `sharingEndedAt` e bloqueia novo convite neste espaço |
| Começar um novo espaço | dono, após encerrar | arquiva o espaço atual (`deletedAt`, dados mantidos) e abre a criação de um espaço novo e vazio |
| Sair do espaço | participante | `purge` da zona no store compartilhado: sai do share e apaga a cópia local; nada é apagado do iCloud do dono |
| Apagar o espaço | dono | ação explícita, digitar "APAGAR"; com share: `purge` da zona no store privado; sem share: exclusão dos objetos (cascata) |
| Exportação | — | não implementada (etapa posterior) |

## Conflitos

**Documentado pela Apple:** o `NSPersistentCloudKitContainer` não oferece gancho de merge com o servidor; a política do contexto vale para conflitos locais.

**Hipótese (pior caso, até C1–C4):** o último aparelho a enviar um registro pode sobrescrever o registro inteiro.

**Estratégia:** registros de um só escritor (`Member`, `Note`, `NoteFavorite`); listas como registros separados (`MemoryPhoto`, `GoalStep`); nada de contadores armazenados; "editado por" visível; exclusão lógica com restauração (facilita recuperar, **não elimina sobrescritas concorrentes**); exclusão física só por ação explícita.

**Observado:** nada ainda.

## Avisos de recadinhos

**Documentado (CKSubscription.h):** `CKDatabaseSubscription` funciona nos bancos privado e compartilhado e aceita `recordType`; `CKQuerySubscription` não funciona no compartilhado; o servidor exclui o aparelho de origem "quando apropriado"; notificações podem ser agrupadas. A existência da API não comprova o funcionamento no servidor.

**Implementado em produção (pedido do usuário, 2026-10-18; substitui o experimento DEBUG):** `NoteAlerts` salva `CKDatabaseSubscription` `note-alerts-v1` com `recordType = CD_Note`: dono no banco privado, participante no compartilhado. Título "Recadinho de <nome do par>". A assinatura de banco não traz campos, então usa `shouldSendMutableContent` e a extensão `NoteNotificationService` troca o corpo pelo texto do recado: busca as zonas alteradas (`databaseChanges`) e os registros alterados (`recordZoneChanges`, só `CD_text`, `CD_authorID`, `CD_createdAt`, `CD_modifiedAt`, `CD_deletedAt`; tokens próprios nos `UserDefaults` da extensão, independentes do espelhamento), escolhe o recado mais recente do parceiro alterado nos últimos 15 min e não excluído (`NoteAlertContent`, testado), corta em 240 caracteres e prefixa "Editado:" em edições. Subtítulo com dia e hora do recado (`NoteTimestamp`: "Hoje às 14:32", "Ontem às 09:05", "12 de out. às 14:32"; em edições, a hora da edição); os cartões de recado no app usam o mesmo formato. Se a zona do espaço foi apagada (dono apagou o espaço ou parou de compartilhar; a assinatura de banco também dispara nisso) ou, no banco compartilhado, não resta zona: "Nosso espaço" / "O espaço compartilhado foi encerrado. Abra o app para ver." (no segundo teste, apagar o espaço gerava "Chegou um carinho" no iPhone da parceira). Sem rede, sem recado elegível ou no limite de tempo do sistema: corpo genérico "Chegou um carinho pra você. Toque para ler." A extensão não esconde avisos: isso exige o entitlement `com.apple.developer.usernotifications.filtering`, concedido pela Apple sob pedido. Sem espaço ativo, o app remove a assinatura dos dois bancos (`removeEverywhere`). A primeira execução sem token lê os metadados de todos os registros da zona (sem fotos). Só é salva com permissão concedida, preferência ligada e parceiro já no espaço; removida ao desligar a preferência ou perder a permissão. Ao salvar, apaga o ID antigo do experimento (`note-alerts-experiment-v1`) para não duplicar. Sincronizada ao abrir o app e a cada mudança remota (uma vez por sessão para a mesma combinação papel + nome). Toque no aviso abre Recados: o delegate de `UNUserNotificationCenter` usa as variantes com completion handler no main actor (as variantes `async` nonisolated retomavam fora da main thread; no primeiro teste, tocar o aviso na tela bloqueada não abriu o app). Não toca nas assinaturas do `NSPersistentCloudKitContainer`. Banco público continua não aprovado.

**Riscos a medir (N1–N6):** aviso das próprias notas no outro aparelho do mesmo usuário, aviso em edições/exclusões/restaurações, atraso e agrupamento. Nada é prometido como imediato na interface.

## Hoje, nós dois (implementado na branch `feature/hoje-nos-dois`; validado localmente)

**Origem:** pedido do usuário (2026-10-18) com especificação e catálogo em `~/Downloads/AppCasal-Hoje-Nos-Dois/` (`PROMPT_CLAUDE.md`). Decisões aprovadas ali: catálogo embarcado, dados do casal no CloudKit pelos serviços atuais, sem sexta aba, sem backend, sem push nem deploy de esquema. Linha de base: `b6b3c86`, árvore limpa, 60 testes unitários + 4 de UI passando.

**Catálogo (`Resources/Moments/*.json`, `MomentsCatalog`):** 365 perguntas (73 por tema, alternadas), 100 dates, 100 gestos, 60 perguntas do jogo; nomes de campos mantidos; enums com os mesmos valores (`QuestionCategory`, `DateLocation`, `DateCost` + `a_confirmar` para ideias próprias e lugares). Validação ao carregar (schema 1, IDs únicos, 4 alternativas distintas); carregado na primeira utilização (`AppEnvironment.catalog`). Metadados de "à distância" revisados: os 10 marcados são viáveis por chamada; nenhum é "fora de casa".

**Modelo v2 (`AppCasal 2.xcdatamodel`, atual; v1 preservada para migração leve):** `CoupleSpace.momentsTimeZone`, `Memory.revisitOfMemoryID` e as entidades `DailyQuestion`, `DailyAnswer`, `GameRound`, `GameAnswer`, `DatePlan`, `DateIdea`, todas na zona do casal (relação com o espaço), atributos opcionais, sem unicidade. Registros guardam cópia do texto do catálogo (pergunta, alternativas), então atualizar o catálogo não muda nada já criado. Migração testada: store v1 com espaço, memória, recado e lugar abre na v2 com tudo preservado (`modelV1StoreMigratesWithItsData`, cópia temporária).

**Pergunta do dia:** o dono prepara hoje + 13 dias (`DailyQuestionPlanner`, determinístico: temas alternados, sem repetir até esgotar, depois novo ciclo); o participante só lê. Dia = data no fuso do espaço (`momentsTimeZone`, gravado pelo dono na primeira preparação); vira à meia-noite desse fuso; horário de verão não muda a chave; relógio divergente ou dia não preparado = "ainda não disponível". Duplicatas (dois aparelhos do dono offline): vence a criada primeiro, depois o menor ID (`Canonical`), sem apagar nada; respostas a outra pergunta ficam guardadas fora daquela descoberta. Resposta enviada é final (reenviar o mesmo texto devolve a existente; texto diferente é recusado); rascunho fica só no aparelho (`MomentsLocalStore`). Revelação só quando os dois enviaram: regra de interface, não sigilo técnico (a resposta do par pode já estar no aparelho).

**Interface:** cartão discreto no Início (pergunta de hoje, estado real, Responder/Continuar/Ver pergunta/Ver respostas, "Explorar momentos"); cinco abas mantidas. Explorar: a pergunta do dia como ação principal, depois Quem conhece melhor?, Escolhe por nós, Pequeno gesto, Vamos reviver?, Perguntas anteriores, Planos e convites. Componentes e tokens existentes; sem roleta, moedas, ranking ou sequência que zera. Linhas horizontais viram verticais em tamanhos de acessibilidade (`AdaptiveStack`); reações são símbolos com rótulo para VoiceOver.

**Pessoal, só no aparelho (`MomentsLocalStore`):** rascunhos de resposta e do jogo, gestos sugeridos e feitos (para não revelar surpresas ao par), memórias já sugeridas em "Vamos reviver?". Chaves incluem o ID do espaço.

**Jogo, dates, ideias:** rodada de 5 perguntas sem repetir, preferindo as não usadas; snapshot fixo; comparação por ID de pergunta + alternativa; pular não entra no denominador. "Vamos fazer" reaproveita o plano aberto da mesma ideia; convite (`invitation`: pending/accepted/declined/cancelled) respondido no mesmo registro; concluir não cria memória nem marca lugar como visitado. Ideias próprias: só o autor edita/exclui (logicamente). Filtros independentes; valores desconhecidos nunca passam em filtros restritivos; "Qualquer custo" aceita custo variável/a confirmar. Lugares "Queremos ir" entram como fonte (sem preço e duração: "a confirmar"); selecionar não marca visitado; "Registrar visita e guardar" usa o fluxo existente do editor de memória (marca visitado só ao salvar). Fontes próprias ligadas por padrão quando têm itens. Sem localização: o sorteio não pede permissão.

**Gestos e reviver:** gesto evita os 30 últimos; "Escrever um recadinho" abre o editor existente vazio (a pessoa escreve e envia). Reviver: aniversário de hoje primeiro (≥ 1 ano; 29/2 lembrado em 28/2 nos anos comuns), senão a memória mais antiga com ≥ 30 dias não sugerida recentemente; "Reviver esse momento" abre o editor com sugestões e grava `revisitOfMemoryID` só ao salvar; a original não muda.

**Memória a partir da área:** "Guardar como memória" (descoberta) e "Guardar esse momento" (date feito) abrem o editor existente preenchido; nada é gravado sem "Salvar"; o editor ignora toque duplo; o vínculo (`memoryID`) guarda só o primeiro.

**Notificações (locais, opt-in em Nosso espaço > Notificações):** lembrete da pergunta do dia no horário escolhido (padrão 20h), ideia de encontro às sextas, aniversário de memórias. No máximo uma por dia (prioridade: pergunta > aniversário > ideia), janela de 7 dias (`moments-*`), refeita ao abrir, após responder e a cada mudança remota; dia já respondido não recebe lembrete. Texto da pergunta só se aquele dia já estiver no aparelho; nunca respostas. `ReminderNotifications.maximumPending` passou de 60 para 56 (56 + 7 < 64). Toque abre a tela certa (`MomentsRoute`); dado ausente (apagado, outro espaço, não sincronizado) mostra indisponível.

**Avisos remotos (par respondeu, convite de date/jogo): não implementados, de propósito.** A única via sem servidor é `CKDatabaseSubscription` por tipo de registro, que dispara em qualquer alteração da zona daquele tipo (inclusive reações, cancelamentos e exclusão do espaço, como visto em N9) e não pode ser escondida pela extensão sem o entitlement de filtragem. Resultado provável: avisos falsos ("seu par respondeu" quando só reagiu). Até haver o entitlement `com.apple.developer.usernotifications.filtering` (pedido à Apple) ou outra aprovação, o estado aparece só dentro do app (cartão, Explorar, Planos). Sem push silencioso + notificação local.

**Limites conhecidos:** a revelação é regra de interface, não sigilo; controle de autoria é no cliente (o compartilhamento atual não dá autorização por registro no servidor); duas rodadas iniciadas offline pelos dois: vale a mais antiga e a outra fica incompleta no histórico; relógio errado mostra "ainda não disponível"; o participante depende do dono ter aberto o app nos últimos 14 dias; o String Catalog só recebe os textos novos quando o projeto é aberto no Xcode (CLI não sincroniza); preços nunca são prometidos.

## Design system (aprovado pelo usuário; não alterar cores)

**Referência:** imagem "Álbum afetivo de Ana e Lucas" (`~/Downloads`). Conteúdo fictício só no modo demonstração e em previews.

| Token (`Palette`) | Asset | Claro | Escuro |
|---|---|---|---|
| `canvas` | Canvas | `#F7F0E8` | `#1C1614` |
| `surface` | Surface | `#FCF8F3` | `#272019` |
| `surfaceMuted` | SurfaceMuted | `#F2E4DA` | `#352A24` |
| `accent` | Terracotta | `#B4553F` | `#A9503B` |
| `onAccent` | OnTerracotta | `#FFFFFF` | `#FFFFFF` |
| `accentText` | TerracottaText | `#9A4433` | `#E39A86` |
| `textPrimary` | Ink | `#3D1F1A` | `#F3E7DF` |
| `textSecondary` | InkSecondary | `#6E5D55` | `#BFAEA5` |
| `success` | Leaf | `#356B40` | `#7CBF88` |
| `hairline` | Hairline | `#E8DAD0` | `#3A302B` |

Contraste ≥ 4,5:1 medido por `PaletteContrastTests` nos dois modos. Tipografia New York (títulos, nomes, recadinhos) + SF Pro, sempre estilos de texto (Dynamic Type); títulos de navegação em serifada via `NavigationAppearance`. `AdaptiveStack` e segmentado verticalizam em tamanhos de acessibilidade. Formulários com linhas `surface` (`listRowBackground`).

**Liquid Glass:** barra de abas e barras nativas; busca, filtros e "+" do mapa (`GlassEffectContainer`, `.glassProminent`); "+"/"Escrever recadinho"/"Nova meta" (`.glassProminent` tingido); botão "Foto do casal" sobre o herói (`.glass`). Sem glass em cartões, formulários, banners e segmentado.

## Testes que dependem de dois aparelhos

Disponibilidade dos dois aparelhos: **não confirmada**. Simulador não conta como validação.

| ID | Teste | Estado |
|---|---|---|
| S1 | Dono cria espaço e envia convite | parcial (2026-10-18): convite pelo WhatsApp chegou; ícone de documento corrigido; share agora salvo antes de abrir a folha. O aviso do sistema "Compartilhe o link no app WhatsApp" (opções "Permitir a Qualquer Pessoa com o Link" e "Continuar") é do iOS para `specifiedRecipientsOnly` em apps de terceiros e não pode ser removido sem link público; "Continuar" mantém o convite privado (só a primeira pessoa a abrir entra). A linha "Convidar seu par" orienta a tocar em Continuar. Terceiro teste: WhatsApp abriu direto depois de "Continuar" (com demora do sistema) |
| S2 | Participante aceita (app fechado e aberto) e entra com o nome | parcial (2026-10-18): aceitou, mas só entrou após reabrir o app; corrigido, revalidar |
| S3 | Recadinho de A aparece em B e vice-versa | não testado |
| S4 | Edição, exclusão lógica e restauração propagam | não testado |
| S5 | Itens criados pelo dono após o share chegam ao participante | não testado |
| S6 | Convite com segundo parceiro é recusado | não testado |
| S7 | Parar de compartilhar revoga acesso, mantém dados do dono, bloqueia novo convite | não testado |
| S8 | Participante "Sair do espaço" não apaga dados do dono | não testado |
| M1 | Memória com 3 fotos criada em A aparece com fotos em B | não testado |
| M2 | Mesma memória editada offline nos dois | não testado |
| G1 | Etapas marcadas ao mesmo tempo nos dois aparelhos | não testado |
| R1 | Lembrete com notificação criado em A agenda a notificação também em B | não testado |
| P1 | Fechar e reabrir nos dois aparelhos (também offline) | não testado em aparelho (coberto por testes locais) |
| R2 | Lembrete mensal notifica nos meses seguintes (inclusive dia 31) | não testado |
| N1–N6 | Avisos: dono↔participante, estados do app (aberto, fundo, fechado), próprio aviso, edição/exclusão, tempo, duplicação | não testado |
| N7 | O aviso mostra o texto do recadinho e o dia e hora no subtítulo (dono→participante e participante→dono) | não testado |
| N8 | Tocar o aviso na tela bloqueada (app fechado e em segundo plano) abre o app em Recados | falhou no primeiro teste; corrigido, revalidar |
| N9 | Dono apaga o espaço: a parceira recebe "O espaço compartilhado foi encerrado", não um recadinho | falhou no segundo teste; corrigido, revalidar |
| H1 | Dono e participante veem a mesma pergunta do dia (inclusive com fusos diferentes nos aparelhos) | não testado |
| H2 | Resposta de A não aparece em B antes de B responder; depois os dois veem as duas | não testado |
| H3 | Participante sem a pergunta sincronizada vê "ainda não disponível", nunca outra pergunta | não testado |
| H4 | Reação e "Guardar como memória" aparecem nos dois sem duplicar | não testado |
| H5 | Convite de date: A convida, B aceita/recusa; o mesmo plano muda nos dois | não testado |
| H6 | Ideia própria de A aparece em B com o autor; B não edita | não testado |
| H7 | Rodada do jogo: mesmas 5 perguntas nos dois; resultado só após os dois terminarem | não testado |
| H8 | "Vamos reviver?" e gestos não mostram nada ao par | não testado |
| H9 | Lembrete local do dia chega no horário e some após responder; toque abre a pergunta | não testado |
| H10 | Atualização do app nos iPhones atuais: migração v1 → v2 preserva memórias, fotos, recados, metas, lugares e o vínculo | não testado (coberto por teste local com store v1) |
| C1–C4 | Conflitos: mesmo campo offline, exclusão × edição, exclusão física × edição, criação offline | não testado |

## Decisões vigentes

| Decisão | Justificativa |
|---|---|
| Core Data + `NSPersistentCloudKitContainer`, sem SwiftData | menos código de sincronização; CKShare, offline e fotos nativos |
| Container `iCloud.jc.app.dev.casal` | neutro, padrão `jc.app.dev.*` |
| iOS 26, Swift 6, só iPhone, pt-BR | alcance, segurança de concorrência, foco |
| Exclusão lógica + "Excluídos recentemente", sem expurgo automático | recuperação (não evita sobrescritas) |
| Exatamente duas pessoas; novo parceiro = novo espaço (arquivar o antigo) | privacidade |
| Favoritos pessoais na zona padrão do store privado, sem relação com dados do casal | nunca compartilhados |
| Só o autor edita/exclui recadinhos | um escritor por registro reduz conflitos |
| Fotos: ≤ 2048 px HEIC, sem metadados; avatar e capa de meta em miniatura 600 px | cota do iCloud do dono e privacidade (sem localização embutida) |
| Identidade iCloud guardada no aparelho | abrir rápido e offline |
| Permissão de localização só ao abrir o Mapa | pedir no momento da necessidade |
| Lembretes do casal (compartilhados); notificação local às 9h, `daysBefore` dias antes; anual por gatilho repetido, mensal por 6 ocorrências avulsas renovadas | o lembrete é do casal; cada aparelho agenda a própria notificação, sem servidor; gatilho repetido não expressa "N dias antes do dia 31" |
| Push de recadinho por `CKDatabaseSubscription` + `recordType` em produção, com preferência pessoal; texto do recado preenchido por Notification Service Extension | pedido do usuário; sem servidor próprio nem banco público; validar N1–N9 |
| Permissão de notificação: tela de explicação uma vez + Nosso espaço > Notificações | o iOS não permite instalar com notificações já ativas; pedir com contexto |
| Convite: share salvo antes, depois folha do sistema com `registerCKShare`; `UICloudSharingController` só para gerenciar | o app escolhido abre no primeiro toque; mesmas restrições (privado, leitura e escrita) |
| Barras das telas de edição com símbolos do iOS 26: X (`role: .cancel`), ✓ (`role: .confirm`; "Enviar" com avião de papel), lixeira em "Apagar"; títulos mantidos para VoiceOver; peças com forma própria usam `.tile` | com "Formatos dos Botões" ativado (visto no iPhone da parceira), os textos "Cancelar"/"Salvar" ficavam sublinhados dentro da cápsula de vidro e o bloco "Adicionar" ganhava um segundo fundo |
| ✓ das barras com `confirmationButtonStyle()` | o botão `role: .confirm` usa vidro proeminente azul do sistema, e o `.tint` da tela não o alcança |
| Telas de pedido ("Convide seu par", notificações) em `PromptScaffold`: ícone, título e texto centralizados; ação principal `.primary` em largura total no rodapé; alternativa ("Agora não", "Remover foto") em `.text` (só texto, centralizado, mesma largura) | regra `primary-action` (Apple HIG, também no `ui-ux-pro-max`): uma ação principal, a secundária visualmente subordinada; antes o "Agora não" era um `.soft` estreito à esquerda |
| Hoje, nós dois: catálogo embarcado; dados do casal no espaço (CloudKit pelo espelhamento atual); modelo v2 aditivo com v1 mantida | pedido aprovado; sem copiar 625 itens por espaço; migração leve sem apagar dados |
| Pergunta do dia preparada pelo dono (14 dias), dia no fuso do espaço, duplicatas resolvidas por criação + ID | mesma pergunta para os dois sem servidor; offline sem inventar pergunta |
| Resposta enviada imutável; revelação quando os dois enviaram | evita mudança silenciosa depois de revelar |
| Avisos de Hoje, nós dois só locais; remotos adiados | assinatura de banco não distingue eventos e a extensão não esconde avisos |
| Modo demonstração só DEBUG, por argumento explícito, stores próprios | nunca misturar com dados reais |

## Pendências do usuário

- Autorizar commit das memórias e das demais funcionalidades.
- Com os dois iPhones: revalidar S1–S2 (convite e entrada) e executar S3–S8, M1–M2, G1, R1–R2, P1, N1–N6, depois C1–C4. Em cada aparelho: iCloud ativo, Modo de Desenvolvedor, rodar pelo Xcode.
- Antes do TestFlight: publicar o esquema CloudKit em Production no CloudKit Console (agora com os tipos `CD_DailyQuestion`, `CD_DailyAnswer`, `CD_GameRound`, `CD_GameAnswer`, `CD_DatePlan`, `CD_DateIdea` e os campos novos; criados no ambiente de desenvolvimento ao usar o app).
- Hoje, nós dois: abrir o projeto no Xcode uma vez (sincroniza o String Catalog), revisar a branch `feature/hoje-nos-dois`, decidir merge/push e executar H1–H10.
- Para avisos remotos de "seu par respondeu": decidir se pede à Apple o entitlement de filtragem de notificações.

## Problemas conhecidos

- Validações entre contas bloqueadas até haver dois aparelhos.
- Entrega real das notificações de lembrete e do push de recadinho não é coberta por teste automatizado (cálculo de datas e configuração da assinatura são testados); conferir no iPhone. No modo demonstração a permissão não é pedida e a tela de explicação não aparece.
- Push de recadinho também dispara em edições, exclusões e restaurações de recados (limitação da assinatura de banco).
- O convite com `specifiedRecipientsOnly` precisa ser revalidado pelo WhatsApp (S1); o aviso com "Continuar" pode ser do próprio sistema.
- A extensão de notificação precisa de perfil de provisionamento próprio (novo bundle ID com iCloud); a assinatura automática do Xcode cria ao rodar no iPhone. Não validado em aparelho.
- Metas: o progresso dependia de observar só a meta; marcar uma etapa altera só a etapa. Corrigido com `GoalStepsObserver` (escuta `NSManagedObjectContextObjectsDidChange` do contexto, inclusive mesclas vindas do parceiro).
- Seletor de fotos do sistema, busca do MapKit e GPS não são cobertos por testes automatizados (dependem de UI do sistema, rede e localização).
- Contagem de pendências só aparece depois de um envio bem-sucedido na sessão.
- Fotos e itens excluídos logicamente continuam ocupando espaço até haver expurgo aprovado.
- A tela de diagnóstico (DEBUG) ainda tenta editar recadinho do parceiro e recebe o erro "Só quem escreveu…", como esperado pela regra atual.
- `navigationSubtitle` é truncado pelo sistema em tamanhos de acessibilidade.
- Reduzir Transparência e Aumentar Contraste não conferidos.

## Validações

| Data | O quê | Resultado |
|---|---|---|
| 2026-10-17 | Etapa 0: builds, perfil com container, Info.plist | OK |
| 2026-10-17 | Design system: contraste (22 casos), Release sem código de demonstração | OK |
| 2026-10-17 | Abertura: ~120 ms até o espaço (simulador, Debug); sem tela preta | OK |
| 2026-10-17 | Ícone escuro no `Assets.car` (`UIAppearanceDark`) | OK |
| 2026-10-17 | Suíte completa após todas as funcionalidades | 35 testes unitários em 8 suítes e 3 testes de UI passaram: `MemoryFlowUITests` (criar, editar, fechar e reabrir), `NotesAndGoalsUITests` (escrever recadinho, criar meta com etapa, marcar, fechar e reabrir), capturas de memórias |
| 2026-10-17 | Lembretes | 42 testes unitários e 4 de UI passaram (`RemindersUITests`: criar pela tela, fechar e reabrir); Release BUILD SUCCEEDED |
| 2026-10-18 | Progresso das metas e texto do recadinho no aviso (extensão) | 56 testes unitários e 4 de UI passaram (UI: marcar, desmarcar e marcar etapa com progresso na hora); Release BUILD SUCCEEDED com a extensão embutida |
| 2026-10-18 | Hoje, nós dois — incrementos 3 a 8 (telas, dates, gestos, reviver, jogo, lembretes, rotas, acessibilidade) | 101 testes unitários e 6 de UI passaram (`MomentsUITests`: responder e reabrir; sortear e combinar date); Debug e Release BUILD SUCCEEDED; Release sem conteúdo de demonstração; sem capturas (preferência do usuário) |
| 2026-10-18 | Hoje, nós dois — incremento 2 (catálogo, modelo v2, regras, repositório) | 94 testes unitários passaram (34 novos: contagens do catálogo, migração v1→v2 com dados, planejador, reconciliação de duplicatas, revelação, idempotência, isolamento entre espaços, jogo, filtros, ideias) |
| 2026-10-18 | Convite logo após criar o espaço ("Agora não") e cartão no Início; ✓ das barras na cor do app | 60 testes unitários e 4 de UI passaram |
| 2026-10-18 | Aviso de espaço encerrado em vez de recadinho falso; assinatura removida sem espaço | 59 testes unitários e 4 de UI passaram; só validável com dois iPhones (N9) |
| 2026-10-18 | Botões com "Formatos dos Botões" ativado (símbolos na barra, `.tile` no "Adicionar") | 59 testes unitários e 4 de UI passaram; aparência com a opção ligada só conferida no iPhone |
| 2026-10-18 | Ajuste de foto (perfil e casal) e convite com share salvo antes | 59 testes unitários e 4 de UI passaram (recorte testado); convite pelo WhatsApp só validável no iPhone (S1) |
| 2026-10-18 | Dia e hora do recado (aviso e cartões) e toque no aviso | 58 testes unitários e 4 de UI passaram; toque na tela bloqueada só validável no iPhone (N8) |
| 2026-10-18 | Lembretes mensais, notificações, push de recadinho, convite por `ShareLink`, correção da entrada do participante, Início | 51 testes unitários e 4 de UI passaram; Release BUILD SUCCEEDED |
| 2026-10-17 | Release após todas as funcionalidades | BUILD SUCCEEDED; sem conteúdo fictício, sem `AppCasalDemo`, sem experimento de avisos; `NSLocationWhenInUseUsageDescription` presente |

## Última tarefa / ponto de retomada

- **2026-10-17:** implementadas todas as funcionalidades que não dependem do segundo celular: foto do casal e perfis com foto; recados completos com favoritos pessoais; metas com etapas, progresso, prazo, conclusão e histórico; mapa com busca, lugares, filtros, distância, rotas e registrar visita; memórias com lugar; excluídos recentemente unificado; rede e pendências; gestão do espaço (convidar, gerenciar, sair, novo espaço, apagar).
- **2026-10-17:** Lembretes em Nosso espaço (pedido do usuário): lista, editor (título, data, repetir todo ano, dias antes, notificação), sugestão de aniversário de namoro, notificações locais, restauração em Excluídos recentemente.
- **2026-10-18:** retorno do primeiro teste com dois iPhones: lembretes mensais; explicação e pedido de permissão + tela de Notificações; push de recadinho em produção (experimento DEBUG removido); convite por `ShareLink` (mais rápido, com miniatura); participante entra sem reabrir o app; Início com miniatura da meta e nome do casal mais acima.
- **2026-10-18:** progresso das metas atualiza na hora; aviso de recadinho mostra o texto do recado (Notification Service Extension).
- **2026-10-18:** dia e hora do recado no subtítulo do aviso e nos cartões; toque no aviso (tela bloqueada) corrigido no delegate, revalidar N8.
- **2026-10-18:** ajuste da foto de perfil e do casal antes de salvar; convite salva o share antes de abrir a folha (WhatsApp no primeiro toque).
- **2026-10-18:** botões das barras de edição viram X / ✓ (iOS 26), sem sublinhado com "Formatos dos Botões"; bloco "Adicionar" sem fundo duplicado.
- **2026-10-18:** apagar o espaço não gera mais "recadinho" na parceira: a extensão detecta a zona apagada e avisa que o espaço foi encerrado.
- **2026-10-18:** aviso "Compartilhe o link no app WhatsApp" identificado como do sistema (manter "Continuar"); dica na linha do convite; ✓ das barras ficava azul (o `.tint` da tela não chega à barra): agora `confirmationButtonStyle()` (`.glassProminent` + `Palette.accent`) em cada botão `role: .confirm`. WhatsApp abriu direto depois de "Continuar", com alguma demora (o iOS prepara o link de uso único no iCloud nesse momento).
- **2026-10-18:** ao criar o espaço, tela "Convide seu par" com "Agora não"; cartão de convite no Início até o par entrar; opção em Nosso espaço mantida.
- **2026-10-18:** telas de pedido refeitas no padrão da Apple (`PromptScaffold`, botão de texto `.text`); "Remover foto" e o botão do cartão de convite alinhados.
- **2026-10-18:** Hoje, nós dois implementado na branch `feature/hoje-nos-dois` (commits locais `c9b4373`, `f507a36` e seguintes; sem push).
- **Retomar em:** usuário revisa a branch de Hoje, nós dois, decide merge/push e testa H1–H10 com os dois iPhones; revalidação dos testes S/N pendentes.

## Próximos passos

1. Usuário testa no próprio iPhone e autoriza o commit.
2. Testes com dois aparelhos (ordem acima).
3. Ajustar o push de recadinho com base em N1–N9 (ex.: avisos de edição).
4. Endurecimento e revisão para App Store.

## Histórico

- **2026-10-17:** projeto criado; GitHub conectado; `.gitignore`; `AGENTS.md` e `CLAUDE.md`.
- **2026-10-17 (substituído):** SwiftData + `CKSyncEngine` → Core Data + `NSPersistentCloudKitContainer`.
- **2026-10-17 (substituído):** iOS 27, iPhone + iPad, Swift 5, `en` → iOS 26, iPhone, Swift 6, pt-BR.
- **2026-10-17 (rejeitado):** avisos por `NoteSignal` no banco público → experimento `CKDatabaseSubscription` + `recordType`.
- **2026-10-17 (corrigido):** "exclusão lógica nunca perde dados" → facilita recuperação, não elimina sobrescritas.
- **2026-10-17 (substituído):** exportação ao sair e reconvite no mesmo espaço → exportação adiada; novo parceiro = novo espaço.
- **2026-10-17:** etapa 0 concluída; etapa 1 implementada (validação real pendente).
- **2026-10-17:** design system, navegação, demonstração, ícones e abertura (commit `71bfd68`).
- **2026-10-17 (substituído):** tela de teste da etapa 1 como tela inicial → diagnóstico só em DEBUG; recadinho editável pelos dois → só pelo autor; lista de excluídos só de memórias → unificada.
- **2026-10-17:** memórias, depois todas as funcionalidades locais (foto do casal, recados, metas, mapa, gestão do espaço, rede/pendências).
- **2026-10-17:** Lembretes.
- **2026-10-18 (substituído):** experimento DEBUG de avisos → push de recadinho em produção; convite por `UICloudSharingController` → `ShareLink` (gerenciar continua no controller) → share salvo antes + `UIActivityViewController` (o `.prepareShare` do `ShareLink` exigia tocar duas vezes no WhatsApp); lembrete só anual → não repetir, mensal, anual.
