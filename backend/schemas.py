from pydantic import BaseModel, EmailStr
from typing import Optional, List
from uuid import UUID


class RegisterRequest(BaseModel):
    email: Optional[str] = None
    phone_number: Optional[str] = None
    password: Optional[str] = None
    full_name: str
    username: str


class LoginRequest(BaseModel):
    email: Optional[str] = None
    phone_number: Optional[str] = None
    password: Optional[str] = None


class OTPRequest(BaseModel):
    phone_number: str


class OTPVerify(BaseModel):
    phone_number: str
    otp_code: str


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    user_id: str
    full_name: str


class TokenRefreshRequest(BaseModel):
    refresh_token: str


class ProfileResponse(BaseModel):
    id: UUID
    email: Optional[str]
    phone_number: Optional[str]
    full_name: str
    username: str
    avatar_url: Optional[str]
    bio: Optional[str] = None
    job_title: Optional[str] = None
    is_online: bool
    public_key: Optional[str] = None

    class Config:
        from_attributes = True


class RoomResponse(BaseModel):
    id: UUID
    name: Optional[str]
    is_group: bool
    last_message: Optional[str] = None

    class Config:
        from_attributes = True


class MessageResponse(BaseModel):
    id: UUID
    sender_id: UUID
    content: Optional[str]
    message_type: str
    reply_to_id: Optional[UUID] = None
    is_read: bool = False
    created_at: str

    class Config:
        from_attributes = True


class RegisterTokenRequest(BaseModel):
    fcm_token: str

class RoomMemberResponse(BaseModel):
    id: UUID
    full_name: str
    public_key: Optional[str] = None
    is_admin_member: bool = False

    class Config:
        from_attributes = True

class StatusResponse(BaseModel):
    id: UUID
    user_id: UUID
    user_name: str
    user_avatar: Optional[str] = None
    media_url: Optional[str] = None
    text: Optional[str] = None
    created_at: str

    class Config:
        from_attributes = True

class StatusCreate(BaseModel):
    media_url: Optional[str] = None
    text: Optional[str] = None

class CallLogCreate(BaseModel):
    receiver_id: Optional[UUID] = None
    room_id: Optional[UUID] = None
    start_time: str
    end_time: Optional[str] = None
    duration: int = 0
    status: str = "completed"
    call_type: str = "audio"

class CallLogResponse(BaseModel):
    id: UUID
    caller_id: UUID
    receiver_id: Optional[UUID] = None
    room_id: Optional[UUID] = None
    start_time: str
    end_time: Optional[str] = None
    duration: int
    status: str
    call_type: str
    
    # We can include caller/receiver info if needed, but let's keep it simple for now
    caller_name: Optional[str] = None
    receiver_name: Optional[str] = None

    class Config:
        from_attributes = True
