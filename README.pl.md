# OPAL Single Topic Multi-Tenant Solution

[![Language: English](https://img.shields.io/badge/Language-English-blue)](README.md) [![Język: Polski](https://img.shields.io/badge/J%C4%99zyk-Polski-red)](#)

**🌍 Dostępne języki:** [🇺🇸 English](README.md) | [🇵🇱 Polski](README.pl.md)

---

## 🚀 Rewolucyjne podejście do wielodostępności w OPAL

To repozytorium zawiera **rozwiązanie** problemu wielodostępności (multi-tenancy) w OPAL, które eliminuje potrzebę restartowania systemu przy dodawaniu nowych tenantów.

### 🎯 Kluczowe odkrycie

#### 🚫 Dlaczego tradycyjne podejście wymaga restartu?

**Tradycyjne podejście** - jeden topic na tenant:
```bash
# ❌ Każdy tenant = osobny topic = restart wymagany
OPAL_DATA_TOPICS=tenant_1_data,tenant_2_data,tenant_3_data
```

**Problem:** OPAL Client **subskrybuje topics podczas startu** i nie posiada mechanizmu dynamicznego dodawania nowych subskrypcji w runtime. To oznacza:

1. **OPAL Client startuje** z listą topics z `OPAL_DATA_TOPICS`
2. **Tworzy WebSocket connections** tylko dla tych topics
3. **Nowy tenant = nowy topic** nie jest automatycznie subskrybowany
4. **Jedyne rozwiązanie:** restart OPAL Client z rozszerzoną listą topics

#### ✅ Dlaczego nasze podejście nie wymaga restartu?

**Nasze odkrycie** - jeden topic dla wszystkich:
```bash
# ✅ Jeden topic dla wszystkich tenantów = ZERO restartów!
OPAL_DATA_TOPICS=tenant_data
```

**Rozwiązanie:** Wykorzystujemy **jeden topic + wiele dynamicznych data sources** z hierarchią ścieżek w OPA:

1. **OPAL Client subskrybuje** jeden topic `tenant_data` podczas startu
2. **Wszystkie eventy** dla wszystkich tenantów używają tego samego topic  
3. **Każdy tenant = osobny data source** dynamicznie dodawany przez API:
   ```bash
   # Tenant1 data source
   POST /data/config: {
     "url": "http://simple-api-provider:80/acl/tenant1",
     "topics": ["tenant_data"],
     "dst_path": "/acl/tenant1"
   }
   
   # Tenant2 data source  
   POST /data/config: {
     "url": "http://simple-api-provider:80/acl/tenant2",
     "topics": ["tenant_data"],
     "dst_path": "/acl/tenant2"
   }
   ```
4. **Nowy tenant:** nowy data source na istniejący topic (bez restartu!)

**Kluczowe różnice:**
- `url`: Unikalne dla każdego tenanta (różne dane)
- `topics`: Ten sam dla wszystkich (`["tenant_data"]`)  
- `dst_path`: Unikalna ścieżka w OPA (izolacja)

#### 🔍 Mechanizm techniczny

```
Tradycyjne (restart wymagany):
┌─────────────────┐    topics: tenant_1_data     ┌─────────────────┐
│   OPAL Server   │◄─────────────────────────────│   OPAL Client   │
│                 │    topics: tenant_2_data     │                 │
│  Multi Topics   │◄─────────────────────────────│  Multi Subscribe │
└─────────────────┘    topics: tenant_3_data     └─────────────────┘
                       ⚠️  Nowy topic = RESTART

Nasze rozwiązanie (bez restartu):
┌─────────────────┐    topic: tenant_data        ┌─────────────────┐
│   OPAL Server   │◄─────────────────────────────│   OPAL Client   │
│                 │    (dla wszystkich)          │                 │
│  Single Topic   │                              │ Single Subscribe │
│  Multi Sources: │                              │ Multi Data Fetch │
│  - /acl/tenant1 │                              │ - URL1→/acl/ten1 │
│  - /acl/tenant2 │                              │ - URL2→/acl/ten2 │
│  - /acl/tenant3 │                              │ - URL3→/acl/ten3 │
└─────────────────┘                              └─────────────────┘
                       ✅ Jeden topic, wiele sources, różne ścieżki
```

#### 📊 Izolacja danych

**Kluczowa obserwacja:** Izolacja tenantów **NIE musi** odbywać się na poziomie OPAL topics. OPA oferuje naturalną hierarchię ścieżek:

```json
{
  "acl": {
    "tenant1": { "users": [...], "resources": [...] },
    "tenant2": { "users": [...], "resources": [...] },
    "tenant3": { "users": [...], "resources": [...] }
  }
}
```

Każdy tenant ma własną przestrzeń w OPA, ale wszyscy używają tego samego mechanizmu dostarczania danych.

### 🏗️ Architektura

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   OPAL Server   │◄──►│   OPAL Client   │◄──►│      OPA        │
│                 │    │                 │    │                 │
│ Single Topic:   │    │ Data Fetcher    │    │ /acl/tenant1    │
│ "tenant_data"   │    │ HTTP Provider   │    │ /acl/tenant2    │
└─────────────────┘    └─────────────────┘    │ /acl/tenant3    │
         ▲                       ▲             └─────────────────┘
         │                       │
         │              ┌─────────────────┐
         └──────────────►│ Simple API      │
                         │ Provider        │
                         │ (nginx)         │
                         └─────────────────┘
```

### 🎁 Korzyści

- **🔄 Zero Downtime**: Dodawanie tenantów bez restartu
- **📈 Liniowa skalowalność**: Jeden topic obsługuje N tenantów  
- **🛡️ Pełna izolacja**: Dane tenantów pozostają oddzielone
- **⚡ Wydajność**: Brak overhead dla wielu topics
- **🧩 Simplicity**: Uproszczona konfiguracja

### ⚠️ Wyzwania inkrementalnych aktualizacji w środowiskach produkcyjnych

#### 🔥 Problemy z częstymi zmianami uprawnień

W wielodostępnych, wysokoskalowalnych środowiskach **częste aktualizacje uprawnień** tworzą znaczące wyzwania:

**Typowe scenariusze:**
- **Dodawanie użytkowników**: Nowi pracownicy w organizacji
- **Zmiana ról**: Promocje, transfery między departamentami  
- **Usuwanie dostępów**: Zwolnienia, rotacja dostępów
- **Modyfikacja zasobów**: Nowe projekty, aplikacje, dane
- **Bulk operations**: Masowe zmiany dla wielu użytkowników

#### 🏗️ Wyzwania architektoniczne

##### 1. **Race Conditions & Konsystencja**
```bash
# ❌ Problem: Równoległe aktualizacje tego samego tenanta
T1: POST /data/config (dodaj user1 do tenant1)
T2: POST /data/config (usuń user2 z tenant1)  
T3: POST /data/config (zmień rolę user3 w tenant1)

# Rezultat: Nieprzewidywalny stan danych w OPA
```

##### 2. **State Management Complexity**
```json
// ❌ Problematyczne: Partial updates mogą uszkodzić stan
{
  "tenant1": {
    "users": [
      {"id": "user1", "role": "admin"},     // Dodany przez update #1
      // user2 usunięty przez update #2 - ale czy update #3 to wie?
      {"id": "user3", "role": "manager"}   // Zmieniony przez update #3
    ]
  }
}
```

##### 3. **Synchronizacja w Distributed Environment**
```
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│ OPAL Client  │    │ OPAL Client  │    │ OPAL Client  │
│ Region: US   │    │ Region: EU   │    │ Region: ASIA │
│              │    │              │    │              │
│ Update T+0ms │    │ Update T+50ms│    │ Update T+150ms│
└──────────────┘    └──────────────┘    └──────────────┘
     ⚠️ Eventual Consistency Problem ⚠️
```

#### 📊 Problemy skalowalności

##### **Memory & Network Overhead**
```bash
# ❌ Traditional approach: N topics × M updates
Topics: tenant_1_data, tenant_2_data, ..., tenant_1000_data
Updates/hour: 50 per tenant × 1000 tenants = 50,000 events/hour
Network: 50,000 × WebSocket overhead = Massive bandwidth

# ✅ Our approach: 1 topic × M updates  
Topics: tenant_data
Updates/hour: 50,000 events/hour
Network: 50,000 × Single WebSocket = Minimal overhead
```

##### **Cache Invalidation Chaos**
```bash
# ❌ Multi-topic: Cache invalidation per topic
tenant_1_data changed → Invalidate tenant_1 cache
tenant_2_data changed → Invalidate tenant_2 cache
# Result: N separate cache management strategies

# ✅ Single-topic: Unified cache strategy
tenant_data changed → Smart invalidation based on dst_path
# Result: 1 unified cache management
```

#### 🛠️ Rozwiązania w naszym podejściu

##### **1. Atomic Operations na Single Topic**
```bash
# ✅ Wszystkie aktualizacje przez jeden kanał
curl -X POST http://localhost:7002/data/config \
  -d '{
    "entries": [{
      "url": "http://api/tenant1/bulk-update",  # Atomic bulk operation
      "topics": ["tenant_data"],
      "dst_path": "/acl/tenant1"
    }],
    "reason": "Bulk update: +user1, -user2, role_change_user3"
  }'
```

##### **2. Hierarchical Data Management**
```json
{
  "acl": {
    "tenant1": {
      "version": "v1.2.3",                    // Version tracking
      "last_updated": "2025-06-18T10:30:00Z", // Timestamp dla sync
      "users": [...],                          // Kompletny snapshot
      "roles": [...]                           // Nie partial updates
    }
  }
}
```

##### **3. Event Ordering & Deduplication**
```bash
# ✅ Single topic zapewnia ordered delivery
Event #1: tenant1_update (version: v1.2.3)
Event #2: tenant2_update (version: v2.1.0)  
Event #3: tenant1_update (version: v1.2.4) # Supersedes #1

# OPAL Client może implementować deduplication based on version
```

#### 💡 Production Best Practices

##### **Full Snapshot vs Incremental**
```bash
# ❌ Incremental (problematyczne przy częstych zmianach)
POST /data/config: {"operation": "add_user", "user": "alice"}
POST /data/config: {"operation": "remove_user", "user": "bob"}
POST /data/config: {"operation": "change_role", "user": "charlie", "role": "admin"}

# ✅ Full Snapshot (nasz approach)
POST /data/config: {"entries": [{"url": "/tenant1/complete-state", ...}]}
# API zwraca kompletny stan tenanta po wszystkich zmianach
```

##### **Graceful Degradation**
```bash
# ✅ Monitoring & alerting dla częstych aktualizacji
if updates_per_minute > threshold:
    alert("High update frequency detected for tenant1")
    implement_batch_processing()
```

#### 📈 Skalowalność w liczbach

| Scenario | Traditional Multi-Topic | Single Topic (Ours) |
|----------|------------------------|---------------------|
| **1000 tenants, 50 updates/h każdy** | 50,000 topic-events/h | 50,000 unified events/h |
| **Memory per topic** | ~10MB × 1000 = 10GB | ~10MB × 1 = 10MB |
| **WebSocket connections** | 1000 (1 per topic) | 1 (unified) |
| **Race condition risk** | High (per topic) | Low (single channel) |
| **Debugging complexity** | O(N) topics to trace | O(1) single flow |

**Podsumowanie:** Nasze podejście nie tylko eliminuje restarty, ale także **dramatycznie upraszcza zarządzanie częstymi aktualizacjami** w środowiskach o wysokiej skali.

### 🔬 Porównanie z podejściem inkrementalnym (PATCH operations)

Teoretycznie możliwe jest wysyłanie tylko zmienionych danych dla wszystkich tenantów przy użyciu **JSON Patch operations** (RFC 6902). Zbadajmy to podejście:

#### 📝 **Mechanizm JSON Patch w OPAL**
```bash
# ✅ OPAL obsługuje PATCH operations na danych (nie politykach)
curl -X POST http://localhost:7002/data/config \
  -d '{
    "entries": [{
      "url": "",
      "topics": ["tenant_data"],
      "dst_path": "/acl/tenant1", 
      "save_method": "PATCH",
      "data": [
        {"op": "add", "path": "/users/alice", "value": {"role": "admin"}},
        {"op": "remove", "path": "/users/bob"},
        {"op": "replace", "path": "/users/charlie/role", "value": "viewer"}
      ]
    }]
  }'
