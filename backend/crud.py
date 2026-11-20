from typing import List, Optional, Tuple
from datetime import datetime
from sqlalchemy.orm import Session
from sqlalchemy import func, or_, and_

try:
    from . import models, schemas
except ImportError:
    import models, schemas

# Используем bcrypt напрямую для избежания проблем совместимости с passlib
try:
    import bcrypt
    _bcrypt_available = True
except ImportError:
    try:
        from passlib.context import CryptContext
        pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
        _bcrypt_available = False
    except ImportError:
        raise ImportError("Необходимо установить bcrypt или passlib[bcrypt]")


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


def create_user(db: Session, user: schemas.UserCreate) -> models.User:
    db_user = models.User(**user.model_dump())
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user


def create_user_with_password(db: Session, user: schemas.UserRegister) -> models.User:
    """Создает пользователя с хешированным паролем"""
    # Проверяем, существует ли email
    existing = db.query(models.User).filter(models.User.email == user.email).first()
    if existing:
        raise ValueError("Email уже зарегистрирован")
    
    # Проверяем, существует ли username
    existing_username = db.query(models.User).filter(models.User.username == user.username).first()
    if existing_username:
        raise ValueError("Имя пользователя уже занято")
    
    # Обрезаем пароль до 72 байт для совместимости с bcrypt
    # КРИТИЧЕСКИ ВАЖНО: bcrypt имеет жесткое ограничение в 72 байта
    password = truncate_password_to_72_bytes(user.password or "")
    
    # Финальная проверка перед хешированием
    password_bytes_final = password.encode('utf-8')
    if len(password_bytes_final) > 72:
        # Если все еще больше (не должно быть, но на всякий случай)
        password = password_bytes_final[:72].decode('utf-8', errors='ignore')
    
    # Хешируем пароль (теперь гарантированно <= 72 байта)
    if _bcrypt_available:
        # Используем bcrypt напрямую
        password_bytes = password.encode('utf-8')
        # Гарантируем, что длина <= 72 байта
        if len(password_bytes) > 72:
            password_bytes = password_bytes[:72]
            password = password_bytes.decode('utf-8', errors='ignore')
        password_hash = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')
    else:
        # Fallback на passlib
        password_hash = pwd_context.hash(password)
    
    db_user = models.User(
        username=user.username,
        email=user.email,
        password_hash=password_hash,
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user


def authenticate_user(db: Session, email: str, password: str) -> Optional[models.User]:
    """Проверяет email и пароль, возвращает пользователя если верно"""
    user = db.query(models.User).filter(models.User.email == email).first()
    if not user:
        return None
    if not user.password_hash:
        return None
    # Bcrypt имеет ограничение на длину пароля в 72 байта
    # Обрезаем пароль до 72 байт перед проверкой (так же, как при регистрации)
    password_to_verify = password
    password_bytes = password_to_verify.encode('utf-8')
    if len(password_bytes) > 72:
        # Обрезаем до 72 байт
        password_bytes = password_bytes[:72]
        # Декодируем обратно, игнорируя ошибки если байты обрезаны посередине символа
        password_to_verify = password_bytes.decode('utf-8', errors='ignore')
    
    # Проверяем пароль
    if _bcrypt_available:
        # Используем bcrypt напрямую
        try:
            if not bcrypt.checkpw(password_to_verify.encode('utf-8'), user.password_hash.encode('utf-8')):
                return None
        except:
            return None
    else:
        # Fallback на passlib
        if not pwd_context.verify(password_to_verify, user.password_hash):
            return None
    return user


def get_user_by_email(db: Session, email: str) -> Optional[models.User]:
    """Получает пользователя по email"""
    return db.query(models.User).filter(models.User.email == email).first()


def get_user(db: Session, user_id: int) -> Optional[models.User]:
    return db.query(models.User).filter(models.User.id == user_id).first()


def update_user(db: Session, user_id: int, payload: schemas.UserUpdate) -> Optional[models.User]:
    db_user = db.query(models.User).filter(models.User.id == user_id).first()
    if not db_user:
        return None
    for key, value in payload.model_dump(exclude_unset=True).items():
        setattr(db_user, key, value)
    db.commit()
    db.refresh(db_user)
    return db_user


def get_or_create_user(db: Session, username: str) -> models.User:
    existing = db.query(models.User).filter(models.User.username == username).first()
    if existing:
        return existing
    return create_user(db, schemas.UserCreate(username=username))


def create_recipe(db: Session, recipe: schemas.RecipeCreate) -> models.Recipe:
    db_recipe = models.Recipe(**recipe.model_dump())
    db.add(db_recipe)
    db.commit()
    db.refresh(db_recipe)
    return db_recipe


def update_recipe(db: Session, recipe_id: int, payload: schemas.RecipeUpdate) -> Optional[models.Recipe]:
    db_recipe = db.query(models.Recipe).filter(models.Recipe.id == recipe_id).first()
    if not db_recipe:
        return None
    for key, value in payload.model_dump(exclude_unset=True).items():
        setattr(db_recipe, key, value)
    db.commit()
    db.refresh(db_recipe)
    return db_recipe


def delete_recipe(db: Session, recipe_id: int) -> bool:
    deleted = db.query(models.Recipe).filter(models.Recipe.id == recipe_id).delete()
    db.commit()
    return deleted > 0


def get_recipe(db: Session, recipe_id: int) -> Optional[models.Recipe]:
    return db.query(models.Recipe).filter(models.Recipe.id == recipe_id).first()


def list_recipes(
    db: Session,
    skip: int = 0,
    limit: int = 20,
    author_id: Optional[int] = None,
    search: Optional[str] = None,
    min_rating: Optional[float] = None,
    max_cook_time: Optional[int] = None,
    min_cook_time: Optional[int] = None,
    dish_type: Optional[str] = None,  # "breakfast", "lunch", "dinner", "dessert"
    temperature: Optional[str] = None,  # "hot", "cold"
) -> Tuple[int, List[models.Recipe]]:
    query = db.query(models.Recipe)
    if author_id is not None:
        query = query.filter(models.Recipe.author_id == author_id)
    
    # Фильтр по времени готовки
    if min_cook_time is not None:
        query = query.filter(models.Recipe.cook_time_minutes >= min_cook_time)
    if max_cook_time is not None:
        query = query.filter(models.Recipe.cook_time_minutes <= max_cook_time)
    
    # Фильтр по типу блюда (поиск в тегах)
    if dish_type:
        dish_type_lower = dish_type.lower()
        query = query.filter(
            and_(
                models.Recipe.tags.isnot(None),
                or_(
                    func.lower(models.Recipe.tags).like(f"%{dish_type_lower}%"),
                    func.lower(models.Recipe.title).like(f"%{dish_type_lower}%"),
                )
            )
        )
    
    # Фильтр по температуре (поиск в тегах и названии)
    if temperature:
        temp_lower = temperature.lower()
        if temp_lower == "hot":
            # Горячее: ищем слова "горяч", "тепл", "hot", "warm" в тегах или названии
            query = query.filter(
                or_(
                    and_(
                        models.Recipe.tags.isnot(None),
                        or_(
                            func.lower(models.Recipe.tags).like("%горяч%"),
                            func.lower(models.Recipe.tags).like("%тепл%"),
                            func.lower(models.Recipe.tags).like("%hot%"),
                            func.lower(models.Recipe.tags).like("%warm%"),
                        )
                    ),
                    func.lower(models.Recipe.title).like("%горяч%"),
                    func.lower(models.Recipe.title).like("%тепл%"),
                )
            )
        elif temp_lower == "cold":
            # Холодное: ищем слова "холод", "cold", "cool" в тегах или названии
            query = query.filter(
                or_(
                    and_(
                        models.Recipe.tags.isnot(None),
                        or_(
                            func.lower(models.Recipe.tags).like("%холод%"),
                            func.lower(models.Recipe.tags).like("%cold%"),
                            func.lower(models.Recipe.tags).like("%cool%"),
                        )
                    ),
                    func.lower(models.Recipe.title).like("%холод%"),
                )
            )
    
    if search and search.strip():
        # Улучшенный поиск: по названию, описанию и тегам
        search_clean = search.strip().lower()
        search_term = f"%{search_clean}%"
        
        # Создаем условия поиска
        conditions = []
        
        # ПРИОРИТЕТ 1: Точное совпадение полного названия (самый высокий приоритет)
        conditions.append(func.lower(models.Recipe.title) == search_clean)
        
        # ПРИОРИТЕТ 2: Название начинается с запроса
        conditions.append(func.lower(models.Recipe.title).like(f"{search_clean}%"))
        
        # ПРИОРИТЕТ 3: Название содержит полный запрос
        conditions.append(func.lower(models.Recipe.title).like(search_term))
        
        # ПРИОРИТЕТ 4: Поиск по отдельным словам в названии
        search_words = search_clean.split()
        for word in search_words:
            if len(word) > 2:  # Игнорируем очень короткие слова
                conditions.append(func.lower(models.Recipe.title).like(f"%{word}%"))
        
        # ПРИОРИТЕТ 5: Поиск по описанию (полный запрос)
        conditions.append(
            and_(
                models.Recipe.description.isnot(None),
                func.lower(models.Recipe.description).like(search_term)
            )
        )
        
        # ПРИОРИТЕТ 6: Поиск по описанию (отдельные слова)
        for word in search_words:
            if len(word) > 2:
                conditions.append(
                    and_(
                        models.Recipe.description.isnot(None),
                        func.lower(models.Recipe.description).like(f"%{word}%")
                    )
                )
        
        # ПРИОРИТЕТ 7: Поиск по тегам
        conditions.append(
            and_(
                models.Recipe.tags.isnot(None),
                func.lower(models.Recipe.tags).like(search_term)
            )
        )
        
        for word in search_words:
            if len(word) > 2:
                conditions.append(
                    and_(
                        models.Recipe.tags.isnot(None),
                        func.lower(models.Recipe.tags).like(f"%{word}%")
                    )
                )
        
        if conditions:
            # Используем OR для всех условий
            query = query.filter(or_(*conditions))
    
    # Фильтр по минимальному рейтингу (через подзапрос)
    if min_rating is not None:
        subquery = select(
            models.Rating.recipe_id,
            func.avg(models.Rating.rating).label('avg_rating')
        ).group_by(models.Rating.recipe_id).having(
            func.avg(models.Rating.rating) >= min_rating
        ).subquery()
        query = query.join(subquery, models.Recipe.id == subquery.c.recipe_id)
    
    total = query.count()
    
    # Сортируем результаты: сначала по релевантности (точные совпадения выше), потом по дате
    # Для этого используем CASE WHEN для приоритизации точных совпадений
    if search and search.strip():
        search_clean = search.strip().lower()
        relevance_order = case(
            (func.lower(models.Recipe.title) == search_clean, 1),  # Точное совпадение
            (func.lower(models.Recipe.title).like(f"{search_clean}%"), 2),  # Начинается с
            (func.lower(models.Recipe.title).like(f"%{search_clean}%"), 3),  # Содержит
            else_=4  # Остальные
        )
        items = query.order_by(relevance_order, models.Recipe.created_at.desc()).offset(skip).limit(limit).all()
    else:
        items = query.order_by(models.Recipe.created_at.desc()).offset(skip).limit(limit).all()
    
    return total, items


def search_suggestions(db: Session, query: str, limit: int = 10) -> List[str]:
    """Возвращает предложения для автодополнения поиска"""
    if not query or len(query.strip()) < 2:
        return []
    
    query_clean = query.strip().lower()
    search_term = f"%{query_clean}%"
    
    # Получаем уникальные названия рецептов, которые начинаются с запроса
    recipes = db.query(models.Recipe.title).filter(
        func.lower(models.Recipe.title).like(search_term)
    ).distinct().limit(limit).all()
    
    suggestions = [title[0] for title in recipes]
    
    # Также получаем популярные теги
    if len(suggestions) < limit:
        tags_query = db.query(models.Recipe.tags).filter(
            and_(
                models.Recipe.tags.isnot(None),
                func.lower(models.Recipe.tags).like(search_term)
            )
        ).distinct().limit(limit - len(suggestions)).all()
        
        for tag_str in tags_query:
            if tag_str[0]:
                tags = [t.strip() for t in tag_str[0].split(',') if t.strip().lower().startswith(query_clean)]
                suggestions.extend(tags[:limit - len(suggestions)])
                if len(suggestions) >= limit:
                    break
    
    return suggestions[:limit]


def recommended_recipes(db: Session, limit: int = 10) -> List[models.Recipe]:
    return (
        db.query(models.Recipe)
        .order_by(models.Recipe.created_at.desc())
        .limit(limit)
        .all()
    )


def add_favorite(db: Session, user_id: int, recipe_id: int) -> models.Favorite:
    existing = (
        db.query(models.Favorite)
        .filter(models.Favorite.user_id == user_id, models.Favorite.recipe_id == recipe_id)
        .first()
    )
    if existing:
        return existing
    favorite = models.Favorite(user_id=user_id, recipe_id=recipe_id)
    db.add(favorite)
    db.commit()
    db.refresh(favorite)
    return favorite


def remove_favorite(db: Session, user_id: int, recipe_id: int) -> bool:
    deleted = (
        db.query(models.Favorite)
        .filter(models.Favorite.user_id == user_id, models.Favorite.recipe_id == recipe_id)
        .delete()
    )
    db.commit()
    return deleted > 0


def list_saved_recipes(db: Session, user_id: int) -> List[models.Recipe]:
    return (
        db.query(models.Recipe)
        .join(models.Favorite, models.Favorite.recipe_id == models.Recipe.id)
        .filter(models.Favorite.user_id == user_id)
        .order_by(models.Favorite.created_at.desc())
        .all()
    )


def stats(db: Session) -> dict:
    recipe_count = db.query(func.count(models.Recipe.id)).scalar() or 0
    user_count = db.query(func.count(models.User.id)).scalar() or 0
    favorite_count = db.query(func.count(models.Favorite.id)).scalar() or 0
    return {"recipes": recipe_count, "users": user_count, "favorites": favorite_count}


def set_rating(db: Session, user_id: int, recipe_id: int, rating_value: float) -> models.Rating:
    """Создает или обновляет оценку пользователя для рецепта"""
    existing = (
        db.query(models.Rating)
        .filter(models.Rating.user_id == user_id, models.Rating.recipe_id == recipe_id)
        .first()
    )
    if existing:
        existing.rating = rating_value
        existing.updated_at = datetime.utcnow()
        db.commit()
        db.refresh(existing)
        return existing
    else:
        new_rating = models.Rating(
            user_id=user_id,
            recipe_id=recipe_id,
            rating=rating_value,
        )
        db.add(new_rating)
        db.commit()
        db.refresh(new_rating)
        return new_rating


def get_user_rating(db: Session, user_id: int, recipe_id: int) -> Optional[models.Rating]:
    """Получает оценку пользователя для рецепта"""
    return (
        db.query(models.Rating)
        .filter(models.Rating.user_id == user_id, models.Rating.recipe_id == recipe_id)
        .first()
    )


def get_recipe_avg_rating(db: Session, recipe_id: int) -> Optional[float]:
    """Вычисляет средний рейтинг рецепта"""
    result = db.query(func.avg(models.Rating.rating)).filter(models.Rating.recipe_id == recipe_id).scalar()
    return float(result) if result else None


def add_ratings_to_recipes(db: Session, recipes: List[models.Recipe]) -> List[dict]:
    """Добавляет средний рейтинг и информацию об авторе к списку рецептов"""
    result = []
    for recipe in recipes:
        avg_rating = get_recipe_avg_rating(db, recipe.id)
        # Получаем информацию об авторе
        author = get_user(db, recipe.author_id)
        author_name = author.username if author else "Неизвестный автор"
        # Если нет оценок, устанавливаем 0.0 вместо None
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
        result.append(recipe_dict)
    return result


