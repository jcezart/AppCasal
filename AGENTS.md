# AGENTS.md — AppCasal

Referência comum para todos os agentes (Claude, Codex e outros) que trabalham neste projeto.

## Regras para agentes

1. **Leia este arquivo inteiro antes de iniciar qualquer tarefa.**
2. **Atualize este arquivo ao concluir cada etapa relevante e antes de interromper o trabalho.** Em tarefas longas, registre pontos de retomada em "Última tarefa / ponto de retomada".
3. O documento deve refletir o estado real do código. Não marque nada como implementado ou validado sem evidência (build, teste, execução em aparelho). Registre a evidência em "Validações".
4. **Compartilhamento e notificações só podem ser marcados como validados após teste real em dois aparelhos com contas iCloud distintas** (ver "Testes que dependem de dois aparelhos").
5. Não inclua credenciais, tokens, senhas ou segredos neste arquivo nem no repositório.
6. Não sobrescreva trabalho existente sem inspecionar antes. Mudanças em `project.pbxproj`, entitlements e capabilities exigem aprovação do usuário.
7. Implemente em incrementos pequenos, na ordem de "Próximos passos". Não implemente todas as funcionalidades de uma vez. Não comece uma etapa sem aprovação registrada em "Decisões".
8. Não implemente exclusão automática definitiva de dados nem retenção permanente de cópia de dados compartilhados sem aprovação da regra de encerramento (ver "Encerramento do compartilhamento").
9. Swift 6 com verificação estrita de concorrência. Não use `@unchecked Sendable`, `nonisolated(unsafe)`, `@preconcurrency` ou `MainActor.assumeIsolated` para silenciar erros sem justificativa escrita no código e registrada aqui.
10. iOS mínimo 26.0. Não use APIs exclusivas do iOS 27 quando houver alternativa adequada no iOS 26; se usar, proteja com `#available` e registre aqui.
11. Idioma: documentação e comunicação em português (pt-BR). Código, identificadores e mensagens de commit em inglês. Todo texto visível ao usuário vai para o String Catalog (`Localizable.xcstrings`), nunca concatenado.
12. Build por linha de comando: `xcode-select` aponta para as Command Line Tools. Use `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild ...`.

## Resumo atual

- **Fase:** planejamento. Direção visual e divisão em etapas **aprovadas** em 2026-10-17. Ajustes de persistência, container, notificações e encerramento **aguardando aprovação**.
- **Após aprovação:** avançar somente pelas etapas 0 (configuração) e 1 (teste mínimo de compartilhamento).
- Nenhum código de app escrito além do template.
- **Última atualização:** 2026-10-17.

## Produto

- **Nome:** AppCasal (**provisório**). Identificadores técnicos (container, App Group) não usam o nome provisório. Nome exibido centralizado no String Catalog.
- **Objetivo:** app iOS privado para um casal guardar memórias, lugares, recadinhos e metas em um espaço compartilhado só entre os dois, sincronizado por iCloud.
- **Vínculo:** exatamente duas pessoas (dono + um participante), cada uma com sua conta iCloud. Sem compartilhamento público.
- **Primeira versão:** somente iPhone, somente português do Brasil (preparado para tradução via String Catalog).

## Ambiente (diagnóstico de 2026-10-17)

| Item | Valor atual | Alvo aprovado (aplicar na etapa 0) |
|---|---|---|
| Xcode / SDK | 27.0 (27A266a) / iPhoneOS 27.0 | — |
| Projeto | `AppCasal.xcodeproj`, pastas sincronizadas (`objectVersion = 77`) | — |
| Target / scheme | `AppCasal`; sem target de testes | adicionar `AppCasalTests` |
| Bundle ID | `jc.app.dev.AppCasal` | manter |
| Team | `F44CYBRGC2` (conta paga confirmada) | — |
| iOS mínimo | 27.0 | **26.0** |
| Dispositivos | iPhone e iPad (`1,2`) | **iPhone (`1`)** |
| Swift | 5.0, `MainActor` padrão, approachable concurrency | **Swift 6**, `MainActor` padrão mantido |
| Idioma base | `en` | **pt-BR** |
| Info.plist | gerado, sem arquivo físico | gerado + arquivo parcial para `CKSharingSupported` |
| Entitlements | nenhum | iCloud (CloudKit), Push, Background Modes (remote notifications) |
| Git | `main`, remoto `git@github.com:jcezart/AppCasal.git` (SSH via Keychain) | — |
| Limitação | agentes não operam a interface do Xcode; inspeção e build pelo diretório e `xcodebuild` | — |