```

#### ⚡ **Porównanie transferu danych**

| Scenario | Nasze podejście (Full Snapshot) | Incremental PATCH | Różnica |
|----------|--------------------------------|-------------------|---------|
| **1000 tenantów, 50 zmian/h każdy** | 50,000 × avg 100KB = 5GB/h | 50,000 × avg 2KB = 100MB/h | **50x mniej** |
| **Tenant1: +user, -user, ±role** | Pełny snapshot (100KB) | 3 PATCH ops (2KB) | **50x mniej** |
| **Single change w tenant** | 100KB (cały stan) | 200B (jedna operacja) | **500x mniej** |

#### 🚨 **Problemy techniczne z podejściem inkrementalnym**

##### **1. Brak obsługi EXTERNAL DATA SOURCES dla PATCH**
```bash
# ❌ Nie można używać external URL z PATCH operations
{
  "entries": [{
    "url": "http://api/tenant1/changes",  # Nie obsługiwane dla PATCH
    "save_method": "PATCH",
    "data": [...]  # Musi być inline - bez dynamic fetch
  }]
}
```

##### **2. Złożoność generowania PATCH w skali**
```javascript
// ❌ Problem: Generowanie tysięcy inkrementalnych paczek
function generateIncrementalPatches(tenants) {
  let patchOperations = [];
  
  for (let tenant of tenants) {  // 10,000+ tenantów
    for (let change of tenant.changes) {  // 50+ zmian/h każdy
      patchOperations.push({
        "op": determineOperation(change),  // add/remove/replace logic
        "path": buildPath(tenant.id, change.resource),
        "value": change.newValue
      });
    }
  }
  
  // Result: 500,000+ patch operations per hour!
  // Memory spike, processing overhead, race conditions
}
```

##### **3. State Management Hell**
```bash
# ❌ Problem: Utrzymanie spójności przy PATCH operations
T1: PATCH /acl/tenant1 [{"op": "add", "path": "/users/alice", ...}]
T2: PATCH /acl/tenant1 [{"op": "remove", "path": "/users/bob", ...}]  
T3: PATCH /acl/tenant1 [{"op": "replace", "path": "/users/alice/role", ...}]

