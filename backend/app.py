from fastapi import FastAPI, Depends
from sqlalchemy.orm import Session
from db import Base, engine, get_db
from models import User

# Crear tablas si no existen
Base.metadata.create_all(bind=engine)

app = FastAPI()

@app.get("/")
def root():
    return {"message": "Telemetr-a-orchestrator funcionando 🚀"}

@app.get("/users")
def list_users(db: Session = Depends(get_db)):
    return db.query(User).all()

@app.post("/users")
def create_user(username: str, email: str, db: Session = Depends(get_db)):
    user = User(username=username, email=email)
    db.add(user)
    db.commit()
    db.refresh(user)
    return user

import uvicorn

if __name__ == "__main__":
    uvicorn.run("app:app", host="0.0.0.0", port=8000)