## Tecnologias

- SwiftUI (iOS 26+, Liquid Glass nativo).
- **Core Data + `NSPersistentCloudKitContainer`** para persistência local e sincronização (proposta; ver comparação).
- CloudKit: `CKShare` gerenciado pelo `NSPersistentCloudKitContainer`; `CKQuerySubscription` no banco público para avisos de recadinho (proposta).
- MapKit, PhotosUI, UserNotifications.
- Swift Concurrency. Nenhuma dependência externa.

## Persistência: comparação e escolha (aguardando aprovação)

| Critério | SwiftData + `CKSyncEngine` | Core Data + `NSPersistentCloudKitContainer` |
|---|---|---|
| `CKShare` | Feito pelo app: zona, share, aceitação, roteamento entre bancos privado e compartilhado | Nativo desde iOS 15: `share(_:to:)`, `acceptShareInvitations(from:into:)`, store privado + store compartilhado |
| Offline | Fila do engine + mapeamento próprio | Automático (SQLite local + histórico persistente) |
| Conflitos | Merge por campo implementado pelo app | Resolvido internamente pelo framework, sem gancho; app mitiga pelo desenho do esquema |
| Fotos | `CKAsset` manual, cache e download próprios | Atributo binário com armazenamento externo vira `CKAsset` automaticamente |
| Código de sincronização próprio | Alto (estimativa 1.500–3.000 linhas: mapeamento, erros, zonas, assets, estado) | Baixo (configuração dos stores, share, monitor de eventos) |
| Manutenção / depuração | Total controle e total responsabilidade | Mais opaco; logs e `eventChangedNotification`; padrão documentado pela Apple com projeto de exemplo |
| Restrições | Nenhuma de esquema | Sem unique constraints; atributos opcionais ou com padrão; relacionamentos opcionais com inverso; sem regra `Deny`; sem relacionamentos ordenados |
| Swift 6 | `@Model` integrado | `NSManagedObject` não é `Sendable`; contextos confinados com `perform` |

**Escolha proposta: Core Data + `NSPersistentCloudKitContainer`.** Atende CKShare, offline e fotos com muito menos código próprio, que é a prioridade do usuário. O custo aceito é o controle limitado de conflitos, mitigado pelo esquema (abaixo) e medido no teste de conflitos. SwiftData não será usado.

**Notas de Swift 6:** o target usa `MainActor` como isolamento padrão. As subclasses de `NSManagedObject` e o `PersistenceController` serão declarados `nonisolated` (isolamento correto, não contorno), o `viewContext` é usado só no `MainActor`, e contextos de fundo só dentro de `perform`. Entre isolamentos trafega apenas `NSManagedObjectID` (que é `Sendable`).

## Arquitetura (proposta, ajustada para Core Data)

**Padrão:** MVVM + Repository, proporcional ao projeto.

- **Views:** SwiftUI, pequenas e compostas. Listas leem com `@FetchRequest` filtrado pelo espaço ativo e por `deletedAt == nil`.
- **ViewModels:** `@Observable @MainActor`, só em telas com lógica (editores, mapa, Início, onboarding, conexão).
- **Repositories:** toda escrita passa por eles (preenchem `modifiedAt`, `modifiedBy`, atribuem o store correto, aplicam exclusão lógica).
- **PersistenceController:** dois stores no mesmo container CloudKit: `Private.sqlite` (`databaseScope = .private`) e `Shared.sqlite` (`.shared`); histórico persistente e notificações remotas ligados.
- **ShareService:** cria o share do espaço, limita a dois participantes, aceita convites, encerra/sai.
- **SyncStatusMonitor:** observa `NSPersistentCloudKitContainer.eventChangedNotification` e o estado da conta para o banner de sincronização.
- **NoteAlertService:** sinal de recadinho no banco público e assinaturas (ver "Notificações").