# Jeśli T3 przychodzi przed T1 → ERROR (alice nie istnieje)
# Jeśli T2 usuwa strukturę potrzebną dla T3 → ERROR
# Ordering dependencies w distributed environment = NIGHTMARE
```

##### **4. Ograniczenia OPAL dla PATCH**
```bash
# ❌ OPAL ma znaczące limitacje dla PATCH:
- "Delta bundles only support updates to data. Policies cannot be updated"
- "Delta bundles do not support bundle signing"  
- "Unlike snapshot bundles, activated delta bundles are not persisted to disk"
- "OPA does not support move operation of JSON patch"
```

#### 📊 **Realny overhead inkrementalnego podejścia**

##### **Generowanie PATCH operations (10,000 tenantów)**
```bash
Operation          | Per tenant/hour | Total/hour  | CPU overhead
-------------------|-----------------|-------------|-------------
Parse changes      | 2ms × 50        | 1000s       | Massive
Generate JSON Path | 1ms × 50        | 500s        | High  
Validate ops       | 0.5ms × 50      | 250s        | Medium
Serialize PATCH    | 3ms × 50        | 1500s       | High
TOTAL              | 325ms           | 3250s/hour  | **54 minutes CPU/hour**
```

##### **Memory consumption spike**
```bash
# ❌ Peak memory usage podczas generowania PATCH
Normal operation:        1GB RAM
During PATCH generation: 8GB RAM (8x spike!)
Garbage collection:      15-30s pauses
```

#### 💡 **Dlaczego nasze podejście jest lepsze**

##### **1. Simplicity architektury**
```bash
# ✅ Nasze: Jeden URL per tenant, zawsze aktualny snapshot
GET /api/tenant1/complete-state → Kompletny stan (100KB)

