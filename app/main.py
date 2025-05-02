from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm

from jose import JWTError, jwt
from passlib.context import CryptContext
from datetime import datetime, timedelta
import boto3
from botocore.exceptions import ClientError
from cryptography.fernet import Fernet
import random
from dotenv import load_dotenv
import os
from app.models.user import User, Token, UserRegister

from app.models.password import PasswordRequest, PasswordResponse
from app.config.raw_config import small_letters, cap_letters, numbers, symbols


# Load environment variables from .env file
load_dotenv()

# FastAPI app
app = FastAPI()

# Configuration from environment variables
SECRET_KEY = os.getenv("SECRET_KEY")
ALGORITHM = os.getenv("JWT_ALGORITHM", "HS256")
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", 30))
FERNET_KEY = os.getenv("FERNET_KEY")
AWS_ACCESS_KEY_ID = os.getenv("AWS_ACCESS_KEY_ID")
AWS_SECRET_ACCESS_KEY = os.getenv("AWS_SECRET_ACCESS_KEY")
AWS_REGION = os.getenv("AWS_REGION", "us-east-1")
USERS_TABLE_NAME = os.getenv("USERS_TABLE_NAME", "Users")
PASSWORDS_TABLE_NAME = os.getenv("PASSWORDS_TABLE_NAME", "Passwords")

# Validate required environment variables
if not all([SECRET_KEY, FERNET_KEY, AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY]):
    raise ValueError("Missing required environment variables")

# DynamoDB setup
dynamodb = boto3.resource(
    'dynamodb',
    aws_access_key_id=AWS_ACCESS_KEY_ID,
    aws_secret_access_key=AWS_SECRET_ACCESS_KEY,
    region_name=AWS_REGION
)
users_table = dynamodb.Table(USERS_TABLE_NAME)
passwords_table = dynamodb.Table(PASSWORDS_TABLE_NAME)

# Password hashing and encryption
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
cipher = Fernet(FERNET_KEY.encode())

# OAuth2 scheme
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

















def verify_password(plain_password, hashed_password):
    return pwd_context.verify(plain_password, hashed_password)


def get_password_hash(password):
    return pwd_context.hash(password)


def create_access_token(data: dict):
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt


async def get_current_user(token: str = Depends(oauth2_scheme)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username: str = payload.get("sub")
        if username is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception

    try:
        response = users_table.get_item(Key={'username': username})
        user = response.get('Item')
        if user is None:
            raise credentials_exception
    except ClientError:
        raise credentials_exception
    return user


def generate_password(nr_cap_letters: int, nr_letters: int, nr_symbols: int, nr_numbers: int) -> str:
    password = (
            [random.choice(cap_letters) for _ in range(nr_cap_letters)] +
            [random.choice(small_letters) for _ in range(nr_letters)] +
            [random.choice(symbols) for _ in range(nr_symbols)] +
            [random.choice(numbers) for _ in range(nr_numbers)]
    )
    secure_password = random.sample(password, len(password))
    return "".join(secure_password)


@app.post("/register", response_model=User)
async def register(user: UserRegister):
    hashed_password = get_password_hash(user.password)
    user = {
        'username': user.username,
        'email': user.email,
        'hashed_password': hashed_password
    }
    try:
        users_table.put_item(
            Item=user,
            ConditionExpression='attribute_not_exists(username)'
        )
        return User(**user)
    except ClientError as e:
        if e.response['Error']['Code'] == 'ConditionalCheckFailedException':
            raise HTTPException(status_code=400, detail="Username already exists")
        raise HTTPException(status_code=500, detail="Internal server error")


@app.post("/token", response_model=Token)
async def login(form_data: OAuth2PasswordRequestForm = Depends()):
    try:
        response = users_table.get_item(Key={'username': form_data.username})
        user = response.get('Item')
        if not user or not verify_password(form_data.password, user['hashed_password']):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Incorrect username or password",
                headers={"WWW-Authenticate": "Bearer"},
            )
        access_token = create_access_token(data={"sub": user['username']})
        return {"access_token": access_token, "token_type": "bearer"}
    except ClientError:
        raise HTTPException(status_code=500, detail="Internal server error")


@app.post("/password", response_model=PasswordResponse)
async def create_password(password_req: PasswordRequest, current_user: dict = Depends(get_current_user)):
    password = generate_password(
        password_req.nr_cap_letters,
        password_req.nr_letters,
        password_req.nr_symbols,
        password_req.nr_numbers
    )
    encrypted_password = cipher.encrypt(password.encode()).decode()

    try:
        passwords_table.put_item(
            Item={
                'username': current_user['username'],
                'platform': password_req.platform,
                'encrypted_password': encrypted_password,
                'created_at': datetime.utcnow().isoformat()
            }
        )
        return PasswordResponse(platform=password_req.platform, password=password)
    except ClientError:
        raise HTTPException(status_code=500, detail="Internal server error")


@app.get("/password/{platform}", response_model=PasswordResponse)
async def get_password(platform: str, current_user: dict = Depends(get_current_user)):
    try:
        response = passwords_table.get_item(
            Key={
                'username': current_user['username'],
                'platform': platform
            }
        )
        item = response.get('Item')
        if not item:
            raise HTTPException(status_code=404, detail="Password not found")

        decrypted_password = cipher.decrypt(item['encrypted_password'].encode()).decode()
        return PasswordResponse(platform=platform, password=decrypted_password)
    except ClientError:
        raise HTTPException(status_code=500, detail="Internal server error")