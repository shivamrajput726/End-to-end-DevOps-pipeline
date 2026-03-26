FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN addgroup --system app \
  && adduser --system --ingroup app app

WORKDIR /app

COPY requirements.txt requirements-dev.txt ./

RUN python -m pip install --no-cache-dir --upgrade pip \
  && pip install --no-cache-dir -r requirements.txt -r requirements-dev.txt

COPY app ./app
COPY tests ./tests
RUN chown -R app:app /app

EXPOSE 8000
USER app

CMD ["gunicorn", "-k", "uvicorn.workers.UvicornWorker", "-w", "2", "-b", "0.0.0.0:8000", "app.main:app"]