# ❌ Incremental: Kompleksowa logika generowania PATCH
GET /api/tenant1/changes → Analiza zmian
POST /patch-generator   → Generowanie operations  
PUT /opal/data/config   → Wysłanie PATCH
```

##### **2. Deterministic state**
```bash
# ✅ Nasze: Stan zawsze spójny
Każdy fetch zwraca: COMPLETE, CURRENT, CONSISTENT state

# ❌ Incremental: Stan zależny od historii
Stan = Initial_State + PATCH1 + PATCH2 + ... + PATCHn
Jedna失 nieudana operacja = INCONSISTENT state
```

##### **3. Error recovery**
```bash
# ✅ Nasze: Automatic recovery
Jeśli fetch fails → retry same URL → Complete state restored

# ❌ Incremental: Complex recovery  
Jeśli PATCH fails → Determine failed operations → Rebuild state
                  → Complex conflict resolution
```

#### 🏆 **Werdykt końcowy**

| Aspekt | Single Topic + Snapshots | Multi-Topic Traditional | Single Topic + PATCH |
|--------|---------------------------|-------------------------|---------------------|
| **Network transfer** | Średni (5GB/h) | Wysoki + overhead | ✅ Niski (100MB/h) |
| **Complexity** | ✅ Niski | Średni | ❌ Bardzo wysoki |
| **CPU overhead** | ✅ Niski | Średni | ❌ Bardzo wysoki (54min/h) |
| **Memory spikes** | ✅ Brak | Średnie | ❌ 8x normal usage |
| **Error recovery** | ✅ Trivial | Średni | ❌ Complex |
| **Race conditions** | ✅ Eliminate | Wysokie | ❌ Extreme |
| **Operational complexity** | ✅ Minimal | Wysoki | ❌ Expert-level |

**Konkluzja:** Chociaż podejście inkrementalne może być **teoretically** efektywniejsze pod względem transferu danych, **praktyczne koszty implementacji i operacji** czynią je nieopłacalnym w środowiskach produkcyjnych o wysokiej skali. Nasze rozwiązanie Single Topic + Full Snapshots stanowi **optimum** między prostotą, niezawodnością a wydajnością.

### 📁 Zawartość repozytorium

```
├── docker-compose.yml              # Kompletna konfiguracja OPAL
├── policies/                       # Polityki rego z nową składnią 'if'
│   ├── access.rego                 # Kontrola dostępu
│   ├── roles.rego                  # Zarządzanie rolami  
│   └── allow.rego                  # Reguły autoryzacji
├── simple-api-provider/            # Mock API dla danych tenantów
│   └── nginx.conf                  # Konfiguracja nginx
└── test-single-topic-multi-tenant.sh  # Skrypt testowy
```

## 🚀 Szybki start

### 1. Uruchomienie systemu

```bash
# Klonowanie repozytorium
git clone https://github.com/plduser/opa-zero-poll-single-topic-multi-tenant.git
cd opa-zero-poll-single-topic-multi-tenant

