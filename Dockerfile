FROM python:3.12-slim AS builder

WORKDIR /build
COPY requirements.txt .

RUN python -m pip install --no-cache-dir --upgrade pip \
  && pip wheel --no-cache-dir --wheel-dir /wheels -r requirements.txt


FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN addgroup --system app \
  && adduser --system --ingroup app app

WORKDIR /app

COPY --from=builder /wheels /wheels
RUN pip install --no-cache-dir /wheels/* \
  && rm -rf /wheels

COPY app ./app

EXPOSE 8000
USER app

CMD ["gunicorn", "-k", "uvicorn.workers.UvicornWorker", "-w", "2", "-b", "0.0.0.0:8000", "app.main:app"]

