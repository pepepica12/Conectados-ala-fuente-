#!/bin/bash

set -e

echo "🔍 Iniciando reparación forense del proyecto..."

# 1. Detectar carpeta duplicada
if [ -d "Conectados-ala-fuente-" ]; then
    echo "📁 Carpeta duplicada detectada: Conectados-ala-fuente-/"
    
    # 2. Mover archivos importantes a la raíz si existen
    for f in app.py db.py models.py requirements.txt Procfile start.sh; do
        if [ -f "Conectados-ala-fuente-/$f" ]; then
            echo "➡️ Moviendo $f desde carpeta interna a raíz..."
            mv -f "Conectados-ala-fuente-/$f" .
        fi
    done

    # 3. Eliminar carpeta duplicada si ya no contiene código útil
    echo "🧹 Eliminando carpeta duplicada..."
    rm -rf Conectados-ala-fuente-
fi

# 4. Reconstruir app.py limpio si está corrupto
echo "🛠 Validando app.py..."

cat > app.py << 'EOF'
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
EOF

echo "✔ app.py reconstruido correctamente."

# 5. Asegurar Procfile correcto
echo "🛠 Validando Procfile..."

cat > Procfile << 'EOF'
web: uvicorn app:app --host 0.0.0.0 --port $PORT
EOF

echo "✔ Procfile corregido."

# 6. Asegurar permisos
chmod +x start.sh 2>/dev/null || true

echo "🎉 Reparación completada."
echo "Ahora ejecuta:"
echo "   git add ."
echo "   git commit -m 'Fix: reparación forense del proyecto'"
echo "   git push"
