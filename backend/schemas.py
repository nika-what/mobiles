from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, HttpUrl, Field, field_validator, model_validator, EmailStr


class UserBase(BaseModel):
    username: str = Field(..., max_length=50)
    avatar_url: Optional[str] = None  # Может быть URL или Base64 строка
    bio: Optional[str] = None


class UserRegister(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=6)
    password_confirm: str
    username: str = Field(..., max_length=50)

    @field_validator('password')
    @classmethod
    def truncate_password(cls, v):
        """Обрезает пароль до 72 байт для совместимости с bcrypt"""
        if v:
            password_bytes = v.encode('utf-8')
            if len(password_bytes) > 72:
                # Обрезаем до 72 байт
                password_bytes = password_bytes[:72]
                # Декодируем обратно, игнорируя ошибки если байты обрезаны посередине символа
                v = password_bytes.decode('utf-8', errors='ignore')
        return v

    @field_validator('password_confirm')
    @classmethod
    def truncate_password_confirm(cls, v):
        """Обрезает подтверждение пароля до 72 байт для совместимости с bcrypt"""
        if v:
            password_bytes = v.encode('utf-8')
            if len(password_bytes) > 72:
                password_bytes = password_bytes[:72]
                v = password_bytes.decode('utf-8', errors='ignore')
        return v

    @model_validator(mode='after')
    def passwords_match(self):
        """Проверяет совпадение паролей после обрезки"""
        if self.password != self.password_confirm:
            raise ValueError('Пароли не совпадают')
        return self


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class UserCreate(UserBase):
    pass


class UserUpdate(BaseModel):
    username: Optional[str] = Field(None, max_length=50)
    avatar_url: Optional[str] = None
    bio: Optional[str] = None


class User(UserBase):
    id: int
    created_at: datetime

    class Config:
        from_attributes = True


class RecipeBase(BaseModel):
    title: str = Field(..., max_length=100)
    description: Optional[str] = None
    instructions: str
    image_url: Optional[str] = None  # Убрали ограничение длины для base64 изображений
    cook_time_minutes: Optional[int] = None
    servings: Optional[int] = None
    tags: Optional[str] = None
    
    @field_validator('cook_time_minutes')
    @classmethod
    def validate_cook_time(cls, v):
        if v is not None and (v < 1 or v > 600):
            raise ValueError('cook_time_minutes must be between 1 and 600')
        return v
    
    @field_validator('servings')
    @classmethod
    def validate_servings(cls, v):
        if v is not None and (v < 1 or v > 20):
            raise ValueError('servings must be between 1 and 20')
        return v


class RecipeCreate(RecipeBase):
    author_id: int


class RecipeUpdate(BaseModel):
    title: Optional[str] = Field(None, max_length=100)
    description: Optional[str] = None
    instructions: Optional[str] = None
    image_url: Optional[str] = None  # Убрали ограничение длины для base64 изображений
    cook_time_minutes: Optional[int] = None
    servings: Optional[int] = None
    tags: Optional[str] = None
    
    @field_validator('cook_time_minutes')
    @classmethod
    def validate_cook_time(cls, v):
        if v is not None and (v < 1 or v > 600):
            raise ValueError('cook_time_minutes must be between 1 and 600')
        return v
    
    @field_validator('servings')
    @classmethod
    def validate_servings(cls, v):
        if v is not None and (v < 1 or v > 20):
            raise ValueError('servings must be between 1 and 20')
        return v


class Recipe(RecipeBase):
    id: int
    created_at: datetime
    author_id: int
    author_name: Optional[str] = None  # Имя автора, вычисляется отдельно
    rating: Optional[float] = None  # Средний рейтинг, вычисляется отдельно

    class Config:
        from_attributes = True


class FavoriteCreate(BaseModel):
    user_id: int
    recipe_id: int


class Favorite(BaseModel):
    id: int
    user_id: int
    recipe_id: int
    created_at: datetime
    recipe: Recipe

    class Config:
        from_attributes = True


class PaginatedRecipes(BaseModel):
    total: int
    items: List[Recipe]


class RatingCreate(BaseModel):
    rating: float = Field(..., ge=1, le=5)


class Rating(BaseModel):
    id: int
    user_id: int
    recipe_id: int
    rating: float
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


