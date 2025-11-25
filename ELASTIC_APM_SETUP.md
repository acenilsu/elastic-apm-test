# Elastic Stack + APM + .NET Uygulaması - Komple Kurulum Rehberi

Bu doküman, Docker üzerinde Elastic Stack kurulumu ve .NET uygulamasının APM ile entegrasyonunu baştan sona açıklar.

## İçindekiler
1. [Gereksinimler](#gereksinimler)
2. [Docker Network Oluşturma](#docker-network-oluşturma)
3. [Elasticsearch Kurulumu](#elasticsearch-kurulumu)
4. [Kibana Kurulumu](#kibana-kurulumu)
5. [APM Server Kurulumu](#apm-server-kurulumu)
6. [.NET Uygulaması APM Entegrasyonu](#net-uygulaması-apm-entegrasyonu)
7. [Doğrulama ve Test](#doğrulama-ve-test)
8. [Sorun Giderme](#sorun-giderme)

---

## Gereksinimler

- Docker Desktop (Mac/Windows) veya Docker Engine (Linux)
- .NET SDK 6.0 veya üzeri
- En az 4GB RAM (Docker için)
- Boş portlar: 9200, 5601, 8200

---

## Docker Network Oluşturma

Tüm Elastic bileşenlerinin birbirleriyle iletişim kurabilmesi için bir Docker network oluşturun:

```bash
docker network create elastic
```

**Doğrulama:**
```bash
docker network ls | grep elastic
```

---

## Elasticsearch Kurulumu

### 1. Elasticsearch Container'ını Başlatın

```bash
docker run -d \
  --name elasticsearch \
  --network elastic \
  -p 9200:9200 \
  -p 9300:9300 \
  -e "discovery.type=single-node" \
  -e "xpack.security.enabled=false" \
  docker.elastic.co/elasticsearch/elasticsearch:8.11.0
```

**Parametreler:**
- `--name elasticsearch`: Container adı
- `--network elastic`: Elastic network'üne bağla
- `-p 9200:9200`: HTTP API portu
- `-p 9300:9300`: Node iletişim portu
- `-e "discovery.type=single-node"`: Tek node cluster
- `-e "xpack.security.enabled=false"`: Güvenliği kapat (sadece test için!)

### 2. Elasticsearch'in Hazır Olmasını Bekleyin

```bash
# 30 saniye bekleyin
sleep 30

# Durumu kontrol edin
curl http://localhost:9200/
```

**Beklenen Çıktı:**
```json
{
  "name": "...",
  "cluster_name": "docker-cluster",
  "version": {
    "number": "8.11.0",
    ...
  },
  "tagline": "You Know, for Search"
}
```

---

## Kibana Kurulumu

### 1. Kibana Container'ını Başlatın

```bash
docker run -d \
  --name kibana \
  --network elastic \
  -p 5601:5601 \
  -e "ELASTICSEARCH_HOSTS=http://elasticsearch:9200" \
  docker.elastic.co/kibana/kibana:8.11.0
```

**Parametreler:**
- `--name kibana`: Container adı
- `--network elastic`: Elastic network'üne bağla
- `-p 5601:5601`: Kibana web arayüzü portu
- `-e "ELASTICSEARCH_HOSTS=..."`: Elasticsearch bağlantı adresi

### 2. Kibana'nın Hazır Olmasını Bekleyin

```bash
# 60 saniye bekleyin (Kibana başlatılması uzun sürer)
sleep 60

# Durumu kontrol edin
curl -s http://localhost:5601/api/status | jq -r '.status.overall.level'
```

**Beklenen Çıktı:**
```
available
```

### 3. Kibana'ya Tarayıcıdan Erişin

Tarayıcınızda açın: **http://localhost:5601/**

---

## APM Server Kurulumu

### ⚠️ Önemli Not: Versiyon Seçimi

**APM Server 8.x** kullanmak için Kibana'da "APM Integration" yüklü olmalıdır. Test ortamları için **APM Server 7.17** kullanmak daha kolaydır.

### 1. APM Server 7.17 Container'ını Başlatın

```bash
docker run -d \
  --name apm-server \
  --network elastic \
  -p 8200:8200 \
  -e "output.elasticsearch.hosts=[\"http://elasticsearch:9200\"]" \
  -e "apm-server.host=0.0.0.0:8200" \
  docker.elastic.co/apm/apm-server:7.17.0 \
  -E apm-server.auth.anonymous.enabled=true
```

**Parametreler:**
- `--name apm-server`: Container adı
- `--network elastic`: Elastic network'üne bağla
- `-p 8200:8200`: APM Server API portu
- `-e "output.elasticsearch.hosts=..."`: Elasticsearch bağlantı adresi
- `-e "apm-server.host=0.0.0.0:8200"`: Tüm IP'lerden bağlantı kabul et
- `-E apm-server.auth.anonymous.enabled=true`: Kimlik doğrulama olmadan (sadece test için!)

### 2. APM Server'ın Hazır Olmasını Bekleyin

```bash
# 10 saniye bekleyin
sleep 10

# Durumu kontrol edin
curl http://localhost:8200/ | jq .
```

**Beklenen Çıktı:**
```json
{
  "build_date": "2022-01-28T10:40:11Z",
  "build_sha": "...",
  "publish_ready": true,
  "version": "7.17.0"
}
```

**✅ Kritik:** `"publish_ready": true` olmalı!

---

## .NET Uygulaması APM Entegrasyonu

### 1. Elastic APM NuGet Paketini Ekleyin

```bash
cd /path/to/your/project
dotnet add package Elastic.Apm.NetCoreAll
```

### 2. Program.cs Dosyasını Güncelleyin

**Önce:**
```csharp
var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

app.MapGet("/", () => "Hello World!");

app.Run();
```

**Sonra:**
```csharp
using Elastic.Apm.NetCoreAll;

var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

app.UseAllElasticApm(builder.Configuration);

app.MapGet("/", () => "Hello World!");

app.Run();
```

### 3. appsettings.json'a Debug Logging Ekleyin (Opsiyonel)

```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning",
      "Elastic.Apm": "Debug"
    }
  },
  "AllowedHosts": "*"
}
```

### 4. Uygulamayı Çalıştırın

```bash
export ELASTIC_APM_SERVER_URLS="http://localhost:8200"
export ELASTIC_APM_SERVICE_NAME="TestApp"
export ELASTIC_APM_LOG_LEVEL="debug"
export ELASTIC_APM_CENTRAL_CONFIG="false"

dotnet run --urls "http://localhost:5050"
```

**Environment Variables:**
- `ELASTIC_APM_SERVER_URLS`: APM Server adresi
- `ELASTIC_APM_SERVICE_NAME`: Kibana'da görünecek servis adı
- `ELASTIC_APM_LOG_LEVEL`: Log seviyesi (debug/info/warning/error)
- `ELASTIC_APM_CENTRAL_CONFIG`: Merkezi yapılandırmayı devre dışı bırak

---

## Doğrulama ve Test

### 1. Uygulamaya Trafik Gönderin

```bash
# Birkaç istek gönderin
for i in {1..10}; do
  curl http://localhost:5050/
  sleep 1
done
```

### 2. Agent Loglarını Kontrol Edin

Uygulama loglarında şunu aramalısınız:

```
dbug: Elastic.Apm[0]
      {PayloadSenderV2} Sent items to server:
          Transaction{...}
```

Bu, verilerin APM Server'a gönderildiğini gösterir.

### 3. Kibana'da APM Verilerini Görüntüleyin

1. **http://localhost:5601/** adresine gidin
2. Sol menüden **☰** → **Observability** → **APM** seçin
3. **"TestApp"** servisini göreceksiniz
4. Servise tıklayarak detayları görün:
   - Transactions (İstekler)
   - Errors (Hatalar)
   - Metrics (Metrikler)
   - Service Map (Servis haritası)

**Eğer veri görmüyorsanız:**
- Sağ üstteki **zaman seçiciyi** "Last 1 hour" yapın
- **Environment** filtresini "All" veya "Development" yapın
- 1-2 dakika bekleyin (veriler index'lenirken)

---

## Sorun Giderme

### Problem: APM Server `publish_ready: false`

**Neden:** APM Server, Elasticsearch'e bağlanamıyor.

**Çözüm:**
```bash
# APM Server loglarını kontrol edin
docker logs apm-server --tail 50

# Elasticsearch'in çalıştığını doğrulayın
curl http://localhost:9200/

# APM Server'ı yeniden başlatın
docker restart apm-server
```

### Problem: Kibana "License is not available" Hatası

**Neden:** Elasticsearch yeni başlatıldı, Kibana henüz lisans bilgisini yükleyemedi.

**Çözüm:**
```bash
# Elasticsearch ve Kibana'yı yeniden başlatın
docker restart elasticsearch
sleep 20
docker restart kibana
sleep 60

# Kibana'yı tarayıcıda yenileyin
```

### Problem: .NET Uygulaması Veri Göndermiyor

**Neden:** Agent yapılandırması yanlış veya APM Server erişilemiyor.

**Çözüm:**
```bash
# Environment variables'ları kontrol edin
echo $ELASTIC_APM_SERVER_URLS
echo $ELASTIC_APM_SERVICE_NAME

# APM Server'a erişimi test edin
curl http://localhost:8200/

# Uygulama loglarında "Sent items to server" araması yapın
```

### Problem: Port Zaten Kullanımda

**Neden:** Başka bir uygulama aynı portu kullanıyor.

**Çözüm:**
```bash
# Portu kullanan process'i bulun
lsof -ti:5050

# Process'i öldürün
lsof -ti:5050 | xargs kill -9

# Veya farklı bir port kullanın
dotnet run --urls "http://localhost:5051"
```

---

## Container'ları Yönetme

### Tüm Container'ları Durdurun
```bash
docker stop elasticsearch kibana apm-server
```

### Tüm Container'ları Başlatın
```bash
docker start elasticsearch
sleep 20
docker start kibana
sleep 10
docker start apm-server
```

### Tüm Container'ları Silin
```bash
docker rm -f elasticsearch kibana apm-server
```

### Container Loglarını Görüntüleyin
```bash
docker logs elasticsearch --tail 50
docker logs kibana --tail 50
docker logs apm-server --tail 50
```

### Container Durumunu Kontrol Edin
```bash
docker ps -a | grep -E "elasticsearch|kibana|apm-server"
```

---

## Docker Compose ile Kurulum (Alternatif)

Yukarıdaki tüm adımları tek bir `docker-compose.yml` dosyası ile yapabilirsiniz:

```yaml
version: '3.8'

services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.11.0
    container_name: elasticsearch
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=false
    ports:
      - "9200:9200"
      - "9300:9300"
    networks:
      - elastic

  kibana:
    image: docker.elastic.co/kibana/kibana:8.11.0
    container_name: kibana
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
    ports:
      - "5601:5601"
    networks:
      - elastic
    depends_on:
      - elasticsearch

  apm-server:
    image: docker.elastic.co/apm/apm-server:7.17.0
    container_name: apm-server
    command: >
      apm-server -e
        -E apm-server.host=0.0.0.0:8200
        -E apm-server.auth.anonymous.enabled=true
        -E output.elasticsearch.hosts=["http://elasticsearch:9200"]
    ports:
      - "8200:8200"
    networks:
      - elastic
    depends_on:
      - elasticsearch

networks:
  elastic:
    driver: bridge
```

**Kullanım:**
```bash
# Başlat
docker-compose up -d

# Durdur
docker-compose down

# Logları görüntüle
docker-compose logs -f
```

---

## Güvenlik Notları

⚠️ **Bu kurulum sadece geliştirme/test ortamları içindir!**

**Production için:**
- Elasticsearch güvenliğini etkinleştirin (`xpack.security.enabled=true`)
- APM Server authentication kullanın
- HTTPS/TLS yapılandırın
- Güçlü şifreler kullanın
- Network izolasyonu sağlayın
- Resource limitleri belirleyin

---

## Kaynaklar

- [Elastic APM .NET Agent Dokümantasyonu](https://www.elastic.co/guide/en/apm/agent/dotnet/current/index.html)
- [APM Server Dokümantasyonu](https://www.elastic.co/guide/en/apm/server/current/index.html)
- [Elasticsearch Dokümantasyonu](https://www.elastic.co/guide/en/elasticsearch/reference/current/index.html)
- [Kibana Dokümantasyonu](https://www.elastic.co/guide/en/kibana/current/index.html)

---

**Hazırlayan:** Antigravity AI Assistant  
**Tarih:** 25 Kasım 2025  
**Versiyon:** 1.0
