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
- **Etapa 1:** implementada, **aguardando validação entre duas contas iCloud reais**.
- **Testes:** 11 testes unitários passando (simulador iOS 26.3).
- **Não validado em aparelhos:** convites, sincronização, notificações e conflitos.
- **Próximo:** primeiro teste real só do fluxo básico (S1–S5 e P1). Offline, conflitos e notificações vêm depois, separadamente. Nenhuma outra funcionalidade antes disso e de nova aprovação.
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
| Scheme | compartilhado em `AppCasal.xcodeproj/xcshareddata/xcschemes/AppCasal.xcscheme` |
| Bundle IDs | `jc.app.dev.AppCasal`, `jc.app.dev.AppCasalTests` |
| Team | `F44CYBRGC2` (conta paga), assinatura automática |
| Container CloudKit | `iCloud.jc.app.dev.casal` (registrado no time; incluído no perfil "iOS Team Provisioning Profile: jc.app.dev.AppCasal") |
| Entitlements | `AppCasal/AppCasal.entitlements`: CloudKit, container acima, `aps-environment = development` |
| Info.plist | gerado + parcial `AppCasal/Info.plist` (`CKSharingSupported`, `UIBackgroundModes = remote-notification`); excluído dos recursos por exceção da pasta sincronizada |
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
- **ViewModels:** `@Observable`, só em telas com lógica real (ainda nenhum; a tela de teste usa estado local).
- **Repositories:** toda escrita passa por eles; atribuem o store do objeto relacionado, preenchem autoria e datas, aplicam exclusão lógica.
- **PersistenceController:** dois stores no mesmo container: `Private.sqlite` (`.private`) e `Shared.sqlite` (`.shared`), com histórico persistente e notificação de mudança remota. Modos `.cloudKit`, `.local(directory:)` (testes de reabertura) e `.inMemory` (testes).
- **ShareService:** cria o share, apresenta `UICloudSharingController` (somente privado + leitura e escrita), aceita convites, aplica `CoupleLimit`.
- **SyncMonitor:** guarda os últimos eventos de `NSPersistentCloudKitContainer.eventChangedNotification`.
- **AccountService:** estado da conta iCloud e `userRecordName`; reage a `CKAccountChanged`.
- **AppEnvironment:** grafo de dependências criado uma vez; usa `.inMemory` quando roda sob testes.

**Isolamento (Swift 6):** o target tem `MainActor` como padrão. As subclasses de `NSManagedObject` são `nonisolated` porque o espelhamento do CloudKit cria e lê objetos nas próprias filas; o isolamento real é o do contexto. Toda leitura e escrita do app acontece no `viewContext`, no `MainActor`. `CKShare`, `CKShare.Metadata` e `CKShare.Participant` são `Sendable` no iOS 17+ (SDK). O delegate de notificações tem um método `nonisolated` que só devolve opções, sem estado. Nenhuma marcação insegura foi usada.

### Árvore atual

```
AppCasal/
├── AGENTS.md / CLAUDE.md
├── AppCasal.xcodeproj/                      # + xcshareddata/xcschemes/AppCasal.xcscheme
├── AppCasal/
│   ├── App/                                 # AppCasalApp, AppDelegate, SceneDelegate, AppEnvironment
│   ├── Data/
│   │   ├── Model/AppCasal.xcdatamodeld      # CoupleSpace, Member, Note
│   │   ├── Model/Entities/                  # subclasses nonisolated
│   │   ├── Persistence/                     # PersistenceController, SyncMonitor
│   │   ├── Sharing/                         # ShareService, CoupleLimit
│   │   ├── Notifications/                   # NoteAlertSubscription (experimento)
│   │   └── Repositories/                    # SpaceRepository, NoteRepository
│   ├── Services/                            # AccountService
│   ├── Features/SharingSpike/               # tela de teste da etapa 1 (sem design; será substituída)
│   ├── Assets.xcassets, Localizable.xcstrings
│   ├── AppCasal.entitlements, Info.plist
└── AppCasalTests/                           # CoupleLimit, esquema CloudKit, repositórios, reabertura
```

Pastas planejadas para etapas futuras: `DesignSystem/{Tokens,Components}`, `Features/{Onboarding,Space,Home,Map,Memories,Notes,Goals}`, `Services/{Location,PhotoProcessing}`.

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

## Referência visual e design system (aprovado; implementação na etapa 3)

**Referência:** imagem "Álbum afetivo de Ana e Lucas" (fora do repositório, em `~/Downloads`). Seis telas: Início, Mapa, Memórias, Recados, Metas, Perfil e conexão. Nomes, fotos e textos são fictícios e não viram conteúdo fixo.

