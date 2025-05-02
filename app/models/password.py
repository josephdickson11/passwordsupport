from pydantic import BaseModel

class PasswordRequest(BaseModel):
    platform: str
    nr_cap_letters: int
    nr_letters: int
    nr_symbols: int
    nr_numbers: int

class PasswordResponse(BaseModel):
    platform: str
    password: str