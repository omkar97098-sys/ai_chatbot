from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, EmailStr
from sqlalchemy.orm import Session
from dotenv import load_dotenv

from database import get_db
from models import User
from auth import (
    hash_password,
    verify_password,
    create_access_token
)

import os
import requests


# =========================================================
# Load environment variables
# =========================================================

load_dotenv()


# =========================================================
# Create FastAPI application
# =========================================================

app = FastAPI()


# =========================================================
# CORS
# =========================================================

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# =========================================================
# OpenRouter configuration
# =========================================================

API_KEY = os.getenv("OPENROUTER_API_KEY")

OPENROUTER_URL = (
    "https://openrouter.ai/api/v1/chat/completions"
)


# =========================================================
# SMART WEB SEARCH DETECTION
# =========================================================

def needs_web_search(message: str) -> bool:
    """
    Decide whether the user's question probably needs
    current/live information from the web.
    """

    message_lower = message.lower().strip()

    web_keywords = [
        # News / current events
        "latest",
        "latest news",
        "today's news",
        "todays news",
        "today news",
        "current news",
        "breaking news",
        "breaking",
        "news today",
        "recent news",
        "recently",

        # Time-sensitive information
        "today",
        "todays",
        "current",
        "currently",
        "right now",
        "live",
        "recent",
        "this week",
        "this month",
        "this year",
        "happening now",
        "what is happening",
        "what's happening",

        # Updates
        "latest update",
        "latest updates",
        "current update",
        "current updates",
        "recent update",
        "recent updates",

        # Technology / AI news
        "latest ai",
        "latest ai news",
        "latest technology news",
        "latest tech news",
        "ai news today",
        "technology news today",
        "tech news today",

        # Weather
        "weather",
        "temperature today",
        "weather today",
        "weather tomorrow",
        "forecast",

        # Finance / markets
        "stock price",
        "share price",
        "stock market",
        "market price",
        "share market",
        "bitcoin price",
        "crypto price",
        "cryptocurrency price",
        "exchange rate",
        "currency rate",
        "price today",

        # Sports
        "live score",
        "live scores",
        "latest score",
        "latest scores",
        "match today",
        "matches today",
        "game today",
        "games today",
        "score today",

        # Trending
        "trending",
        "trending now",
        "what's trending",
        "what is trending",

        # Current people / positions
        "who is the current",
        "current president",
        "current prime minister",
        "current ceo",

        # General live information
        "what happened today",
        "what happened recently",
        "what happened this week",
        "what happened this month",
    ]

    return any(
        keyword in message_lower
        for keyword in web_keywords
    )


# =========================================================
# Home endpoint
# =========================================================

@app.get("/")
def home():
    return {
        "message": "NEXA AI V4 Backend is running!"
    }


# =========================================================
# SIGNUP
# =========================================================

class SignupRequest(BaseModel):
    name: str
    email: EmailStr
    password: str


@app.post("/signup")
def signup(
    user_data: SignupRequest,
    db: Session = Depends(get_db)
):

    # -----------------------------------------------------
    # Check if email already exists
    # -----------------------------------------------------

    existing_user = (
        db.query(User)
        .filter(User.email == user_data.email)
        .first()
    )

    if existing_user:
        return {
            "success": False,
            "message": "Email is already registered."
        }

    # -----------------------------------------------------
    # Hash password using Argon2
    # -----------------------------------------------------

    hashed_password = hash_password(
        user_data.password
    )

    # -----------------------------------------------------
    # Create new user
    # -----------------------------------------------------

    new_user = User(
        name=user_data.name,
        email=user_data.email,
        password_hash=hashed_password
    )

    # -----------------------------------------------------
    # Save user to database
    # -----------------------------------------------------

    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    # -----------------------------------------------------
    # Return response
    # -----------------------------------------------------

    return {
        "success": True,
        "message": "Account created successfully!",
        "user": {
            "id": new_user.id,
            "name": new_user.name,
            "email": new_user.email
        }
    }


# =========================================================
# LOGIN
# =========================================================

class LoginRequest(BaseModel):
    email: EmailStr
    password: str


@app.post("/login")
def login(
    user_data: LoginRequest,
    db: Session = Depends(get_db)
):

    # -----------------------------------------------------
    # Find user by email
    # -----------------------------------------------------

    user = (
        db.query(User)
        .filter(User.email == user_data.email)
        .first()
    )

    # -----------------------------------------------------
    # Check if user exists
    # -----------------------------------------------------

    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password."
        )

    # -----------------------------------------------------
    # Verify password
    # -----------------------------------------------------

    password_correct = verify_password(
        user_data.password,
        user.password_hash
    )

    if not password_correct:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password."
        )

    # -----------------------------------------------------
    # Create JWT access token
    # -----------------------------------------------------

    access_token = create_access_token(
        data={
            "sub": str(user.id),
            "email": user.email
        }
    )

    # -----------------------------------------------------
    # Return login response
    # -----------------------------------------------------

    return {
        "success": True,
        "message": "Login successful!",
        "access_token": access_token,
        "token_type": "bearer",
        "user": {
            "id": user.id,
            "name": user.name,
            "email": user.email
        }
    }


# =========================================================
# CHAT
# =========================================================

@app.get("/chat")
def chat(message: str):

    # -----------------------------------------------------
    # Check OpenRouter API key
    # -----------------------------------------------------

    if not API_KEY:
        return {
            "error": (
                "OPENROUTER_API_KEY is missing from .env"
            )
        }

    try:

        # -------------------------------------------------
        # Decide whether web search is needed
        # -------------------------------------------------

        use_web_search = needs_web_search(message)

        # -------------------------------------------------
        # Create basic OpenRouter request
        # -------------------------------------------------

        request_data = {
            "model": "openrouter/free",

            "messages": [
                {
                    "role": "user",
                    "content": message
                }
            ]
        }

        # -------------------------------------------------
        # Add web search ONLY when needed
        # -------------------------------------------------

        if use_web_search:

            request_data["plugins"] = [
                {
                    "id": "web",
                    "max_results": 3
                }
            ]

        # -------------------------------------------------
        # Send request to OpenRouter
        # -------------------------------------------------

        response = requests.post(
            OPENROUTER_URL,

            headers={
                "Authorization": f"Bearer {API_KEY}",
                "Content-Type": "application/json"
            },

            json=request_data,

            timeout=60
        )

        # -------------------------------------------------
        # Convert response to JSON
        # -------------------------------------------------

        data = response.json()

        # -------------------------------------------------
        # Handle OpenRouter errors
        # -------------------------------------------------

        if response.status_code != 200:
            return {
                "error": data
            }

        # -------------------------------------------------
        # Get AI response
        # -------------------------------------------------

        ai_message = data[
            "choices"
        ][0][
            "message"
        ][
            "content"
        ]

        # -------------------------------------------------
        # Return AI response
        # -------------------------------------------------

        return {
            "message": ai_message
        }

    # -----------------------------------------------------
    # Connection error
    # -----------------------------------------------------

    except requests.exceptions.RequestException as e:

        return {
            "error": f"Connection error: {str(e)}"
        }

    # -----------------------------------------------------
    # Unexpected error
    # -----------------------------------------------------

    except Exception as e:

        return {
            "error": f"Unexpected error: {str(e)}"
        }