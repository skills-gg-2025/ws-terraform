from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse
import uvicorn

app = FastAPI()

@app.get('/ver')
def ver():
    return JSONResponse(content={"version": "WSK v1"})  

@app.get('/health')
def health():
    return JSONResponse(content={"status": "ok"})

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8080)