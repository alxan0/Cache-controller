# Cache Controller HDL - Documentatie Tehnica

## 1. Descriere

Controller de cache implementat structural in Verilog. Suporta operatii de citire si scriere pe 32 de biti, 128 de seturi cu 4 cai, politica de inlocuire LRU si scriere inapoi cu alocare la scriere (write-back + write-allocate).

## 2. Specificatii

| Parametru | Valoare |
|---|---|
| Tip | Set-asociativ pe 4 cai |
| Dimensiune totala | 32 KB |
| Dimensiune bloc | 64 octeti |
| Dimensiune cuvant | 4 octeti (32 biti) |
| Numar de seturi | 128 |
| Politica de inlocuire | LRU cu contoare de varsta |
| Politica de scriere | Write-back cu write-allocate |

Adresa de 32 de biti este impartita in: tag [31:13] (19 biti), index [12:6] (7 biti), offset [5:0] (6 biti).

## 3. Limbaj HDL ales

Proiectul a fost implementat in Verilog. Verilog a fost ales datorita sintaxei compacte, suportului larg in simulatoare open-source (iverilog) si compatibilitatii cu proiectele anterioare din cadrul cursului.

## 4. Diagrama bloc functionala

Sistemul este format din doua blocuri principale conectate la nivelul top-level:

- **FSM** (`cache_fsm`) - primeste semnalele `hit` si `dirty` de la tabloul de cache si genereaza semnalele de control (`try_read`, `try_write`, `write_hit_en`, `read_alloc_en`, `write_alloc_en`, `mem_read`, `mem_write`, `ready`)
- **Cache array** (`cache_array`) - primeste adresa si datele de la CPU si semnalele de control de la FSM; returneaza datele citite, semnalul `hit` si semnalul `dirty` al victimei LRU

In interiorul `cache_array` se afla 128 de instante `cache_set`, fiecare cu 4 linii (`cache_line`) si un tracker LRU (`lru_unit`). Fiecare linie este construita din flip-flop-uri DFF individuale pentru tag, data, valid si dirty.

## 5. Masina de stare (FSM)

### 5.1 Diagrama starilor

```
                     op_read & hit  --> READ_HIT  --> IDLE
                     op_read & !hit --> READ_MISS -+
IDLE ----+                                         +--> dirty --> EVICT --> ALLOCATE --> IDLE
         |           op_write & hit --> WRITE_HIT --> IDLE      |
         +       op_write & !hit --> WRITE_MISS --+             +--> clean -> ALLOCATE --> IDLE
```

### 5.2 Tranzitii

| Stare curenta | Conditie | Stare urmatoare |
|---|---|---|
| IDLE | `op_read & hit` | READ_HIT |
| IDLE | `op_read & !hit` | READ_MISS |
| IDLE | `op_write & hit` | WRITE_HIT |
| IDLE | `op_write & !hit` | WRITE_MISS |
| IDLE | nicio cerere | IDLE |
| READ_MISS, WRITE_MISS | `dirty` | EVICT |
| READ_MISS, WRITE_MISS | `!dirty` | ALLOCATE |
| EVICT | - | ALLOCATE |
| READ_HIT, WRITE_HIT, ALLOCATE | - | IDLE |

### 5.3 Iesiri (Moore)

| Stare | `try_read` | `try_write` | `mem_write` | `mem_read` | `write_hit_en` | `read_alloc_en` | `write_alloc_en` | `ready` |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| IDLE | op_read | op_write | 0 | 0 | 0 | 0 | 0 | 0 |
| READ_HIT | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1 |
| READ_MISS | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| WRITE_HIT | 0 | 0 | 0 | 0 | 1 | 0 | 0 | 1 |
| WRITE_MISS | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| EVICT | 0 | 0 | 1 | 0 | 0 | 0 | 0 | 0 |
| ALLOCATE | 0 | 0 | 0 | 1 | 0 | !fwm | fwm | 1 |

`fwm` = `from_write_miss`: registru setat cand se intra in ALLOCATE din WRITE_MISS, pentru a distinge `read_alloc_en` de `write_alloc_en`.

