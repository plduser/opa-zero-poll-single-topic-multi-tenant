# OPAL Single Topic Multi-Tenant Solution

## 🚀 Rewolucyjne podejście do wielodostępności w OPAL

To repozytorium zawiera **przełomowe rozwiązanie** problemu wielodostępności (multi-tenancy) w OPAL, które eliminuje potrzebę restartowania systemu przy dodawaniu nowych tenantów.

### 🎯 Kluczowe odkrycie

**Tradycyjne podejście** wymaga restartu:
```bash
# ❌ Każdy tenant = osobny topic = restart wymagany
OPAL_DATA_TOPICS=tenant_1_data,tenant_2_data,tenant_3_data
```

**Nasze rozwiązanie** działa bez restartu:
```bash
# ✅ Jeden topic dla wszystkich tenantów = ZERO restartów!
OPAL_DATA_TOPICS=tenant_data
```

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
- **🧩 Simplicitas**: Uproszczona konfiguracja

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
      "url": "http://host.docker.internal:8090/acl/tenant1",
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
      "url": "http://host.docker.internal:8090/acl/tenant2", 
      "topics": ["tenant_data"],
      "dst_path": "/acl/tenant2"
    }],
    "reason": "Load tenant2 data - NO RESTART NEEDED!"
  }'
```

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