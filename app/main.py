from fastapi import FastAPI
from prometheus_fastapi_instrumentator import Instrumentator

from app.api.routes import router as api_router


def create_app() -> FastAPI:
    app = FastAPI(title="DevOps Demo API", version="1.0.0")
    app.include_router(api_router)

    @app.get("/", tags=["root"])
    def root() -> dict:
        return {"message": "DevOps Demo API is running"}

    Instrumentator().instrument(app).expose(
        app,
        endpoint="/metrics",
        include_in_schema=False,
    )
    return app


app = create_app()
