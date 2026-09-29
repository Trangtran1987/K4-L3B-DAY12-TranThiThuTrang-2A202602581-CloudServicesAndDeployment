# ═══════════════════════════════════════════════════════════════════
# CP2 — Containerization (bản production-ready)
#
#   [x] Multi-stage build: `builder` cài dependency, `runtime` chỉ copy kết quả
#   [x] Base image slim
#   [x] COPY requirements.txt + pip install TRƯỚC khi COPY source code
#   [x] Chạy bằng user thường (appuser), không phải root
#   [x] HEALTHCHECK gọi /health
#   [x] Đọc cổng từ biến môi trường PORT
#
# Kiểm tra:  pytest tests/test_cp2.py -v
# Build thử: docker build -t day12-agent:prod .
# ═══════════════════════════════════════════════════════════════════

# ── Stage 1: builder — cài thư viện vào /install, stage này bị bỏ đi ──
FROM python:3.11-slim AS builder

ENV PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /build

# Chỉ copy requirements trước: sửa code không làm mất cache layer pip install
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ── Stage 2: runtime — image thật sự được deploy ──
FROM python:3.11-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8000

# Thư viện đã cài sẵn ở builder, không mang theo pip cache hay compiler
COPY --from=builder /install /usr/local

RUN useradd --create-home --uid 10001 appuser

WORKDIR /app

# Source code copy SAU cùng — layer hay thay đổi nhất
COPY --chown=appuser:appuser app ./app
COPY --chown=appuser:appuser utils ./utils

USER appuser

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import os, urllib.request; urllib.request.urlopen(f'http://127.0.0.1:{os.environ.get(\"PORT\", \"8000\")}/health', timeout=3).read()" || exit 1

# `exec` để uvicorn thay thế sh làm PID 1 → nhận được SIGTERM trực tiếp
# (không có exec, sh nuốt SIGTERM và container bị SIGKILL sau grace period)
CMD ["sh", "-c", "exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
