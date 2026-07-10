# MegaGame — Server
> Clone Roblox de Megabonk (vampire survivors / bullet-heaven roguelite) — Loic (Lopapon)

---

## Patch Notes

### v0.3.0 — Player (current)
- Ajout de `Entities/Entity.lua` : classe de base pour toute entité du jeu (Player, Mob, Boss à venir). Porte un `Maid` propre + un signal `Died`.
- Ajout de `Entities/PlayerEntity.lua` : wrapper runtime autour d'un `Player` (HP, XP de run, Kills, RunId). Distinct de la donnée persistante — reset à chaque run, jamais sauvegardé.
- Ajout de `Services/PlayerService.lua` : pont entre `DataService` (persistant) et `PlayerEntity` (runtime). Gère le cycle `CharacterAdded`/`CharacterRemoving`/`PlayerRemoving`, republie `PlayerReady` / `PlayerLeaving` sur l'`EventBus`.
- Ajout de `Types/PlayerTypes.lua` : types `PersistentData` et `RuntimeState` partagés.

### v0.2.0 — Data
- Ajout de `Data/DataTemplate.lua` : schéma par défaut des données joueur + `Version` (base du système de migration).
- Ajout de `Data/MigrationService.lua` : chaîne de migrations version N → N+1, appliquées automatiquement au chargement.
- Ajout de `Data/BackupService.lua` : DataStore secondaire, écrit après chaque save réussi (rotation sur 3 slots), restauration manuelle uniquement.
- Ajout de `Data/DataService.lua` : chargement/sauvegarde avec retry + backoff exponentiel, cache mémoire par session, save au `PlayerRemoving` + sauvegarde périodique (5 min) + `BindToClose`.

### v0.1.0 — Core
- Ajout de `Core/Logger.lua` : wrapper `print`/`warn` avec niveaux (`Debug`/`Info`/`Warn`/`Error`) et préfixe par module.
- Ajout de `Core/Maid.lua` : cleanup centralisé (connections, instances, callbacks) — pattern Janitor.
- Ajout de `Core/EventBus.lua` : bus d'événements global basé sur `Nova.Signal`, permet aux Services/Systems de communiquer sans dépendances circulaires.
- Ajout de `Core/StateManager.lua` : store clé/valeur pour l'état global du jeu (pas les données joueur), avec notifications de changement.
- Ajout de `Core/ServiceManager.lua` : auto-discovery des Services (`Init`/`Start`), scan de dossier + `require()` automatique.
- Ajout de `Core/SystemManager.lua` : auto-discovery des Systems (`Init`/`Start`/`Update`), boucle `Heartbeat` centralisée pour tous les systems.

---

## Structure

```
src/
├── Server/
│   ├── Bootstrap.server.lua       ← Point d'entrée serveur
│   │
│   ├── Core/
│   │   ├── ServiceManager.lua     ← Auto-discovery + Init/Start des Services
│   │   ├── SystemManager.lua      ← Auto-discovery + Init/Start/Update des Systems
│   │   ├── StateManager.lua       ← Etat global clé/valeur
│   │   ├── EventBus.lua           ← Communication inter-modules (Nova.Signal)
│   │   ├── Maid.lua                ← Cleanup centralisé
│   │   └── Logger.lua              ← Logs avec niveaux
│   │
│   ├── Data/
│   │   ├── DataService.lua        ← Chargement/sauvegarde joueur (retry, cache, BindToClose)
│   │   ├── DataTemplate.lua       ← Schéma par défaut + version
│   │   ├── MigrationService.lua   ← Migrations de version en chaîne
│   │   └── BackupService.lua      ← DataStore secondaire (filet de sécurité)
│   │
│   ├── Services/
│   │   └── PlayerService.lua      ← Pont DataService <-> PlayerEntity
│   │
│   └── Entities/
│       ├── Entity.lua              ← Classe de base (Maid + Died signal)
│       └── PlayerEntity.lua        ← Etat runtime du joueur (HP, XP, Kills, RunId)
│
└── Shared/
    └── Types/
        └── PlayerTypes.lua         ← PersistentData, RuntimeState
```

---

## Modules

### `Core`

#### `Logger.new(tag)` → `Logger`
Crée un logger préfixé par module. Niveau minimum configurable via `Logger.MinLevel`.
```lua
local log = Logger.new("WaveService")
log:Info("Vague démarrée")
log:Error("Echec critique :", err)
```

#### `Maid.new()` → `Maid`
Centralise le cleanup d'un ensemble de ressources (connections, instances, callbacks). Un `Maid` par run, par entité, ou par système temporaire.
```lua
local maid = Maid.new()
maid:GiveTask(someConnection)
maid:GiveTask(someInstance)
maid:Destroy() -- nettoie tout d'un coup
```

#### `EventBus:Subscribe(eventName, callback)` / `EventBus:Publish(eventName, ...)`
Bus d'événements global basé sur `Nova.Signal`. Évite aux Services/Systems de se `require()` entre eux.
```lua
EventBus:Subscribe("PlayerReady", function(player, entity) ... end)
EventBus:Publish("EnemyDied", enemy, killer)
```