**Extraído da imagem:** fundo creme quente; cartões claros quase planos; fotos com cantos arredondados; destaque terracota; títulos em serifada e metadados em sem serifa; subtítulos poéticos; chips de categoria e estado; segmentado em pílula; memórias por mês; 5 abas; perfil pelo avatar; banner de sincronização.

**Tokens (proposta complementar baseada na imagem; medir contraste ao implementar):**

| Token | Claro | Uso |
|---|---|---|
| `canvas` | `#F7F0E8` | fundo |
| `surface` | `#FCF8F3` | cartões |
| `surfaceMuted` | `#F2E4DA` | chips, banner, controles inativos |
| `accent` | `#B4553F` | botões preenchidos, seleção (branco ≈ 4,9:1) |
| `accentText` | `#9A4433` | texto/ícones terracota pequenos (≈ 5,7:1) |
| `textPrimary` | `#3D1F1A` | títulos e corpo |
| `textSecondary` | `#76655D` | metadados (≈ 4,9:1) |
| `success` | `#4E8B5A` | "Conectado" |
| `separator` | `#E8DAD0` | divisores raros |

- Modo escuro: variantes no Asset Catalog (complementar; a imagem só mostra o claro).
- Tipografia: New York (`.fontDesign(.serif)`) em títulos, nomes, títulos de cartões e recadinhos; SF Pro no resto; sempre estilos de texto (Dynamic Type).
- Espaçamento em grade de 4 pt; margem 20; padding de cartão 16; `@ScaledMetric`.
- Cantos `.continuous`: cartão 20, foto 14, botão 14, chips e segmentado em cápsula.
- Sombra muito suave ou nenhuma; SF Symbols; sem emoji como ícone.
- Componentes: `CoupleHeroHeader`, `SurfaceCard`, `MemoryCard`, `MemoryRow`, `NoteCard`, `NotePreview`, `GoalCard`, `GoalSummaryRow`, `ProgressBar`, `StepChecklist`, `TagChip`, `StatusChip`, `PillSegmentedControl`, `PrimaryButton`, `SoftButton`, `AvatarView`, `CoupleAvatars`, `SyncStatusBanner`, `EmptyStateView`, `ErrorBanner`, `PlaceCard`, `MapFilterBar`, `SettingsRow`.
- Estados por tela: vazio, carregando, erro, sincronização pendente (contagem aproximada pelo histórico persistente).

**Navegação:** `TabView` nativo com Início, Mapa, Memórias (linha do tempo das memórias), Recados, Metas (com histórico de concluídas). "Nosso espaço" pelo avatar no Início. Criação em sheets. Onboarding antes das abas.

**Liquid Glass (APIs do iOS 26, sem fallback de versão):**

| Onde | Como | Por quê |
|---|---|---|
| Barra de abas | `TabView` nativo | padrão do sistema |
| Barras de navegação e ações "+" / "Escrever recadinho" | `ToolbarItem` nativo; ação principal `.glassProminent` com `accent` | controles sobre conteúdo rolável |
| Mapa: busca, filtros, "+", localização | `glassEffect` em `GlassEffectContainer` | controles flutuantes sobre conteúdo dinâmico |
| Mapa: detalhe do lugar | sheet nativa com `presentationDetents` | material do sistema |
| Ações sobre fotos | `.buttonStyle(.glass)` | legibilidade sobre imagem |
| Sem glass | cartões, recadinhos, metas, formulários, perfil, banner, segmentado | superfícies estáveis de leitura |

Verificar com Reduzir Transparência, Aumentar Contraste e Reduzir Movimento.

**Ajustes em relação à imagem:** barra de abas nativa flutuante; títulos de navegação nativos em serifada; mapa no estilo nativo; linhas horizontais viram verticais em Dynamic Type grande.

## Estado das funcionalidades

