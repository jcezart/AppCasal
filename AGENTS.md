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

- **App completo em uso local:** todas as funcionalidades previstas, mais Lembretes (anuais e mensais) e notificações (permissão, tela de Notificações, push de recadinho), estão implementadas e validadas localmente (build, 58 testes unitários, 4 testes de UI de ponta a ponta).
- **Primeiro teste com dois iPhones (2026-10-18, relato do usuário):** convite pelo WhatsApp chegou e foi aceito, mas o WhatsApp demorou a abrir, a folha de compartilhamento mostrava um ícone de documento e a participante só viu o espaço após reabrir o app. Os três problemas foram corrigidos e **precisam ser revalidados** (S1, S2).
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

SwiftUI (Liquid Glass do iOS 26), Core Data + `NSPersistentCloudKitContainer` (sem SwiftData), CloudKit (espelhamento e `CKShare` pelo framework), MapKit (iOS 26: `MKMapItem.location`/`address`), CoreLocation (`CLLocationUpdate`), PhotosUI, ImageIO, Network (`NWPathMonitor`), UserNotifications (lembretes locais; push de recadinho por `CKDatabaseSubscription`), CoreTransferable (`ShareLink` + `CKShareTransferRepresentation`). Nenhuma dependência externa.

## Arquitetura

**Padrão:** MVVM + Repository, proporcional. Views leem com `@FetchRequest`; toda escrita passa por repositórios; ViewModels só se surgir lógica que justifique (hoje nenhum).

- **RootView:** erro do store → boas-vindas (carregando) → iCloud indisponível → convite aceito aguardando o espaço (`AcceptingInvitationView`, sem formulário; recarrega a cada 2 s e a cada mudança remota) → criar espaço → entrar no espaço (participante sem `Member`) → `MainTabView`. A participação (`isMember`) fica em `@State` e é recalculada em `reload()`: o objeto do espaço é o mesmo antes e depois de entrar, então ler no `body` não atualizava a tela (causa do "Entrar no espaço" que não avançava).
- **MainTabView:** `TabView` nativo com Início, Mapa, Memórias, Recados, Metas; um `NavigationStack` por aba; "Nosso espaço" em sheet pelo avatar; abre a aba pedida por `AppEnvironment.pendingTab` (toque em aviso de recadinho → Recados); oferece uma vez, só em produção, `NotificationPromptView` antes do pedido de permissão do sistema.
- **AppEnvironment** (`RunMode`): `.production` (CloudKit), `.demo` (só DEBUG, `-AppCasalDemo YES`, stores em `Application Support/DemoStores/`, sem CloudKit, identidade local, dados fictícios por `DemoData` usando os repositórios de produção; `-AppCasalDemoReset YES` e `-AppCasalDemoEmpty YES` para testes de UI), `.preview` (só DEBUG, em memória), `.tests` (em memória). Nunca ativado automaticamente.
- **PersistenceController:** `Private.sqlite` (`.private`) e `Shared.sqlite` (`.shared`) no mesmo container; histórico persistente e notificação remota; `viewContext` com `NSMergeByPropertyObjectTrumpMergePolicy`, `automaticallyMergesChangesFromParent`, `transactionAuthor = "app"`.
- **Repositórios:** `SpaceRepository` (espaço, membros, fotos, data, arquivar), `NoteRepository` (só o autor edita/exclui), `FavoriteRepository` (favoritos pessoais), `MemoryRepository` (+ `MemoryDraft`, `PlaceLink`), `GoalRepository` (+ `GoalDraft`), `PlaceRepository` (+ `PlaceDraft`), `ReminderRepository` (+ `ReminderDraft`). Atribuem o store do objeto relacionado; preenchem autoria e datas; exclusão lógica.
- **ShareService:** cria share (com título e miniatura: foto do casal ou logo), convite por `ShareLink` com `SpaceInvitation` (`CKShareTransferRepresentation`: `.existing` se o share já existe, `.prepareShare` se não; `specifiedRecipientsOnly` + `readWrite`; `SharePreview` com a miniatura), `UICloudSharingController` só para gerenciar (participantes, parar de compartilhar; `itemThumbnailData` com a miniatura), aceita convites com `CoupleLimit`, marca `sharingEndedAt` ao parar de compartilhar, `leave` (participante) e `deletePermanently` (dono).
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
│   │                        # PhotoView, PhotoPickerButton (+ DecodedImage, ImageDecoder), GoalStepsObserver
│   ├── Data/
│   │   ├── Model/           # AppCasal.xcdatamodeld, Entities/*, MemoryCategory, Categories (PlaceStatus, GoalCategory)
│   │   ├── Persistence/     # PersistenceController, SyncMonitor
│   │   ├── Sharing/         # ShareService, CoupleLimit, SpaceInvitation (+ ShareThumbnail)
│   │   ├── Repositories/    # Space, Note, Favorite, Memory, Goal, Place, Reminder
│   │   ├── Notifications/   # NoteAlerts (push de recadinho), NoteAlertContent e NoteTimestamp (compartilhados com a extensão)
│   │   └── Demo/            # DemoData (só DEBUG)
│   ├── Services/            # Account, Network, Location, PhotoProcessing, ReminderNotifications, LaunchLog
│   ├── Features/
│   │   ├── Onboarding/      # WelcomeView, CreateSpaceView, AcceptingInvitationView, JoinSpaceView, AccountUnavailableView
│   │   ├── Home/            # HomeView
│   │   ├── Map/             # MapTabView, PlaceDetailView, PlaceSearch(+View)
│   │   ├── Memories/        # MemoriesView, MemoryDetailView, MemoryEditorView (+ seletor de lugar)
│   │   ├── Notes/           # NotesView, NoteComposerView
│   │   ├── Goals/           # GoalsView, GoalEditorView
│   │   ├── Notifications/   # NotificationPromptView, NotificationSettingsView
│   │   ├── Space/           # SpaceView (perfil, foto do casal, data, lembretes, notificações, compartilhamento, apagar), RemindersView (+ editor), DeletedItemsView
│   │   └── SharingSpike/    # diagnóstico da etapa 1, só DEBUG
│   ├── Assets.xcassets, Localizable.xcstrings, AppCasal.entitlements, Info.plist
├── NoteNotificationService/ # NotificationService, PartnerNoteFetcher, Info.plist, entitlements
├── AppCasalTests/           # 58 testes (Swift Testing)
└── AppCasalUITests/         # MemoryFlowUITests, NotesAndGoalsUITests, RemindersUITests
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
| `Reminder` | casal | `title`, `date`, `daysBefore` (0–60; mensal 0–27), `notifies`, `repeatInterval` (`none`/`monthly`/`yearly`), `repeatsYearly` (legado, ainda gravado; usado quando `repeatInterval` é nulo) | ambos; `notifies` vale para os dois aparelhos |

