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
| 000 | IDLE | Asteptare cerere |
| 001 | READ_HIT | Citire cu date in cache |
| 010 | READ_MISS | Citire fara date in cache |
| 011 | WRITE_HIT | Scriere cu bloc prezent |
| 100 | WRITE_MISS | Scriere fara bloc in cache |
| 101 | EVICT | Evacuare bloc murdar |
| 110 | ALLOCATE | Incarcare bloc din memorie |