## 6. Interfata externa

Modul: `cache_controller.v`

| Semnal | Dir | Latime | Descriere |
|---|---|---:|---|
| `clk` | in | 1 | Ceas, esantionat pe front crescator |
| `rst_b` | in | 1 | Reset asincron activ pe nivel scazut |
| `opcode` | in | 1 | 0 = citire, 1 = scriere |
| `data_in` | in | 32 | Date de scris sau aduse din memorie |
| `address` | in | 32 | Adresa |
| `data_out` | out | 32 | Date citite din cache |
| `fsm_state` | out | 3 | Starea curenta a FSM-ului |
| `hit` | out | 1 | Ridicat cand adresa se gaseste in cache |
| `ready` | out | 1 | Ridicat cand operatia este finalizata |

## 7. Module

### cache_line

O singura linie de cache cu tag (19 biti), data (32 biti), valid si dirty. Toate registrele sunt construite din instante `dff`. Bitul dirty este setat la write-hit sau write-allocate si sters la read-allocate. Hit-ul este combinational: `tag_match & valid`.

### lru_unit

Tracker LRU cu 4 contoare de varsta pe 2 biti (0 = LRU, 3 = MRU). La accesul caii W: `age[W]` devine 3 si toate caile cu varsta mai mare sunt decrementate. Victima este calea cu `age == 0`.

### cache_set

Contine 4 instante `cache_line` si o instanta `lru_unit`. Foloseste `encoder_4to2` pentru detectarea caii cu hit si `lru_way` pentru selectia victimei la alocare. Semnalele de scriere si alocare sunt mascate per cale.

### cache_array

128 instante `cache_set` generate cu `generate`. Semnalele active sunt mascate cu `active = (index == i)`.

## 8. Latente

Perioada de ceas: 10 ns

| Operatie | Cicluri |
|---|---:|
| Hit (citire sau scriere) | 2 |
| Miss fara evacuare | 3 |
| Miss cu evacuare | 4 |

## 9. Testbench si rezultate

Fisier: `sim/cache_controller_tb.v`. Acopera 5 grupuri de teste care exercita toate cele 7 stari FSM. Genereaza `cache_sim.vcd` pentru GTKWave.

Exemple de iesire din simulare:

```
[  36 ns]  READ   addr=00000000  state=ALLOCATE    MISS
[  56 ns]  READ   addr=00000000  state=READ_HIT    HIT
[  76 ns]  WRITE  addr=00000000  data=deadbeef  state=WRITE_HIT   HIT
[ 126 ns]  WRITE  addr=00002140  data=cafe0001  state=ALLOCATE    MISS
[ 446 ns]  READ   addr=00008280  state=ALLOCATE    MISS  (40 ns gap = EVICT activ)
[ 466 ns]  READ   addr=00008280  state=READ_HIT    HIT

Hit rate final: 14/23 = 60%
```

Rulare: `bash run.sh` sau `bash run.sh --view` pentru GTKWave.

## 10. Provocari tehnice

**Distinctia read-allocate vs write-allocate**: FSM-ul are o singura stare ALLOCATE, dar comportamentul bitului dirty difera in functie de originea miss-ului. Solutia a fost registrul `from_write_miss` in `cache_fsm.v`, care permite separarea semnalelor `read_alloc_en` si `write_alloc_en` in `output_logic.v`.

**Selectia caii la alocare**: la un miss, calea de scris este victima LRU, nu calea cu hit. `cache_set` expune separat `hit_way` (pentru WRITE_HIT) si `lru_way` (pentru ALLOCATE), fiecare mascat corespunzator pe cele 4 linii.

**Timing in testbench**: semnalele bazate pe registre (hit, stare) nu sunt valabile imediat dupa frontul de ceas din cauza asignarilor non-blocking. Rezolvat prin esantionarea intrarilor pe front descrescator si adaugarea unui `#1` dupa `@(posedge clk)` la citirea rezultatelor.
