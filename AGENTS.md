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
- **Hoje, nós dois (na `main` e no GitHub desde 2026-10-19):** pergunta do dia com revelação, histórico, Escolhe por nós (catálogo, Queremos ir, ideias próprias, planos e convites internos), Pequeno gesto, Vamos reviver?, Quem conhece melhor?, aviso diário de pergunta nova (ligado por padrão), push de "seu par respondeu" e rotas diretas. Validado localmente (testes unitários e de UI, Debug e Release); nada validado entre duas contas (H1–H13).
- **Pendente:** apenas o que exige o segundo celular (convite, aceitação, sincronização entre parceiros, avisos, conflitos, sair/encerrar/apagar com o parceiro conectado).
- **Commits:** `71bfd68` (design system, navegação, demonstração, ícone, abertura). Memórias e o restante das funcionalidades estão **sem commit** (aguardando autorização do usuário).
- **Última atualização:** 2026-10-26 (assinatura com Superwall configurada; esquema CloudKit publicado; ficha da App Store completa, com site de suporte e privacidade e rótulos de privacidade publicados; pronto para commit quando o usuário pedir — o commit vai para o TestFlight pelo Xcode Cloud).

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
| Dispositivos | só iPhone (`TARGETED_DEVICE_FAMILY = 1`, `SUPPORTED_PLATFORMS = iphoneos iphonesimulator`; sem Mac Catalyst, sem "Designed for iPhone" no Mac e no Vision Pro) |
| Modelo Core Data | `AppCasal 3` (atual; só `CoupleSpace.accessExpiresAt`) + `AppCasal 2` e `AppCasal` (v1), mantidas para migração leve automática |
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

SwiftUI (Liquid Glass do iOS 26), Core Data + `NSPersistentCloudKitContainer` (sem SwiftData), CloudKit (espelhamento e `CKShare` pelo framework), MapKit (iOS 26: `MKMapItem.location`/`address`), CoreLocation (`CLLocationUpdate`), PhotosUI, ImageIO, Network (`NWPathMonitor`), UserNotifications (lembretes locais; push de recadinho por `CKDatabaseSubscription`), LinkPresentation (prévia do convite na folha de compartilhamento), StoreKit 2 (estado da assinatura). Única dependência externa: **SuperwallKit** (SPM, `Superwall-iOS` até a próxima major a partir de 4.0.0; resolvido 4.18.2), só no target do app.

## Arquitetura

**Padrão:** MVVM + Repository, proporcional. Views leem com `@FetchRequest`; toda escrita passa por repositórios; ViewModels só se surgir lógica que justifique (hoje nenhum).

- **RootView:** erro do store → boas-vindas (carregando) → iCloud indisponível → convite aceito aguardando o espaço (`AcceptingInvitationView`, sem formulário; recarrega a cada 2 s e a cada mudança remota) → criar espaço → entrar no espaço (participante sem `Member`) → `MainTabView`. A participação (`isMember`) fica em `@State` e é recalculada em `reload()`: o objeto do espaço é o mesmo antes e depois de entrar, então ler no `body` não atualizava a tela (causa do "Entrar no espaço" que não avançava).
- **MainTabView:** `TabView` nativo com Início, Hoje ("Hoje, nós dois"), Mapa, Memórias, Recados; Metas fica no fim do Início (resumo da meta em andamento e "Ver todas as metas", `home.goals`), porque a barra do iPhone comporta 5 abas; um `NavigationStack` por aba; "Nosso espaço" em sheet pelo avatar; abre a aba pedida por `AppEnvironment.pendingTab` (toque em aviso de recadinho → Recados); logo após "Criar nosso espaço" (`AppEnvironment.offersInvitation`) abre `InvitePartnerPromptView` ("Convidar seu par" salva o share com progresso e, ao fechar, abre a folha de compartilhamento; "Agora não"); depois oferece uma vez, só em produção, `NotificationPromptView` antes do pedido de permissão do sistema.
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
├── AppCasalTests/           # 102 testes (Swift Testing)
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
| Nosso espaço: perfil com foto e foto do casal (ajuste antes de salvar como Instagram/WhatsApp: arrastar, pinça ancorada nos dedos para aproximar e afastar até a foto inteira, toque duplo, elástico nas bordas, "Mostrar a foto inteira"; afastada, o quadrado é completado com a própria foto desfocada; `PhotoProcessing.process(_:cropping:)` testado nos dois casos), data de início, lembretes, notificações, excluídos recentemente, banner de sincronização | sim | sim (repositórios testados) | — |
| Convite, gerenciar/parar de compartilhar, sair do espaço, começar novo espaço, apagar o espaço | sim | parcial (`CoupleLimit`, arquivar testados) | S1–S8 |
| Memórias: criar, editar, seletor de ano (mostra só o ano escolhido; começa no mais recente; UI testada), linha do tempo por mês, detalhe, até 10 fotos, lugar, excluir/restaurar | sim | sim (unitários + UI: criar, editar, reabrir) | M1–M2 |
| Recados: escrever, recebidos/enviados, editar/excluir os próprios, favoritos pessoais | sim | sim (unitários + UI: escrever, reabrir) | S3–S5, N1–N6 |
| Metas: criar/editar com etapas e foto, marcar etapas, progresso, prazo, concluir/reabrir, histórico, excluir/restaurar | sim | sim (unitários + UI: criar, marcar/desmarcar etapa com progresso atualizado na hora, reabrir) | G1 |
| Mapa: busca, salvar lugar, marcadores, filtros, lista de lugares (Todos/Visitados/Queremos ir, distância; tocar mostra no mapa), distância, como chegar, registrar visita → memória, editar/excluir | sim | parcial (repositório testado; busca e mapa dependem de rede/GPS, não automatizados) | — |
| Lembretes: título, data, repetir (não, todo mês, todo ano), dias antes, notificação local; sugestão de aniversário de namoro a partir da data de início | sim | sim (11 testes: cálculo de datas, anual, mensal, dia 31 em meses curtos, virada de mês, lembrete único passado, legado, repositório; UI: criar, fechar e reabrir) | notificação no aparelho do parceiro (R1) |
| Excluídos recentemente (memórias, metas, recados próprios, lugares, lembretes) | sim | sim (restauração testada nos repositórios) | — |
| Rede e alterações pendentes ("Sem conexão · N alterações aguardando envio") | sim | parcial (estado offline testado; contagem depende de envio real) | sim |
| Notificações: explicação + pedido de permissão uma vez; tela Nosso espaço > Notificações (estado, ativar, abrir Ajustes, preferência "Recadinhos do seu par") | sim | parcial (preferência testada; pedido do sistema não automatizado) | — |
| Hoje, nós dois: cartão no Início, Explorar momentos, pergunta do dia (rascunho local, envio com confirmação, espera, revelação, reação, guardar como memória), histórico | sim | sim (unitários: planejador, fuso, horário de verão, revelação, idempotência, duplicatas, isolamento; UI: responder, reabrir) | H1–H4 |
| Escolhe por nós (filtros, três fontes, sem repetir), ideias próprias, planos e convites internos, guardar memória do date | sim | sim (unitários: filtros, sorteio, deduplicação, planos, convites, lugar não vira visitado; UI: sortear e combinar) | H5–H6 |
| Pequeno gesto, Vamos reviver?, Quem conhece melhor? | sim | sim (unitários: gestos recentes, aniversários com 29/2, rodada, pontuação com pulos) | H7–H8 |
| Lembretes locais de Hoje, nós dois (pergunta nova ligada por padrão; demais opt-in; um por dia; rotas diretas) | sim | sim (planejador e rotas testados; entrega só no aparelho) | H9 |
| Push "seu par respondeu" (`CKDatabaseSubscription` `answer-alerts-v1` + extensão) | sim | parcial (escolha do evento, textos, rota e assinatura testados) | H11–H13 |
| Push do quiz "Quem conhece melhor?" (`game-alerts-v1` + extensão) | sim | parcial (evento, textos, rota e assinatura testados) | H14 |
| Push de recadinho com o texto do recado (`CKDatabaseSubscription` + `recordType` + `NoteNotificationService`) | sim | parcial (assinatura, banco por papel, escolha do recado e texto testados) | N1–N9 |