#### `StateManager:Set(key, value)` / `StateManager:Get(key)` / `StateManager:OnChange(key, callback)`
Store global pour l'état du jeu (phase de run, difficulté active, etc.) — pas les données joueur.
```lua
StateManager:Set("GamePhase", "InRun")
StateManager:OnChange("GamePhase", function(new, old) ... end)
```

#### `ServiceManager:LoadFolder(folder)` / `:InitAll()` / `:StartAll()`
Scanne un dossier, `require()` chaque `ModuleScript`, puis appelle `Init()` sur tous, puis `Start()` sur tous. Un nouveau Service = un nouveau fichier, rien à modifier ailleurs.

#### `SystemManager:LoadFolder(folder)` / `:InitAll()` / `:StartAll()` / `:StopAll()`
Même principe que `ServiceManager`, avec en plus une boucle `Heartbeat` centralisée qui appelle `:Update(dt)` sur tous les systems chargés.

---

### `Data`

#### `DataTemplate.new()` → table
Retourne le schéma par défaut d'un nouveau joueur (Level, XP, Gold, héros/armes débloqués, stats lifetime).

#### `MigrationService.Migrate(data, targetVersion)` → table
Applique en chaîne les migrations nécessaires pour amener une donnée d'une ancienne version vers la version actuelle du code.

#### `BackupService:SaveBackup(userId, data)` / `:GetLatestBackup(userId)`
DataStore secondaire, écrit après chaque sauvegarde réussie du `DataService` (rotation sur 3 slots). Restauration **manuelle uniquement**, jamais automatique.

#### `DataService:Get(player)` → table
Retourne la donnée persistante du joueur. Bloquant (`Signal:Wait()`) si le chargement n'est pas encore terminé — attention à ne pas l'appeler dans un contexte sensible au timing frame par frame.

#### `DataService:Set(player, key, value)`
Modifie une clé de la donnée en cache. La sauvegarde effective se fait au `PlayerRemoving`, périodiquement (5 min), ou au `BindToClose`.

---

### `Entities`

#### `Entity.new(instance)` → `Entity`
Classe de base pour toute entité du jeu. Porte un `Maid` propre et un signal `Died`.

#### `PlayerEntity.new(player, character)` → `PlayerEntity`
Wrapper runtime autour d'un `Player` : HP (via `Humanoid.HealthChanged`), XP de run, Kills, RunId. Recréé à chaque `CharacterAdded`, détruit au respawn/déconnexion. **Ne contient aucune donnée persistante.**
```lua
entity:GainXP(10)
entity:AddKill()
entity:EnterRun(runId)
entity:ExitRun()
```

---

### `Services`

#### `PlayerService:GetEntity(player)` → `PlayerEntity?`
Récupère le `PlayerEntity` runtime actif d'un joueur.

#### `PlayerService:GetData(player)` → table
Raccourci vers `DataService:Get(player)`.

Publie sur l'`EventBus` : `PlayerReady(player, entity)` à la création du personnage, `PlayerLeaving(player, entity)` avant déconnexion.

---

## Principes suivis

- **Server-authoritative** : toute logique sensible (dégâts, spawn, économie) reste dans `ServerScriptService`.
- **Registry/factory pattern** : nouvelle feature = nouveau fichier, jamais de modification du code existant (`ServiceManager`/`SystemManager` en auto-discovery suivent ce principe).
- **Séparation runtime / persistant** : `PlayerEntity` (run en cours) ne touche jamais au DataStore ; `DataService` ne connaît rien du combat en cours.
- **Nova reste pur** : `EventBus` et `StateManager` réutilisent `Nova.Signal` plutôt que dupliquer un système d'événements dans `Shared/Util`.
- **Maid systématique** : toute ressource temporaire (connections, instances) passe par un `Maid` pour un cleanup garanti.

---

## Roadmap

- [x] v0.1.0 — Core (Logger, Maid, EventBus, StateManager, ServiceManager, SystemManager)
- [x] v0.2.0 — Data (DataTemplate, MigrationService, BackupService, DataService)
- [x] v0.3.0 — Player (Entity, PlayerEntity, PlayerService, PlayerTypes)
- [ ] Stats — StatService
- [ ] Run — RunService, StageService, DifficultyService, FreezeService
- [ ] Spawn — SpawnService, SpawnSystem
- [ ] IA — MobAISystem, PathfindingSystem
- [ ] Combat — CombatSystem, HitboxSystem, DamageSystem, KnockbackSystem, StatusEffectSystem
- [ ] Reward — RewardService, LootService, ChestService
- [ ] Level — LevelSystem
- [ ] Weapons — WeaponService, InventoryService, AbilityService
- [ ] Boss — BossService, BossEntity
- [ ] Portal / Lobby
- [ ] Coop — CoopService
- [ ] Ranked — MatchService, LeaderboardService
