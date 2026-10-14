# Automatyczne przełączanie lewego monitora: Mac mini ↔ MacBook

Lewy monitor przechodzi na Miniego lub MacBooka na zasadzie **„ostatnio aktywny wygrywa”**: kto się obudził lub odblokował, ten trzyma lewy monitor. Przełączanie robi Spoon [DisplayKVM](https://github.com/jabbas/DisplayKVM), dołączony do tego repozytorium jako submoduł `Spoons/DisplayKVM.spoon`.

---

## 1. Sprzęt

Stan zweryfikowany ręcznie — nie zmieniaj okablowania.

| Monitor | Model | Mac mini | MacBook |
|---|---|---|---|
| **Lewy** | Dell P2715Q (rev. A03) | USB-C → **DisplayPort** (wejście DP, kod DDC **15**) | USB-C → DP → **mini DisplayPort** (kod DDC **16**) |
| **Prawy** | Dell P2715Q | **HDMI** (kod DDC 17), 60 Hz | — |

- Mac mini: M1, host `mini` (adres `mini.local`).
- MacBook: Pro 13" M2 (służbowy), host `<host MacBooka>`, użytkownik `<użytkownik MacBooka>`.
- W obu monitorach **MST = Off** (z MST On DisplayPort działa tylko w 30 Hz, macOS nie obsługuje MST).
- W lewym monitorze **włączone HDMI 2.0** (ukryta opcja „Disable HDMI 1.4 support”). Reset fabryczny monitora ją cofa.
- DDC/CI włączone w obu monitorach.
- W OSD lewego monitora wyłączone automatyczne wybieranie wejścia — inaczej monitor sam wraca na poprzednie wejście.

### Ustalone zachowanie (z testów)

- **DDC działa tylko przez DisplayPort.** Przez wbudowane HDMI M1 Mini polecenia DDC są ignorowane albo kończą się błędem `device offline`.
- **P2715Q zrywa łącze DP na nieaktywnym wejściu.** Gdy lewy pokazuje mini DP (MacBook), Mac mini **nie widzi** lewego monitora, i odwrotnie (potwierdzone testem 2026-10-14: oba kierunki `HIDDEN`). Dlatego w konfiguracji nie ma opcji `pull` (zostaje domyślna): przejęcie z nieaktywnego wejścia i tak nie zajdzie, więc DisplayKVM prosi bieżącego właściciela, żeby oddał monitor.
- Po udanym przełączeniu `m1ddc` często zwraca `DDC communication failure: (iokit/common) no such device`. **To jest oczekiwane**: monitor znika w trakcie polecenia, ale przełączenie się udaje.
- Numery wyświetlaczy (`display 1`, `display 2`) **zmieniają się**. Zawsze używaj **UUID**.

### UUID

| Komputer | Lewy monitor (DP / mini DP) | Prawy monitor |
|---|---|---|
| Mac mini | `1B5F0426-EFF5-4986-ABCE-67B1F3E2FF67` | `B6AEAC4A-F7B9-48AA-A437-B9E44A47848D` (HDMI) |
| MacBook | `F10F3853-1195-47E4-B1B9-EDA17BE38872` | — |

UUID mogą się zmienić po przepięciu kabla do innego portu lub zmianie ustawień MST. Weryfikacja (lewy musi pokazywać dany komputer):

```bash
m1ddc display list     # na MacBooku wpis (null) to wbudowany ekran; lewy to DELL P2715Q
hs -c 'for _, s in ipairs(hs.screen.allScreens()) do print(s:name(), s:getUUID()) end'
```

Jeśli UUID się różnią, popraw je w bloku `displays` w `init.lua`.

### Mac mini — bez pełnego usypiania systemu

Mini **nigdy nie powinien przechodzić w usypianie systemu** (tylko usypianie ekranu), inaczej nie odpowie MacBookowi. Sprawdź: `pmset -g` → `sleep 0`, `displaysleep 5`. Jeśli trzeba: `sudo pmset -a sleep 0` lub Ustawienia → Energia → „Zapobiegaj automatycznemu usypianiu, gdy ekran jest wyłączony”.

---

## 2. Jak to działa teraz

DisplayKVM nie ma serwera ani lidera: oba Maki to **równorzędne węzły** (`mini`, `macbook`). Znajdują się przez Bonjour w sieci lokalnej, rozmawiają bezpośrednio i podpisują każdą wiadomość wspólnym sekretem (uwierzytelnienie, bez szyfrowania — tylko zaufana sieć). Każdy węzeł replikuje niewielki stan: kto jest właścicielem lewego monitora i który Mac jest aktywny.

- Mac, który się **odblokował, wybudził lub wystartował** (przy realnej aktywności użytkownika, nie przy samym hot-plugu monitora), przełącza lewy monitor na swoje wejście. Gdy sam go nie widzi, prosi bieżącego właściciela o oddanie.
- Mac, który się **zablokował, uśpił lub zamknął klapę**, oddaje lewy monitor ostatnio aktywnemu drugiemu Makowi, a gdy nikt inny nie jest aktywny — do `home` (Mini). Jeśli sam jest `home`, zachowuje monitor.
- Oddanie do `home` nie wymaga, żeby Mini był wybudzony; następne przejęcie naprawia stan.
- Semantyka blokady: wybudzenie MacBooka do ekranu blokady nic nie robi — dopiero odblokowanie przejmuje lewy. Praca na MacBooku z zamkniętą klapą na lewym monitorze (clamshell) **nie jest wspierana**.
- Progi aktywności: `userIdle = 5` s (wybudzenie liczy się tylko przy realnym wejściu HID — to chroni przed ping-pongiem wywołanym przełączeniem wejścia), `startIdle = 30` s (przeładowanie Hammerspoona nie jest startem, chyba że ktoś używał maszyny w ciągu ostatnich 30 s).
- Skrót `ctrl+alt+cmd+M` przejmuje lewy monitor na bieżącym Macu.

Szczegóły działania, protokół i przypadki brzegowe: [README DisplayKVM](https://github.com/jabbas/DisplayKVM#readme) oraz [docs/design.md](https://github.com/jabbas/DisplayKVM/blob/main/docs/design.md).

---

## 3. Konfiguracja

### Repozytorium

| Plik | Zawartość |
|---|---|
| `init.lua` | wczytuje `localconfig.lua`, ładuje Spoon, konfiguruje blok `displays`, `start()`, skrót |
| `localconfig.lua` | poza gitem, `chmod 600`: `node` (`"mini"` albo `"macbook"`) i `secret` |
| `Spoons/DisplayKVM.spoon` | submoduł przypięty do tagu; po `pull` wymaga `git submodule update --init` |

Blok `displays` w `init.lua` jest identyczny na obu Macach; różni się tylko `node` z `localconfig.lua`. Zawiera dla lewego monitora: `match` (UUID widziany z każdego węzła), `inputs` (`mini = 15`, `macbook = 16`) i `home = "mini"`. Backend: `m1ddc` (`/opt/homebrew/bin/m1ddc`). Port domyślny `8765`.

Sekret (64 znaki hex, ten sam na obu Macach):

```bash
openssl rand -hex 32
```

Wpisz go do `localconfig.lua` obu maszyn. Nie umieszczaj go w repozytorium ani w dokumentacji.

Instalacja i aktualizacja: [README](../README.md).

### Uprawnienia macOS (akcja użytkownika)

- Ustawienia systemowe → Prywatność i ochrona → **Dostępność** → włącz Hammerspoon.
- Ustawienia systemowe → Prywatność i ochrona → **Sieć lokalna** → włącz Hammerspoon (Bonjour i rozmowa z drugim Makiem).
- Zapora macOS: jeśli zapyta o połączenia przychodzące dla Hammerspoona → **Zezwól**. Dotyczy zwłaszcza MacBooka, który wcześniej niczego nie nasłuchiwał.
- Preferencje Hammerspoona → **Launch Hammerspoon at login**.

`require("hs.ipc")` jest pierwszą linią `init.lua`, więc `hs -c` działa nawet przy błędnej konfiguracji. Zapis plików konfiguracji **nie** przeładowuje Hammerspoona — zawsze przeładowuj ręcznie (`/opt/homebrew/bin/hs -c "hs.reload()"`; przez SSH `PATH` nie zawiera `/opt/homebrew/bin`).

---

## 4. Testy akceptacyjne

Obserwacja między krokami, na obu Macach: `hs -c 'return hs.inspect(spoon.DisplayKVM:status())'` oraz `hs -c 'return hs.console.getConsole()' | grep DisplayKVM | tail -5`.

| # | Scenariusz | Oczekiwane |
|---|---|---|
| A1 | Odblokowanie MacBooka | lewy na MacBooku w ciągu ~3 s; `owner = macbook` na obu |
| A2 | Blokada MacBooka (Ctrl+Cmd+Q) | lewy na Mini; `owner = mini` |
| A3 | MacBook odblokowany (lewy na MacBooku); `pmset displaysleepnow` na Mini, potem ruch myszą przy Mini | lewy na Mini w ciągu ~3 s (prośba `request` do MacBooka) |
| A4 | Reload Config przy pracy na MacBooku, potem Reload Config przy pracy na Mini | lewy na MacBooku, potem na Mini |
| A5 | Zamknięcie klapy MacBooka (lewy na MacBooku); potem otwarcie klapy i odblokowanie | lewy na Mini; po odblokowaniu na MacBooku |
| A6 | Uśpienie MacBooka (menu Apple → Uśpij) przy lewym na MacBooku; po wybudzeniu i odblokowaniu | lewy na Mini; po odblokowaniu na MacBooku |
| A7 | Skrót `ctrl+alt+cmd+M` na Macu, który nie ma lewego | lewy przechodzi na ten Mac |
| A8 | Wi-Fi wyłączone na MacBooku, odblokowanie; potem włączenie Wi-Fi i ponowne odblokowanie | powiadomienie „cannot claim left” (lub przejęcie przez pull, jeśli monitor widoczny); po włączeniu Wi-Fi lewy na MacBooku |
| A9 | Logi obu maszyn po testach | brak `error`, `401`, `duplicate-node`; `status()` spójny |

A1–A6 są blokujące; A7–A8 można naprawiać osobno.

---

## 5. Rozwiązywanie problemów

| Objaw | Przyczyna / rozwiązanie |
|---|---|
| Stan węzła | `hs -c 'return hs.inspect(spoon.DisplayKVM:status())'` → `peers[...].alive`, `displays.left.owner`, `visible`, `input`. |
| Logi | Logger `DisplayKVM` (start konfiguracji: logger `config`): `hs -c 'return hs.console.getConsole()' \| grep -E "config:\|DisplayKVM"`. Więcej szczegółów: `logLevel = "debug"` w `configure`. |
| Drugi Mac nie jest widoczny w `status()` | Sprawdź Bonjour: `dns-sd -B _displaykvm._tcp local.` (na drugim Macu powinien być widoczny ten węzeł). |
| Brak węzłów, Bonjour milczy | Uprawnienie **Sieć lokalna** dla Hammerspoona na obu Macach; zapora na MacBooku (połączenia przychodzące dla Hammerspoona → Zezwól). |
| `401` lub „clock skew” w logach | Różne sekrety w `localconfig.lua` albo rozjechane zegary (włącz czas sieciowy). |
| Powiadomienie „duplicate-node” | Oba Maki mają ten sam `node` w `localconfig.lua`. |
| Powiadomienie „cannot listen on port” | Port zajęty przez inny program lub starą instancję Hammerspoona. |
| Monitor sam wraca na poprzednie wejście | Wyłącz automatyczne wybieranie wejścia w OSD monitora. |
| Brak katalogu Spoona / komunikat „brak Spoons/DisplayKVM.spoon” | `git -C ~/.hammerspoon submodule update --init`, potem przeładuj. |
| `The specified display does not exist` | Monitor pokazuje inne wejście (łącze DP zerwane) albo zmienił się UUID → `m1ddc display list`. |
| `device offline` / `no such device` po przełączeniu | Normalne, przełączenie się udało. |
| Lewy na 30 Hz na MacBooku | macOS wybrał 30 Hz w trybie „looks like 3008x1692” → Ustawienia → Monitory → 60 Hz. Inne możliwe przyczyny: reset fabryczny monitora cofnął HDMI 2.0, albo włączone MST. |
| `hs.screen:availableModes()` zwraca pustą listę | Znany problem tej wersji Hammerspoona/macOS — nie polegaj na tej funkcji. |
| `hs -c` zwraca „can't access Hammerspoon message port” | `hs.ipc` nie załadowane lub Hammerspoon nie działa. |
| Mini nie odpowiada | Mini w pełnym usypianiu systemu (nie powinien — sprawdź `pmset -g`) albo Hammerspoon nie działa. |

---

## 6. Czego nie robić

- Nie zmieniaj okablowania ani ustawień OSD monitorów (MST, HDMI 2.0, DDC/CI) bez zgody użytkownika.
- Nie używaj numerów wyświetlaczy zamiast UUID.
- Nie używaj `git clean -x` ani `-X` — usuwa `localconfig.lua` i lokalne archiwa.
- Nie wypisuj sekretu (`cat localconfig.lua`, `echo` zmiennej) i nie umieszczaj go w dokumentacji ani w repozytorium.
- Nie wypisuj całego obiektu Spoona (`hs.inspect(spoon.DisplayKVM)`) — zawiera sekret; używaj tylko `status()`.
