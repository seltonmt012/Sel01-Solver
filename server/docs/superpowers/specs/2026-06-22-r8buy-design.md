# R8-Buy Plugin — Design

**Datum:** 2026-06-22
**Ziel:** SourceMod-Plugin für legacy CSGO (nicht CS2). Spieler tippt `!r8` im Chat und kauft den R8 Revolver. Ersetzt das kaputte Buymenu der alten Version.

## Problem

In der alten CSGO-Version lässt sich das Buymenu/Inventar nicht mehr öffnen. Spieler können den R8 Revolver nicht normal kaufen. Lösung: Chat-Befehl, der den Kauf serverseitig durchführt — mit normalen Buy-Regeln (Geld, Buyzone, Buytime).

## Scope

- **Plattform:** SourceMod (SourcePawn `.sp` → `.smx`, Metamod).
- **Nur** der R8 Revolver (`weapon_revolver`). Kein allgemeines Chat-Buy-System.
- Kosten: $600 abziehen (echter R8-Preis), nur bei genug Geld.
- Buy-Regeln wie normal: in Buyzone + während Buytime, beliebig oft pro Runde.

## Befehle

| Befehl | Kontext | Wirkung |
|---|---|---|
| `!r8`, `/r8` | Chat (`say` / `say_team`) | Kauft R8 |
| `sm_r8` | Server-Konsole / Client-Konsole | Gleiche Wirkung (Komfort/Test) |

Chat-Trigger via `RegConsoleCmd("sm_r8", ...)` — SourceMod mappt `!`/`/` automatisch auf gleichnamige Konsolen-Commands.

## Ablauf (`!r8`)

1. **Plugin aktiv?** (`sm_r8_enabled`) → sonst stumm ignorieren.
2. **Client gültig + im Spiel + lebt?** → sonst Chat: `[R8] Du musst am Leben sein.`
3. **In Buyzone + Buytime aktiv?** (nur wenn `sm_r8_require_buyzone == 1`) → sonst: `[R8] Nur in der Buyzone (Kaufphase).`
4. **Geld ≥ Preis?** (`m_iAccount`) → sonst: `[R8] Nicht genug Geld (braucht $%d).`
5. **Alte Sekundärwaffe entfernen** (Pistolen-Slot, `CS_SLOT_SECONDARY`) → vermeidet doppelten Bodendrop.
6. **R8 geben:** `GivePlayerItem(client, "weapon_revolver")`.
7. **Geld abziehen:** `m_iAccount -= preis`.
8. **Bestätigung:** `[R8] R8 gekauft (-$%d).`

## Cvars

| Cvar | Default | Zweck |
|---|---|---|
| `sm_r8_enabled` | `1` | Plugin an/aus |
| `sm_r8_price` | `600` | Kaufpreis (0 = gratis) |
| `sm_r8_require_buyzone` | `1` | `1` = Buyzone+Buytime nötig (realistisch), `0` = überall jederzeit |

Auto-generierte Config: `cfg/sourcemod/r8buy.cfg` via `AutoExecConfig(true, "r8buy")`.

## Netprops / SDK

- `m_iAccount` — Geld lesen/schreiben (`GetEntProp`/`SetEntProp` auf `CCSPlayer`).
- `m_bInBuyZone` — Buyzone-Check.
- Buytime: cvar `mp_buytime` + Rundenstart-Zeit, ODER simpler `m_bInBuyZone` allein (CSGO setzt Buyzone-Flag nur während Kaufphase im Bereich). **Entscheidung:** `m_bInBuyZone` reicht — deckt Zone UND Zeit ab.
- `GetClientWeaponSlot` / `RemovePlayerItem` für Slot-Wechsel.
- `GivePlayerItem` für die Waffe.

## Fehlerfälle

| Fall | Reaktion |
|---|---|
| Tot / kein gültiger Client | Chat-Hinweis, kein Kauf |
| Zu wenig Geld | Chat-Hinweis, kein Abzug |
| Nicht in Buyzone (wenn erzwungen) | Chat-Hinweis |
| Plugin aus | Stumm ignorieren |

## Nicht im Scope (YAGNI)

- Andere Waffen, Aliase pro Waffe.
- Pro-Runde-Limit (beliebig oft = normal).
- Menüs / VGUI.
- Cooldowns.

## Build / Deploy

- Quelle: `addons/sourcemod/scripting/r8buy.sp`
- Kompilieren: `spcomp r8buy.sp` (SourceMod-Compiler) → `r8buy.smx`
- Deploy: `.smx` nach `addons/sourcemod/plugins/` auf den Server, `sm plugins load r8buy`.