Categorias: memória/lugar (Encontro, Viagem, Praia, Restaurante, Comemoração, Especial, Dia a dia, Outro); meta (Viagem, Relacionamento, Casa, Finanças, Saúde, Comemoração, Outro); situação do lugar (Queremos ir, Visitado).

## Funcionalidades (estado)

Legenda: **validado localmente** = build + testes automatizados (unitários e/ou UI) no simulador; **aguardando duas contas** = só validável com dois aparelhos.

| Funcionalidade | Implementado | Validado localmente | Aguardando duas contas |
|---|---|---|---|
| Abertura com marca, boas-vindas, abertura sem rede | sim | sim (medição ~120 ms; testes de conta) | — |
| Onboarding: criar espaço, entrar como participante, iCloud indisponível | sim | parcial (repositórios testados) | aceitar convite (S2) |
| Início: foto do casal, nomes (na linha da barra, ao lado do avatar), dias juntos, último recadinho, meta em andamento (com miniatura da foto da meta), última memória, nova memória | sim | sim (testes de repositório; fluxos de UI relacionados) | ver dados do parceiro |
| Nosso espaço: perfil com foto, foto do casal, data de início, lembretes, notificações, excluídos recentemente, banner de sincronização | sim | sim (repositórios testados) | — |
| Convite, gerenciar/parar de compartilhar, sair do espaço, começar novo espaço, apagar o espaço | sim | parcial (`CoupleLimit`, arquivar testados) | S1–S8 |
| Memórias: criar, editar, linha do tempo por mês, detalhe, até 10 fotos, lugar, excluir/restaurar | sim | sim (unitários + UI: criar, editar, reabrir) | M1–M2 |
| Recados: escrever, recebidos/enviados, editar/excluir os próprios, favoritos pessoais | sim | sim (unitários + UI: escrever, reabrir) | S3–S5, N1–N6 |
| Metas: criar/editar com etapas e foto, marcar etapas, progresso, prazo, concluir/reabrir, histórico, excluir/restaurar | sim | sim (unitários + UI: criar, marcar/desmarcar etapa com progresso atualizado na hora, reabrir) | G1 |
| Mapa: busca, salvar lugar, marcadores, filtros, distância, como chegar, registrar visita → memória, editar/excluir | sim | parcial (repositório testado; busca e mapa dependem de rede/GPS, não automatizados) | — |
| Lembretes: título, data, repetir (não, todo mês, todo ano), dias antes, notificação local; sugestão de aniversário de namoro a partir da data de início | sim | sim (11 testes: cálculo de datas, anual, mensal, dia 31 em meses curtos, virada de mês, lembrete único passado, legado, repositório; UI: criar, fechar e reabrir) | notificação no aparelho do parceiro (R1) |
| Excluídos recentemente (memórias, metas, recados próprios, lugares, lembretes) | sim | sim (restauração testada nos repositórios) | — |
| Rede e alterações pendentes ("Sem conexão · N alterações aguardando envio") | sim | parcial (estado offline testado; contagem depende de envio real) | sim |
| Notificações: explicação + pedido de permissão uma vez; tela Nosso espaço > Notificações (estado, ativar, abrir Ajustes, preferência "Recadinhos do seu par") | sim | parcial (preferência testada; pedido do sistema não automatizado) | — |
| Push de recadinho com o texto do recado (`CKDatabaseSubscription` + `recordType` + `NoteNotificationService`) | sim | parcial (assinatura, banco por papel, escolha do recado e texto testados) | N1–N8 |