### Árvore de arquivos proposta

```
AppCasal/
├── AGENTS.md / CLAUDE.md
├── AppCasal/
│   ├── App/
│   │   ├── AppCasalApp.swift          # @main, injeção de dependências
│   │   ├── AppDelegate.swift          # registro de push, configuração de cena
│   │   ├── SceneDelegate.swift        # aceitação de CKShare
│   │   ├── RootView.swift             # onboarding x app principal
│   │   └── AppTab.swift
│   ├── DesignSystem/{Tokens,Components}/
│   ├── Features/{Onboarding,Space,Home,Map,Memories,Notes,Goals}/
│   ├── Data/
│   │   ├── Model/AppCasal.xcdatamodeld
│   │   ├── Model/Entities/            # subclasses NSManagedObject (nonisolated)
│   │   ├── Persistence/               # PersistenceController, SyncStatusMonitor
│   │   ├── Sharing/                   # ShareService
│   │   ├── Notifications/             # NoteAlertService
│   │   └── Repositories/
│   ├── Services/                      # AccountService, LocationService, PhotoProcessing
│   ├── Resources/{Assets.xcassets,Localizable.xcstrings}
│   └── Info.plist                     # parcial: CKSharingSupported
└── AppCasalTests/
```

### Modelo de dados

Campos comuns a toda entidade compartilhada: `id` (UUID), `createdAt`, `createdBy`, `modifiedAt`, `modifiedBy`, `deletedAt?`, `deletedBy?`, e relacionamento para `CoupleSpace` (é o que coloca o objeto na zona compartilhada). `createdBy`/`modifiedBy` = `recordName` do usuário iCloud.

**Compartilhadas (zona do share do casal):**

| Entidade | Campos principais | Quem escreve |
|---|---|---|
| `CoupleSpace` | `relationshipStart`, `coverPhoto` (binário externo) | ambos |
| `Member` | `userRecordName`, `displayName`, `avatar`, `role`, `alertKey` (UUID aleatório para avisos) | só o próprio usuário |
| `Memory` | `title`, `details`, `date`, `category`, `placeID?`, `locationName`, `latitude`, `longitude` | ambos |
| `MemoryPhoto` | `memory`, `image` (binário externo), `thumbnail`, `sortIndex` | ambos |
| `Place` | `name`, `category`, `latitude`, `longitude`, `address`, `mapItemIdentifier?`, `status`, `note`, `memoryID?` | ambos |
| `Note` (recadinho) | `text`, `authorID`, `recipientID`, `sentAt` | só o autor; imutável após envio na v1 |
| `Goal` | `title`, `category`, `dueDate?`, `completedAt?`, `coverPhoto?` | ambos |
| `GoalStep` | `goal`, `title`, `sortIndex`, `doneAt?`, `doneBy?` | ambos |

**Pessoais (store privado, zona padrão, sem relacionamento com dados compartilhados):** `NoteFavorite(noteID)`, `UserPreferences`. Favoritos de recadinhos são pessoais (aprovado).

Progresso de metas e dias juntos são calculados, nunca armazenados (evita conflito de contadores). Histórico de conclusão de metas = `completedAt` da meta + `doneAt` das etapas.

## Compartilhamento (proposta)

