from __future__ import annotations

from dataclasses import dataclass, field
from typing import Dict, List
from uuid import uuid4

from fastapi import APIRouter
from pydantic import BaseModel, Field

router = APIRouter()


class HealthResponse(BaseModel):
    status: str = "ok"


class ItemIn(BaseModel):
    name: str = Field(min_length=1, max_length=100)


class Item(ItemIn):
    id: str


@dataclass
class ItemStore:
    items: Dict[str, Item] = field(default_factory=dict)

    def list_items(self) -> List[Item]:
        return list(self.items.values())

    def create_item(self, item_in: ItemIn) -> Item:
        item = Item(id=str(uuid4()), name=item_in.name)
        self.items[item.id] = item
        return item


_store = ItemStore()


@router.get("/health", response_model=HealthResponse, tags=["health"])
def health() -> HealthResponse:
    return HealthResponse()


@router.get("/api/v1/items", response_model=List[Item], tags=["items"])
def list_items() -> List[Item]:
    return _store.list_items()


@router.post("/api/v1/items", response_model=Item, status_code=201, tags=["items"])
def create_item(item_in: ItemIn) -> Item:
    return _store.create_item(item_in)