## Assinatura (Superwall; em implementação desde 2026-10-26)

**Decisões do usuário (2026-10-26):** app 100% pago com 7 dias grátis; planos mensal e anual no mesmo grupo, teste de 7 dias como oferta introdutória nos dois; **uma assinatura cobre o casal**; paywall **na primeira abertura, antes de tudo**. Projeto Superwall "OnlyUs" (org `28370`, projeto `43628`, app iOS `58713`, bundle `jc.app.dev.AppCasal`, Apple App ID `6825528600`, Team `F44CYBRGC2`), criado pelo Claude in Chrome; chave pública no código (`SubscriptionService.superwallAPIKey`). **Proibido mexer no projeto Superwall "Orante"** (mesma organização; projeto `43112`, apps `57966`/`57967`; no CLI sempre passar `--app 58713`/`--project 43628`). As chaves Apple (App Store Connect API e In-App Purchase) foram importadas da organização pela própria Superwall, e ela configurou a URL de notificações do servidor (produção e sandbox) do app.

**Implementado:**
- `SubscriptionService` (`Services/Subscription`): `Superwall.configure` em `AppCasalApp.init` (só `.production`); `identify` com UUID v5 derivado do `userRecordName` (SHA-256; o ID do iCloud não sai do aparelho); estado lido do StoreKit 2 (`Transaction.currentEntitlements`, funciona offline) somado ao `subscriptionStatus` da Superwall; observa `Transaction.updates` e o publisher da Superwall; `presentPaywall()` registra o placement `app_launch_gate`; `restore()`.
- `AccessRules` (pura, testada): demo/preview/testes nunca bloqueiam; assinatura própria libera; convite sendo aceito nunca é bloqueado; sem assinatura, o espaço libera até `accessExpiresAt` + 7 dias de tolerância; estado desconhecido mostra a abertura em vez do paywall.
- Uma assinatura para os dois: quem assina grava `CoupleSpace.accessExpiresAt` (só avança; `SpaceRepository.recordAccess`) ao abrir, a cada mudança da assinatura e no `BGAppRefreshTask`. Verificação só no cliente (sem servidor): limitação aceita.
- **Correção de 2026-10-27 (pagamento em dobro no TestFlight):** o usuário assinou; horas depois a namorada atualizou o app e também teve de pagar. Causa provável: o aparelho dela, ainda na versão sem `accessExpiresAt`, importou a mudança do espaço e descartou o campo desconhecido; depois da atualização o `NSPersistentCloudKitContainer` não busca o registro de novo, então a data nunca chegou. Também faltava fechar o paywall da Superwall quando o espaço libera o acesso por baixo. Agora: (1) quando o acesso é liberado pelo espaço, `SubscriptionService.dismissPaywall()` fecha o paywall e aparece o aviso "Seu par já assinou"; (2) com os dois no espaço, `PaywallGateView` primeiro lê `CD_accessExpiresAt` direto do registro no CloudKit (`SpaceRepository.accessExpirationInCloud`, banco privado do dono ou compartilhado do participante; `AppEnvironment.syncSpaceAccessFromCloud` grava a data local só para frente) e só abre o paywall se continuar bloqueado; há o botão "Meu par já assinou" para conferir de novo; (3) sem par no espaço, "Recebi um convite do meu par" virou botão de destaque e o aviso diz que quem é convidado não paga. Risco restante, sem servidor: os dois comprarem quase ao mesmo tempo, ou o par assinar antes de abrir o convite. **Não validado em dois aparelhos.**
- `PaywallGateView`: tela nativa atrás do paywall (abre o paywall ao aparecer; "Começar 7 dias grátis", "Recebi um convite do meu par", "Restaurar compras", Termos de uso da Apple). A liberação vem só do StoreKit/Superwall, nunca do callback do paywall (sem campanha, a Superwall executa o bloco na hora).
- `Products.storekit` na raiz (fora do target, mesmos preços da loja: R$ 14,90 / R$ 89,90) para testar compras no simulador; ativar em Scheme > Run > Options > StoreKit Configuration (não está ligado no scheme compartilhado).
- Preços (decisão do usuário, 2026-10-26, para converter o máximo): **R$ 14,90/mês** e **R$ 89,90/ano**, 7 dias grátis nos dois.
- App Store Connect (criado pelo `superwall asc`): grupo `22516583` "OnlyUs Premium" (localização pt-BR); anual `jc.app.dev.AppCasal.premium.yearly` (`6827262098`, nível 1) e mensal `jc.app.dev.AppCasal.premium.monthly` (`6827262314`, nível 2); oferta introdutória grátis de 1 semana; **vendidas só no Brasil** (decisão do usuário, 2026-10-26: app sem inglês, distribuição só no Brasil; `availability set --available-territories BRA`, sem territórios novos automáticos). Localizações só pt-BR ("Premium Anual"/"Premium Mensal", "Acesso completo para o casal"). Captura de revisão enviada (print do paywall em 1290×2796): estado `READY_TO_SUBMIT`; falta enviar junto com a primeira versão do app para a App Store. O app em si ainda não tem disponibilidade de territórios definida (só TestFlight); ao publicar, escolher só Brasil.
- Superwall: entitlement `pro` (`62714`) nos dois produtos; campanha `115007` "Abertura do app (paywall obrigatório)", placement `app_launch_gate`, audiência `196304` com 100% no paywall `285202` "OnlyUs - Abertura" (identificador `onlyus-abertura`, tela cheia, **Gated**, publicado; espera/holdout em 0%). Paywall em pt-BR nas cores do app: benefícios, anual em destaque ("Economize 50%", preço mensal equivalente) e mensal, seleção por toque, botão compra o plano selecionado, texto do teste trocado para "Assinar agora" sem oferta introdutória, "Restaurar compras", "Termos de uso" e "Privacidade" (versão 4, salva em 2026-10-26: abre https://jcapps.dev.br/onlyus/privacidade/ no navegador do app).

**Pendente (nada validado em aparelho):**
1. App Store Connect: enviar as duas assinaturas junto com a primeira versão para a App Store.
2. Paywall: ~~link da política de privacidade~~ feito em 2026-10-26 (rodapé da Superwall e tela própria `PaywallGateView`); falta a revisão visual do usuário.
3. ~~CloudKit~~ **feito em 2026-10-26:** `CD_accessExpiresAt` (Date/Time, sem índices) criado à mão em `CD_CoupleSpace` no Development pelo CloudKit Console (o usuário fez o login; a ferramenta `-AppCasalInitializeCloudKitSchema` não foi usada porque o iPhone tinha o build do TestFlight e ela abre os stores reais) e publicado em Production ("Modify 1 field on CD_CoupleSpace", nada mais); conferido em Production.
4. ~~Privacidade~~ feito em 2026-10-26: "App Privacy" publicado no App Store Connect (ver Ficha da App Store).
5. Testar no aparelho: compra, teste grátis, restauração, par liberado pelo espaço (inclusive com o paywall aberto no aparelho do par e depois de atualizar de uma versão sem o campo), fim da tolerância.

## Ficha da App Store (versão 1.0, preenchida pelo `superwall asc` em 2026-10-26)

App `6825528600`, versão `75f04923-8f15-41f2-9389-4dd0a5adff73` (1.0, `PREPARE_FOR_SUBMISSION`), app info `ab4e4d14-63fb-4507-b8a1-7402072579ca`, idioma principal pt-BR (único).

**Preenchido:** descrição, palavras-chave, texto promocional (localização pt-BR da versão); subtítulo "Memórias e rotina do casal"; categoria principal Estilo de vida (`LIFESTYLE`), sem secundária; copyright "2026 Julio Cezar Teixeira"; direitos de conteúdo "não usa conteúdo de terceiros"; classificação etária respondida (tudo "nenhum", exceto mensagens/chat e conteúdo gerado pelo usuário = sim, pelos recadinhos e fotos compartilhados com o par; resultado 4+ / Brasil L); exportação: `ITSAppUsesNonExemptEncryption = NO` já no build.

Dados de revisão: contato Julio Cezar Teixeira (e-mail e telefone do usuário), sem conta de demonstração, notas em inglês (iCloud no aparelho, paywall na abertura, uma assinatura para o casal via convite, dados só no iCloud do casal).
Preço e disponibilidade (pelo site, Claude in Chrome, 2026-10-26): app grátis, referência Brasil (R$ 0,00); disponível só no Brasil ("Disponível no lançamento do app"), demais 174 indisponíveis. A proxy não envia recursos embutidos (`included`), exigidos por `appPriceSchedules`/`appAvailabilities`.
Capturas: 10 imagens 1320×2868 (`APP_IPHONE_67`, set `a2e79a2f-51d6-421a-942f-d1acbc6ccf31`), cada uma com título em duas linhas (tinta `#3D1F1A` + terracota `#B4553F`), subtítulo e iPhone em fundo creme: Início, Memórias, Memória (piquenique), Mapa, Recados, Pergunta do dia respondida pelos dois, Ideias de encontro, Quiz, Metas, Nosso espaço. Fotos do casal fictício Ana e Lucas geradas por IA no ChatGPT do usuário (13 fotos, prompts em `~/Desktop/OnlyUs-fotos/PROMPTS.md`; finais em `~/Desktop/OnlyUs-fotos/prints-finais/`). Captura: modo demonstração no simulador iPhone 17 Pro Max, pt-BR, barra 9:41, com os argumentos só de DEBUG `-AppCasalDemoPhotos <pasta>` (fotos reais para capa, avatares, memórias e metas; a pasta não pode ser protegida pelo TCC, como a Mesa, porque a leitura trava) e `-AppCasalStoreScreenshots YES` (esconde o aviso de modo demonstração e o diagnóstico em Nosso espaço). Com `-AppCasalDemoReset YES`, esperar uns 20 s antes de encerrar o app, senão o store fica pela metade.

Cabeçalho e resultados de busca (aba da versão 1.0, enviados pelo site, salvos automaticamente): cabeçalho 5244×2950 e resultados de busca 3840×2560, foto do casal à esquerda, título "Um lugar / só de vocês dois" e dois iPhones à direita. O campo aceita só PNG e o envio pelo navegador tem limite de 10 MB, então os PNGs foram comprimidos com `pngquant`. Feitas a pedido do usuário para a loja (não para conferência).

Site (Netlify, domínio `jcapps.dev.br`, o mesmo do Orante; páginas do Orante intocadas): https://jcapps.dev.br/onlyus/ (início), `/onlyus/privacidade/` (política, pt-BR com seção em inglês) e `/onlyus/suporte/` (perguntas frequentes e contato `support@jcapps.dev.br`, o mesmo e-mail do Orante). A página inicial do domínio ganhou o link "OnlyUs" no menu e um cartão do app depois do do Orante. Publicado pela CLI do Netlify (login pelo navegador do usuário) com deploy por resumo: só os 4 arquivos novos/alterados enviados; conferido que os arquivos do Orante ficaram idênticos (SHA-1). Deploy `6adfceb1429fc9f06f4eb64a`. Os arquivos-fonte do site não estão neste repositório.
URLs no App Store Connect: política de privacidade (informações do app e TestFlight), URL de suporte e URL de marketing (versão 1.0, pt-BR); descrição com linha de privacidade.
Link de privacidade dentro do app (diretriz 3.1.2): rodapé do paywall da Superwall e `PaywallGateView` ("Termos de uso" e "Política de privacidade").
Privacidade do app (rótulos, publicados pelo site em 2026-10-26): dados vinculados à identidade, nenhum usado para rastreamento: ID de usuário e ID do dispositivo (Funcionalidade do app e Análise), Histórico de compras (Funcionalidade do app e Análise), Interações com o produto (Análise). Tudo por causa da Superwall (identificador pseudônimo, vendor ID, compras, eventos do paywall); o conteúdo do casal fica só no iCloud. O manifesto da Superwall declara histórico de compras sem rastreamento; o do app continua sem dados coletados pelo código próprio.

**Falta:**
- Anexar o build do TestFlight à versão e enviar as duas assinaturas junto (decisão e envio do usuário).

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

## Hoje, nós dois (na `main`; validado localmente)

**Origem:** pedido do usuário (2026-10-18) com especificação e catálogo em `~/Downloads/AppCasal-Hoje-Nos-Dois/` (`PROMPT_CLAUDE.md`). Decisões aprovadas ali: catálogo embarcado, dados do casal no CloudKit pelos serviços atuais, sem sexta aba, sem backend, sem push nem deploy de esquema. Linha de base: `b6b3c86`, árvore limpa, 60 testes unitários + 4 de UI passando.

**Catálogo (`Resources/Moments/*.json`, `MomentsCatalog`):** 365 perguntas (73 por tema, alternadas), 100 dates, 100 gestos, 60 perguntas do jogo; nomes de campos mantidos; enums com os mesmos valores (`QuestionCategory`, `DateLocation`, `DateCost` + `a_confirmar` para ideias próprias e lugares). Validação ao carregar (schema 1, IDs únicos, 4 alternativas distintas); carregado na primeira utilização (`AppEnvironment.catalog`). Metadados de "à distância" revisados: os 10 marcados são viáveis por chamada; nenhum é "fora de casa".

**Modelo v2 (`AppCasal 2.xcdatamodel`, atual; v1 preservada para migração leve):** `CoupleSpace.momentsTimeZone`, `Memory.revisitOfMemoryID` e as entidades `DailyQuestion`, `DailyAnswer`, `GameRound`, `GameAnswer`, `DatePlan`, `DateIdea`, todas na zona do casal (relação com o espaço), atributos opcionais, sem unicidade. Registros guardam cópia do texto do catálogo (pergunta, alternativas), então atualizar o catálogo não muda nada já criado. Migração testada: store v1 com espaço, memória, recado e lugar abre na v2 com tudo preservado (`modelV1StoreMigratesWithItsData`, cópia temporária).

**Pergunta do dia:** o dono prepara hoje + 13 dias (`DailyQuestionPlanner`, determinístico: temas alternados, sem repetir até esgotar, depois novo ciclo); o participante só lê. Dia = data no fuso do espaço (`momentsTimeZone`, gravado pelo dono na primeira preparação); vira à meia-noite desse fuso; horário de verão não muda a chave; relógio divergente ou dia não preparado = "ainda não disponível". Duplicatas (dois aparelhos do dono offline): vence a criada primeiro, depois o menor ID (`Canonical`), sem apagar nada; respostas a outra pergunta ficam guardadas fora daquela descoberta. Resposta enviada é final (reenviar o mesmo texto devolve a existente; texto diferente é recusado); rascunho fica só no aparelho (`MomentsLocalStore`). Revelação só quando os dois enviaram: regra de interface, não sigilo técnico (a resposta do par pode já estar no aparelho).

**Interface:** cartão no Início só enquanto a pergunta de hoje espera a resposta da pessoa (some depois de responder; `MomentsHomeCard.showsOnHome`). A área é a aba "Hoje" da barra, com navegação própria (`momentsPath`); toque em aviso de "Hoje, nós dois" seleciona essa aba e abre a tela. Metas saiu da barra e foi para o fim do Início (no iPhone a barra comporta 5 itens: uma sexta aba, mesmo com `role: .search`, foi para "Mais" no teste). Explorar: a pergunta do dia como ação principal, depois Quem conhece melhor?, Escolhe por nós, Pequeno gesto, Vamos reviver?, Perguntas anteriores, Planos e convites. Componentes e tokens existentes; sem roleta, moedas, ranking ou sequência que zera. Linhas horizontais viram verticais em tamanhos de acessibilidade (`AdaptiveStack`); reações são símbolos com rótulo para VoiceOver.

**Pessoal, só no aparelho (`MomentsLocalStore`):** rascunhos de resposta e do jogo, gestos sugeridos e feitos (para não revelar surpresas ao par), memórias já sugeridas em "Vamos reviver?". Chaves incluem o ID do espaço.

**Jogo, dates, ideias:** rodada de 5 perguntas sem repetir, preferindo as não usadas; snapshot fixo; comparação por ID de pergunta + alternativa; pular não entra no denominador. "Vamos fazer" reaproveita o plano aberto da mesma ideia; convite (`invitation`: pending/accepted/declined/cancelled) respondido no mesmo registro; concluir não cria memória nem marca lugar como visitado. Ideias próprias: só o autor edita/exclui (logicamente). Filtros na tela: Lugar, Custo e Duração (o filtro "à distância" saiu da tela a pedido do usuário; continua no modelo). Filtros independentes; valores desconhecidos nunca passam em filtros restritivos; "Qualquer custo" aceita custo variável/a confirmar. Lugares "Queremos ir" entram como fonte (sem preço e duração: "a confirmar"); selecionar não marca visitado; "Registrar visita e guardar" usa o fluxo existente do editor de memória (marca visitado só ao salvar). Fontes próprias ligadas por padrão quando têm itens. Sem localização: o sorteio não pede permissão. Ligar "Nossas ideias" sem nenhuma ideia abre o editor de ideia nova (ao salvar, a fonte fica ligada); ligar "Queremos ir" sem lugar salvo abre a aba Mapa no filtro "Queremos ir" (`AppEnvironment.pendingMapFilter`). O cartão da ideia não mostra mais o `costNote` do catálogo ("Combine o orçamento antes…"), a pedido do usuário (2026-10-23); o campo continua no JSON e no modelo.

**Gestos e reviver:** gesto evita os 30 últimos; "Escrever um recadinho" abre o editor existente vazio (a pessoa escreve e envia). Reviver: aniversário de hoje primeiro (≥ 1 ano; 29/2 lembrado em 28/2 nos anos comuns), senão a memória mais antiga com ≥ 30 dias não sugerida recentemente; "Reviver esse momento" abre o editor com sugestões e grava `revisitOfMemoryID` só ao salvar; a original não muda.

**Memória a partir da área:** "Guardar como memória" (descoberta) e "Guardar esse momento" (date feito) abrem o editor existente preenchido; nada é gravado sem "Salvar"; o editor ignora toque duplo; o vínculo (`memoryID`) guarda só o primeiro.

**Notificações locais (Nosso espaço > Notificações):** "Pergunta nova todo dia" ligada por padrão (pedido do usuário, 2026-10-19; vale só com a permissão do sistema), título "Pergunta nova", no horário escolhido (padrão 9h); ideia de encontro às sextas e aniversário de memórias continuam opt-in. No máximo uma por dia (prioridade: pergunta > aniversário > ideia); dia já respondido não recebe lembrete; texto da pergunta só se aquele dia já estiver no aparelho (o dono prepara 14 dias), senão texto genérico; nunca respostas. Toque abre a tela certa (`MomentsRoute`); dado ausente mostra indisponível.

**Confiabilidade dos lembretes (auditoria de 2026-10-19):**
- **Horizonte:** um pedido não repetido por dia (`moments-AAAA-M-D`), até 60 dias, limitado pelo espaço livre no limite de 64 pedidos pendentes do app: `MomentReminderPlanner.horizon(otherPending:)` = mín(60, máx(7, 63 − outros pendentes)). Com os lembretes no máximo (56), continuam 7 dias. Antes eram sempre 7. `syncReminderNotifications` primeiro reduz "Hoje, nós dois" para caber os lembretes que vai gravar (`ReminderNotifications.plannedCount`), grava os lembretes e depois volta a ampliar.
- **Rejeitados:** gatilho diário repetido (`repeats = true`) não pula um dia respondido (remover cancela todos) e não tem data de início, então misturá-lo aos pedidos datados (híbrido) geraria aviso em dobro durante o horizonte; o iOS não tem condição entre notificações locais. Por isso, nenhum aviso recorrente.
- **Horário:** componentes ano/mês/dia + hora/minuto escolhidos, sem fuso (seguem o fuso atual do iPhone). Corrigido: antes era meia-noite + minutos, o que daria 10h num dia de horário de verão que começa à meia-noite. O dia da pergunta usa o fuso do espaço.
- **Sincronização idempotente e em fila:** `MomentNotifications.sync` roda uma de cada vez (encadeada) e calcula o plano na sua vez; compara com os pedidos pendentes por assinatura (título, corpo, rota, data) e só remove/adiciona o que mudou (`changes`).
- **Avisos obsoletos:** lembretes da pergunta e avisos "esperando a sua resposta" levam `momentsObsoleteWhenAnswered = <dia>`; "toque para responder" do quiz leva `momentsObsoleteWhenPlayed = <rodada>`. A cada sincronização, os já entregues que pedem algo feito saem da Central de Notificações; com o app aberto, `willPresent` não mostra esses avisos. Novidades (os dois responderam, resultado pronto) ficam.
- **Sem abrir o app:** `observeChangesForNotifications` (iniciado no `AppDelegate`; funciona em lançamento em segundo plano, sem cena) refaz a pergunta do dono e os lembretes a cada mudança remota do CloudKit (pushes silenciosos do espelhamento), troca de fuso e mudança significativa de horário. `BGAppRefreshTask` `jc.app.dev.AppCasal.notifications-refresh` (`.backgroundTask(.appRefresh)`, `UIBackgroundModes` com `fetch`, `BGTaskSchedulerPermittedIdentifiers`) pede uma atualização a cada ~20 h. Os dois são oportunistas (o sistema decide; não rodam depois de encerrar o app à força) e só complementam o horizonte.

**Push "seu par respondeu" (pedido do usuário, 2026-10-19; substitui o adiamento):** `AnswerAlerts` salva `CKDatabaseSubscription` `answer-alerts-v1` com `recordType = CD_DailyAnswer` (dono no banco privado, participante no compartilhado), preferência pessoal ligada por padrão ("Quando seu par responder"), salva com permissão, preferência e parceiro no espaço; sincronizada junto com `NoteAlerts` (`syncNoteAlerts`) e removida dos dois bancos sem espaço. Título "Hoje, nós dois"; a assinatura leva o nome do par no subtítulo. A extensão (`PartnerAnswerFetcher`, `AnswerAlertContent`, testado) lê as respostas alteradas com tokens próprios (prefixo `answers-`, para não consumir as mudanças do aviso de recadinho; `ZoneChangeReader` comum), só `CD_authorID`, `CD_dayKey`, `CD_questionText`, `CD_submittedAt`, `CD_reactedAt` (nunca o texto da resposta) e guarda os dias que a própria pessoa respondeu (últimos 60). Textos: "<par> respondeu à pergunta do dia e está esperando a sua resposta." (subtítulo: a pergunta) ou, se a pessoa já respondeu, "… Vejam as respostas de vocês!"; reação: "<par> reagiu às respostas de hoje."; aviso no próprio aparelho que respondeu (se o servidor não o excluir): "Sua resposta foi enviada…"; espaço encerrado: o mesmo aviso do recadinho (podem chegar dois, um de cada assinatura); sem rede ou fora do prazo: "Tem novidade na pergunta do dia. Toque para ver." A extensão põe `momentsRoute = daily:<dia>` no aviso: o toque abre a pergunta; sem isso, abre a aba Hoje. Limites: a extensão não esconde avisos (sem o entitlement de filtragem), entrega pode atrasar ou ser agrupada; o tipo `CD_DailyAnswer` precisa estar no esquema de Produção antes do TestFlight. Convites de date continuam sem push.

**Push do quiz (pedido do usuário, 2026-10-19):** a mesma preferência ("Quando seu par responder (pergunta e quiz)") salva também `game-alerts-v1` com `recordType = CD_GameAnswer`; `AnswerAlerts` salva e remove as duas juntas. Avisa quando o par termina a rodada (envia as respostas), não quando a inicia: a rodada só existe para o par depois disso. Título "Quem conhece melhor?"; corpo "Um novo quiz foi iniciado! <par> já respondeu. Toque para responder." ou, se a pessoa já jogou aquela rodada, "<par> terminou o quiz. O resultado de vocês está pronto!". `PartnerGameFetcher` (tokens com prefixo `games-`) lê só `CD_authorID`, `CD_roundID`, `CD_submittedAt` (nunca as escolhas) e guarda as rodadas que a pessoa jogou (últimas 40). Toque abre o quiz (`momentsRoute = game`). Espaço encerrado: o mesmo aviso de espaço encerrado (até três avisos, um por assinatura). Sem rede: "Tem novidade no quiz de vocês. Toque para ver." `CD_GameAnswer` também precisa estar no esquema de Produção.

**Apresentação dos avisos remotos (auditoria de 2026-10-19):** centralizada em `RemoteAlertPresentation` (compilado no app e na extensão, testado). A extensão não pode descartar um push (exige o entitlement de filtragem), então o que não é novidade vira aviso discreto (`interruptionLevel = .passive`, sem som; fica na Central sem banner): reação do par, a própria resposta ou rodada (outro aparelho da mesma conta) e mudanças sem novidade (`irrelevant`: exclusão, edição antiga). Falha de rede ou fim do prazo (`unknown`) mantém o aviso genérico audível, porque pode ser novidade real. Encerramento do espaço: as três assinaturas disparam; o primeiro push avisa com som, os seguintes em 30 min chegam discretos (`spaceEndedShownAt` nos `UserDefaults` da extensão, com trava). Grupos (`threadIdentifier`): `notes`, `moments`, `space`. Os desfechos (`NoteAlertOutcome`, `AnswerAlertOutcome`, `GameAlertOutcome`) foram para o arquivo comum. Assinaturas (nenhuma redundante): `note-alerts-v1` (`CD_Note`), `answer-alerts-v1` (`CD_DailyAnswer`), `game-alerts-v1` (`CD_GameAnswer`), todas `CKDatabaseSubscription` no banco privado (dono) ou compartilhado (participante), mais as do `NSPersistentCloudKitContainer` (silenciosas, não tocadas); `CKQuerySubscription` não funciona no banco compartilhado. Assinaturas são por conta: cada aparelho da mesma conta recebe seu push.

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

## Preparação para TestFlight e App Store (auditoria de 2026-10-19)

**Corrigido (branch `audit/testflight`):**
- Manifestos de privacidade `AppCasal/PrivacyInfo.xcprivacy` e `NoteNotificationService/PrivacyInfo.xcprivacy`: sem rastreamento, sem dados coletados, `UserDefaults` com motivo `CA92.1` (só o próprio app). Exigidos pela Apple para APIs de motivo obrigatório; `UserDefaults` é usado no app e na extensão.
- `ITSAppUsesNonExemptEncryption = false` no `Info.plist` (só criptografia do sistema: HTTPS e CloudKit), para o TestFlight não pedir a declaração a cada build.
- Convite: quem já participa de um espaço não aceita convite de outro casal (antes só o dono era barrado; dois espaços compartilhados misturariam casais no banco compartilhado e nos avisos). O mesmo convite aberto de novo é tratado como já aceito. Com o app já num espaço, o motivo aparece num alerta ("Convite não aceito"). Regra pura em `ShareService.decision`, testada.
- Extensão de notificação: busca o `userRecordName` a cada push (cache só se falhar), para não confundir contas depois de trocar o iCloud no iPhone.
- Ferramenta só de DEBUG: `-AppCasalInitializeCloudKitSchema YES` chama `initializeCloudKitSchema` num store privado temporário (os stores reais não são tocados) e cria no ambiente Development todos os tipos e campos do modelo atual.
- Teste novo: tipos de registro e campos lidos pelos avisos (`CD_Note`, `CD_DailyAnswer`, `CD_GameAnswer`) existem no modelo.

**Verificado por inspeção (sem mudança):** banco público não usado; `CKShare` privado (`publicPermission = .none`, só convidados, leitura e escrita, no máximo um parceiro); sair do espaço apaga a cópia local (`purgeObjectsAndRecordsInZone`); logs só com mensagens de erro e marcas de tempo, nunca textos, fotos ou nomes; sem credenciais no código; demonstração, tela de teste de compartilhamento e ferramenta de esquema fora do Release; fotos limitadas a 2048 px e guardadas como arquivo externo (asset no CloudKit); seletor de fotos do sistema (sem permissão de Fotos); localização só durante o uso, com texto explicativo; avisos pedidos com explicação antes.

**Pendências manuais antes do TestFlight:**
1. Esquema — **Development completo (2026-10-19, verificado no CloudKit Console):** a ferramenta rodou no iPhone 13 Pro Max (Debug, `devicectl ... -- -AppCasalInitializeCloudKitSchema YES`; log "CloudKit Development schema initialized"). Antes faltavam o tipo `CD_DateIdea` e campos nunca preenchidos (`deletedAt`/`deletedBy` em quase tudo, `CD_CoupleSpace.sharingEndedAt`, `CD_Memory.revisitOfMemoryID`, `CD_DailyQuestion.memoryID`, `CD_DatePlan.memoryID`, `CD_GameRound.cancelledAt`, `CD_Place.memoryID`, `CD_Goal.dueDate`, os `_ckAsset` das fotos). Agora os 16 tipos `CD_*` + `Users` + `cloudkit.share` têm todos os campos do modelo v2 (mais os `_ckAsset` de texto e `CD_moveReceipt`, gerados pelo Core Data). **Publicado em Production em 2026-10-19 (autorizado pelo usuário):** Deploy Schema Changes pelo CloudKit Console criou os 16 tipos `CD_*` e `cloudkit.share`, os índices dos 16 tipos e as permissões padrão (`_creator` WRITE, `_icloud` CREATE, `_world` READ; só valem no banco público, não usado); `Users` inalterado; nada removido. Conferido depois: Development e Production idênticos (18 tipos, 310 campos com tipo e índices iguais), sem marcas "Modified". Se o modelo ganhar campos ou entidades, rodar a ferramenta de novo e publicar outra vez antes do TestFlight. Aviso inofensivo da ferramenta: o `defer` apaga a pasta temporária com o store ainda aberto ("vnode unlinked while in use" só no `SchemaInit-*/Schema.sqlite`). Procedimento original: no iPhone com iCloud, rodar o build Debug pelo Xcode com o argumento `-AppCasalInitializeCloudKitSchema YES`; no Console do Xcode, esperar "CloudKit Development schema initialized". Depois, no CloudKit Console (container `iCloud.jc.app.dev.casal`), conferir em Development os tipos `CD_*` de todas as entidades (incluindo `CD_DailyQuestion`, `CD_DailyAnswer`, `CD_GameRound`, `CD_GameAnswer`, `CD_DateIdea`, `CD_DatePlan` e os campos novos de `CD_CoupleSpace` e `CD_Memory`) e usar "Deploy Schema Changes" para Production. Não exige índices: o espelhamento lê mudanças por zona, sem consultas. A publicação é só aditiva; tipos e campos publicados em Production não podem ser apagados depois.
2. App Store Connect: criar o app com o bundle `jc.app.dev.AppCasal`, URL da política de privacidade, URL de suporte, informações de revisão (notas abaixo) e questionário de classificação etária.
3. ~~Política de privacidade~~ feito em 2026-10-26: https://jcapps.dev.br/onlyus/privacidade/, com link no paywall (ver Ficha da App Store). Link em Nosso espaço ainda não existe.
4. ~~Privacidade do app~~ substituído: com a Superwall há dados coletados; publicado em 2026-10-26 (ver Ficha da App Store).
5. Classificação etária: conteúdo do catálogo leve (sem conteúdo sexual; álcool só citado como "sem álcool"); declarar mensagens privadas entre os dois (recados, respostas) no questionário.

**Notas para a revisão (rascunho):** o app usa a conta iCloud do iPhone, sem cadastro nem senha. Para testar sozinho: abrir, criar "Nosso espaço" e usar memórias, mapa, recados, metas, lembretes e "Hoje, nós dois". O compartilhamento com o par exige uma segunda conta iCloud (convite por link pelo Compartilhar). Localização só no Mapa, para mostrar a distância; notificações para recados, respostas do par e lembretes. Os dados ficam no iCloud do usuário; o dono pode apagar o espaço em Nosso espaço, e o par pode sair.

## Testes que dependem de dois aparelhos

**Ambientes do CloudKit (observado em 2026-10-23):** build rodado pelo Xcode usa o ambiente Development; TestFlight e App Store usam Production. São bancos separados: espaço, share e convites de um não existem no outro. A parceira trocou o build do Xcode pelo do TestFlight e o app continuou mostrando o espaço antigo (cópia local do Development, sem sincronizar); o convite novo foi recusado porque o app já se via participante. Tiveram de criar outro espaço. Regra para testes: os dois aparelhos no mesmo tipo de build (de preferência TestFlight); ao trocar de Xcode para TestFlight, apagar e reinstalar o app. Usuários da App Store não passam por isso (só Production).

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
| H11 | A responde a pergunta do dia: B recebe "A respondeu à pergunta do dia e está esperando a sua resposta." com a pergunta; toque abre a pergunta | não testado |
| H12 | B responde depois: A recebe "B respondeu… Vejam as respostas de vocês!"; reação gera "reagiu", nunca "respondeu" | não testado |
| H13 | Desligar "Quando seu par responder" para de avisar; apagar o espaço não gera "respondeu" | não testado |
| H14 | A inicia e termina um quiz: B recebe "Um novo quiz foi iniciado!… Toque para responder."; toque abre o quiz; B termina e A recebe "resultado pronto" | não testado |
| H15 | Apagar o espaço: o parceiro recebe um só aviso "espaço encerrado" com som; os demais (se chegarem) ficam discretos na Central | não testado |
| H16 | Reação do par chega discreta (sem som); responder tira da Central o "Pergunta nova" e o "esperando a sua resposta" daquele dia | não testado |
| H17 | Lembretes sem abrir o app: depois de 8 dias e de 30 dias sem abrir, "Pergunta nova" continua chegando (com poucos lembretes cadastrados) | não testado (planejamento de 60 dias testado) |
| H18 | Mesma conta em dois aparelhos: responder em um tira o lembrete do outro quando o outro recebe a mudança | não testado |
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
| Push "seu par respondeu" por `CKDatabaseSubscription` + extensão; pergunta nova diária ligada por padrão | pedido do usuário (2026-10-19); a extensão identifica o evento pelos registros e cai em texto genérico verdadeiro quando não consegue |
| "Hoje, nós dois" como aba "Hoje" na barra; Metas no fim do Início | pedido do usuário (escolheu tirar Metas da barra); no iPhone a sexta aba vai para "Mais" (observado no simulador, iOS 26) |
| Modo demonstração só DEBUG, por argumento explícito, stores próprios | nunca misturar com dados reais |
| App pago (Superwall + StoreKit 2), 7 dias grátis, uma assinatura para o casal via `accessExpiresAt` no espaço, paywall antes de tudo | pedido do usuário (2026-10-26); sem servidor; convite nunca bloqueado |
| Testes de UI não paralelos (`parallelizable = "NO"` no scheme) | em paralelo o xcodebuild clona simuladores e o xctrunner não abre |

## Pendências do usuário

- Autorizar commit das memórias e das demais funcionalidades.
- Com os dois iPhones: revalidar S1–S2 (convite e entrada) e executar S3–S8, M1–M2, G1, R1–R2, P1, N1–N6, depois C1–C4. Em cada aparelho: iCloud ativo, Modo de Desenvolvedor, rodar pelo Xcode.
- Esquema CloudKit publicado em Production (2026-10-19), idêntico ao Development; republicar só se o modelo mudar.
- Hoje, nós dois: abrir o projeto no Xcode uma vez (sincroniza o String Catalog), executar H1–H18 com os dois iPhones.
- Para esconder avisos genéricos (reação, espaço encerrado em dobro): decidir se pede à Apple o entitlement de filtragem de notificações.

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
| 2026-10-26 | Cabeçalho do Início com foto de capa horizontal: o título saía pela esquerda (a foto em "preencher" alargava o `ZStack`); a foto foi para um overlay de `Color.clear` com altura fixa | Visto nas capturas da loja (demonstração, 1320×2868) e corrigido; Debug simulador BUILD SUCCEEDED; testes unitários e 7 de UI passaram (TEST SUCCEEDED) |
| 2026-10-26 | Assinatura com Superwall (gate, regras de acesso, modelo v3, StoreKit) | 139 testes unitários (8 novos em `SubscriptionTests`; migração v1 → atual e esquema CloudKit continuam passando) e 7 de UI passaram; Release iPhone BUILD SUCCEEDED sem avisos. UI só passou com `parallelizable = "NO"` de volta no scheme (sem isso o xctrunner não abre: "Application failed preflight checks"). Compra real não testada |
| 2026-10-24 | Destinos só iPhone (Mac Catalyst, Mac e Vision Pro removidos); tentativa de iOS mínimo 18.6 desfeita (sem simulador iOS 18 no Xcode 27) | 131 testes unitários (18 suítes) e 7 de UI passaram no iPhone 17 Pro, iOS 26.3; Release iPhone (sem assinatura) BUILD SUCCEEDED sem avisos |
| 2026-10-17 | Etapa 0: builds, perfil com container, Info.plist | OK |
| 2026-10-17 | Design system: contraste (22 casos), Release sem código de demonstração | OK |
| 2026-10-17 | Abertura: ~120 ms até o espaço (simulador, Debug); sem tela preta | OK |
| 2026-10-17 | Ícone escuro no `Assets.car` (`UIAppearanceDark`) | OK |
| 2026-10-17 | Suíte completa após todas as funcionalidades | 35 testes unitários em 8 suítes e 3 testes de UI passaram: `MemoryFlowUITests` (criar, editar, fechar e reabrir), `NotesAndGoalsUITests` (escrever recadinho, criar meta com etapa, marcar, fechar e reabrir), capturas de memórias |
| 2026-10-17 | Lembretes | 42 testes unitários e 4 de UI passaram (`RemindersUITests`: criar pela tela, fechar e reabrir); Release BUILD SUCCEEDED |
| 2026-10-18 | Progresso das metas e texto do recadinho no aviso (extensão) | 56 testes unitários e 4 de UI passaram (UI: marcar, desmarcar e marcar etapa com progresso na hora); Release BUILD SUCCEEDED com a extensão embutida |
| 2026-10-19 | Auditoria para TestFlight (manifestos, criptografia, segundo convite, identidade na extensão, ferramenta de esquema) | 131 testes unitários e 7 de UI passaram; Release BUILD SUCCEEDED (simulador e iPhone, sem assinatura) sem avisos; Release sem demonstração nem ferramenta de esquema; manifestos no app e na extensão |
| 2026-10-19 | Auditoria das notificações (horizonte, horário de verão, idempotência, obsoletos, apresentação remota) | 129 testes unitários (17 novos) e 7 de UI passaram; Release BUILD SUCCEEDED com `fetch` e o identificador da tarefa no Info.plist; entrega, segundo plano e dois aparelhos só validáveis no iPhone (H15–H18) |
| 2026-10-19 | Push do quiz (par terminou a rodada) | 113 testes unitários passaram, 4 novos de `GameAlertContent`; Release BUILD SUCCEEDED; entrega só validável com dois iPhones (H14) |
| 2026-10-19 | Pergunta nova diária (padrão ligado, 9h) e push "seu par respondeu" | 116 testes (unitários e de UI) passaram, 6 novos de `AnswerAlertContent`; Release BUILD SUCCEEDED; entrega só validável com dois iPhones (H11–H13) |
| 2026-10-23 | Escolhe por nós: fonte vazia leva ao cadastro (ideia nova / Mapa em Queremos ir); cartão sem `costNote` | testes unitários e `MomentsUITests` (2) passaram, TEST SUCCEEDED; navegação nova sem teste de UI próprio |
| 2026-10-18 | Aba "Hoje" na barra no lugar de Metas; Metas no fim do Início | 102 testes unitários e 6 de UI afetados passaram (Moments abre pela aba; NotesAndGoals cria e reabre a meta pelo Início) |
| 2026-10-18 | Ajustes pedidos: recorte com zoom/afastar/deslocar, lista de lugares no Mapa, ano em Memórias, botão de Hoje, nós dois na barra, filtros reduzidos, cartão some após responder | 102 testes unitários e 7 de UI passaram (novos: recorte afastado, seletor de ano, cartão some do Início e a área abre pelo botão da barra); lista do Mapa sem teste de UI (permissão de localização) |
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
- **2026-10-18:** ajustes do usuário na branch: recorte estilo Instagram/WhatsApp, lista no Mapa, ano em Memórias, botão "Hoje, nós dois" na barra, filtros reduzidos, cartão do Início some após responder.
- **2026-10-18:** "Hoje, nós dois" virou a aba "Hoje" da barra (o botão acessório saiu); Metas saiu da barra e fica como última seção do Início.
- **2026-10-19:** aviso diário de pergunta nova ligado por padrão (9h) e push "seu par respondeu" pela assinatura `answer-alerts-v1`.
- **2026-10-19:** push do quiz "Quem conhece melhor?" quando o par termina a rodada (`game-alerts-v1`).
- **2026-10-19:** branch `feature/hoje-nos-dois` juntada na `main` (fast-forward) e enviada ao GitHub, a pedido do usuário. Segundo iPhone disponível na quarta-feira (2026-10-21).
- **2026-10-19:** auditoria das notificações: horizonte de até 60 dias, horário certo no horário de verão, sincronização idempotente, remoção de avisos obsoletos, atualização em segundo plano, avisos discretos para reação e eventos sem novidade, um único "espaço encerrado" com som (branch `fix/notifications-reliability`).
- **2026-10-19:** auditoria para TestFlight na branch `audit/testflight` (sem push nem merge); pendências manuais na seção "Preparação para TestFlight e App Store".
- **2026-10-19:** esquema CloudKit de Development completado pela ferramenta e conferido no CloudKit Console (Claude in Chrome); publicado em Production com autorização do usuário; os dois ambientes conferidos e idênticos.
- **Retomar em:** usuário revisa `audit/testflight`; (esquema do CloudKit já publicado em Production); testar H1–H18 com os dois iPhones na quarta-feira (2026-10-21); revalidação dos testes S/N pendentes.

## Próximos passos

0. Assinatura: pendências 1–5 da seção "Assinatura".

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