- **Container:** ver "Identificador do container".
- **Criar espaço (dono):** cria `CoupleSpace` e o próprio `Member` no store privado e chama `share(_:to: nil)`. O framework cria a zona e o `CKShare`.
- **Exatamente duas pessoas, sem público:** `share.publicPermission = .none`; convite só por participante privado com permissão `.readWrite`; `UICloudSharingController` com `availablePermissions = [.allowPrivate, .allowReadWrite]`; o app só oferece convite quando não há participante aceito ou pendente; ao aceitar, o app confere que o share tem no máximo 2 participantes e recusa o espaço caso contrário.
- **Aceitar (participante):** `CKSharingSupported = YES`; `windowScene(_:userDidAcceptCloudKitShareWith:)` chama `acceptShareInvitations(from:into: sharedStore)`; o participante cria o próprio `Member`. Objetos criados pelo participante são atribuídos ao store compartilhado (`assign(_:to:)`).
- **Um espaço por usuário:** quem já tem espaço ativo e recebe convite é avisado antes de aceitar.
- **Cota:** tudo na zona compartilhada usa o iCloud **do dono**, inclusive fotos enviadas pelo participante.
- **iCloud indisponível:** verificar `accountStatus` e `CKAccountChanged`; sem conta, onboarding explica e bloqueia criar/aceitar. Troca de conta: o framework apaga os dados locais da conta anterior; o app volta ao onboarding.

## Conflitos (estratégia concreta, a medir no teste C1–C4)

O `NSPersistentCloudKitContainer` não expõe gancho de merge com o servidor. A estratégia é desenhar o esquema para que conflitos sejam raros e de baixo custo, e documentar o comportamento real medido.

1. **Local (UI x importação):** `viewContext` com `NSMergeByPropertyObjectTrumpMergePolicy` e `automaticallyMergesChangesFromParent = true`. Edição em andamento na tela vence a importação, campo a campo.
2. **Entre aparelhos:** premissa de pior caso até o teste C1: **o último aparelho a enviar o registro vence o registro inteiro**, independentemente do horário da edição. Se C1 mostrar merge por campo, a regra é atualizada aqui.
3. **Mitigações no esquema:** registros com um único escritor (`Member`, `Note`); listas como registros separados (`GoalStep`, `MemoryPhoto`); nada de contadores armazenados; textos longos editados por um de cada vez é aceito como risco baixo para um casal.
4. **Edição offline dos dois no mesmo campo:** vale a regra 2. A UI mostra "editado por X em data" (`modifiedBy`/`modifiedAt`) para tornar o resultado compreensível.
5. **Exclusão concorrente com edição:** exclusão do usuário é **lógica** (`deletedAt`, `deletedBy`), não remove o registro. Assim exclusão e edição são duas alterações no mesmo registro, nunca "registro inexistente". Resultado esperado no pior caso: se a edição chegar por último, o item volta (nada se perde); se a exclusão chegar por último, o item fica em "Excluídos recentemente" e pode ser restaurado por qualquer um. Filhos (fotos, etapas) somem junto com o pai pela consulta, sem serem alterados.
6. **Exclusão física** só por ação explícita (esvaziar item da lixeira, apagar espaço). Sem expurgo automático até aprovação da regra de encerramento.
7. **Duplicatas:** sem unique constraints no CloudKit. `Member` é deduplicado por `userRecordName` e `CoupleSpace` é único por zona; deduplicação roda após importação.

## Notificações de recadinhos (proposta, aguardando aprovação)

Requisito: aviso imediato para dono e participante. Notificação local gerada após sincronizar **não** é garantia (depende de push silencioso, que o sistema limita e não entrega com o app encerrado pelo usuário).

Limitação do CloudKit: assinaturas por consulta (`CKQuerySubscription`) não funcionam no banco compartilhado; lá só há assinatura do banco inteiro, que dispararia para qualquer alteração (memórias, metas), não só recadinhos.

**Proposta A (recomendada): sinal sem conteúdo no banco público.**
- Ao enviar um recadinho, o app grava também um registro `NoteSignal` no banco público com apenas `recipientKey` (o `alertKey` aleatório do destinatário, guardado só no `Member` da zona privada) e data. Sem texto, sem nomes, sem IDs do iCloud.
- Cada membro tem uma `CKQuerySubscription` no banco público com predicado `recipientKey == meuAlertKey` e `notificationInfo` com alerta visível localizado ("Você recebeu um recadinho") e som.
- Mesmo mecanismo para dono e participante. Entrega via APNs pelo CloudKit, com o app fechado.
- O conteúdo do recadinho continua só na zona privada do casal e chega pela sincronização normal; ao tocar no aviso, o app abre Recados.
- Limpeza: o remetente apaga os próprios sinais com mais de 7 dias.
- Custo: registros mínimos no banco público (legíveis por consulta, mas sem conteúdo identificável). Não é compartilhamento público dos dados do casal.

