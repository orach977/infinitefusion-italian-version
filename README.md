# 🇮🇹 Pokémon Infinite Fusion — Versione Italiana

> Fork italiano di [Pokémon Infinite Fusion](https://github.com/infinitefusion/infinitefusion-e18) con localizzazione completa, strumenti esclusivi e upscaling grafico.

---

## 📋 Sommario

- [Cos'è questo progetto](#-cosè-questo-progetto)
- [Funzionalità esclusive](#-funzionalità-esclusive)
- [Requisiti](#-requisiti)
- [Installazione da zero](#-installazione-da-zero)
- [Aggiornamento](#-aggiornamento)
- [Come giocare](#-come-giocare)
- [Radar Habitat — Guida completa](#-radar-habitat--guida-completa)
- [Pokédex HTML offline](#-pokédex-html-offline)
- [Remaster grafico con Magpie](#-remaster-grafico-con-magpie)
- [Randomizer integrato](#-randomizer-integrato)
- [Struttura del progetto](#-struttura-del-progetto)
- [Domande frequenti (FAQ)](#-domande-frequenti-faq)
- [Crediti](#-crediti)
- [Disclaimer](#-disclaimer)

---

## 🎮 Cos'è questo progetto

Pokémon Infinite Fusion è un fan game gratuito basato su RPG Maker XP che permette di **fondere qualsiasi coppia di Pokémon** tra le prime 6 generazioni (oltre 176.000 combinazioni possibili!).

Questa versione aggiunge:
- **Traduzione italiana** completa dei menù e dell'interfaccia
- **Radar Habitat** — un nuovo strumento nel menù di pausa per esplorare tutti i Pokémon selvatici zona per zona
- **Pokédex HTML** consultabile offline nel browser
- **Launcher Remaster** con upscaling grafico tramite Magpie
- **Supporto Randomizer** integrato

---

## ✨ Funzionalità esclusive

| Funzione | Descrizione |
|---|---|
| 🇮🇹 **Localizzazione IT** | Interfaccia di gioco tradotta in italiano |
| 📡 **Radar Habitat** | Menu completo con lista selvatici per mappa, statistiche base, tipi, rarità, percentuali di incontro, ricerca globale e sistema GPS di tracciamento |
| 📖 **Pokédex HTML** | Pagina HTML offline con dati di tutti i 420 Pokémon base, apribile nel browser |
| 🎨 **Remaster grafico** | Launcher con Magpie integrato per upscaling in tempo reale (ALT+F11) |
| 🎲 **Randomizer** | Supporto completo per le modalità randomizzate del gioco |

---

## 💻 Requisiti

- **Sistema operativo**: Windows 10 / 11 (64-bit)
- **Spazio su disco**: ~1 GB
- **RAM**: 4 GB minimo
- **Per il Remaster grafico**: GPU con supporto DirectX 11 (qualsiasi GPU discreta degli ultimi 10 anni)

---

## 📥 Installazione da zero

### Metodo 1 — Clone da GitHub (consigliato)

1. **Scarica e installa Git** da [git-scm.com](https://git-scm.com/) se non lo hai già

2. **Apri il Terminale / PowerShell** e naviga dove vuoi installare il gioco:
   ```powershell
   cd "$HOME\Desktop"
   ```

3. **Clona il repository**:
   ```powershell
   git clone https://github.com/orach977/infinitefusion-italian-version.git InfiniteFusion
   ```

4. **Avvia il gioco**:
   - Apri la cartella `InfiniteFusion`
   - Fai doppio click su **`Game.exe`** per giocare normalmente
   - Oppure usa **`Avvia_Con_Remaster.bat`** per giocare con la grafica upscalata

### Metodo 2 — Download ZIP

1. Clicca il pulsante verde **"Code"** in alto a destra in questa pagina
2. Seleziona **"Download ZIP"**
3. Estrai lo ZIP in una cartella chiamata esattamente `InfiniteFusion`
4. Avvia con `Game.exe` oppure `Avvia_Con_Remaster.bat`

---

## 🔄 Aggiornamento

Se hai già il gioco installato tramite Git:

```powershell
cd "$HOME\Desktop\InfiniteFusion"
git pull origin main
```

I tuoi salvataggi **non verranno toccati**: sono salvati separatamente in:
```
%APPDATA%\infinitefusion
```

---

## 🕹️ Come giocare

### Avvio standard
Fai doppio click su **`Game.exe`**. Il gioco si aprirà in una finestra.

### Avvio con Remaster grafico
Fai doppio click su **`Avvia_Con_Remaster.bat`**:
1. Il launcher avvia automaticamente **Magpie** (incluso nella cartella del gioco)
2. Poi avvia **Game.exe**
3. Premi **ALT + F11** con la finestra del gioco attiva per attivare l'upscaling fullscreen
4. Premi **ALT + F11** o **ESC** per tornare alla finestra normale

> ⚠️ Per il remaster, imposta le dimensioni schermo nel gioco su **M (1x)** o **XL (2x)**, **non** su "Full".

### Comandi di gioco
| Tasto | Azione |
|---|---|
| **Frecce** | Movimento / Navigazione menù |
| **Z / Invio** | Conferma / Interagisci |
| **X / Esc** | Annulla / Apri menù |
| **C** | Azione speciale / Registra oggetto |
| **F5** | Toggle Fullscreen (nativo) |

---

## 📡 Radar Habitat — Guida completa

Il **Radar Habitat** è uno strumento esclusivo di questa versione, accessibile dal **menù di pausa** (premi X/Esc durante il gioco).

### Come aprirlo
1. Premi **X** o **Esc** durante il gioco per aprire il menù di pausa
2. Seleziona **"Radar Habitat"**

### Interfaccia

L'interfaccia è divisa in 4 aree:

| Area | Contenuto |
|---|---|
| **Header** (in alto) | Nome mappa corrente, contatore mappe, percentuale cattura |
| **Lista Pokémon** (sinistra) | 4 card scrollabili con nome, icona, livello, tipo di incontro, rarità % |
| **Dettaglio** (destra in alto) | Sprite del Pokémon selezionato, numero Pokédex, tipi, rarità |
| **Statistiche** (destra in basso) | Statistiche base (HP, ATK, DEF, SpA, SpD, Spe), BST totale, esclusività mappa |

### Controlli del Radar

| Tasto | Azione |
|---|---|
| **▲ / ▼** | Scorri la lista Pokémon (tieni premuto per scorrere veloce!) |
| **◄ / ►** | Cambia mappa (scorri tutte le zone di gioco) |
| **Z / Invio** | Apri menù azioni (Imposta GPS, Mostra tutti i percorsi) |
| **C / S** | Ricerca globale per nome |
| **X / Esc** | Esci dal Radar |

### Funzione GPS (Tracciamento Target)
1. Seleziona un Pokémon nella lista
2. Premi **Invio** → **"Imposta come Target GPS"**
3. Quando quel Pokémon apparirà in un combattimento selvatico, riceverai un **avviso sonoro e visivo** automatico!
4. L'indicatore GPS appare nell'header del Radar

### Funzione Ricerca Globale
1. Premi **C** o **S** nel Radar
2. Digita il nome del Pokémon che cerchi (anche parziale)
3. Verrà mostrata la lista di **tutte le mappe** dove quel Pokémon appare, ordinate per percentuale di incontro

### Indicatori di rarità

| Tag | Colore | Significato |
|---|---|---|
| COMUNE | Verde | Oltre 20% di probabilità |
| NON COMUNE | Giallo | 10% — 20% |
| RARO | Arancione | 5% — 9% |
| MOLTO RARO | Rosso | Sotto il 5% |

### Note tecniche
- Il Radar **non causa input lag**: i dati delle mappe sono cacheati in memoria e le icone vengono ricaricate solo quando cambiano
- Compatibile con il **Randomizer**: se attivo, il Radar mostra gli incontri randomizzati
- Se un Pokémon non è ancora stato visto, apparirà come **"?????????"** con silhouette nera

---

## 📖 Pokédex HTML offline

Il file **`pokedex.html`** nella cartella del gioco è un Pokédex consultabile nel browser:

1. Fai doppio click su `pokedex.html`
2. Si aprirà nel tuo browser predefinito
3. Puoi cercare, filtrare e consultare i dati di tutti i 420 Pokémon base

> 💡 Funziona completamente offline, non serve connessione internet.

---

## 🎨 Remaster grafico con Magpie

[Magpie](https://github.com/Blinue/Magpie) è un tool gratuito di upscaling in tempo reale. In questa versione è **già incluso** nella cartella `Magpie/`.

### Come funziona
Il launcher `Avvia_Con_Remaster.bat`:
1. Avvia Magpie automaticamente (se non è già in esecuzione)
2. Avvia il gioco
3. Aspetta che tu prema **ALT + F11** per attivare l'upscaling

### Configurazione consigliata
- **Nel gioco**: Dimensioni schermo → **M (1x)** o **XL (2x)**
- **In Magpie**: L'algoritmo di default va bene per la maggior parte dei casi
- **Attivazione**: **ALT + F11** con la finestra del gioco selezionata
- **Disattivazione**: **ALT + F11** oppure **ESC**

---

## 🎲 Randomizer integrato

Il gioco include un sistema di randomizzazione degli incontri selvatici. Quando attivato dalle opzioni di gioco:
- Gli incontri selvatici vengono mescolati
- Il **Radar Habitat** si aggiorna automaticamente per mostrare i Pokémon randomizzati
- I dati del randomizer sono salvati in `Data/encounters_randomized.dat`

---

## 📁 Struttura del progetto

```
InfiniteFusion/
├── Game.exe                          # Eseguibile principale
├── Avvia_Con_Remaster.bat            # Launcher con Magpie
├── INSTALL_OR_UPDATE.bat             # Script di installazione/aggiornamento
├── pokedex.html                      # Pokédex HTML offline
├── README.md                         # Questo file
│
├── Data/
│   ├── Scripts/
│   │   ├── 016_UI/
│   │   │   └── 001_UI_PauseMenu.rb   # Menù pausa (con voce Radar Habitat)
│   │   ├── 052_InfiniteFusion/
│   │   │   └── Menus/
│   │   │       └── HabitatRadar.rb   # Radar Habitat (script completo)
│   │   └── 998_RandomizerList.rb     # Dati randomizer
│   ├── italian.dat                   # Dati localizzazione italiana
│   └── pokedex/dex.json              # Dati Pokédex
│
├── Magpie/                           # Magpie (upscaling grafico)
├── Graphics/                         # Sprite, tileset, UI
├── Audio/                            # Musica e effetti sonori
└── REQUIRED_BY_INSTALLER_UPDATER/    # Git portatile per l'installer
```

---

## ❓ Domande frequenti (FAQ)

### Dove sono i miei salvataggi?
I salvataggi sono in `%APPDATA%\infinitefusion` (separati dalla cartella del gioco). Aggiornare il gioco **non li cancella**.

### Posso usare i salvataggi della versione originale inglese?
**Sì**, i salvataggi sono pienamente compatibili.

### Il gioco ha lag / è lento a caricare
Prova `InfiniteFusion-performance.exe` al posto di `Game.exe`. Ha ottimizzazioni per PC meno potenti.

### Il Radar Habitat non mostra nessun Pokémon
Alcune mappe interne (edifici, grotte senza incontri) non hanno Pokémon selvatici. Usa le frecce **◄ / ►** per navigare verso un percorso o una zona con erba.

### Il Remaster non si attiva
1. Assicurati che Magpie sia in esecuzione (controlla la system tray)
2. La finestra del gioco deve essere selezionata/in primo piano
3. Premi **ALT + F11**
4. Le dimensioni schermo nel gioco devono essere **M** o **XL**, **non** "Full"

### Come aggiorno all'ultima versione?
```powershell
cd "$HOME\Desktop\InfiniteFusion"
git pull origin main
```

---

## 🙏 Crediti

- **Pokémon Infinite Fusion** — [Schrrrup](https://github.com/infinitefusion) e la community di sviluppatori
- **Versione Italiana** — [orach977](https://github.com/orach977)
- **Magpie** (upscaling) — [Blinue](https://github.com/Blinue/Magpie)
- **Essentials Engine** — Maruno e la community di Pokémon Essentials
- **Sprite** — Artisti della community di Pokémon Infinite Fusion ([credits completi](https://www.pokecommunity.com/showthread.php?t=347883))

---

## ⚖️ Disclaimer

Questo è un fan game **gratuito**. Se hai pagato per giocarci, sei stato truffato.

Questo progetto non è affiliato con Nintendo, Game Freak, Creatures Inc. o The Pokémon Company.

Pokémon e tutti i nomi correlati sono marchi registrati dei rispettivi proprietari.

---

## 🔗 Link utili

- [Wiki ufficiale](https://infinitefusion.fandom.com/)
- [Discord ufficiale](https://discord.gg/infinitefusion)
- [Reddit](https://www.reddit.com/r/PokemonInfiniteFusion/)
- [Pokécommunity](https://www.pokecommunity.com/showthread.php?t=347883)
- [Showdown](http://play.pokeathlon.com)
- [Fusion Calculator](https://www.fusiondex.org/)
- [Repository originale](https://github.com/infinitefusion/infinitefusion-e18)