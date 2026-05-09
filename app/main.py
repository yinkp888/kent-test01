from fastapi import FastAPI

app = FastAPI(title="Kent Test 01", version="0.1.0")


@app.get("/")
def root():
    return {"message": "Hello World"}