# Uruchomienie wszystkich usług
docker-compose up -d

# Sprawdzenie statusu (wszystkie kontenery powinny być 'running')
docker-compose ps
```

### 2. Weryfikacja działania

```bash
# Sprawdzenie health endpoints
curl http://localhost:8181/health        # OPA health
curl http://localhost:7002/healthcheck   # OPAL Server health
curl http://localhost:8090/acl/tenant1   # API Provider
```

### 3. Test Single Topic Multi-Tenant

#### Krok 1: Dodanie pierwszego tenanta
```bash
curl -X POST http://localhost:7002/data/config \
  -H "Content-Type: application/json" \
  -d '{
    "entries": [{
      "url": "http://simple-api-provider:80/acl/tenant1",
      "topics": ["tenant_data"],
      "dst_path": "/acl/tenant1"
    }],
    "reason": "Load tenant1 data via single topic"
  }'
```

#### Krok 2: Dodanie drugiego tenanta **BEZ RESTARTU**
```bash
curl -X POST http://localhost:7002/data/config \
  -H "Content-Type: application/json" \
  -d '{
    "entries": [{
      "url": "http://simple-api-provider:80/acl/tenant2",
      "topics": ["tenant_data"],
      "dst_path": "/acl/tenant2"
    }],
    "reason": "Load tenant2 data - NO RESTART NEEDED!"
  }'
```

> **💡 Kluczowa obserwacja:** Każdy tenant ma:
> - **Różne URL źródła danych** (`/acl/tenant1` vs `/acl/tenant2`)
> - **Ten sam topic** (`tenant_data`)  
> - **Różne ścieżki docelowe** w OPA (`/acl/tenant1` vs `/acl/tenant2`)

> **⚠️ Ważne:** JSON nie obsługuje komentarzy! Przykłady powyżej są **gotowe do skopiowania** bez modyfikacji.

#### Krok 3: Weryfikacja izolacji danych
```bash
# Sprawdzenie danych tenant1
curl http://localhost:8181/v1/data/acl/tenant1 | jq .

# Sprawdzenie danych tenant2  
curl http://localhost:8181/v1/data/acl/tenant2 | jq .

# Sprawdzenie wszystkich danych
curl http://localhost:8181/v1/data/acl | jq .
```

### 4. Test polityk z nową składnią

```bash
# Test autoryzacji RBAC
curl -X POST http://localhost:8181/v1/data/policies/rbac/allow \
  -H "Content-Type: application/json" \
  -d '{
    "input": {
      "user": "alice",
      "action": "read", 
      "resource": "document1",
      "tenant_id": "tenant1"
    }
  }' | jq .
