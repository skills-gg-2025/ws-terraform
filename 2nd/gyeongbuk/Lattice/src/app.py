from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse
from pydantic import BaseModel
import boto3
from botocore.exceptions import ClientError
import json
from typing import Optional, List, Dict, Any
import uvicorn

TABLE_NAME = 'skills-app-table'
REGION_NAME = 'ap-southeast-1'
HOST = "0.0.0.0"
PORT = 8000

class Settings:
    table_name: str = TABLE_NAME
    region_name: str = REGION_NAME
    host: str = HOST
    port: int = PORT

settings = Settings()

class PrettyJSONResponse(JSONResponse):
    def render(self, content: Any) -> bytes:
        return (json.dumps(content, indent=2) + "\n").encode("utf-8")

app = FastAPI(default_response_class=PrettyJSONResponse)

@app.exception_handler(HTTPException)
async def custom_http_exception_handler(request: Request, exc: HTTPException):
    return PrettyJSONResponse(
        status_code=exc.status_code,
        content={"detail": exc.detail}
    )

class User(BaseModel):
    UserId: str
    Name: str
    SkillLevel: Optional[str] = None

class UserUpdate(BaseModel):
    Name: Optional[str] = None
    SkillLevel: Optional[str] = None

class DynamoDBService:
    def __init__(self):
        self.dynamodb = boto3.resource('dynamodb', region_name=settings.region_name)
        self.table = self.dynamodb.Table(settings.table_name)

    def health_check(self) -> bool:
        """Check DynamoDB connection status"""
        try:
            self.table.table_status
            return True
        except ClientError:
            return False

    def create_user(self, user: User) -> None:
        """Create a new user"""
        try:
            self.table.put_item(
                Item=user.dict(exclude_none=True),
                ConditionExpression="attribute_not_exists(UserId)"
            )
        except ClientError as e:
            if e.response['Error']['Code'] == 'ConditionalCheckFailedException':
                raise HTTPException(status_code=400, detail="UserId already exists")
            raise HTTPException(status_code=500, detail=f"Error creating user: {str(e)}")

    def get_user(self, user_id: str) -> Dict[str, Any]:
        """Retrieve a user by ID"""
        try:
            response = self.table.get_item(Key={'UserId': user_id})
            item = response.get('Item')
            if not item:
                raise HTTPException(status_code=404, detail="User not found")
            return item
        except ClientError as e:
            raise HTTPException(status_code=500, detail=f"Error retrieving user: {str(e)}")

    def list_users(self) -> List[Dict[str, Any]]:
        """List all users"""
        try:
            response = self.table.scan()
            return response.get('Items', [])
        except ClientError as e:
            raise HTTPException(status_code=500, detail=f"Error scanning users: {str(e)}")

    def update_user(self, user_id: str, user_update: UserUpdate) -> Dict[str, Any]:
        """Update user information"""
        update_expression = "SET"
        expression_attribute_values = {}
        expression_attribute_names = {}

        if user_update.Name:
            update_expression += " #n = :name,"
            expression_attribute_values[":name"] = user_update.Name
            expression_attribute_names["#n"] = "Name"
        if user_update.SkillLevel:
            update_expression += " SkillLevel = :skill,"
            expression_attribute_values[":skill"] = user_update.SkillLevel

        if not expression_attribute_values:
            raise HTTPException(status_code=400, detail="No fields to update")

        try:
            response = self.table.update_item(
                Key={'UserId': user_id},
                UpdateExpression=update_expression.rstrip(","),
                ExpressionAttributeValues=expression_attribute_values,
                ExpressionAttributeNames=expression_attribute_names or None,
                ReturnValues="ALL_NEW"
            )
            return response['Attributes']
        except ClientError as e:
            if e.response['Error']['Code'] == 'ValidationException':
                raise HTTPException(status_code=404, detail="User not found")
            raise HTTPException(status_code=500, detail=f"Error updating user: {str(e)}")

    def delete_user(self, user_id: str) -> None:
        """Delete a user"""
        try:
            self.table.delete_item(
                Key={'UserId': user_id},
                ConditionExpression="attribute_exists(UserId)"
            )
        except ClientError as e:
            if e.response['Error']['Code'] == 'ConditionalCheckFailedException':
                raise HTTPException(status_code=404, detail="User not found")
            raise HTTPException(status_code=500, detail=f"Error deleting user: {str(e)}")

db_service = DynamoDBService()

@app.get("/health")
async def health_check():
    """Check application health for ALB"""
    return {"status": "OK"}

@app.post("/users", response_model=User)
async def create_user(user: User):
    """Create a new user"""
    db_service.create_user(user)
    return user

@app.get("/users/{user_id}", response_model=User)
async def read_user(user_id: str):
    """Get a user by ID"""
    return db_service.get_user(user_id)

@app.get("/users", response_model=List[User])
async def list_users():
    """List all users"""
    return db_service.list_users()

@app.put("/users/{user_id}", response_model=User)
async def update_user(user_id: str, user_update: UserUpdate):
    """Update a user"""
    return db_service.update_user(user_id, user_update)

@app.delete("/users/{user_id}")
async def delete_user(user_id: str):
    """Delete a user"""
    db_service.delete_user(user_id)
    return {"message": f"User {user_id} deleted successfully"}

if __name__ == "__main__":
    uvicorn.run(app, host=settings.host, port=settings.port)