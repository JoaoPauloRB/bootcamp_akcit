# Ashes of the Forge — Game Design Document

## 1. Elevator Pitch

Um RPG top-down de ação rápida onde um espadachim destemido explora florestas e dungeons, derrota slimes e esqueletos, e forja equipamentos cada vez mais poderosos na bigorna de uma vila antiga.

## 2. Design Pillars

1. **Exploração destemida** — sempre há algo novo para descobrir na próxima sala
2. **Ação rápida** — combate responsivo, sem downtime, cada segundo conta
3. **Progressão tangível** — o jogador VÊ seu personagem evoluir visualmente

## 3. Core Loop

```
Explorar → Combater → Coletar recursos → Forjar na Anvil → Ficar mais forte → Explorar mais fundo
```

## 4. Player — "The Forgeborn"

| Stat | Valor |
|------|-------|
| HP | 3 corações (6 half-hearts) |
| HP máximo | 6 corações (12 half-hearts) |
| Velocidade | 80 px/s |
| Dano (espada) | 1 coração por hit |
| Attack speed | 0.4s cooldown |
| Invincibility frames | 1.0s após tomar dano |
| Stun on hit | 0.3s (ainda pode se mover depois) |
| Sprite | Swordsman_lvl1 → lvl2 → lvl3 |
| Tamanho sprite | 48x48 px (side-scroller sheets) |

### Progressão Visual

| Nível | Requisito | Bônus |
|-------|-----------|-------|
| Lvl 1 | Início | Dano base 1, 3 corações |
| Lvl 2 | Forjar com 5 Slime Cores | Dano 2, +1 coração max |
| Lvl 3 | Forjar com 3 Bone Shards | Dano 3, +2 corações max |

## 5. Enemies

### Slime (3 variantes)

| Stat | Slime Verde | Slime Azul | Slime Vermelho |
|------|------------|------------|----------------|
| HP | 2 hits | 3 hits | 4 hits |
| Dano | 0.5 coração | 1 coração | 1.5 coração |
| Velocidade | 30 px/s | 40 px/s | 50 px/s |
| AI | Wander aleatório | Persegue ao ver player (96px) | Persegue agressivo (128px) |
| Drop | Slime Core (80%) | Slime Core (100%) | Slime Core x2 (100%) |
| Localização | Floresta | Floresta | Dungeon |

### Skeleton (2 variantes)

| Stat | Skeleton Base | Skeleton Warrior (BOSS) |
|------|--------------|------------------------|
| HP | 4 hits | 10 hits |
| Dano | 1 coração | 2 corações |
| Velocidade | 50 px/s | 60 px/s |
| AI | Patrol + chase (96px) | Chase + dash attack |
| Drop | Bone Shard (60%) | Key / Victory trigger |
| Localização | Dungeon | Dungeon (boss room) |

## 6. World Map

```
┌──────────┐     ┌──────────┐     ┌──────────┐
│          │     │          │     │          │
│   VILA   │────▶│ FLORESTA │────▶│ DUNGEON  │
│          │     │          │     │          │
│ - Anvil  │     │ - Slimes │     │- Skeletons│
│ - NPCs   │     │ - Trees  │     │- Boss     │
│ - Respawn│     │ - Pickup │     │- Treasure │
│          │     │          │     │          │
└──────────┘     └──────────┘     └──────────┘
```

### Salas

| Sala | Tamanho | Conteúdo | Tileset |
|------|---------|----------|---------|
| Vila | 320x320 px | Anvil, 2 NPCs (Knight, Wizard), respawn point | Floors + structures |
| Floresta | 480x320 px | 3-5 Slimes, árvores, recursos | Floors + vegetation |
| Dungeon | 480x480 px | 4-6 Skeletons, Skeleton Warrior boss | Dungeon tiles + walls |

## 7. NPCs

| NPC | Localização | Diálogo |
|-----|------------|---------|
| Knight | Vila | "The dungeon grows darker... Take this advice: dodge before you strike." |
| Wizard | Vila (perto da Anvil) | "Bring me Slime Cores and Bone Shards. I'll help you forge something extraordinary." |

## 8. HUD

```
┌─────────────────────────────────┐
│ ♥ ♥ ♥ ♡ ♡ ♡          SALA: Vila│
│                                 │
│                                 │
│          (game world)           │
│                                 │
│                                 │
│ Cores: 0    Shards: 0          │
└─────────────────────────────────┘
```

- Corações: top-left
- Nome da sala: top-right
- Inventário de recursos: bottom-left

## 9. Audio

| Contexto | Track | Arquivo |
|----------|-------|---------|
| Vila | Calma, acolhedora | Take some rest and eat some food! |
| Floresta | Aventura, exploração | And The Journey Begins / Exploring The Unknown |
| Dungeon | Tensão, mistério | Mysterious Dungeon / The Icy Cave |
| Boss fight | Épica, urgência | Prepare for Battle! / Decisive Battle |
| Game Over | Melancólica | The Final of The Fantasy |
| Título | Tema principal | Title Theme |

SFX: Kenney RPG (hit, death, pickup) + Interface (menu, confirm)

## 10. Art Style

- **Pixel art** — sprites 48x48 (player, swordsman pack)
- **Palette** — tons terrosos, fantasia medieval
- **Viewport** — 320x180, scale 4x para 1280x720
- **Texture filter** — Nearest (pixel crisp)

## 11. Collision Layers

| Layer # | Nome | Bitmask | Usado por |
|---------|------|---------|-----------|
| 1 | World | 1 | Paredes, obstáculos |
| 2 | Player | 2 | CharacterBody2D do player |
| 3 | Enemies | 4 | CharacterBody2D dos inimigos |
| 4 | PlayerHitbox | 8 | Area2D do ataque do player |
| 5 | EnemyHitbox | 16 | Area2D de dano do inimigo |
| 6 | Pickups | 32 | Itens no chão |

## 12. Scope Tiers

### MUST HAVE (protótipo)
- [x] Player movement (4 direções)
- [x] Sword attack (hitbox)
- [x] 3 Slime variants com AI básica
- [x] 2 Skeleton variants (incluindo boss)
- [x] 3 salas conectadas (Vila → Floresta → Dungeon)
- [x] HP system (corações)
- [x] Forja na Anvil (lvl1 → lvl2 → lvl3)
- [x] HUD (corações + recursos)
- [x] Morte → respawn na vila
- [x] Boss fight + tela de vitória

### SHOULD HAVE (se der tempo)
- [ ] NPC dialogue system
- [ ] SFX (hit, death, pickup)
- [ ] Background music por sala
- [ ] Damage numbers / hit flash
- [ ] Screen shake on hit

### COULD HAVE (pós-protótipo)
- [ ] Mais salas / dungeons
- [ ] Mais tipos de inimigo (Orcs)
- [ ] Inventory screen
- [ ] Pause menu

### OUT OF SCOPE
- Multiplayer
- Save/Load system
- Procedural generation
- Mobile/web export
- Cutscenes
- Quest system