**Alternativa B:** assinatura do banco compartilhado/privado inteiro com alerta genérico ("Novidades no espaço de vocês"). Imediata, mas dispara para qualquer alteração. Rejeitada por gerar ruído.

**Alternativa C:** servidor próprio de push. Rejeitada: exige backend e credenciais APNs.

Enriquecer o aviso com o texto do recadinho (Notification Service Extension lendo o store local) fica para depois, se o teste mostrar que vale a pena.

## Encerramento do compartilhamento (proposta, aguardando aprovação)

Três conceitos distintos:

| Conceito | O que é | Efeito nos dados |
|---|---|---|
| **Encerrar o vínculo** | Dono para de compartilhar ou participante sai | Dados do espaço permanecem no iCloud do dono |
| **Perda de acesso** | Consequência para quem deixa de participar | O framework remove do aparelho do participante a cópia local da zona compartilhada; os dados não são apagados do iCloud do dono |
| **Exclusão definitiva** | Apagar o espaço e todos os dados | Remove a zona do iCloud do dono; irreversível para os dois |

**Dono:**
- "Encerrar compartilhamento": confirmação explicando que o parceiro perderá acesso e que os dados continuam com o dono. Remove o share. O espaço continua no aparelho e no iCloud do dono; ele pode convidar alguém de novo depois.
- "Apagar espaço": ação separada, só do dono, com confirmação forte (digitar uma palavra). Só depois de aprovação desta regra.

**Participante:**
- "Sair do espaço": confirmação explicando que perderá acesso e que os dados, inclusive fotos que enviou, permanecem com o dono. Antes de sair, o app oferece **"Exportar uma cópia"** (fotos para o app Fotos e um resumo das memórias/recadinhos em PDF ou pasta no Arquivos), sempre por ação do usuário.
- Participante não pode apagar o espaço inteiro.

**Não implementado sem aprovação:** expurgo automático, retenção de cópia somente leitura no aparelho de quem saiu, exportação automática.

## Identificador do container (proposta, aguardando aprovação)

- Padrão dos identificadores do usuário: `jc.app.dev.<Nome>` (todos os projetos locais, incluindo este bundle ID).
- **Proposto: `iCloud.jc.app.dev.casal`** — neutro em relação ao nome provisório "AppCasal" e descritivo do domínio. É permanente: não pode ser apagado nem renomeado depois de criado.
- Alternativa se o app for publicado sob o padrão de `ZenSounds` (`com.juliocezar.*`): `iCloud.com.juliocezar.casal`.
- O container não depende do bundle ID; mudar o bundle ID depois não exige novo container.

## Referência visual e design system (aprovado)

**Referência:** imagem "Álbum afetivo de Ana e Lucas" (fora do repositório, em `~/Downloads`). Seis telas: Início, Mapa, Memórias, Recados, Metas, Perfil e conexão. Nomes, fotos e textos da imagem são fictícios e não devem virar conteúdo fixo.

### Extraído da imagem

- Atmosfera de álbum: fundo creme quente, cartões claros quase planos, fotografias com cantos arredondados, tom romântico discreto.
- Cor de destaque terracota (botões principais, aba ativa, chips selecionados, coração, barras de progresso).
- Títulos em serifada; metadados e rótulos em sem serifa. Subtítulos poéticos sob os títulos.
- Chips suaves de categoria e de estado; controle segmentado em pílula com seleção terracota.
- Memórias agrupadas por mês; 5 abas (Início, Mapa, Memórias, Recados, Metas); perfil pelo avatar no Início; banner de sincronização no perfil.

### Tokens (proposta complementar baseada na imagem)

