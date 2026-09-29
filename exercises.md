# Phiếu Phản Ánh — K4 Level 3B, Ngày 12

> **Bài làm cá nhân.** Trả lời bằng lời của chính bạn, dựa trên những gì bạn
> quan sát được khi chạy code — không sao chép đáp án của người khác.
>
> Cách trả lời: thay dòng placeholder "Câu trả lời của bạn" dưới mỗi câu bằng câu trả lời.
> `grade.py` đếm số câu đã trả lời (15 điểm cho 10 câu).
>
> Họ và tên: Trần Thị Thu Trang  Mã học viên: 2A202602581

---

### Câu 1 — Fail fast (CP1)

Trong `Settings`, `agent_api_key` không có giá trị mặc định nên app chết ngay
khi khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà
việc "chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.

> Khi deploy lên Render, `AGENT_API_KEY` được khai báo `sync: false` trong `render.yaml`, nghĩa là
> phải tự nhập tay trên dashboard. Giả sử tôi quên nhập hoặc tạo thêm một service mới mà quên set biến này:
> - **Có mặc định `"changeme"`:** app vẫn khởi động bình thường, `/health` trả 200, Render báo "Live",
>   nên tôi tưởng mọi thứ ổn. Nhưng URL là công khai, và `changeme` là giá trị ai cũng đoán được (nó còn nằm
>   ngay trong source trên GitHub). Bot quét Internet gọi `/ask` bằng khóa đó, mỗi lần gọi là tôi trả tiền LLM,
>   và tôi chỉ phát hiện ra khi nhìn hóa đơn.
> - **Không có mặc định:** `Settings()` ném `ValidationError: agent_api_key Field required` ngay lúc khởi động,
>   container không lên được, health check fail và deploy báo đỏ. Tôi thấy lỗi ngay khi còn đang ngồi trước
>   màn hình deploy và sửa trong một phút, không có request nào lọt vào.
>
> Test `test_thieu_api_key_thi_fail_fast` kiểm tra đúng hành vi này: xóa biến `AGENT_API_KEY` thì
> `Settings()` phải báo `ValidationError`.

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/ask` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.

> Dòng log thật lấy từ `docker compose logs agent` sau khi gọi `/ask`:
> ```json
> {"event": "ask_completed", "level": "info", "timestamp": "2026-09-29T04:25:17.028973+00:00", "user_id": "sv-rate", "tokens_in": 392, "tokens_out": 43, "cost_usd": 8.46e-05}
> ```
> Hai việc làm được mà `print("đã trả lời xong")` không làm được:
> 1. **Lọc và tổng hợp theo trường:** lọc `event == "ask_completed"`, gom theo `user_id` rồi cộng `cost_usd`
>    để biết user nào tiêu nhiều tiền nhất hôm nay; hoặc cộng `tokens_in` để thấy prompt đang phình to.
>    Với `print` thì không biết ai hỏi, tốn bao nhiêu, nên không cộng được gì.
> 2. **Đếm theo thời gian và đặt cảnh báo:** nhờ `timestamp` chuẩn ISO-8601 (UTC) và `level`, hệ thống log
>    trên cloud có thể đếm số dòng `level == "error"` trong 5 phút gần nhất và bắn cảnh báo khi vượt ngưỡng.
>    Dòng `print` không có thời gian hay mức độ nên máy không phân loại được.
>
> Điều kiện là mỗi event nằm trên **một dòng** (không dùng `indent`), vì cloud gom log theo từng dòng.
> Tôi cũng thấy log `service_started` và `service_stopped` ở cùng định dạng khi bật và tắt container.

---

### Câu 3 — Kích thước image (CP2)

Build cả hai phiên bản và ghi lại số đo thật:

```bash
docker build -f <Dockerfile-1-stage> -t agent:single .
docker build -t agent:multi .
docker images | grep agent
```

| Bản | Dung lượng |
|-----|-----------|
| 1 stage (bản đầu) | 1730 MB (1.73GB) |
| Multi-stage | 271 MB |

Giải thích: phần dung lượng chênh lệch đó là những gì?

> Tôi lưu Dockerfile gốc thành một file riêng rồi build cả hai bản. Bản multi-stage nhỏ hơn khoảng **6,4 lần**
> (chênh khoảng 1,46GB). Phần chênh lệch gồm:
> - **Base image:** bản 1 stage dùng `python:3.11` đầy đủ (dựa trên Debian đầy đủ). Nó kèm trình biên dịch
>   gcc/build-essential, header file của nhiều thư viện C, git, curl và rất nhiều công cụ hệ thống. Những thứ
>   này chỉ cần khi *cài đặt*, không cần khi *chạy*. Bản mới dùng `python:3.11-slim` chỉ có Python tối thiểu.
>   Đây là phần chênh lớn nhất.
> - **Cache của pip:** bản cũ `pip install` không có `--no-cache-dir` nên các file tải về nằm lại trong image.
>   Bản mới cài ở stage `builder` với `--no-cache-dir`, rồi chỉ `COPY --from=builder /install` sang stage runtime,
>   nên mọi thứ thừa của quá trình cài đặt bị bỏ lại cùng stage `builder`.
> - **File thừa do `COPY . .`:** bản cũ chép cả thư mục (tests, tài liệu .md, có thể cả `.venv`, `.git` nếu
>   `.dockerignore` sơ sài). Bản mới chỉ chép `app/` và `utils/`, kết hợp `.dockerignore` đầy đủ.
>
> Image nhỏ giúp mỗi lần build, push và deploy lên Render nhanh hơn, đồng thời ít phần mềm hơn cũng nghĩa là
> ít lỗ hổng bảo mật tiềm ẩn hơn.

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

> Tôi thêm một dòng trống vào cuối `app/main.py` rồi chạy `docker build --progress=plain`. Kết quả thật:
> ```
> [builder 3/4] COPY requirements.txt .       CACHED
> [builder 4/4] RUN pip install ...           CACHED
> [runtime 2/6] COPY --from=builder ...       CACHED
> [runtime 3/6] RUN useradd ...               CACHED
> [runtime 4/6] WORKDIR /app                  CACHED
> [runtime 5/6] COPY app ./app                chạy lại (0.0s)
> [runtime 6/6] COPY utils ./utils            chạy lại (0.1s)
> ```
> - **Dùng lại từ cache:** toàn bộ stage `builder` (kể cả `pip install`, bước lâu nhất), bước copy thư viện sang
>   runtime, tạo user và `WORKDIR`. Lý do là `requirements.txt` không đổi, nên Docker thấy input các bước đó
>   giống hệt lần trước.
> - **Chạy lại:** chỉ `COPY app ./app`, vì file trong `app/` đã đổi, và mọi layer sau nó (`COPY utils`),
>   vì Docker hủy cache từ layer đầu tiên thay đổi trở đi. Cả lần build mất chưa tới 1 giây.
>
> Nếu đặt `COPY . .` **trước** `RUN pip install`, sửa bất kỳ ký tự nào trong code cũng làm layer `COPY . .`
> thay đổi. Mọi layer sau nó, trong đó có `pip install`, mất cache và phải cài lại toàn bộ thư viện
> (fastapi, uvicorn, redis, pydantic...) mỗi lần build. Build sẽ mất vài phút thay vì vài giây.

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

> Chuỗi sự kiện nếu container chạy bằng root:
> 1. Code hoặc một thư viện Python có lỗ hổng (ví dụ lỗi cho phép thực thi lệnh từ input của người dùng,
>    hay một thư viện bị cài mã độc). Kẻ tấn công gửi request đặc biệt tới `/ask` và chạy được lệnh shell
>    bên trong container.
> 2. Vì process uvicorn chạy bằng **root**, lệnh đó cũng chạy với quyền root trong container. Kẻ tấn công đọc
>    được biến môi trường (lấy `AGENT_API_KEY`, `REDIS_URL`), sửa code của app, cài thêm công cụ.
> 3. Container không phải máy ảo: nó dùng chung kernel với máy host. Root trong container chính là UID 0 trên
>    host. Chỉ cần một cấu hình lỏng (mount thư mục host vào, mount `docker.sock`, chạy `--privileged`) hoặc
>    một lỗ hổng kernel/container runtime, kẻ tấn công "thoát" ra ngoài và có ngay **quyền root trên host**,
>    kiểm soát mọi container khác và toàn bộ máy.
>
> Lệnh `USER appuser` (UID 10001) cắt chuỗi ở **bước 2**: lệnh của kẻ tấn công chỉ có quyền của một user
> thường. Họ không cài được gói hệ thống, không sửa được file ngoài quyền của `appuser`, và nếu thoát được
> ra host thì cũng chỉ là một UID không có đặc quyền. Tôi đã kiểm tra thật bằng
> `docker compose exec agent whoami`, kết quả là `appuser`, không phải `root`.

---

### Câu 6 — Cửa sổ trượt (CP3)

Rate limit của bạn dùng sliding window 60 giây. Nếu thay bằng cách đếm theo
phút đồng hồ (reset lúc giây 00), một người dùng có thể gửi tối đa bao nhiêu
request trong 2 giây liên tiếp khi hạn mức là 10/phút? Giải thích cách đạt được
con số đó.

> **Tối đa 20 request trong 2 giây.** Cách đạt được:
> - Lúc 10:00:59 gửi 10 request. Tất cả được tính vào "phút 10:00", đúng hạn mức 10, nên đều qua.
> - Lúc 10:01:00 bộ đếm reset về 0. Lúc 10:01:00 đến 10:01:01 gửi tiếp 10 request, được tính vào
>   "phút 10:01", cũng đều qua.
> - Tổng: 20 request trong khoảng 2 giây, gấp đôi hạn mức mà vẫn "đúng luật".
>
> Với sliding window, mỗi lần gọi tôi đếm số request trong **60 giây ngay trước thời điểm hiện tại**
> (`zremrangebyscore` xóa các request cũ hơn `now - 60`, rồi `zcard` đếm). Ở lúc 10:01:00, 10 request lúc
> 10:00:59 vẫn còn trong cửa sổ, nên request thứ 11 bị chặn 429. Trong bất kỳ 60 giây nào cũng không quá 10.
> Khi thử thật 15 request liên tiếp, tôi nhận `200` ×10 rồi `429` ×5, kèm header `retry-after: 60`, và
> `ZCARD ratelimit:sv-rate = 10`, tức các request bị chặn không bị ghi vào sổ.

---

### Câu 7 — Rate limit và cost guard (CP3)

Hai cơ chế này khác nhau ở điểm nào? Cho một tình huống mà rate limit cho qua
nhưng cost guard phải chặn, và một tình huống ngược lại.

> **Khác nhau:** rate limit giới hạn **số lần gọi** trong một khoảng ngắn (10 request / 60 giây, lỗi 429) để
> chống spam và bảo vệ server. Cost guard giới hạn **số tiền** tích lũy trong một khoảng dài
> (10 USD / tháng / user, key `cost:<user>:<YYYY-MM>`, lỗi 402) để bảo vệ ngân sách. Rate limit không biết
> một request đắt hay rẻ; cost guard không biết request đến nhanh hay chậm.
>
> - **Rate limit cho qua nhưng cost guard chặn:** một user chỉ gọi 5 lần/phút (dưới hạn mức 10), nhưng mỗi lần
>   gửi câu hỏi rất dài cộng lịch sử hội thoại dài, mỗi lần hàng chục nghìn token. Họ đều đặn gọi như vậy suốt
>   nhiều ngày, chưa bao giờ vượt 10/phút, nhưng tổng chi phí tháng chạm 10 USD. Từ đó mọi request bị chặn 402
>   cho đến tháng sau. Tôi đã thử bằng cách set `cost:sv-test:<tháng>` = 999 thì `/ask` trả 402 ngay.
> - **Cost guard cho qua nhưng rate limit chặn:** một script lỗi gọi `/ask` liên tục với câu hỏi ngắn `"test"`.
>   Mỗi lần chỉ tốn khoảng 0,00008 USD nên ngân sách gần như không suy chuyển, nhưng tới request thứ 11 trong
>   cùng một phút thì bị 429. Đây đúng là thí nghiệm 15 request tôi đã chạy: 10 lần 200, 5 lần 429.
>
> Vì vậy cần cả hai lớp, và cả hai đều phải kiểm tra **trước** khi gọi LLM, vì tiền mất ở bước gọi LLM.

---

### Câu 8 — /health khác /ready (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

> Thứ tự sự kiện nếu gộp làm một endpoint có kiểm tra Redis:
> 1. Redis mất kết nối.
> 2. Cả 3 container gọi Redis thất bại, nên endpoint chung trả 503 **cùng lúc** ở cả 3.
> 3. Orchestrator coi đó là liveness fail: sau vài lần health check liên tiếp thất bại (ví dụ 3 lần × 10 giây),
>    nó đánh dấu **cả 3** là unhealthy và **khởi động lại cả 3**.
> 4. Trong lúc 3 container đang restart, không còn instance nào phục vụ, nên mọi request (kể cả những request
>    không cần Redis) đều lỗi 502/503. Request đang xử lý dở bị cắt ngang.
> 5. Redis quay lại sau 30 giây, nhưng các container vẫn đang khởi động (hoặc lại fail vì khởi động đúng lúc
>    Redis chưa sẵn sàng, rồi restart vòng lặp). Hệ thống hồi phục chậm hơn nhiều so với 30 giây mất Redis.
>
> Kết quả: một sự cố nhỏ ở một dependency thành **sập toàn hệ thống**.
>
> Khi tách riêng, tôi đã thử thật bằng `docker compose stop redis`:
> - `/health` vẫn trả `200 {"status":"ok"}`, và sau 35 giây container vẫn `healthy`, `restarts=0`.
>   Không restart vì process vẫn sống.
> - `/ready` trả `503 {"status":"not ready","redis":false}`, chỉ báo load balancer tạm ngừng gửi traffic.
> - `docker compose start redis` xong thì `/ready` tự trở về `200 {"status":"ready","redis":true}`,
>   không cần làm gì thêm.

---

### Câu 9 — Stateless (CP4)

Chạy `docker compose up --scale agent=3` rồi gọi `/ask` nhiều lần với cùng một
`X-User-Id`. Quan sát `history_length` trong response. Nếu lịch sử được lưu
trong một dict Python thay vì Redis, bạn sẽ thấy con số đó thay đổi thế nào?

> Tôi chạy 3 container agent ở 3 cổng 8000, 8001, 8002 (`AGENT_PORTS=8000-8002 docker compose up -d
> --scale agent=3`) và gọi xoay vòng với cùng `X-User-Id: sv-scale` để chắc chắn mỗi lượt vào một container
> khác. Kết quả thật:
> ```
> lượt 1 → cổng 8000 → history_length=0
> lượt 2 → cổng 8001 → history_length=2
> lượt 3 → cổng 8002 → history_length=4
> lượt 4 → cổng 8000 → history_length=6
> lượt 5 → cổng 8001 → history_length=8
> lượt 6 → cổng 8002 → history_length=10
> ```
> Con số tăng đều thêm 2 mỗi lượt (1 message user + 1 message assistant) dù container thay đổi liên tục, vì
> cả 3 cùng đọc và ghi key `history:sv-scale` trong một Redis (`LLEN` = 12 sau 6 lượt).
>
> Nếu lưu trong dict Python, mỗi container có dict riêng trong RAM của nó:
> - lượt 1 vào A → 0; lượt 2 vào B → **0** (B chưa thấy gì); lượt 3 vào C → **0**;
> - lượt 4 quay lại A → **2** (A chỉ nhớ lượt 1); lượt 5 vào B → **2**; lượt 6 vào C → **2**.
>
> Con số nhảy lung tung, agent "mất trí nhớ" ngẫu nhiên tùy request rơi vào container nào. Thêm nữa, khi
> container restart hoặc deploy bản mới thì dict mất sạch. Test `test_state_khong_nam_trong_process` mô phỏng
> đúng điều này: hai object store khác nhau phải thấy chung dữ liệu.

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

> Lần deploy lên Render (Blueprint từ `render.yaml`) chạy thành công ngay; `/health` và `/ready` đều 200.
> Lý do là tôi đã gặp và sửa lỗi nghiêm trọng nhất khi chạy thử image production bằng Docker trên máy,
> trước khi deploy. Lỗi đó sẽ xảy ra y hệt trên cloud mỗi lần deploy bản mới:
>
> **Lỗi: container không tắt êm khi nhận SIGTERM, bị kill cứng sau grace period.**
> - **Dấu hiệu:** `docker compose stop agent` mất **21 giây** (đúng bằng `stop_grace_period: 20s` cộng 1 giây),
>   và log không có dòng `Shutting down` hay `service_stopped`. Không có thông báo lỗi nào, chỉ thấy app bị
>   SIGKILL. Trên Render, điều này nghĩa là mỗi lần deploy bản mới, các request đang xử lý dở sẽ bị cắt ngang.
> - **Tìm nguyên nhân:** tôi đã viết `lifecycle.install()` và cả 5 test graceful shutdown đều pass, nên lỗi
>   không nằm ở code Python. Tôi nhìn lại lệnh khởi động trong Dockerfile:
>   `CMD ["sh", "-c", "uvicorn app.main:app ... --port ${PORT:-8000}"]`. Phải dùng `sh -c` để shell hiểu
>   `${PORT:-8000}`, nhưng như vậy `sh` trở thành **PID 1** của container, còn uvicorn là process con.
>   Docker gửi SIGTERM tới PID 1 là `sh`, và `sh` không chuyển tiếp tín hiệu cho uvicorn.
> - **Sửa:** thêm `exec`: `CMD ["sh", "-c", "exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]`.
>   `exec` thay thế process `sh` bằng uvicorn, nên uvicorn thành PID 1 và nhận SIGTERM trực tiếp.
> - **Kết quả sau khi sửa:** `docker compose stop agent` xong trong **0 giây**, log đúng trình tự:
>   `Shutting down` → `{"event": "service_stopped", ...}` → `Application shutdown complete` →
>   `Finished server process [1]` (PID 1 chính là uvicorn).
>
> Bài học: test tự động không bắt được lỗi này. Phải chạy image thật và quan sát thời gian tắt cùng log.
> Cũng trong lúc chạy thử, tôi gặp một lỗi khác: container nhận cổng 8001 thay vì 8000 do dùng dải cổng
> trong compose. Tôi sửa thành cổng cố định `${AGENT_PORTS:-8000}:8000`.