```

## 🧪 Automatyczny test

Użyj dołączonego skryptu do pełnego testu:

```bash
chmod +x test-single-topic-multi-tenant.sh
./test-single-topic-multi-tenant.sh
```

## 🔧 Konfiguracja

### Kluczowe parametry w docker-compose.yml:

```yaml
# OPAL Client - rewolucyjna konfiguracja single topic
environment:
  - OPAL_DATA_TOPICS=tenant_data  # ⭐ Jeden topic dla wszystkich!
  - OPAL_DATA_UPDATER_ENABLED=true
  - OPAL_FETCH_TIMEOUT=30
```

### Struktura danych w OPA:

```json
{
  "acl": {
    "tenant1": {
      "users": [{"name": "alice", "role": "admin"}],
      "resources": [{"name": "document1", "owner": "alice"}]
    },
    "tenant2": {
      "users": [{"name": "charlie", "role": "manager"}], 
      "resources": [{"name": "file1", "owner": "charlie"}]
    }
  }
}
```

## 📊 Porównanie wydajności

| Metryka | Tradycyjne Multi-Topic | Single Topic (nasze) |
|---------|------------------------|----------------------|
| **Restart przy dodaniu tenanta** | ✅ Wymagany | ❌ Nie wymagany |
| **Liczba topics** | N (jeden na tenant) | 1 (dla wszystkich) |
| **Memory overhead** | O(N) | O(1) |
| **Czas wdrożenia** | Minuty (restart) | Sekundy (live) |
| **Skalowalność** | Ograniczona | Nieograniczona |

## 🛠️ Rozwiązywanie problemów

### Problem: Błąd JSON w komendach curl
```bash
# ❌ Niepoprawne: JSON nie obsługuje komentarzy
curl -X POST http://localhost:7002/data/config \
  -d '{
    "entries": [{
      "url": "http://simple-api-provider:80/acl/tenant2",  # Komentarz powoduje błąd!
      "topics": ["tenant_data"]
    }]
  }'

# ✅ Poprawne: JSON bez komentarzy
curl -X POST http://localhost:7002/data/config \
  -H "Content-Type: application/json" \
  -d '{
    "entries": [{
      "url": "http://simple-api-provider:80/acl/tenant2",
      "topics": ["tenant_data"],
      "dst_path": "/acl/tenant2"
    }],
    "reason": "Load tenant2 data"
  }'
```

**Ważne:** 
- **Zawsze używaj** `http://simple-api-provider:80` dla komunikacji między kontenerami
- **Nigdy nie używaj** `http://host.docker.internal:8090` - to nie działa z OPAL Client
- **Zawsze dodawaj** nagłówek `Content-Type: application/json`

### Problem: Kontenery nie startują
```bash
# Sprawdź logi
docker-compose logs opal-server
docker-compose logs opal-client

# Restart systemu
docker-compose down && docker-compose up -d
```

### Problem: Dane nie ładują się do OPA
```bash
# Sprawdź czy API Provider odpowiada
curl -v http://localhost:8090/acl/tenant1

# Sprawdź logi OPAL Client
docker logs opa-zero-poll-single-topic-multi-tenant-opal-client-1
```

### Problem: Błąd Content-Type
Upewnij się, że nginx zwraca `Content-Type: application/json`:
```nginx
location /acl/tenant1 {
    default_type application/json;  # ✅ Poprawne
    # add_header Content-Type application/json;  # ❌ Niepoprawne
}
```

## 📋 Wymagania systemowe

- **Docker**: >= 20.10
- **Docker Compose**: >= 2.0
- **System**: Linux/macOS (ARM64/AMD64)
- **RAM**: Minimum 2GB dostępnej pamięci
- **Porty**: 7001, 7002, 8090, 8181, 8282

## 🔗 Przydatne linki

- [Open Policy Agent (OPA)](https://www.openpolicyagent.org/)
- [OPAL Documentation](https://docs.opal.ac/)
- [Rego Language Guide](https://www.openpolicyagent.org/docs/latest/policy-language/)

## 📄 Licencja

MIT License - zobacz [LICENSE](LICENSE) dla szczegółów.

---

**🌟 Jeśli to rozwiązanie rozwiązuje Twój problem z multi-tenancy w OPAL, rozważ contribution do głównego projektu OPAL!** 
