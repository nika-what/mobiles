from datetime import datetime
from sqlalchemy import Column, Integer, String, Text, DateTime, ForeignKey, Float, UniqueConstraint
from sqlalchemy.orm import relationship

try:
    from .database import Base
except ImportError:
    from database import Base


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String(50), unique=True, index=True, nullable=False)
    email = Column(String(100), unique=True, index=True, nullable=True)
    password_hash = Column(String(255), nullable=True)  # Хеш пароля
    avatar_url = Column(String(255), nullable=True)
    bio = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    recipes = relationship("Recipe", back_populates="author", cascade="all, delete-orphan")
    saved_recipes = relationship(
        "Favorite",
        back_populates="user",
        cascade="all, delete-orphan",
    )
    ratings = relationship("Rating", back_populates="user", cascade="all, delete-orphan")


class Recipe(Base):
    __tablename__ = "recipes"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String(100), nullable=False, index=True)
    description = Column(Text, nullable=True)
    instructions = Column(Text, nullable=False)
    image_url = Column(Text, nullable=True)
    cook_time_minutes = Column(Integer, nullable=True)
    servings = Column(Integer, nullable=True)
    tags = Column(String(120), nullable=True)  # comma-separated tags
    created_at = Column(DateTime, default=datetime.utcnow, index=True)
    author_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)

    author = relationship("User", back_populates="recipes")
    favorited_by = relationship("Favorite", back_populates="recipe", cascade="all, delete-orphan")
    ratings = relationship("Rating", back_populates="recipe", cascade="all, delete-orphan")


class Favorite(Base):
    __tablename__ = "favorites"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    recipe_id = Column(Integer, ForeignKey("recipes.id", ondelete="CASCADE"), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("User", back_populates="saved_recipes")
    recipe = relationship("Recipe", back_populates="favorited_by")


class Rating(Base):
    __tablename__ = "ratings"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    recipe_id = Column(Integer, ForeignKey("recipes.id", ondelete="CASCADE"), nullable=False)
    rating = Column(Float, nullable=False)  # от 1 до 5
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    __table_args__ = (
        UniqueConstraint('user_id', 'recipe_id', name='unique_user_recipe_rating'),
    )

    user = relationship("User", back_populates="ratings")
    recipe = relationship("Recipe", back_populates="ratings")