## Compartilhamento

**Documentado pela Apple (headers do SDK):** `share(_:to:)` compartilha o grafo relacionado; `acceptShareInvitations(from:into:)` aceita no store compartilhado; `purgeObjectsAndRecordsInZone(with:in:)` "remove a zona do banco associado ao store"; `CKSharingSupported` necessário para receber convites; `publicPermission = .none`; `UICloudSharingController.availablePermissions = [.allowPrivate, .allowReadWrite]`.

**Implementado:** dono convida por `ShareLink` (folha de compartilhamento do sistema com título e miniatura; o share é criado ao escolher o destino ou reaproveitado); gerencia pelo `UICloudSharingController`; aceitação a frio e com app aberto (`SceneDelegate`); recusa de convite com mais de um parceiro e de quem já é dono de um espaço; participante cria o próprio `Member`; objetos novos no store do espaço.

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

**Implementado em produção (pedido do usuário, 2026-10-18; substitui o experimento DEBUG):** `NoteAlerts` salva `CKDatabaseSubscription` `note-alerts-v1` com `recordType = CD_Note`: dono no banco privado, participante no compartilhado. Título "Recadinho de <nome do par>". A assinatura de banco não traz campos, então usa `shouldSendMutableContent` e a extensão `NoteNotificationService` troca o corpo pelo texto do recado: busca as zonas alteradas (`databaseChanges`) e os registros alterados (`recordZoneChanges`, só `CD_text`, `CD_authorID`, `CD_createdAt`, `CD_modifiedAt`, `CD_deletedAt`; tokens próprios nos `UserDefaults` da extensão, independentes do espelhamento), escolhe o recado mais recente do parceiro alterado nos últimos 15 min e não excluído (`NoteAlertContent`, testado), corta em 240 caracteres e prefixa "Editado:" em edições. Subtítulo com dia e hora do recado (`NoteTimestamp`: "Hoje às 14:32", "Ontem às 09:05", "12 de out. às 14:32"; em edições, a hora da edição); os cartões de recado no app usam o mesmo formato. Sem rede, sem recado elegível ou no limite de tempo do sistema: corpo genérico "Chegou um carinho pra você. Toque para ler." A primeira execução sem token lê os metadados de todos os registros da zona (sem fotos). Só é salva com permissão concedida, preferência ligada e parceiro já no espaço; removida ao desligar a preferência ou perder a permissão. Ao salvar, apaga o ID antigo do experimento (`note-alerts-experiment-v1`) para não duplicar. Sincronizada ao abrir o app e a cada mudança remota (uma vez por sessão para a mesma combinação papel + nome). Toque no aviso abre Recados: o delegate de `UNUserNotificationCenter` usa as variantes com completion handler no main actor (as variantes `async` nonisolated retomavam fora da main thread; no primeiro teste, tocar o aviso na tela bloqueada não abriu o app). Não toca nas assinaturas do `NSPersistentCloudKitContainer`. Banco público continua não aprovado.