| Token | Claro | Uso |
|---|---|---|
| `canvas` | `#F7F0E8` | fundo das telas |
| `surface` | `#FCF8F3` | cartões |
| `surfaceMuted` | `#F2E4DA` | chips, banner, controles inativos |
| `accent` | `#B4553F` | botões preenchidos, seleção (branco sobre ele ≈ 4,9:1) |
| `accentText` | `#9A4433` | texto e ícones terracota pequenos (≈ 5,7:1 sobre `canvas`) |
| `textPrimary` | `#3D1F1A` | títulos e corpo |
| `textSecondary` | `#76655D` | metadados (≈ 4,9:1 sobre `canvas`) |
| `success` | `#4E8B5A` | "Conectado" |
| `separator` | `#E8DAD0` | divisores raros |

Variante escura definida no Asset Catalog (a imagem só mostra o modo claro). Valores aproximados; medir contraste ao implementar.

- **Tipografia:** New York (`.fontDesign(.serif)`) para títulos, nomes, títulos de cartões e texto dos recadinhos; SF Pro para o resto. Sempre estilos de texto para Dynamic Type.
- **Espaçamento:** grade de 4 pt (4–40); margem lateral 20; padding de cartão 16; `@ScaledMetric` para medidas que crescem com o texto.
- **Cantos (`.continuous`):** cartão 20, foto em cartão 14, botão 14, chips e segmentado em cápsula.
- **Sombra:** muito suave ou nenhuma. **Ícones:** SF Symbols; sem emoji como ícone.
- **Componentes:** `CoupleHeroHeader`, `SurfaceCard`, `MemoryCard`, `MemoryRow`, `NoteCard`, `NotePreview`, `GoalCard`, `GoalSummaryRow`, `ProgressBar`, `StepChecklist`, `TagChip`, `StatusChip`, `PillSegmentedControl`, `PrimaryButton`, `SoftButton`, `AvatarView`, `CoupleAvatars`, `SyncStatusBanner`, `EmptyStateView`, `ErrorBanner`, `PlaceCard`, `MapFilterBar`, `SettingsRow`.
- **Estados por tela:** vazio, carregando, erro, sincronização pendente. O banner "N alterações aguardando envio" usa contagem aproximada (transações locais do histórico persistente após o último evento de exportação bem-sucedido).

### Navegação

- `TabView` nativo, 5 abas: Início, Mapa, Memórias (**linha do tempo das memórias do casal**, aprovado), Recados, Metas (com histórico de concluídas; sem outra linha do tempo nesta versão). Um `NavigationStack` por aba.
- "Nosso espaço" pelo avatar no Início. Criação em sheets. Onboarding antes das abas.

### Liquid Glass (APIs do iOS 26; sem fallback de versão)

| Onde | Como | Por quê |
|---|---|---|
| Barra de abas | `TabView` nativo | padrão do sistema, flutua sobre o conteúdo |
| Barras de navegação e ações "+" / "Escrever recadinho" | `ToolbarItem` nativo; ação principal `.glassProminent` tingida de `accent` | controles sobre conteúdo rolável |
| Mapa: busca, filtros, "+", localização | `glassEffect` em `GlassEffectContainer` | controles flutuantes sobre conteúdo dinâmico |
| Mapa: detalhe do lugar | sheet nativa com `presentationDetents` | material e gestos do sistema |
| Ações sobre fotos (avatar no herói, visualizador) | `.buttonStyle(.glass)` circular | legibilidade sobre imagem variável |
| **Sem glass** | cartões, recadinhos, metas, formulários, perfil, banner, segmentado em pílula | superfícies estáveis de leitura |

Verificar com Reduzir Transparência, Aumentar Contraste e Reduzir Movimento ligados.

### Ajustes em relação à imagem

- Barra de abas nativa (cápsula de vidro flutuante) no lugar da barra plana; terracota na aba ativa.
- Títulos grandes como títulos de navegação nativos em serifada.
- Mapa no estilo nativo da Apple.
- Em Dynamic Type grande, linhas horizontais (foto + texto) viram verticais.

## Estado das funcionalidades

