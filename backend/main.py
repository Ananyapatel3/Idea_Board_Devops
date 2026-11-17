import logging
import os

import models
import schemas
from fastapi import Depends, FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text
from sqlalchemy.orm import Session

from database import Base, engine, get_db

Base.metadata.create_all(bind=engine)

logger = logging.getLogger(__name__)
app = FastAPI(title="Idea Board API")

origins = [
    origin.strip()
    for origin in os.environ.get("CORS_ORIGINS", "http://localhost:3000").split(",")
    if origin.strip()
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
def health_check(db: Session = Depends(get_db)):
    try:
        db.execute(text("SELECT 1"))
        return {"status": "ok", "db": "connected"}
    except Exception:
        logger.exception("Database health check failed")
        raise HTTPException(status_code=503, detail={"status": "error", "db": "unreachable"})


@app.get("/live")
def liveness_check():
    return {"status": "ok"}


@app.get("/api/ideas", response_model=list[schemas.IdeaResponse])
def get_ideas(db: Session = Depends(get_db)):
    return db.query(models.Idea).order_by(models.Idea.created_at.desc()).all()


@app.post("/api/ideas", response_model=schemas.IdeaResponse, status_code=201)
def create_idea(idea: schemas.IdeaCreate, db: Session = Depends(get_db)):
    db_idea = models.Idea(content=idea.content)
    db.add(db_idea)
    db.commit()
    db.refresh(db_idea)
    return db_idea