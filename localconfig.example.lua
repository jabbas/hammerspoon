-- Skopiuj do localconfig.lua (plik jest poza gitem) i uzupełnij.
-- token: `openssl rand -hex 16`, ten sam na obu maszynach.
return {
  role     = "macbook",                    -- "mini" albo "macbook"
  token    = "__TOKEN__",
  mini_url = "http://__MINI_HOST__:8765",  -- tylko dla roli "macbook", np. http://mini.local:8765
}
