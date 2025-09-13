from fastapi import FastAPI
from fastapi.responses import PlainTextResponse
import uvicorn

app = FastAPI()

@app.get("/api", response_class=PlainTextResponse)
def get_api():
    return "product v1"

@app.get("/health", response_class=PlainTextResponse)
def health_check():
    return "ok"

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8080, reload=True)