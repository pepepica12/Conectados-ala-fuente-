#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$HOME/telemetr-a-orchestrator"
PYVER="python3"
VENV_DIR="$REPO_DIR/venv"
PORT="${PORT:-8000}"

# ===== Helpers =====
log() { printf "\n\033[1;32m[OK]\033[0m %s\n" "$*"; }
warn() { printf "\n\033[1;33m[WARN]\033[0m %s\n" "$*"; }
err() { printf "\n\033[1;31m[ERR]\033[0m %s\n" "$*"; }
ensure_dir() { mkdir -p "$1"; }

# ===== 0. Pre-chequeos =====
if [ ! -d "$REPO_DIR" ]; then
  err "No existe $REPO_DIR. Crea el repo y vuelve a ejecutar."
  exit 1
fi
cd "$REPO_DIR"

# ===== 1. Variables de entorno =====
# Prioriza ~/.bashrc; si no existe, crea .env local
if ! grep -q "DATABASE_URL=" "$HOME/.bashrc" 2>/dev/null; then
  warn "DATABASE_URL no está en ~/.bashrc. Creando .env local..."
  cat > .env << 'EOV'
# Ajusta si cambias credenciales o DB
DATABASE_URL="postgresql://neondb_owner:npg_1Jf7OIPHwYuL@ep-fancy-glade-a44j0e4a-pooler.us-east-1.aws.neon.tech/Nefosys3?sslmode=require"
EOV
fi

# Cargar variables desde ~/.bashrc y .env si existe
set +u
source "$HOME/.bashrc" 2>/dev/null || true
[ -f ".env" ] && source ".env"
set -u

if [ -z "${DATABASE_URL:-}" ]; then
  err "DATABASE_URL no está definida. Añádela a ~/.bashrc o .env y reintenta."
  exit 1
fi
log "DATABASE_URL cargada."

# ===== 2. Virtualenv =====
if [ ! -d "$VENV_DIR" ]; then
  $PYVER -m venv "$VENV_DIR"
  log "Virtualenv creada en $VENV_DIR."
fi
source "$VENV_DIR/bin/activate"
log "Virtualenv activada."

# ===== 3. Requirements =====
cat > requirements.txt << 'EOR'
fastapi==0.115.0
uvicorn==0.30.0
sqlalchemy==2.0.45
psycopg2-binary==2.9.11
EOR
pip install --upgrade pip
pip install -r requirements.txt
log "Dependencias instaladas."

# ===== 4. Archivos base =====
# db.py
cat > db.py << 'EOD'
import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base

DATABASE_URL = os.getenv("DATABASE_URL")
if not DATABASE_URL:
    raise RuntimeError("DATABASE_URL no está definida")

engine = create_engine(DATABASE_URL, echo=True, future=True)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
EOD

# models.py
cat > models.py << 'EOM'
from sqlalchemy import Column, Integer, String
from db import Base

class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    username = Column(String, unique=True, index=True, nullable=False)
    email = Column(String, unique=True, index=True, nullable=False)
EOM

# app.py (FastAPI)
cat > app.py << 'EOA'
from fastapi import FastAPI, Depends
from sqlalchemy.orm import Session
from db import Base, engine, get_db
from models import User

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
EOA

log "Archivos db.py, models.py y app.py listos."

# ===== 5. Migraciones (crear tablas) =====
$PYVER - << 'PYCODE'
from db import Base, engine
from models import User
print("Creando tablas en Neon...")
Base.metadata.create_all(bind=engine)
print("Listo ✅")
PYCODE
log "Migraciones aplicadas."

# ===== 6. Pruebas rápidas de conexión =====
$PYVER - << 'PYCODE'
from sqlalchemy import text
from db import engine
with engine.connect() as conn:
    print("Ping:", conn.execute(text("SELECT 1")).scalar())
PYCODE
log "Conexión a Neon verificada."

# ===== 7. Config Railway/Vercel =====
# Procfile
cat > Procfile << 'EOP'
web: uvicorn app:app --host 0.0.0.0 --port $PORT
EOP

# vercel.json
cat > vercel.json << 'EOVJ'
{
  "version": 2,
  "builds": [
    { "src": "app.py", "use": "@vercel/python" },
    { "src": "package.json", "use": "@vercel/next" }
  ],
  "routes": [
    { "src": "/api/(.*)", "dest": "app.py" },
    { "src": "/(.*)", "dest": "/" }
  ]
}
EOVJ

log "Procfile y vercel.json generados."

# ===== 8. GitHub Actions =====
ensure_dir ".github/workflows"
cat > .github/workflows/deploy.yml << 'EOY'
name: Deploy Telemetr-a-orchestrator
on:
  push:
    branches: [ main ]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.13'
      - name: Install dependencies
        run: |
          python -m pip install --upgrade pip
          pip install -r requirements.txt
      - name: Run migrations
        env:
          DATABASE_URL: ${{ secrets.DATABASE_URL }}
        run: |
          python - << 'PYCODE'
          from db import Base, engine
          from models import User
          print("Creando tablas en Neon...")
          Base.metadata.create_all(bind=engine)
          print("Listo ✅")
          PYCODE
      - name: Run tests
        env:
          DATABASE_URL: ${{ secrets.DATABASE_URL }}
        run: |
          python - << 'PYCODE'
          from sqlalchemy import text
          from db import engine
          with engine.connect() as conn:
              print("Ping:", conn.execute(text("SELECT 1")).scalar())
          PYCODE
EOY

log "Workflow de GitHub Actions listo."

# ===== 9. Git commit & push =====
git add db.py models.py app.py requirements.txt Procfile vercel.json .github/workflows/deploy.yml .env || true
git commit -m "Orquestación completa: backend, DB, CI/CD, Railway, Vercel" || warn "Nada que commitear."
git push origin main || warn "Push falló o no hay remoto configurado."

# ===== 10. Arranque local =====
warn "Arrancando local en http://localhost:${PORT} (CTRL+C para salir)"
uvicorn app:app --host 0.0.0.0 --port "$PORT"
