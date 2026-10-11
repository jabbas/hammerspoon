# hammerspoon

Konfiguracja [Hammerspoona](https://www.hammerspoon.org/) dla dwóch Maców: automatyczne przełączanie lewego monitora między Mac mini a MacBookiem („ostatnio wybudzony wygrywa”).

## Wymagania

- Hammerspoon (`brew install --cask hammerspoon`), uprawnienie Dostępności, „Launch Hammerspoon at login”
- m1ddc (`brew install m1ddc`)

## Instalacja

```bash
git clone git@github.com:jabbas/hammerspoon.git ~/.hammerspoon
cp ~/.hammerspoon/localconfig.example.lua ~/.hammerspoon/localconfig.lua
chmod 600 ~/.hammerspoon/localconfig.lua
# uzupełnij role / token / mini_url
hs -c "hs.reload()"   # albo Reload Config z menu Hammerspoona
```

Brak lub błąd w `localconfig.lua` → komunikat w konsoli Hammerspoona i powiadomienie macOS; przełączanie jest wtedy wyłączone.

Nie używaj `git clean -x` ani `git clean -X` — usuwają ignorowany `localconfig.lua` (oraz lokalne archiwa, jeśli istnieją).

## Struktura

| Ścieżka | Opis |
|---|---|
| `init.lua` | punkt wejścia: wczytuje `localconfig.lua`, uruchamia rolę |
| `lib/monitor.lua` | część wspólna |
| `roles/mini.lua` | Mac mini: arbiter, serwer HTTP |
| `roles/macbook.lua` | MacBook: zdarzenia, odpytywanie, klapa |
| `docs/monitor-switching.md` | pełna dokumentacja |

Zapis `init.lua` nie przeładowuje konfiguracji automatycznie — przeładuj ręcznie.

Katalogi `macbook/` i `macmini/` (jeśli istnieją) to lokalne archiwa i są wykluczone z gita.
