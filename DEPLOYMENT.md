# Thông Tin Deploy — Checkpoint 5

> Điền file này sau khi deploy xong. `pytest tests/test_cp5.py` đọc file này
> để tìm địa chỉ service của bạn và gọi thử.
>
> **Chỉ ghi TÊN biến môi trường, tuyệt đối không dán giá trị API key vào đây.**
> Repo này công khai — dán khóa vào là mất khóa.

## Thông Tin Học Viên

| Mục | Nội dung |
|-----|----------|
| Họ và tên | Trần Thị Thu Trang |
| Mã học viên | 2A202602581 |
| Repo | https://github.com/Trangtran1987/K4-L3B-DAY12-TranThiThuTrang-2A202602581-CloudServicesAndDeployment |

## Service

| Mục | Nội dung |
|-----|----------|
| Public URL | https://day12-agent-ld0f.onrender.com |
| Platform | Render (Blueprint từ `render.yaml`, runtime Docker, free plan) |
| Ngày deploy | 2026-09-29 |

## Biến Môi Trường Đã Set Trên Cloud

Ghi tên biến và **nguồn giá trị**, không ghi giá trị:

| Biến | Đã set | Ghi chú |
|------|--------|---------|
| `PORT` | ✅ | Render tự gán, app đọc qua `${PORT:-8000}` trong Dockerfile |
| `AGENT_API_KEY` | ✅ | nhập trong dashboard lúc tạo Blueprint (`sync: false`), không nằm trong repo |
| `REDIS_URL` | ✅ | Render Key Value `day12-redis`, nối qua `fromService` trong `render.yaml` |
| `RATE_LIMIT_PER_MINUTE` | ✅ | 10 (khai báo trong `render.yaml`) |
| `MONTHLY_BUDGET_USD` | ✅ | 10.0 (khai báo trong `render.yaml`) |
| `LOG_LEVEL` | ✅ | INFO (khai báo trong `render.yaml`) |

## Lệnh Kiểm Tra

`URL=https://day12-agent-ld0f.onrender.com`

```bash
# 1. Liveness — mong đợi 200 {"status":"ok"}
curl -i $URL/health

# 2. Readiness — mong đợi 200 {"status":"ready"} (đã nối được Redis)
curl -i $URL/ready

# 3. Không có API key — mong đợi 401
curl -i -X POST $URL/ask \
  -H "Content-Type: application/json" \
  -d '{"question":"Hello"}'

# 4. Có API key — mong đợi 200 kèm câu trả lời
curl -i -X POST $URL/ask \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $AGENT_API_KEY" \
  -H "X-User-Id: sv-test" \
  -d '{"question":"Deploy là gì?"}'

# 5. Rate limit — gọi 15 lần, những lần cuối phải trả 429
for i in $(seq 1 15); do
  curl -s -o /dev/null -w "%{http_code} " -X POST $URL/ask \
    -H "Content-Type: application/json" \
    -H "X-API-Key: $AGENT_API_KEY" \
    -H "X-User-Id: sv-test" \
    -d '{"question":"test"}'
done; echo
```

## Kết Quả Chạy Thật

```
$ curl -i $URL/health
HTTP/1.1 200 OK
Content-Type: application/json
{"status":"ok","service":"day12-agent","version":"1.0.0"}

$ curl -i $URL/ready
HTTP/1.1 200 OK
Content-Type: application/json
{"status":"ready","redis":true}

$ curl -i -X POST $URL/ask -d '{"question":"Hello"}'        # không có key
HTTP/1.1 401 Unauthorized
{"detail":"invalid or missing API key"}
```

## Ảnh Chụp Màn Hình

Đặt ảnh trong thư mục `screenshots/`:

- `screenshots/dashboard.png` — trang quản lý service trên platform
- `screenshots/health.png` — kết quả gọi `/health` từ trình duyệt hoặc curl
