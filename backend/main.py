from fastapi import FastAPI, Depends, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from sqlalchemy import text

# Support both relative imports (when run as module) and absolute imports (when run directly)
try:
    from . import models, schemas, crud
    from .database import engine, Base, get_db, SessionLocal, migrate_database
except ImportError:
    # Fallback for direct execution
    import models, schemas, crud
    from database import engine, Base, get_db, SessionLocal, migrate_database


# Migrate existing database if needed (add missing columns)
# This must be called BEFORE create_all() to ensure columns exist
migrate_database()

# Create tables on startup for MVP
# This will create new tables if they don't exist, but won't modify existing ones
Base.metadata.create_all(bind=engine)

# Ensure a default demo user exists for the client mock (id = 1)
# Use raw SQL to avoid SQLAlchemy schema caching issues
try:
    with SessionLocal() as seed_db:
        # Check if user exists using raw SQL to avoid schema issues
        result = seed_db.execute(text("SELECT id FROM users WHERE id = 1"))
        if result.first() is None:
            seed_db.execute(text("INSERT INTO users (id, username) VALUES (1, 'demo')"))
            seed_db.commit()
            print("✓ Created default demo user")
        else:
            print("✓ Default demo user already exists")
except Exception as e:
    print(f"Warning: Could not create default user: {e}")
    # Try using ORM as fallback
    try:
        with SessionLocal() as seed_db:
            if not seed_db.query(models.User).filter(models.User.id == 1).first():
                demo = models.User(id=1, username="demo")
                seed_db.add(demo)
                seed_db.commit()
    except Exception as e2:
        print(f"Warning: Could not create default user with ORM: {e2}")

app = FastAPI(title="Recipes MVP", version="0.1.0")

# Allow local dev origins (Flutter emulator/web)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/users", response_model=schemas.User)
def create_user(user: schemas.UserCreate, db: Session = Depends(get_db)):
    existing = db.query(models.User).filter(models.User.username == user.username).first()
    if existing:
        raise HTTPException(status_code=400, detail="Username already exists")
    return crud.create_user(db, user)


def truncate_password_to_72_bytes(password: str) -> str:
    """Гарантированно обрезает пароль до 72 байт в UTF-8"""
    if not password:
        return password
    
    # Метод 1: Обрезаем посимвольно до тех пор, пока длина в байтах <= 72
    result = ""
    for char in password:
        test_result = result + char
        test_bytes = test_result.encode('utf-8')
        if len(test_bytes) > 72:
            break
        result = test_result
    
    # Финальная проверка - если все еще больше 72 байт (не должно быть, но на всякий случай)
    final_bytes = result.encode('utf-8')
    if len(final_bytes) > 72:
        # Обрезаем байты напрямую
        final_bytes = final_bytes[:72]
        result = final_bytes.decode('utf-8', errors='ignore')
    
    return result


@app.post("/auth/register", response_model=schemas.User)
async def register(request: Request, db: Session = Depends(get_db)):
    """Регистрация нового пользователя"""
    try:
        # Получаем сырые данные запроса
        body = await request.json()
        
        # Обрезаем пароли до 72 байт перед валидацией
        if 'password' in body:
            body['password'] = truncate_password_to_72_bytes(body['password'])
        
        if 'password_confirm' in body:
            body['password_confirm'] = truncate_password_to_72_bytes(body['password_confirm'])
        
        # Создаем схему из обрезанных данных
        user = schemas.UserRegister(**body)
        return crud.create_user_with_password(db, user)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@app.post("/auth/login", response_model=schemas.User)
def login(credentials: schemas.UserLogin, db: Session = Depends(get_db)):
    """Вход пользователя"""
    user = crud.authenticate_user(db, credentials.email, credentials.password)
    if not user:
        raise HTTPException(status_code=401, detail="Неверный email или пароль")
    return user


