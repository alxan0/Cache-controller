# Cache Controller HDL

Controller de cache set-asociativ pe 4 cai implementat in Verilog, cu politica LRU si write-back cu write-allocate.

## Parametri

| Parametru | Valoare |
|---|---|
| Dimensiune totala | 32 KB |
| Dimensiune bloc | 64 octeti |
| Seturi | 128 |
| Asociativitate | 4-way |
| Politica de inlocuire | LRU |
| Politica de scriere | Write-back, write-allocate |

## Rulare

```bash
bash run.sh
```

```bash
bash run.sh --view   # deschide GTKWave dupa simulare
```

Dependinte: `iverilog`, `vvp`, `gtkwave`.

## Stari FSM

| Cod | Stare | Descriere |
|---|---|---|
| 0 | IDLE | Asteptare cerere |
| 1 | READ_HIT | Citire cu date in cache |
| 2 | READ_MISS | Citire fara date in cache |
| 3 | WRITE_HIT | Scriere cu bloc prezent |
| 4 | WRITE_MISS | Scriere fara bloc in cache |
| 5 | EVICT_RD | Evacuare bloc murdar (lant citire) |
| 6 | EVICT_WR | Evacuare bloc murdar (lant scriere) |
| 7 | ALLOC_RD | Alocare bloc din memorie (citire) |
| 8 | ALLOC_WR | Alocare bloc din memorie (scriere) |