**Riscos a medir (N1–N6):** aviso das próprias notas no outro aparelho do mesmo usuário, aviso em edições/exclusões/restaurações, atraso e agrupamento. Nada é prometido como imediato na interface.

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
| S1 | Dono cria espaço e envia convite | parcial (2026-10-18): convite pelo WhatsApp chegou; abertura lenta e ícone de documento corrigidos (`ShareLink`), revalidar |
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
| Push de recadinho por `CKDatabaseSubscription` + `recordType` em produção, com preferência pessoal; texto do recado preenchido por Notification Service Extension | pedido do usuário; sem servidor próprio nem banco público; validar N1–N8 |
| Permissão de notificação: tela de explicação uma vez + Nosso espaço > Notificações | o iOS não permite instalar com notificações já ativas; pedir com contexto |
| Convite por `ShareLink` + `CKShareTransferRepresentation`; `UICloudSharingController` só para gerenciar | folha do sistema com miniatura e título, share reaproveitado; mesmas restrições (privado, leitura e escrita) |
| Modo demonstração só DEBUG, por argumento explícito, stores próprios | nunca misturar com dados reais |

## Pendências do usuário

- Autorizar commit das memórias e das demais funcionalidades.
- Com os dois iPhones: revalidar S1–S2 (convite e entrada) e executar S3–S8, M1–M2, G1, R1–R2, P1, N1–N6, depois C1–C4. Em cada aparelho: iCloud ativo, Modo de Desenvolvedor, rodar pelo Xcode.
- Antes do TestFlight: publicar o esquema CloudKit em Production no CloudKit Console.

## Problemas conhecidos

- Validações entre contas bloqueadas até haver dois aparelhos.
- Entrega real das notificações de lembrete e do push de recadinho não é coberta por teste automatizado (cálculo de datas e configuração da assinatura são testados); conferir no iPhone. No modo demonstração a permissão não é pedida e a tela de explicação não aparece.
- Push de recadinho também dispara em edições, exclusões e restaurações de recados (limitação da assinatura de banco).
- O convite por `ShareLink` com `specifiedRecipientsOnly` precisa ser revalidado pelo WhatsApp (S1).
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
| 2026-10-18 | Dia e hora do recado (aviso e cartões) e toque no aviso | 58 testes unitários e 4 de UI passaram; toque na tela bloqueada só validável no iPhone (N8) |
| 2026-10-18 | Lembretes mensais, notificações, push de recadinho, convite por `ShareLink`, correção da entrada do participante, Início | 51 testes unitários e 4 de UI passaram; Release BUILD SUCCEEDED |
| 2026-10-17 | Release após todas as funcionalidades | BUILD SUCCEEDED; sem conteúdo fictício, sem `AppCasalDemo`, sem experimento de avisos; `NSLocationWhenInUseUsageDescription` presente |

## Última tarefa / ponto de retomada

- **2026-10-17:** implementadas todas as funcionalidades que não dependem do segundo celular: foto do casal e perfis com foto; recados completos com favoritos pessoais; metas com etapas, progresso, prazo, conclusão e histórico; mapa com busca, lugares, filtros, distância, rotas e registrar visita; memórias com lugar; excluídos recentemente unificado; rede e pendências; gestão do espaço (convidar, gerenciar, sair, novo espaço, apagar).
- **2026-10-17:** Lembretes em Nosso espaço (pedido do usuário): lista, editor (título, data, repetir todo ano, dias antes, notificação), sugestão de aniversário de namoro, notificações locais, restauração em Excluídos recentemente.
- **2026-10-18:** retorno do primeiro teste com dois iPhones: lembretes mensais; explicação e pedido de permissão + tela de Notificações; push de recadinho em produção (experimento DEBUG removido); convite por `ShareLink` (mais rápido, com miniatura); participante entra sem reabrir o app; Início com miniatura da meta e nome do casal mais acima.
- **2026-10-18:** progresso das metas atualiza na hora; aviso de recadinho mostra o texto do recado (Notification Service Extension).
- **2026-10-18:** dia e hora do recado no subtítulo do aviso e nos cartões; toque no aviso (tela bloqueada) corrigido no delegate, revalidar N8.
- **Retomar em:** commit (aguardando autorização) e revalidação com dois aparelhos.

## Próximos passos

1. Usuário testa no próprio iPhone e autoriza o commit.
2. Testes com dois aparelhos (ordem acima).
3. Ajustar o push de recadinho com base em N1–N8 (ex.: avisos de edição).
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
- **2026-10-18 (substituído):** experimento DEBUG de avisos → push de recadinho em produção; convite por `UICloudSharingController` → `ShareLink` (gerenciar continua no controller); lembrete só anual → não repetir, mensal, anual.