| Funcionalidade | Estado |
|---|---|
| Projeto Xcode base (template SwiftUI) | implementado (build no simulador OK em 2026-10-17) |
| Configuração (etapa 0) | planejada |
| Teste mínimo de compartilhamento (etapa 1) | planejada |
| Avisos de recadinho | planejada |
| Persistência Core Data completa | planejada |
| Design system e shell de navegação | planejada |
| Onboarding, perfil e conexão por convite | planejada |
| Recadinhos (histórico, favoritos pessoais) | planejada |
| Memórias com fotos e linha do tempo | planejada |
| Metas com prazo, etapas, progresso e histórico | planejada |
| Mapa: lugares, busca, filtros, distâncias, rotas | planejada |
| Converter lugar desejado em memória | planejada |
| Início (foto, contador, resumos) | planejada |
| Encerramento do compartilhamento | regra em definição |

## Persistência, CloudKit e CKShare — configuração atual

- Persistência: nenhuma.
- CloudKit: não configurado (sem capability, sem container).
- CKShare: não configurado.

## Etapas de implementação

| # | Etapa | Critério de conclusão verificável |
|---|---|---|
| 0 | Configuração: iOS 26.0, iPhone, Swift 6, pt-BR + String Catalog, target de testes, capabilities iCloud/CloudKit com o container aprovado, Push, Background Modes, Info.plist parcial com `CKSharingSupported` | build sem avisos de concorrência; container visível no CloudKit Console; teste vazio passa |
| 1 | Teste mínimo de compartilhamento (UI sem design): conta iCloud, `PersistenceController` com 2 stores, criar espaço, convidar, aceitar, criar/editar/excluir `Note` dos dois lados, sinal de recadinho e assinatura | preparação: build e testes unitários; **validação somente com S1–S6, N1–N4 e C1–C4 em dois aparelhos** |
| 2 | Modelo de dados completo, repositórios, exclusão lógica, monitor de sincronização | testes de repositório em store em memória; offline com modo avião |
| 3 | Design system e shell | previews; Dynamic Type AX3 e modo escuro sem cortes; contraste ≥ 4,5:1 |
| 4 | Onboarding e "Nosso espaço" (convite, conexão, encerrar/sair conforme regra aprovada) | fluxo entre 2 contas |
| 5 | Recadinhos + favoritos + avisos | N1–N4 em aparelhos |
| 6 | Memórias + fotos + linha do tempo | memória com 3 fotos no outro aparelho; miniatura offline |
| 7 | Metas + etapas + histórico | C-testes com etapas marcadas simultaneamente |
| 8 | Mapa + lugares + busca + rotas + converter em memória | busca, rota no Mapas, memória ligada |
| 9 | Início | dados reais e estados vazios |
| 10 | Endurecimento: troca de conta, cota cheia, VoiceOver, revisão App Store | checklist com evidências |

## Testes que dependem de dois aparelhos

Disponibilidade de dois aparelhos com contas iCloud distintas: **não confirmada**. Simulador com conta iCloud serve para preparação, mas aceitação de convite e push nele não contam como validação.

| ID | Teste | Estado |
|---|---|---|
| S1 | Dono cria espaço e envia convite | não testado |
| S2 | Participante aceita pelo link (app fechado e aberto) | não testado |
| S3 | Recadinho criado em A aparece em B e vice-versa | não testado |
| S4 | Edição e exclusão lógica propagam nos dois sentidos | não testado |
| S5 | Objeto criado pelo dono após o share entra na zona compartilhada | não testado |
| S6 | Terceira conta não consegue entrar (limite de 2) | não testado |
| N1 | Participante → dono: aviso com app em primeiro plano, fundo e encerrado | não testado |
| N2 | Dono → participante: mesmos três estados | não testado |
| N3 | Remetente não recebe o próprio aviso | não testado |
| N4 | Tempo entre envio e aviso (meta: segundos) | não testado |
| C1 | Mesmo campo editado offline nos dois; medir se vence o último envio do registro inteiro ou por campo | não testado |
| C2 | Exclusão lógica em A e edição em B offline; reconectar em ordens diferentes | não testado |
| C3 | Exclusão física em A com edição em B | não testado |
| C4 | Criação offline nos dois aparelhos e reconexão | não testado |

## Decisões importantes

