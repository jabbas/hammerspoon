-- Skopiuj do localconfig.lua (plik jest poza gitem, chmod 600) i uzupełnij.
-- secret: `openssl rand -hex 32` (64 znaki hex), ten sam na obu maszynach.
return {
  node   = "__NODE__",     -- "mini" albo "macbook" (klucze z bloku displays w init.lua)
  secret = "__SECRET__",
}
