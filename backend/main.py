from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
import os
import requests

# Load variables from .env
load_dotenv()

# Create FastAPI application
app = FastAPI()

# Allow Flutter/Chrome to communicate with the backend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Get OpenRouter API key from .env
API_KEY = os.getenv("OPENROUTER_API_KEY")


# Home endpoint
@app.get("/")
def home():
    return {
        "message": "AI Chatbot Backend is running!"
    }


# Chat endpoint
@app.get("/chat")
def chat(message: str):

    # Check whether API key exists
    if not API_KEY:
        return {
            "error": "OPENROUTER_API_KEY is missing from .env"
        }

    try:
        # Send message to OpenRouter
        response = requests.post(
            "https://openrouter.ai/api/v1/chat/completions",

            headers={
                "Authorization": f"Bearer {API_KEY}",
                "Content-Type": "application/json"
            },

            json={
                "model": "openrouter/free",
                "messages": [
                    {
                        "role": "user",
                        "content": message
                    }
                ]
            },

            timeout=60
        )

        # Convert response to JSON
        data = response.json()

        # Handle OpenRouter errors
        if response.status_code != 200:
            return {
                "error": data
            }

        # Return AI response
        return {
            "message": data["choices"][0]["message"]["content"]
        }

    except requests.exceptions.RequestException as e:
        return {
            "error": f"Connection error: {str(e)}"
        }

    except Exception as e:
        return {
            "error": f"Unexpected error: {str(e)}"
        }