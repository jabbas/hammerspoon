# hammerspoon

Konfiguracja [Hammerspoona](https://www.hammerspoon.org/) dla dwóch Maców: automatyczne przełączanie lewego monitora między Mac mini a MacBookiem („ostatnio aktywny wygrywa”). Przełączanie robi Spoon [DisplayKVM](https://github.com/jabbas/DisplayKVM), dołączony jako submoduł git.

## Wymagania

- Hammerspoon (`brew install --cask hammerspoon`) z uprawnieniem Dostępności i „Launch Hammerspoon at login”.
- Uprawnienie **Sieć lokalna** dla Hammerspoona (Ustawienia systemowe → Prywatność i ochrona → Sieć lokalna). macOS pyta przy pierwszym starcie DisplayKVM.
- Uprawnienie **Powiadomienia** dla Hammerspoona (Ustawienia systemowe → Powiadomienia → Hammerspoon → Zezwalaj). Błędy `init.lua` i ostrzeżenia DisplayKVM to powiadomienia macOS; bez zgody pojawiają się tylko w konsoli.
- Jeśli działa zapora macOS i zapyta o połączenia przychodzące dla Hammerspoona — **Zezwól**. Bez tego drugi Mac nie połączy się z tym.
- m1ddc (`brew install m1ddc`).

## Instalacja

Istniejącą konfigurację najpierw odsuń (`mv ~/.hammerspoon ~/.hammerspoon.old`), klon wymaga nieistniejącego lub pustego katalogu.

```bash
git clone --recurse-submodules https://github.com/jabbas/hammerspoon.git ~/.hammerspoon
cp ~/.hammerspoon/localconfig.example.lua ~/.hammerspoon/localconfig.lua
chmod 600 ~/.hammerspoon/localconfig.lua
# uzupełnij node ("mini" albo "macbook") i secret (openssl rand -hex 32, ten sam na obu Macach)
```

Klon przez HTTPS służy tylko do wdrożenia (pull). Push robi się wyłącznie z klonu roboczego przez SSH.

Pierwsze uruchomienie: **Reload Config** z menu Hammerspoona (CLI `hs` może jeszcze nie istnieć na świeżym Macu). Kolejne przeładowania: `hs -c "hs.reload()"`.

Brak lub błąd w `localconfig.lua`, albo pusty katalog submodułu → komunikat w konsoli Hammerspoona i powiadomienie macOS; przełączanie jest wtedy wyłączone.

## Aktualizacja

```bash
git -C ~/.hammerspoon pull --ff-only && git -C ~/.hammerspoon submodule update --init && hs -c "hs.reload()"
```

### Aktualizacja Spoona (w klonie roboczym)

```bash
git -C Spoons/DisplayKVM.spoon fetch --tags
git -C Spoons/DisplayKVM.spoon checkout <tag>
```

Rób to w klonie roboczym, z którego pushujesz. Potem zatwierdź zmieniony gitlink i wypchnij:

```bash
git add Spoons/DisplayKVM.spoon && git commit -m "updates DisplayKVM to <tag>" && git push
```

Na końcu wdróż na każdym Macu komendami z sekcji „Aktualizacja”.

## Struktura

| Ścieżka | Opis |
|---|---|
| `init.lua` | punkt wejścia: wczytuje `localconfig.lua`, konfiguruje i uruchamia DisplayKVM |
| `localconfig.example.lua` | wzór `localconfig.lua` (`node`, `secret`) |
| `Spoons/DisplayKVM.spoon` | submoduł: Spoon DisplayKVM przypięty do tagu |
| `docs/monitor-switching.md` | sprzęt, konfiguracja, testy, rozwiązywanie problemów |

## Diagnostyka

```bash
hs -c 'return hs.inspect(spoon.DisplayKVM:status())'
hs -c 'return hs.console.getConsole()' | grep DisplayKVM
```

Używaj wyłącznie `status()` — nie wypisuj całego obiektu Spoona (zawiera sekret).

## Uwagi

- Zapis `init.lua` nie przeładowuje konfiguracji automatycznie — przeładuj ręcznie.
- Nie używaj `git clean -x` ani `git clean -X` — usuwają ignorowany `localconfig.lua` (oraz lokalne archiwa, jeśli istnieją).
- Katalogi `macbook/` i `macmini/` (jeśli istnieją) to lokalne archiwa i są wykluczone z gita.
