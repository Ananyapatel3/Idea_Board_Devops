FROM python:3.11-slim

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .
RUN mkdir -p /home/app && chown -R 10001:10001 /app /home/app
ENV HOME=/home/app
USER 10001:10001

CMD ["sh", "-c", "python -c 'from database import engine; from models import Base; Base.metadata.create_all(engine)' && uvicorn main:app --host 0.0.0.0 --port 8000"]