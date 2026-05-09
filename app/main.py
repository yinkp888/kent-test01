from fastapi import FastAPI

from app.routers import items

app = FastAPI(title="Kent Test 01", version="0.1.0")
app.include_router(items.router)


@app.get("/")
def root():
    return {"message": "Hello World"}