| Funcionalidade | Estado |
|---|---|
| Configuração do projeto (etapa 0) | implementada (build, testes, perfil com container) |
| Fluxo mínimo de compartilhamento (etapa 1) | implementada; **validação real pendente** |
| Experimento de avisos de recadinho | implementado só em DEBUG, ativação manual; não testado |
| Modelo de dados completo, deduplicação, monitor de sync | planejada |
| Design system e shell de navegação | planejada |
| Onboarding, perfil, "Nosso espaço", encerramento | planejada |
| Recadinhos (histórico, favoritos pessoais, avisos) | planejada |
| Memórias com fotos e linha do tempo | planejada |
| Metas com prazo, etapas, progresso e histórico | planejada |
| Mapa, lugares, busca, rotas, converter em memória | planejada |
| Início | planejada |

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
| 2 | Modelo completo, repositórios, deduplicação, monitor de sincronização | testes em store em memória; modo avião | aguardando |
| 3 | Design system e shell | previews; Dynamic Type AX3; modo escuro; contraste ≥ 4,5:1 | aguardando |
| 4 | Onboarding e "Nosso espaço" (convite, conexão, encerrar/sair, novo parceiro = novo espaço) | fluxo entre 2 contas | aguardando |
| 5 | Recadinhos + favoritos + avisos | N1–N6 | aguardando |
| 6 | Memórias + fotos + linha do tempo | memória com 3 fotos no outro aparelho | aguardando |
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

## Validações

| Data | O quê | Resultado |
|---|---|---|
| 2026-10-17 | Build do template para iOS Simulator | BUILD SUCCEEDED |
| 2026-10-17 | Build Swift 6, iPhone 17 (iOS 26.3) Simulator | BUILD SUCCEEDED, sem avisos de compilação |
| 2026-10-17 | `xcodebuild test`, iPhone 17 (iOS 26.3) Simulator | 11 testes em 3 suítes passaram (`CoupleLimitTests`, `CloudKitSchemaTests`, `RepositoryTests`, incluindo reabertura do store em disco); repetido após a regra de não reconvidar |
| 2026-10-17 | Build para aparelho com `-allowProvisioningUpdates` | BUILD SUCCEEDED; perfil inclui `iCloud.jc.app.dev.casal`, CloudKit e `aps-environment = development`; Info.plist final com `CKSharingSupported`, `remote-notification`, `pt-BR`, família 1 |
| 2026-10-17 | App aberto no simulador iOS 26.3 sem conta iCloud | abre sem falhas; mostra "Entre no iCloud nos Ajustes…" |
| 2026-10-17 | Build Release para aparelho | BUILD SUCCEEDED; ID `note-alerts-experiment-v1` ausente do binário Release (presente no Debug) |

Não testado: fluxo com conta iCloud real, criação do esquema CloudKit, convite, aceitação, sincronização entre aparelhos, avisos, conflitos.

## Última tarefa / ponto de retomada

- **2026-10-17:** etapas 0 e 1 implementadas. Arquivos principais: `AppCasal.xcodeproj/project.pbxproj`, `AppCasal/AppCasal.entitlements`, `AppCasal/Info.plist`, `AppCasal/App/*`, `AppCasal/Data/**`, `AppCasal/Services/AccountService.swift`, `AppCasal/Features/SharingSpike/SharingSpikeView.swift`, `AppCasalTests/*`. Template `ContentView.swift` removido.
- Experimento de avisos restrito a DEBUG; commit local da etapa (sem push).
- **Retomar em:** resultados do primeiro teste básico (S1–S5, P1) em aparelhos → registrar em "Validações" e "Observado em testes"; depois aguardar aprovação da etapa 2.

## Próximos passos (em ordem)

1. Usuário executa o fluxo básico: S1–S5 e P1.
2. Em seguida, separadamente: offline e conflitos (C1–C4), encerramento (S6–S7), avisos (N1–N6).
3. Registrar resultados; decidir solução de avisos com base em N1–N6.
4. Etapa 2 (após aprovação).

## Histórico

- **2026-10-17:** projeto criado a partir do template; GitHub conectado; `.gitignore`; `AGENTS.md` e `CLAUDE.md` criados com diagnóstico e plano.
- **2026-10-17 (substituído):** plano inicial com SwiftData + `CKSyncEngine` e merge por campo próprio. Substituído por Core Data + `NSPersistentCloudKitContainer` para reduzir código de sincronização.
- **2026-10-17 (substituído):** proposta de iOS 27, iPhone + iPad, Swift 5, idioma `en`. Substituída por iOS 26, somente iPhone, Swift 6, pt-BR.
- **2026-10-17 (rejeitado):** avisos por `NoteSignal` no banco público. Não aprovado; substituído pelo experimento com `CKDatabaseSubscription` + `recordType`.
- **2026-10-17 (corrigido):** afirmação de que a exclusão lógica "nunca perde dados". Corrigida: facilita recuperação, não elimina sobrescritas.
- **2026-10-17 (substituído):** proposta de "Exportar uma cópia" ao sair e reconvite no mesmo espaço. Exportação adiada; novo parceiro passa a exigir novo espaço.
- **2026-10-17:** etapa 0 concluída e etapa 1 implementada (validação real pendente).