@app.get("/users/{user_id}", response_model=schemas.User)
def get_user(user_id: int, db: Session = Depends(get_db)):
    user = crud.get_user(db, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user


@app.put("/users/{user_id}", response_model=schemas.User)
def update_user(user_id: int, payload: schemas.UserUpdate, db: Session = Depends(get_db)):
    updated = crud.update_user(db, user_id, payload)
    if not updated:
        raise HTTPException(status_code=404, detail="User not found")
    return updated


@app.get("/users/{user_id}/recipes", response_model=schemas.PaginatedRecipes)
def user_recipes(
    user_id: int,
    skip: int = 0,
    limit: int = 20,
    db: Session = Depends(get_db),
):
    total, items = crud.list_recipes(db, skip=skip, limit=limit, author_id=user_id)
    items_with_ratings = crud.add_ratings_to_recipes(db, items)
    return schemas.PaginatedRecipes(
        total=total,
        items=[schemas.Recipe(**item) for item in items_with_ratings]
    )


@app.get("/users/{user_id}/saved", response_model=list[schemas.Recipe])
def saved_recipes(user_id: int, db: Session = Depends(get_db)):
    return crud.list_saved_recipes(db, user_id=user_id)


@app.post("/users/{user_id}/saved/{recipe_id}", response_model=schemas.Favorite)
def save_recipe(user_id: int, recipe_id: int, db: Session = Depends(get_db)):
    if not crud.get_recipe(db, recipe_id):
        raise HTTPException(status_code=404, detail="Recipe not found")
    if not crud.get_user(db, user_id):
        raise HTTPException(status_code=404, detail="User not found")
    return crud.add_favorite(db, user_id=user_id, recipe_id=recipe_id)


@app.delete("/users/{user_id}/saved/{recipe_id}")
def unsave_recipe(user_id: int, recipe_id: int, db: Session = Depends(get_db)):
    removed = crud.remove_favorite(db, user_id=user_id, recipe_id=recipe_id)
    if not removed:
        raise HTTPException(status_code=404, detail="Favorite not found")
    return {"status": "removed"}


@app.post("/recipes", response_model=schemas.Recipe)
def create_recipe(recipe: schemas.RecipeCreate, db: Session = Depends(get_db)):
    author = crud.get_user(db, recipe.author_id)
    if not author:
        raise HTTPException(status_code=400, detail="Author does not exist")
    return crud.create_recipe(db, recipe)


@app.get("/recipes", response_model=schemas.PaginatedRecipes)
def list_all_recipes(
    skip: int = 0,
    limit: int = 20,
    author_id: int | None = None,
    search: str | None = None,
    min_rating: float | None = None,
    max_cook_time: int | None = None,
    min_cook_time: int | None = None,
    dish_type: str | None = None,  # "breakfast", "lunch", "dinner", "dessert"
    temperature: str | None = None,  # "hot", "cold"
    db: Session = Depends(get_db),
):
    total, items = crud.list_recipes(
        db, 
        skip=skip, 
        limit=limit, 
        author_id=author_id, 
        search=search,
        min_rating=min_rating,
        max_cook_time=max_cook_time,
        min_cook_time=min_cook_time,
        dish_type=dish_type,
        temperature=temperature,
    )
    items_with_ratings = crud.add_ratings_to_recipes(db, items)
    return schemas.PaginatedRecipes(
        total=total,
        items=[schemas.Recipe(**item) for item in items_with_ratings]
    )


@app.get("/recipes/search/suggestions", response_model=list[str])
def get_search_suggestions(
    q: str,
    limit: int = 10,
    db: Session = Depends(get_db),
):
    """Возвращает предложения для автодополнения поиска"""
    return crud.search_suggestions(db, q, limit=limit)


@app.get("/recipes/recommended", response_model=list[schemas.Recipe])
def recommended(limit: int = 10, db: Session = Depends(get_db)):
    recipes = crud.recommended_recipes(db, limit=limit)
    items_with_ratings = crud.add_ratings_to_recipes(db, recipes)
    return [schemas.Recipe(**item) for item in items_with_ratings]


@app.get("/recipes/{recipe_id}", response_model=schemas.Recipe)
def get_recipe(recipe_id: int, db: Session = Depends(get_db)):
    recipe = crud.get_recipe(db, recipe_id)
    if not recipe:
        raise HTTPException(status_code=404, detail="Recipe not found")
    # Вычисляем средний рейтинг, если нет оценок - возвращаем 0.0
    avg_rating = crud.get_recipe_avg_rating(db, recipe_id)
    # Получаем информацию об авторе
    author = crud.get_user(db, recipe.author_id)
    author_name = author.username if author else "Неизвестный автор"
    recipe_dict = {
        "id": recipe.id,
        "title": recipe.title,
        "description": recipe.description,
        "instructions": recipe.instructions,
        "image_url": recipe.image_url,
        "cook_time_minutes": recipe.cook_time_minutes,
        "servings": recipe.servings,
        "tags": recipe.tags,
        "created_at": recipe.created_at,
        "author_id": recipe.author_id,
        "author_name": author_name,
        "rating": avg_rating if avg_rating is not None else 0.0,
    }
    return schemas.Recipe(**recipe_dict)


@app.put("/recipes/{recipe_id}", response_model=schemas.Recipe)
def update_recipe(recipe_id: int, payload: schemas.RecipeUpdate, db: Session = Depends(get_db)):
    updated = crud.update_recipe(db, recipe_id, payload)
    if not updated:
        raise HTTPException(status_code=404, detail="Recipe not found")
    return updated


@app.delete("/recipes/{recipe_id}")
def delete_recipe(recipe_id: int, db: Session = Depends(get_db)):
    deleted = crud.delete_recipe(db, recipe_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Recipe not found")
    return {"status": "deleted"}


@app.post("/recipes/{recipe_id}/rate")
def rate_recipe(recipe_id: int, user_id: int, rating: schemas.RatingCreate, db: Session = Depends(get_db)):
    """Создает или обновляет оценку пользователя для рецепта"""
    if not crud.get_recipe(db, recipe_id):
        raise HTTPException(status_code=404, detail="Recipe not found")
    if not crud.get_user(db, user_id):
        raise HTTPException(status_code=404, detail="User not found")
    result = crud.set_rating(db, user_id=user_id, recipe_id=recipe_id, rating_value=rating.rating)
    # Возвращаем обновленный средний рейтинг и оценку пользователя
    avg_rating = crud.get_recipe_avg_rating(db, recipe_id)
    return {
        "user_rating": result.rating,
        "average_rating": avg_rating
    }


@app.get("/recipes/{recipe_id}/rating/{user_id}")
def get_user_rating(recipe_id: int, user_id: int, db: Session = Depends(get_db)):
    """Получает оценку пользователя для рецепта"""
    rating = crud.get_user_rating(db, user_id, recipe_id)
    if not rating:
        return {"rating": null}
    return {"rating": rating.rating}


@app.get("/stats")
def get_stats(db: Session = Depends(get_db)):
    return crud.stats(db)


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)

