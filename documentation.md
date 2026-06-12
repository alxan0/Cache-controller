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

In interiorul `cache_array` se afla 128 de instante `cache_set`, fiecare cu 4 linii (`cache_line`) si un tracker LRU (`lru_unit`).

## 5. Masina de stare (FSM)

### 5.1 Diagrama starilor

```
IDLE ── op_read  &  hit  ──> READ_HIT  ─────────────────────────────────> IDLE
IDLE ── op_write &  hit  ──> WRITE_HIT ─────────────────────────────────> IDLE
IDLE ── op_read  & !hit  ──> READ_MISS  ── clean ──> ALLOC_RD ──────────> IDLE
                                         └─ dirty ──> EVICT_RD ──> ALLOC_RD ──> IDLE
IDLE ── op_write & !hit  ──> WRITE_MISS ── clean ──> ALLOC_WR ──────────> IDLE
                                          └─ dirty ──> EVICT_WR ──> ALLOC_WR ──> IDLE
```

### 5.2 Tranzitii

| Stare curenta | Conditie     | Stare urmatoare |
|---|---|---|
| IDLE          | `op_read & hit`  | READ_HIT  |
| IDLE          | `op_read & !hit` | READ_MISS |
| IDLE          | `op_write & hit` | WRITE_HIT |
| IDLE          | `op_write & !hit`| WRITE_MISS|
| IDLE          | nicio cerere     | IDLE      |
| READ_MISS     | `dirty`          | EVICT_RD  |
| READ_MISS     | `!dirty`         | ALLOC_RD  |
| WRITE_MISS    | `dirty`          | EVICT_WR  |
| WRITE_MISS    | `!dirty`         | ALLOC_WR  |
| EVICT_RD      | -                | ALLOC_RD  |
| EVICT_WR      | -                | ALLOC_WR  |
| READ_HIT, WRITE_HIT, ALLOC_RD, ALLOC_WR | - | IDLE |

### 5.3 Iesiri (Moore)

| Stare      | `try_r` | `try_w` | `mem_w` | `mem_r` | `wh_en` | `ra_en` | `wa_en` | `ready` |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| IDLE       | op_r | op_w | 0 | 0 | 0 | 0 | 0 | 0 |
| READ_HIT   | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1 |
| READ_MISS  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| WRITE_HIT  | 0 | 0 | 0 | 0 | 1 | 0 | 0 | 1 |
| WRITE_MISS | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| EVICT_RD   | 0 | 0 | 1 | 0 | 0 | 0 | 0 | 0 |
| EVICT_WR   | 0 | 0 | 1 | 0 | 0 | 0 | 0 | 0 |
| ALLOC_RD   | 0 | 0 | 0 | 1 | 0 | 1 | 0 | 1 |
| ALLOC_WR   | 0 | 0 | 0 | 1 | 0 | 0 | 1 | 1 |

Abrevieri coloane: `try_r` = try_read, `try_w` = try_write, `mem_w` = mem_write, `mem_r` = mem_read, `wh_en` = write_hit_en, `ra_en` = read_alloc_en, `wa_en` = write_alloc_en.

## 6. Interfata externa

Modul: `cache_controller.v`

| Semnal | Dir | Latime | Descriere |
|---|---|---:|---|
| `clk`       | in  |  1 | Ceas, esantionat pe front crescator |
| `rst_b`     | in  |  1 | Reset asincron activ pe nivel scazut |
| `req`       | in  |  1 | Cerere activa de la CPU |
| `opcode`    | in  |  1 | 0 = citire, 1 = scriere |
| `data_in`   | in  | 32 | Date de scris |
| `address`   | in  | 32 | Adresa |
| `data_out`  | out | 32 | Date citite din cache |
| `fsm_state` | out |  4 | Starea curenta a FSM-ului |
| `hit`       | out |  1 | Ridicat cand adresa se gaseste in cache |
| `ready`     | out |  1 | Ridicat cand operatia este finalizata |

## 7. Module

### cache_line

O singura linie de cache cu tag (19 biti), 16 cuvinte de date de 32 de biti, valid si dirty. Hit-ul este combinational: `tag_match & valid`. Bitul dirty este setat la write-hit sau write-allocate si sters la read-allocate.

### lru_unit

Tracker LRU cu 4 contoare de varsta pe 2 biti (0 = LRU, 3 = MRU). La accesul caii W: `age[W]` devine 3 si toate caile cu varsta mai mare sunt decrementate. Victima este calea cu `age == 0`.

### cache_set

Contine 4 instante `cache_line` si o instanta `lru_unit`. Foloseste `encoder_4to2` pentru detectarea caii cu hit si `lru_way` pentru selectia victimei la alocare. Semnalele de scriere si alocare sunt mascate per cale.

### cache_array

128 instante `cache_set` generate cu `generate`. Semnalele active sunt mascate cu `active = (index == i)`.

### Primitive

- `comparator` - comparator parametrizabil pe N biti, folosit pentru tag matching
- `encoder_4to2` - encoder cu prioritate 4:2 cu semnal valid, folosit pentru detectarea caii cu hit

## 8. Latente

Perioada de ceas: 10 ns. Latentele sunt masurate de la ciclul in care `req` este ridicat.

| Operatie | Cicluri |
|---|---:|
| Hit (citire sau scriere)   | 2 |
| Miss fara evacuare         | 3 |
| Miss cu evacuare (dirty)   | 4 |

## 9. Testbench si rezultate

Fisier: `sim/cache_controller_tb.v`. Acopera 8 teste care exercita toate cele 9 stari FSM. Genereaza `cache_sim.vcd` pentru GTKWave.

Teste incluse:

| Test | Operatie | Comportament asteptat |
|---|---|---|
| 1 | Citire la adresa noua | READ_MISS -> ALLOC_RD |
| 2 | Citire repetata | READ_HIT |
| 3 | Scriere la adresa noua | WRITE_MISS -> ALLOC_WR, dirty=1 |
| 4 | Scriere la adresa existenta | WRITE_HIT |
| 5 | Citire dupa scriere | READ_HIT, data corecta |
| 6 | Citire in alt set | READ_MISS -> ALLOC_RD |
| 7 | Umplere set + evacuare | WRITE_MISS x4, apoi READ_MISS -> EVICT_RD -> ALLOC_RD |
| 8 | Acces la word diferit in acelasi bloc | WRITE_HIT, READ_HIT |

Rulare: `bash run.sh` sau `bash run.sh --view` pentru GTKWave.

## 10. Provocari tehnice

**Distinctia read-allocate vs write-allocate**: In loc de un registru auxiliar care sa retina originea miss-ului, FSM-ul foloseste stari separate pentru fiecare cale. EVICT_RD si ALLOC_RD apartin exclusiv lantului de citire, EVICT_WR si ALLOC_WR lantului de scriere. Starea curenta poarta in sine contextul operatiei, fara informatii suplimentare.

**Selectia caii la alocare**: La un miss, calea de scris este victima LRU, nu calea cu hit. `cache_set` expune separat `hit_way` (pentru WRITE_HIT) si `lru_way` (pentru ALLOCATE), fiecare mascat corespunzator pe cele 4 linii.

**Timing in testbench**: Semnalele bazate pe registre (hit, stare) nu sunt valabile imediat dupa frontul de ceas din cauza asignarilor non-blocking. Rezolvat prin adaugarea unui `#1` dupa `@(posedge clk)` la citirea rezultatelor.
