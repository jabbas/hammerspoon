# Automatyczne przełączanie lewego monitora: Mac mini ↔ MacBook

Lewy monitor przechodzi na Miniego lub MacBooka na zasadzie **„ostatnio aktywny wygrywa”**: kto się obudził lub odblokował, ten trzyma lewy monitor. Przełączanie robi Spoon [DisplayKVM](https://github.com/jabbas/DisplayKVM), dołączony do tego repozytorium jako submoduł `Spoons/DisplayKVM.spoon`.

---

## 1. Sprzęt

Stan zweryfikowany ręcznie (2026-10-20) — nie zmieniaj okablowania.

| Monitor | Model | Mac mini | MacBook |
|---|---|---|---|
| **Lewy** (współdzielony) | HP 727pk (27" 4K) | **HDMI** (kod DDC **17**) | **USB-C / Thunderbolt** (kod DDC **21**) |
| **Prawy** (tylko Mini) | HP 727pk (27" 4K) | USB-C / Thunderbolt przez hub z urządzeniami Miniego — **nie wolno przepinać** | — |

- Mac mini: M1, host `<host Mini>`. M1 obsługuje drugi monitor **wyłącznie przez HDMI**, więc lewy musi zostać na HDMI.
- MacBook: Pro 13" M2 (służbowy), host `<host MacBooka>`, użytkownik `<użytkownik MacBooka>`.
- Kody wejść (VCP 0x60) zostały **zmierzone** — HP ich nie dokumentuje: HDMI = 17, USB-C = 21.
- Poprzedni sprzęt (Dell P2715Q, DisplayPort/mini DP) wycofany 2026-10-20; jego UUID i kody wejść nie obowiązują.

### Ustawienia monitorów (OSD) i systemu

- **Auto-Switch Input lewego monitora: wyłączony**, razem z podopcjami „USB-C Video Auto-Switch” i „Do not auto-switch away from USB-C until cable is disconnected”. Lewy przełącza się wyłącznie przez DDC z MacBooka. Powód: przy włączonym Auto-Switch monitor po wygaszeniu ekranów Miniego (zanik sygnału HDMI) sam uciekał na USB-C, do MacBooka, bez wiedzy DisplayKVM — a gdy MacBook potem zasnął, lewy zostawał u niego i Mini nie miał jak go odzyskać. Przy włączonym Auto-Switch, ale wyłączonych podopcjach, monitor z kolei wracał na HDMI przy odblokowaniu MacBooka (polecenie DDC docierało, zanim MacBook zaczął nadawać obraz), a `m1ddc` i tak zgłaszał sukces.
- Koszt: po wypięciu kabla USB-C monitor **nie** przechodzi sam na Miniego (zob. „Znane ograniczenia” w §2). **Zanim wypniesz kabel, zablokuj MacBooka albo zamknij klapę** — wtedy lewy wraca do Miniego normalną drogą.
- **USB host lewego monitora: na stałe „USB-C1 (Thunderbolt 4)”** (MacBook), czyli Auto-Switch USB Host wyłączony. Powód: przewodowa sieć MacBooka to karta Ethernet wbudowana w lewy monitor (w macOS „HP LAN”), podłączona tym samym kablem USB-C. Przy fabrycznym ustawieniu KVM hub USB monitora (razem z Ethernetem) przechodził wraz z wejściem do Miniego, więc MacBook przy każdym oddaniu monitora tracił sieć, a DisplayKVM — kontakt z nim (Mini poprawiał stan dopiero po ok. 2 min). Mini nie korzysta z niczego, co jest podłączone do lewego monitora.
- **Wi-Fi na MacBooku włączone** w sieci domowej jako zapas: po wypięciu kabla USB-C Ethernet monitora znika razem z nim, a MacBook dalej może powiadomić Miniego.
- **Power Mode: Performance** (zalecenie HP dla komputerów bez baterii). Ustawienia zasilania monitora nie zrywają łącza HDMI do Miniego.
- Profil kolorów musi pasować do trybu monitora: **sRGB w monitorze i w macOS** na obu Macach; **HDR wyłączony** na obu Macach (inaczej obraz ma pomarańczowy odcień).
- DDC/CI włączone w monitorach.

### Ustalone zachowanie (z testów 2026-10-20)

- **HDMI w Mac mini M1 nie ma działającego DDC.** `m1ddc ... set` zwraca `rc=0`, ale monitor nie reaguje; odczyty zawsze `110`. Porażki nie da się wykryć po stronie Miniego. Dlatego lewym steruje **wyłącznie MacBook** (`control = { "macbook" }`): przełącza go przez USB-C w obie strony (`set input 17` → Mini, `set input 21` → MacBook), także na prośbę (`request`) Miniego.
- **Oba Maki zawsze widzą lewy monitor**, niezależnie od wybranego wejścia (`hs.screen.allScreens()`, `m1ddc display list`). DisplayKVM nie może więc sprawdzić po przełączeniu, czy zadziałało (monitor „sticky").
- Odczyty DDC z MacBooka (`get input`) są nieaktualne po przełączeniu (zostaje `21`), w czuwaniu monitora `-7`. Nie polegaj na nich; DisplayKVM ich nie używa.
- **Lustro (`whenAway`)**: gdy lewy pokazuje MacBooka, Mini „ukrywa" go przez lustro prawego na lewy (`mirrorOf`): kursor nie wjeżdża na lewy, okna zostają na prawym, lewy pokazuje MacBooka bez mrugania. Po odzyskaniu monitora (`mirrorStop`) układ i okna wracają. Włączenie i wyłączenie lustra chwilowo przeładowuje układ ekranów (migotanie).
- Numery wyświetlaczy (`display 1`, `display 2`) **zmieniają się**. Zawsze używaj **UUID**.

### UUID

| Komputer | Lewy monitor | Prawy monitor |
|---|---|---|
| Mac mini | `E321F73C-9A55-44D8-A1E1-FEED1B9C4EE0` (HDMI) | `F638DE24-9CA5-4873-9A0D-6A1B7B19A360` (nie jest w konfiguracji) |
| MacBook | `EE2BE0B3-F2B2-4ECF-94B2-723446299A1C` (USB-C) | — |

UUID mogą się zmienić po przepięciu kabla do innego portu. Weryfikacja:

```bash
m1ddc display list     # na MacBooku wpis (null) to wbudowany ekran
hs -c 'for _, s in ipairs(hs.screen.allScreens()) do print(s:name(), s:getUUID()) end'
```

Jeśli UUID się różnią, popraw je w bloku `displays` w `init.lua`.

### Mac mini — bez pełnego usypiania systemu

Mini **nigdy nie powinien przechodzić w usypianie systemu** (tylko usypianie ekranu), inaczej nie odpowie MacBookowi. Sprawdź: `pmset -g` → `sleep 0`, `displaysleep 5`. Jeśli trzeba: `sudo pmset -a sleep 0` lub Ustawienia → Energia → „Zapobiegaj automatycznemu usypianiu, gdy ekran jest wyłączony".

---

## 2. Jak to działa teraz

DisplayKVM nie ma serwera ani lidera: oba Maki to **równorzędne węzły** (`mini`, `macbook`). Znajdują się przez Bonjour w sieci lokalnej, rozmawiają bezpośrednio i podpisują każdą wiadomość wspólnym sekretem (uwierzytelnienie, bez szyfrowania — tylko zaufana sieć). Każdy węzeł replikuje niewielki stan: kto jest właścicielem lewego monitora i który Mac jest aktywny.

- Mac, który się **odblokował, wybudził lub wystartował** (przy realnej aktywności użytkownika, nie przy samym hot-plugu monitora), przełącza lewy monitor na swoje wejście. **MacBook** (węzeł z `control`) robi to sam przez DDC. **Mini** nie ma DDC, więc **prosi MacBooka** (`request`), żeby przełączył lewy na HDMI.
- Mac, który się **zablokował, uśpił lub zamknął klapę**, oddaje lewy monitor ostatnio aktywnemu drugiemu Makowi, a gdy nikt inny nie jest aktywny — do `home` (Mini). Samo przełączenie zawsze wykonuje MacBook.
- **Lustro**: gdy właścicielem lewego jest MacBook, Mini włącza lustro (`whenAway = { mini = "mirror" }`); gdy Mini odzyskuje monitor — wyłącza je. Dotyczy też startu, przeładowania i `stop()`.
- **Odzyskiwanie bez DDC**: MacBook, który był właścicielem i przestał widzieć monitor (wypięty kabel USB-C), zapisuje `owner = mini` bez DDC i rozgłasza to przez Wi-Fi — Mini wyłącza lustro od razu. Mini (`home`), gdy żaden węzeł z `control` nie jest żywy, a właścicielem w stanie jest nieżywy węzeł, przejmuje własność w stanie i wyłącza lustro. Jeśli MacBook po wypięciu kabla nie ma sieci (Wi-Fi wyłączone), nie powiadomi Miniego: Mini trzyma lustro jeszcze ok. 1–2 min, do tej drugiej naprawy. W obu przypadkach naprawiany jest tylko stan — obraz Miniego na lewym trzeba wtedy włączyć przyciskiem monitora (Auto-Switch Input jest wyłączony, §1).
- **Start Miniego**: po starcie lub przeładowaniu Mini nie uznaje lewego za swój, dopóki nie usłyszy MacBooka (ponowienia przez ok. 22 s). Dopiero gdy MacBooka nie ma, zakłada, że lewy pokazuje Miniego (wpis info `no controller reachable … assuming it shows this node`).
- Oddanie do `home` nie wymaga, żeby Mini był wybudzony; następne przejęcie naprawia stan.
- Semantyka blokady: wybudzenie MacBooka do ekranu blokady nic nie robi — dopiero odblokowanie przejmuje lewy. Domyślnie zamknięcie klapy oddaje monitor (`activity.lid = true`); praca w trybie clamshell wymagałaby `activity = { lid = false }` w `init.lua`.
- Progi aktywności (domyślne wartości DisplayKVM, nieustawiane w `init.lua`): `userIdle = 5` s (wybudzenie liczy się tylko przy realnym wejściu HID — to chroni przed ping-pongiem wywołanym przełączeniem wejścia), `startIdle = 30` s (przeładowanie Hammerspoona nie jest startem, chyba że ktoś używał maszyny w ciągu ostatnich 30 s).
- Skrót `ctrl+alt+cmd+M` przejmuje lewy monitor na bieżącym Macu.

### Znane ograniczenia

- **Monitor „sticky"**: oba Maki zawsze widzą lewy, więc po przełączeniu nie da się sprawdzić, czy zadziałało; DisplayKVM nie ponawia ani nie alarmuje z tego powodu.
- **MacBook poza siecią dłużej niż ok. 90 s, gdy trzymał lewy**: Mini przejmuje lewy w stanie (naprawa „wszyscy sterujący zniknęli"), choć monitor dalej pokazuje MacBooka. Następna blokada MacBooka nic wtedy nie zrobi — **naciśnij skrót `ctrl+alt+cmd+M` na MacBooku** (albo zablokuj i odblokuj), żeby zsynchronizować stan.
- **Wypięcie kabla USB-C bez wcześniejszej blokady** (lewy u MacBooka): monitor zostaje na wejściu USB-C bez sygnału („Input Signal Not Found”, potem czuwanie). DisplayKVM poprawia stan (`owner = mini`, lustro wyłączone), ale obraz Miniego trzeba włączyć **przyciskiem monitora** (wejście HDMI). Przy kolejności blokada/klapa → wypięcie nic takiego się nie dzieje.
- **Ponowne wpięcie kabla USB-C nie przejmuje lewego z powrotem** — po wypięciu stan wskazuje Miniego; MacBook przejmie lewy dopiero przy następnym odblokowaniu/skrócie.
- **MacBook zawieszony lub rozładowany z wpiętym kablem**: monitor zasypia razem z nim (sam nie zmienia wejścia). Po minucie lub dwóch Mini poprawi stan i wyłączy lustro, ale obraz wróci dopiero po przełączeniu wejścia przyciskami monitora.
- Lustro to systemowe dublowanie ekranów: chwilowo przeładowuje układ (migotanie, przesuwanie okien). Odzyskiwanie lustra po awarii/przeładowaniu bez `stop()` jest heurystyką.
- **MacBook poza domem** (bez monitora i bez Miniego): każde odblokowanie kończy się po ok. 22 s błędem `cannot claim left` i powiadomieniem. Nieszkodliwe; do poprawienia w Spoonie.
- Udane przełączenie nie zostawia wpisu w logu — potwierdzaj je wzrokowo albo przez `status()`.
- Wersje 0.1.x nie znają `control` — **oba Maki muszą mieć tę samą wersję** Spoona (obecnie 0.2.1; 0.2.0 miał błąd: Mini po przeładowaniu przy aktywnym MacBooku błędnie uznawał lewy za swój).

Szczegóły działania, protokół i przypadki brzegowe: [README DisplayKVM](https://github.com/jabbas/DisplayKVM#readme) oraz [docs/design.md](https://github.com/jabbas/DisplayKVM/blob/main/docs/design.md).

---

## 3. Konfiguracja

### Repozytorium

| Plik | Zawartość |
|---|---|
| `init.lua` | wczytuje `localconfig.lua`, ładuje Spoon, konfiguruje blok `displays`, `start()`, skrót |
| `localconfig.lua` | poza gitem, `chmod 600`: `node` (`"mini"` albo `"macbook"`) i `secret` |
| `Spoons/DisplayKVM.spoon` | submoduł przypięty do tagu; po `pull` wymaga `git submodule update --init` |

Blok `displays` w `init.lua` jest identyczny na obu Macach; różni się tylko `node` z `localconfig.lua`. Zawiera dla lewego monitora: `match` (UUID widziany z każdego węzła), `inputs` (`mini = 17`, `macbook = 21`), `home = "mini"`, `control = { "macbook" }` (tylko MacBook przełącza przez DDC) i `whenAway = { mini = "mirror" }` (lustro na Mini, gdy lewy należy do MacBooka). Backend: `m1ddc` (`/opt/homebrew/bin/m1ddc`). Port domyślny `8765`.

Sekret (64 znaki hex, ten sam na obu Macach):

```bash
openssl rand -hex 32
```

Wpisz go do `localconfig.lua` obu maszyn. Nie umieszczaj go w repozytorium ani w dokumentacji.

Instalacja i aktualizacja: [README](../README.md).

### Uprawnienia macOS (akcja użytkownika)

- Ustawienia systemowe → Prywatność i ochrona → **Dostępność** → włącz Hammerspoon.
- Ustawienia systemowe → Prywatność i ochrona → **Sieć lokalna** → włącz Hammerspoon (Bonjour i rozmowa z drugim Makiem).
- Ustawienia systemowe → **Powiadomienia** → Hammerspoon → **Zezwalaj** (błędy `init.lua` i ostrzeżenia DisplayKVM to powiadomienia macOS).
- Zapora macOS: jeśli zapyta o połączenia przychodzące dla Hammerspoona → **Zezwól**. Dotyczy zwłaszcza MacBooka, który wcześniej niczego nie nasłuchiwał.
- Preferencje Hammerspoona → **Launch Hammerspoon at login**.

`require("hs.ipc")` jest pierwszą linią `init.lua`, więc `hs -c` działa nawet przy błędnej konfiguracji. Zapis plików konfiguracji **nie** przeładowuje Hammerspoona — zawsze przeładowuj ręcznie (`/opt/homebrew/bin/hs -c "hs.reload()"`; przez SSH `PATH` nie zawiera `/opt/homebrew/bin`).

---

## 4. Testy akceptacyjne

Obserwacja między krokami, na obu Macach: `hs -c 'return hs.inspect(spoon.DisplayKVM:status())'` (pola `displays.left.owner`, `mirrored`) oraz `hs -c 'return hs.console.getConsole()' | grep DisplayKVM | tail -5`.

| # | Scenariusz | Oczekiwane |
|---|---|---|
| A1 | Odblokowanie MacBooka | lewy → MacBook; `owner = macbook` na obu; na Mini lustro (kursor nie wjeżdża na lewy, okna na prawym) |
| A2 | Blokada MacBooka (Ctrl+Cmd+Q) | lewy → Mini; `owner = mini`; lustro wyłączone, okna wracają na lewy |
| A3 | MacBook aktywny; ruch myszą przy Mini (po uśpieniu ekranu Mini: `pmset displaysleepnow`) | lewy → Mini (przełącza MacBook na prośbę Miniego) |
| A4 | Reload Config przy pracy na każdej maszynie | lewy → ta maszyna; stan lustra zgodny |
| A5 | Zamknięcie klapy MacBooka / otwarcie i odblokowanie | Mini / MacBook |
| A6 | Uśpienie MacBooka (menu Apple) i samo uśpienie ekranu (`pmset displaysleepnow`) przy lewym u MacBooka | lewy → Mini **zanim** monitor zaśnie (ryzyko R4: jeśli zaśnie przed oddaniem — zapisz i zgłoś) |
| A7 | Skrót `ctrl+alt+cmd+M` na Macu bez lewego | lewy → ten Mac |
| A8 | Sieć wyłączona na MacBooku (Wi-Fi i Ethernet monitora), odblokowanie; potem włączenie sieci | MacBook **przejmuje lewy sam** (przez USB-C, bez sieci); po włączeniu sieci Mini włącza lustro |
| A9 | Wypięcie kabla USB-C z MacBooka, gdy lewy jest u MacBooka (bez wcześniejszej blokady) | `owner = mini`, lustro wyłączone (z Wi-Fi od razu; bez sieci po ok. 1–2 min); monitor zostaje na USB-C bez sygnału — HDMI włącza się przyciskiem monitora |
| A10 | MacBook poza siecią > 90 s, lewy u MacBooka w stanie | Mini przejmuje w stanie, lustro wyłączone (potem skrót na MacBooku — zob. §2) |
| A11 | Logi i `status()` na obu po testach | brak `ERROR`, `401`, `duplicate-node`; stan spójny |

A1–A5 są blokujące; A6–A11 można naprawiać osobno.

Wynik (październik 2026, DisplayKVM 0.2.1): A1–A11 zaliczone. Oddanie przy uśpieniu MacBooka następuje, zanim monitor zaśnie (ryzyko R4 nie wystąpiło). Po wyłączeniu Auto-Switch Input (§1) powtórzono blokadę/odblokowanie, wybudzenie Miniego przy aktywnym MacBooku oraz wygaszenie ekranów Miniego i uśpienie MacBooka — lewy zostaje tam, gdzie powinien, a Mini po wybudzeniu go odzyskuje.

---

## 5. Rozwiązywanie problemów

| Objaw | Przyczyna / rozwiązanie |
|---|---|
| Stan węzła | `hs -c 'return hs.inspect(spoon.DisplayKVM:status())'` → `peers[...].alive`, `displays.left.owner`, `visible`, `input`. |
| Logi | Logger `DisplayKVM` (start konfiguracji: logger `config`): wynik `hs -c 'return hs.console.getConsole()'` przefiltruj przez `grep -e config: -e DisplayKVM`. Więcej szczegółów: `logLevel = "debug"` w `configure`. |
| Drugi Mac nie jest widoczny w `status()` | Sprawdź Bonjour: `dns-sd -B _displaykvm._tcp local.` (na drugim Macu powinien być widoczny ten węzeł). |
| Brak węzłów, Bonjour milczy | Uprawnienie **Sieć lokalna** dla Hammerspoona na obu Macach; zapora na MacBooku (połączenia przychodzące dla Hammerspoona → Zezwól). |
| `401` lub „clock skew” w logach | Różne sekrety w `localconfig.lua` albo rozjechane zegary (włącz czas sieciowy). Seria `401 from macbook` co 30 s na Mini, gdy MacBook śpi, to znany, jeszcze niewyjaśniony objaw (podejrzenie: krótkie wybudzenia MacBooka w tle z nieaktualnym zegarem); jeśli ustaje po wybudzeniu MacBooka, sekrety są w porządku. |
| MacBook traci sieć, gdy lewy przechodzi na Mini | USB host lewego monitora nie jest przypięty do MacBooka — ustaw w OSD na stałe „USB-C1 (Thunderbolt 4)” (zob. §1). |
| Brak powiadomień/ostrzeżeń, tylko wpisy w konsoli | Włącz Powiadomienia dla Hammerspoona (Ustawienia systemowe → Powiadomienia → Hammerspoon → Zezwalaj). |
| Powiadomienie „duplicate-node” | Oba Maki mają ten sam `node` w `localconfig.lua`. |
| Powiadomienie „cannot listen on port” | Port zajęty przez inny program lub starą instancję Hammerspoona. |
| Lewy sam zmienia wejście (np. ucieka na MacBooka, gdy Mini wygasza ekrany) albo wraca na Mini zaraz po odblokowaniu MacBooka | Włączony Auto-Switch Input w lewym monitorze — wyłącz go w OSD razem z podopcjami „USB-C Video Auto-Switch” i „Do not auto-switch away from USB-C…” (zob. §1). |
| Po wypięciu kabla USB-C lewy jest czarny („Input Signal Not Found”) | Oczekiwane przy wyłączonym Auto-Switch Input — wybierz HDMI przyciskiem monitora. Następnym razem najpierw zablokuj MacBooka lub zamknij klapę. |
| Lewy nie przełącza się na Mini mimo `owner = mini` | Mini nie ma DDC przez HDMI (`m1ddc` zgłasza sukces mimo braku efektu). Sprawdź, czy MacBook jest żywy w `peers` i czy ma kabel USB-C; w ostateczności przyciski monitora. |
| Lewy pokazuje MacBooka, a Mini nie dubluje | Sprawdź `displays.left.mirrored` na Mini i `owner`; po dłuższej nieobecności MacBooka w sieci naciśnij skrót na MacBooku (zob. §2). |
| Brak katalogu Spoona / komunikat „brak Spoons/DisplayKVM.spoon” | `git -C ~/.hammerspoon submodule update --init`, potem przeładuj. |
| `The specified display does not exist` | Zmienił się UUID lub kabel → `m1ddc display list`. |
| `device offline` / `no such device` po przełączeniu | Normalne, przełączenie się udało. |
| Lewy na 30 Hz | Ustawienia → Monitory → wybierz 60 Hz; sprawdź kabel/port. |
| `hs.screen:availableModes()` zwraca pustą listę | Znany problem tej wersji Hammerspoona/macOS — nie polegaj na tej funkcji. |
| `hs -c` zwraca „can't access Hammerspoon message port” | `hs.ipc` nie załadowane lub Hammerspoon nie działa. |
| Mini nie odpowiada | Mini w pełnym usypianiu systemu (nie powinien — sprawdź `pmset -g`) albo Hammerspoon nie działa. |

---

## 6. Czego nie robić

- Nie zmieniaj okablowania ani ustawień OSD monitorów (Auto-Switch Input, USB host, Power Mode, DDC/CI) bez zgody użytkownika.
- Nie dodawaj Miniego do `control` — jego HDMI nie ma DDC, a `m1ddc` i tak zgłasza sukces.
- Nie używaj numerów wyświetlaczy zamiast UUID.
- Nie używaj `git clean -x` ani `-X` — usuwa `localconfig.lua` i lokalne archiwa.
- Nie wypisuj sekretu (`cat localconfig.lua`, `echo` zmiennej) i nie umieszczaj go w dokumentacji ani w repozytorium.
- Nie wypisuj całego obiektu Spoona (`hs.inspect(spoon.DisplayKVM)`) — zawiera sekret; używaj tylko `status()`.
