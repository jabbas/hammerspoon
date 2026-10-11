# Automatyczne przełączanie lewego monitora: Mac mini ↔ MacBook

Instrukcja dla agenta (lub osoby), który może uruchamiać polecenia na **Mac mini** i na **MacBooku**.
Cel: lewy monitor przechodzi na Miniego lub MacBooka na podstawie zasady **„ostatnio wybudzony wygrywa"** — kto się obudził / odblokował, ten trzyma lewy monitor.

---

## 1. Stan sprzętu (zweryfikowany ręcznie, nie zmieniaj okablowania)

| Monitor | Model | Mac mini | MacBook |
|---|---|---|---|
| **Lewy** | Dell P2715Q (rev. A03) | USB-C → **DisplayPort** (wejście DP, kod DDC **15**) | USB-C → DP → **mini DisplayPort** (kod DDC **16**) |
| **Prawy** | Dell P2715Q | **HDMI** (kod DDC 17), 60 Hz | — |

- Mac mini: M1, użytkownik `jabbas`, host `mini` (adresy `mini.home` i `mini.local`).
- MacBook: Pro 13" M2 (służbowy), użytkownik `<użytkownik MacBooka>`, host `<host MacBooka>`.
- W obu monitorach **MST = Off** (z MST On DisplayPort działa tylko w 30 Hz, macOS nie obsługuje MST).
- W lewym monitorze **włączone HDMI 2.0** (ukryta opcja „Disable HDMI 1.4 support"). Reset fabryczny monitora ją cofa.
- DDC/CI włączone w obu monitorach.

### Ustalone zachowanie (z testów)

- **DDC działa tylko przez DisplayPort.** Przez wbudowane HDMI M1 Mini polecenia DDC są ignorowane albo kończą się błędem `device offline`.
- **P2715Q zrywa łącze DP na nieaktywnym wejściu.** Gdy lewy pokazuje mini DP (MacBook), Mac mini **nie widzi** lewego monitora, i odwrotnie.
- W efekcie **każdy komputer może tylko „oddać" lewy monitor drugiemu**, niggo go sobie „zabrać":
  - Mac mini (gdy lewy pokazuje Miniego): `set input 16` → lewy idzie do MacBooka.
  - MacBook (gdy lewy pokazuje MacBooka): `set input 15` → lewy idzie do Miniego.
- Po udanym przełączeniu `m1ddc` często zwraca `DDC communication failure: (iokit/common) no such device`. **To jest oczekiwane**: monitor znika w trakcie polecenia, ale przełączenie się udaje.
- Numery wyświetlaczy (`display 1`, `display 2`) **zmieniają się**. Zawsze używaj **UUID**.

### UUID (stan na 2026-10-10; zweryfikuj w kroku 3.3)

| Komputer | Lewy monitor (DP / mini DP) | Prawy monitor |
|---|---|---|
| Mac mini | `1B5F0426-EFF5-4986-ABCE-67B1F3E2FF67` | `B6AEAC4A-F7B9-48AA-A437-B9E44A47848D` (HDMI) |
| MacBook | `F10F3853-1195-47E4-B1B9-EDA17BE38872` | — |

UUID mogą się zmienić po przepięciu kabla do innego portu lub zmianie ustawień MST.

---

## 2. Architektura rozwiązania

**Zasada: „ostatnio wybudzony wygrywa".** Kto się obudził lub odblokował, ten trzyma lewy monitor.

- **Mac mini** jest arbitrem — trzyma zmienną `monitorOwner` (`mini` | `macbook`).
- **Serwer HTTP na Minim**, port **8765**, wszystkie routy wymagają `?token=<TOKEN>`. Zły token → 403, nieznana routa → 404:
  - `GET /owner` → zwraca `mini` lub `macbook`.
  - `GET /claim/macbook` → owner = macbook, Mini przełącza lewy na MacBooka (`m1ddc display <LEFT> set input 16`).
  - `GET /claim/mini` → owner = mini.
- **MacBook** nie ma serwera — polluje Miniego co **2 s** (`GET /owner`). Nie wymaga otwartego portu (korporacyjne MDM/firewall). Koszt: do ~2 s opóźnienia przy wybudzaniu Miniego. Poza domem zapytania po cichu się nie udają; timeout 15 s na każde zapytanie (strażnik `inflight`).

### Tabela zdarzeń

| Gdzie | Zdarzenie | Działanie |
|---|---|---|
| Mini | wybudzenie ekranów / odblokowanie / `systemDidWake`, tylko gdy `hs.host.idleTime() < 5` | owner = mini |
| Mini | start Hammerspoona: idle < 30 s → owner = mini; inaczej owner wg stanu faktycznego | — |
| MacBook | blokada / wygaszenie ekranu / usypianie systemu | oddaje lewy (input 15) + `/claim/mini` |
| MacBook | zamknięcie klapy (AppleClamshellState No→Yes) | oddaje lewy; macOS sam usypia MacBooka |
| MacBook | odblokowanie | `/claim/macbook` |
| MacBook | wybudzenie bez blokady (idle < 5) lub otwarcie klapy bez blokady | `/claim/macbook` |
| MacBook | start Hammerspoona: odblokowany i idle < 30 s → `/claim/macbook` | — |
| MacBook | co 2 s GET `/owner`: `mini` + MacBook aktywny i widzi lewy → oddaje; `macbook` + aktywny + nie widzi lewego → ponawia claim (max 5) | — |

### Dlaczego sprawdzanie idleTime?

Przełączenie wejścia monitora wygląda dla macOS jak hot-plug (display re-connect) i może wywołać zdarzenie „wake". Zliczanie tylko wybudzeń z rzeczywistym wejściem HID (idle < 5 s) zapobiega ping-pongowi. Przeładowanie Hammerspoona nie jest traktowane jako start, chyba że ktoś używał maszyny w ciągu ostatnich 30 s.

### Dlaczego polling zamiast serwera na MacBooku?

MacBook to laptop służbowy — polling nie wymaga otwartego portu przychodzącego (firewall/MDM). Koszt: do ~2 s opóźnienia przy wybudzaniu Miniego. Poza domem zapytania po cichu się nie udają.

### Semantyka blokady (wybór użytkownika)

Zablokowanie MacBooka oddaje lewy Miniemu. Wybudzenie MacBooka do ekranu blokady nic nie robi — dopiero odblokowanie przejmuje lewy.

### Zamknięcie klapy

Z zasilaczem AC i podłączonym monitorem zewnętrznym macOS wchodzi w tryb clamshell i nie generuje zdarzenia lock/sleep — stąd jawny watcher klapy (`hs.screen.watcher` + `ioreg` AppleClamshellState, debounce 1.5 s). Konsekwencja: praca na MacBooku z zamkniętą klapą na lewym monitorze **nie jest wspierana**.

### Mac mini — bez pełnego usypiania systemu

Mini **nigdy nie powinien przechodzić w usypianie systemu** (tylko usypianie ekranu). Sprawdź: `pmset -g` → `sleep 0`, `displaysleep 5`. Jeśli trzeba: `sudo pmset -a sleep 0` lub Ustawienia → Energia → „Zapobiegaj automatycznemu usypianiu, gdy ekran jest wyłączony".

---

## 3. Kroki

### 3.1. Oba komputery: zależności

```bash
brew list m1ddc >/dev/null 2>&1 || brew install m1ddc
brew list --cask hammerspoon >/dev/null 2>&1 || brew install --cask hammerspoon
which m1ddc   # oczekiwane: /opt/homebrew/bin/m1ddc
```

Jeśli ścieżka jest inna, popraw stałą `M1DDC` w `lib/monitor.lua` (sekcja 3.6).

### 3.2. Wygeneruj token (raz, ten sam na obu komputerach)

```bash
openssl rand -hex 16
```

Wstaw wynik jako `token` w `localconfig.lua` na obu komputerach (sekcja 3.6).

### 3.3. Zweryfikuj UUID lewego monitora

**Mac mini** (lewy musi pokazywać Miniego):
```bash
m1ddc display list
```

**MacBook** (lewy musi pokazywać MacBooka):
```bash
m1ddc display list
```

Na MacBooku wpis `(null)` to wbudowany ekran. Lewy to `DELL P2715Q`.

UUID można też sprawdzić w Hammerspoonie: `hs.screen:getUUID()`.

Jeśli UUID różnią się od tabeli w sekcji 1, użyj aktualnych.

### 3.4. Hostname Miniego

Na Mac mini:
```bash
scutil --get LocalHostName   # np. "mini" → adres mini.local
ipconfig getifaddr en0       # zapasowo adres IP
```

Na MacBooku sprawdź osiągalność: `ping -c 1 mini.local`. Jeśli nie działa, użyj adresu IP w `mini_url` (`localconfig.lua`, sekcja 3.6).

**Uwaga:** Mini ma dwa adresy: `mini.home` i `mini.local` (różne podsieci). Konfiguracja używa `mini.local`.

### 3.5. Mac mini: ustawienie zasilania

```bash
pmset -g
```

Oczekiwane: `sleep 0`, `displaysleep 5`. Jeśli `sleep > 0`:
```bash
sudo pmset -a sleep 0
```

Alternatywnie: Ustawienia → Energia → „Zapobiegaj automatycznemu usypianiu, gdy ekran jest wyłączony".

### 3.6. Konfiguracja Hammerspoona (repozytorium)

Kod jest w repozytorium — dokument go nie powiela:

| Plik | Zawartość |
|---|---|
| `init.lua` | wczytuje i waliduje `localconfig.lua`, uruchamia rolę |
| `lib/monitor.lua` | stałe (`PORT`, `USER_IDLE`, `START_IDLE`), logger `monitor`, `haveScreen`, `setInput` |
| `roles/mini.lua` | serwer HTTP i stan `monitorOwner` (Mac mini) |
| `roles/macbook.lua` | watcher zdarzeń, odpytywanie `/owner`, obsługa klapy (MacBook) |

Na każdej maszynie:

```bash
git clone git@github.com:jabbas/hammerspoon.git ~/.hammerspoon
cp ~/.hammerspoon/localconfig.example.lua ~/.hammerspoon/localconfig.lua
chmod 600 ~/.hammerspoon/localconfig.lua
```

`localconfig.lua` (poza gitem):

| Pole | Mac mini | MacBook |
|---|---|---|
| `role` | `"mini"` | `"macbook"` |
| `token` | token z kroku 3.2 | ten sam token |
| `mini_url` | — | `http://<adres Mini>:8765`, np. `http://mini.local:8765` |

UUID lewego monitora są w `roles/mini.lua` i `roles/macbook.lua` (stała `LEFT`). Jeśli krok 3.3 pokazał inne UUID, popraw tam.

### 3.7. Uruchomienie Hammerspoona (oba komputery)

```bash
open -a Hammerspoon
```

Przeładowanie konfiguracji (CLI):
```bash
# Mac mini / MacBook lokalnie:
hs -c "hs.reload()"

# Mac mini przez SSH:
/opt/homebrew/bin/hs -c "hs.reload()"
```

**Uwaga:** automatyczne przeładowanie po zapisie plików konfiguracji **nie działa** na tych maszynach. Zawsze przeładowuj ręcznie.

Wymaga **ręcznej akcji użytkownika** (agent nie może tego zrobić sam):
- Ustawienia systemowe → Prywatność i ochrona → **Dostępność** → włącz Hammerspoon.
- Na Mac mini: jeśli zapora macOS zapyta o połączenia przychodzące dla Hammerspoona → **Zezwól** (obecnie zapora wyłączona).
- Preferencje Hammerspoona → **Launch Hammerspoon at login**.

`require("hs.ipc")` jest pierwszą linią `init.lua`, więc `hs -c` działa od razu.

---

## 4. Testy (zweryfikowano 2026-10-11)

### Endpointy (curl z dowolnego komputera)

1. **Zły token** → 403:
   ```bash
   curl -s -o /dev/null -w "%{http_code}\n" "http://mini.local:8765/owner?token=zly"
   ```
2. **Brak tokena** → 403:
   ```bash
   curl -s -o /dev/null -w "%{http_code}\n" "http://mini.local:8765/owner"
   ```
3. **`/owner`** zwraca wartość:
   ```bash
   curl -s "http://mini.local:8765/owner?token=__TOKEN__"
   ```
4. **Nieznana routa** → 404:
   ```bash
   curl -s -o /dev/null -w "%{http_code}\n" "http://mini.local:8765/nieistnieje?token=__TOKEN__"
   ```

### Scenariusze (wymagają obserwacji fizycznej)

| # | Scenariusz | Oczekiwane | Status |
|---|---|---|---|
| 1 | Odblokuj MacBooka | lewy przechodzi na MacBooka | ✅ |
| 2 | Zablokuj MacBooka (Ctrl+Cmd+Q) | lewy wraca na Miniego | ✅ |
| 3 | Wybudź MacBooka do ekranu blokady | nic się nie dzieje do odblokowania | ✅ |
| 4 | MacBook odblokowany: `pmset displaysleepnow` na Minim, potem ruch myszką na Minim | lewy wraca na Miniego w ~2 s | ✅ |
| 5 | Zamknij klapę MacBooka (AC + monitor) | pulpit przenosi się na lewy, ~2 s → lewy idzie do Miniego, MacBook śpi; otwórz + odblokuj → lewy wraca | ✅ |
| 6 | Restart każdego komputera | — | ❌ nie testowano |

### Jak obserwować

Logi Hammerspoona (oba komputery):
```bash
hs -c "return hs.console.getConsole()" | grep "monitor:"
```

Każda gałąź loguje z nazwą loggera `monitor`.

Endpoint właściciela:
```bash
curl -s "http://mini.local:8765/owner?token=__TOKEN__"
```

Lista wyświetlaczy na Minim:
```bash
m1ddc display list
```

---

## 5. Rozwiązywanie problemów

| Objaw | Przyczyna / rozwiązanie |
|---|---|
| `The specified display does not exist` | Monitor pokazuje inne wejście (łącze DP zerwane) albo zmienił się UUID → `m1ddc display list`. |
| `device offline` / `no such device` po przełączeniu | Normalne, przełączenie się udało. |
| Lewy na 30 Hz na MacBooku | macOS wybrał 30 Hz w trybie „looks like 3008x1692" → Ustawienia → Monitory → 60 Hz. **Nie** jest to wina MST ani adaptera. Inne możliwe przyczyny: reset fabryczny monitora cofnął HDMI 2.0 (lewty na HDMI Miniego), albo MST włączone (DP). |
| `hs.screen:availableModes()` zwraca pustą listę | Znany problem na tej wersji Hammerspoona/macOS — nie polegaj na tej funkcji. |
| `m1ddc` na MacBooku kończy się segfault (exit 139) | Gdy wyświetlacze MacBooka śpią, `hs.screen` trzyma nieaktualny wpis dla lewego monitora. Konfiguracja chroni się flagą `monitorActive`. |
| `hs -c` zwraca „can't access Hammerspoon message port" | `hs.ipc` nie załadowane lub Hammerspoon nie działa. |
| Serwer nie odpowiada | Hammerspoon na Minim nie działa, `mini.local` nie rozwiązuje się (Mini ma dwa adresy: `mini.home` i `mini.local`), Mini w pełnym usypianiu systemu (nie powinien — sprawdź `pmset -g`). |
| Lewy nie wraca po odblokowaniu | Sprawdź log MacBooka: `claim/macbook -> <status>`, log Miniego: `owner ... -> macbook`. |
| Zmienne globalne / garbage collector | Watchery, serwer i timery muszą być w zmiennych globalnych — inaczej Lua GC je usunie. |

---

## 6. Czego nie robić

- Nie zmieniaj okablowania ani ustawień OSD monitorów (MST, HDMI 2.0, DDC/CI) bez zgody użytkownika.
- Nie używaj numerów wyświetlaczy zamiast UUID.
- Nie dodawaj skrótów klawiszowych (Ctrl+Alt+Cmd+M/B itp.) — odrzucone przez użytkownika.
- Nie wywołuj `/claim/*` przypadkowo — fizycznie przełącza monitor.
- Nie umieszczaj prawdziwego tokena w dokumentacji ani w repozytorium.