| Data | Decisão | Justificativa | Estado |
|---|---|---|---|
| 2026-10-17 | Direção visual baseada na imagem e divisão em etapas | — | aprovada |
| 2026-10-17 | iOS mínimo 26.0; evitar APIs só do iOS 27 | alcance maior com Liquid Glass | aprovada |
| 2026-10-17 | Swift 6 com concorrência estrita | segurança de dados | aprovada |
| 2026-10-17 | Somente iPhone e pt-BR na v1, String Catalog | foco | aprovada |
| 2026-10-17 | Favoritos de recadinhos pessoais | — | aprovada |
| 2026-10-17 | Memórias = linha do tempo; metas concluídas só no histórico de Metas | — | aprovada |
| 2026-10-17 | Vínculo de exatamente duas pessoas, sem compartilhamento público | privacidade | aprovada |
| 2026-10-17 | Core Data + `NSPersistentCloudKitContainer` (sem SwiftData) | menos código próprio de sincronização; CKShare nativo | proposta |
| 2026-10-17 | Exclusão lógica com "Excluídos recentemente" | torna exclusão x edição concorrente segura | proposta |
| 2026-10-17 | Avisos de recadinho por sinal sem conteúdo no banco público | único mecanismo nativo imediato e específico para os dois papéis | proposta |
| 2026-10-17 | Container `iCloud.jc.app.dev.casal` | neutro, segue padrão `jc.app.dev.*` | proposta |
| 2026-10-17 | Regra de encerramento (dono encerra/apaga; participante sai com exportação opcional) | separa vínculo, acesso e exclusão | proposta |
| 2026-10-17 | Tipografia New York + SF Pro; paleta da referência | identidade da referência, nativa, Dynamic Type | proposta |
| 2026-10-17 | Glass só em navegação, controles flutuantes e ações sobre fotos | legibilidade do conteúdo | aprovada |

## Pendências do usuário

- Aprovar: persistência (Core Data), container `iCloud.jc.app.dev.casal`, avisos via banco público, regra de encerramento, exclusão lógica.
- Confirmar dois aparelhos com contas iCloud distintas.
- Etapa 0 exigirá criar o container (irreversível) — confirmar o valor exato antes.

## Problemas conhecidos e bloqueios

- `xcode-select` aponta para Command Line Tools; usar `DEVELOPER_DIR` (regra 12).
- Validação de compartilhamento e avisos bloqueada até haver dois aparelhos.
- Comportamento exato de conflito do `NSPersistentCloudKitContainer` não documentado pela Apple; depende de C1–C4.
- Push do CloudKit em ambiente de desenvolvimento usa APNs sandbox; precisa de build de debug instalada em aparelho.

## Validações

| Data | O quê | Resultado |
|---|---|---|
| 2026-10-17 | `xcodebuild build` do template para iOS Simulator | BUILD SUCCEEDED |

Não testado: qualquer funcionalidade (nenhuma implementada).

## Última tarefa / ponto de retomada

- **2026-10-17:** ajustes do usuário incorporados (iOS 26, Swift 6, iPhone, pt-BR, favoritos pessoais, Memórias = linha do tempo). Comparação de persistência, estratégia de conflitos, avisos de recadinho, regra de encerramento e container propostos. Nenhum código alterado. **Próximo:** aguardar aprovação; então etapa 0 e etapa 1, nada além.
- Arquivos envolvidos: `AGENTS.md`, `CLAUDE.md`.

## Próximos passos (em ordem)

1. Usuário aprova os itens "proposta" e confirma o container.
2. Etapa 0 (configuração).
3. Etapa 1 (teste mínimo de compartilhamento) até o ponto possível sem aparelhos; registrar o que falta.
4. Testes S/N/C em dois aparelhos quando disponíveis.

## Histórico

- **2026-10-17:** projeto criado a partir do template; GitHub conectado; `.gitignore`; `AGENTS.md` e `CLAUDE.md` criados com diagnóstico e plano.
- **2026-10-17:** decisões do usuário registradas; persistência trocada para Core Data + `NSPersistentCloudKitContainer` (proposta); estratégias de conflito, avisos e encerramento detalhadas.
