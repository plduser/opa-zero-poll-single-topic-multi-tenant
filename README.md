# OPAL Single Topic Multi-Tenant Solution

[![Language: English](https://img.shields.io/badge/Language-English-blue)](#) [![Język: Polski](https://img.shields.io/badge/J%C4%99zyk-Polski-red)](README.pl.md)

**🌍 Available Languages:** [🇺🇸 English](README.md) | [🇵🇱 Polski](README.pl.md)

---

## 🚀 Revolutionary Multi-Tenancy Approach for OPAL

This repository contains a **breakthrough solution** for multi-tenancy in OPAL that **eliminates the need for system restarts** when adding new tenants.

### 🎯 Key Discovery

**Traditional approach** requires restarts:
```bash
# ❌ Each tenant = separate topic = restart required
OPAL_DATA_TOPICS=tenant_1_data,tenant_2_data,tenant_3_data
```

**Our revolutionary approach** - zero restarts:
```bash
# ✅ One topic for all tenants = ZERO restarts!
OPAL_DATA_TOPICS=tenant_data
```

### 🏗️ How It Works

Instead of multiple topics, we use:
- **Single topic** (`tenant_data`) for all tenants
- **Multiple data sources** with unique URLs per tenant
- **Hierarchical paths** in OPA for data isolation

```bash
# Add Tenant 1
curl -X POST http://localhost:7002/data/config \
  -H "Content-Type: application/json" \
  -d '{
    "entries": [{
      "url": "http://simple-api-provider:80/acl/tenant1",
      "topics": ["tenant_data"],
      "dst_path": "/acl/tenant1"
    }]
  }'

# Add Tenant 2 - NO RESTART NEEDED!
curl -X POST http://localhost:7002/data/config \
  -H "Content-Type: application/json" \
  -d '{
    "entries": [{
      "url": "http://simple-api-provider:80/acl/tenant2", 
      "topics": ["tenant_data"],
      "dst_path": "/acl/tenant2"
    }]
  }'
```

### 🎁 Benefits

- **🔄 Zero Downtime**: Add tenants without restarts
- **📈 Linear Scalability**: One topic handles N tenants
- **🛡️ Full Isolation**: Tenant data remains separated  
- **⚡ Performance**: No overhead from multiple topics
- **🧩 Simplicity**: Streamlined configuration

### 🚀 Quick Start

```bash
# Clone repository
git clone https://github.com/plduser/opa-zero-poll-single-topic-multi-tenant.git
cd opa-zero-poll-single-topic-multi-tenant

# Start all services
docker-compose up -d

# Verify health
curl http://localhost:8181/health        # OPA health
curl http://localhost:7002/healthcheck   # OPAL Server health
curl http://localhost:8090/acl/tenant1   # API Provider
```

### 📊 Performance Comparison

| Metric | Traditional Multi-Topic | Single Topic (Ours) |
|--------|------------------------|---------------------|
| **Restart on new tenant** | ✅ Required | ❌ Not required |
| **Number of topics** | N (one per tenant) | 1 (for all) |
| **Memory overhead** | O(N) | O(1) |
| **Deployment time** | Minutes (restart) | Seconds (live) |
| **Scalability** | Limited | Unlimited |

### 🧪 Test Script

Run the included automated test:

```bash
chmod +x test-single-topic-multi-tenant.sh
./test-single-topic-multi-tenant.sh
```

### 🔧 Architecture

The solution uses:
- **OPAL Server** (port 7002) - Central policy/data management
- **OPAL Client** (port 7001) - Fetches and updates OPA
- **OPA** (ports 8181, 8282) - Policy engine with modern Rego policies
- **Simple API Provider** (port 8090) - Mock tenant data endpoints

### 📋 Requirements

- **Docker**: >= 20.10
- **Docker Compose**: >= 2.0  
- **System**: Linux/macOS (ARM64/AMD64)
- **RAM**: Minimum 2GB available memory
- **Ports**: 7001, 7002, 8090, 8181, 8282

### 🛠️ Troubleshooting

**JSON Comments Error:**
```bash
# ❌ Wrong: JSON doesn't support comments
curl -X POST http://localhost:7002/data/config \
  -d '{"url": "http://simple-api-provider:80/acl/tenant2"}' # Comment causes error!

# ✅ Correct: Pure JSON without comments  
curl -X POST http://localhost:7002/data/config \
  -H "Content-Type: application/json" \
  -d '{"entries": [{"url": "http://simple-api-provider:80/acl/tenant2", "topics": ["tenant_data"], "dst_path": "/acl/tenant2"}]}'
```

**Important:**
- Always use `http://simple-api-provider:80` for container-to-container communication
- Never use `http://host.docker.internal:8090` - doesn't work with OPAL Client  
- Always add `Content-Type: application/json` header

### 🔗 Useful Links

- [Open Policy Agent (OPA)](https://www.openpolicyagent.org/)
- [OPAL Documentation](https://docs.opal.ac/)  
- [Rego Language Guide](https://www.openpolicyagent.org/docs/latest/policy-language/)

### 📄 License

MIT License - see [LICENSE](LICENSE) for details.

---

**🌟 If this solution solves your multi-tenancy problem in OPAL, consider contributing to the main OPAL project!**

## 📖 Documentation in Other Languages

- **🇵🇱 Polish (Polski)**: [README.pl.md](README.pl.md) - Complete documentation in Polish
- **🇺🇸 English**: This file - Complete documentation in English

---

*This repository demonstrates a working OPAL pattern that enables multi-tenant data management WITHOUT restarts when adding new tenants.*
