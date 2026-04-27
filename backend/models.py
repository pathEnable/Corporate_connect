import uuid
from sqlalchemy import Column, String, Boolean, DateTime, ForeignKey, Text, Integer, JSON
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from database import Base


class Profile(Base):
    __tablename__ = "profiles"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email = Column(String, unique=True, index=True, nullable=True)
    phone_number = Column(String, unique=True, index=True, nullable=True)
    hashed_password = Column(String, nullable=True)
    full_name = Column(String, index=True, nullable=False)
    username = Column(String, unique=True, index=True)
    avatar_url = Column(String, nullable=True)
    bio = Column(String, nullable=True) # Biographie de l'utilisateur
    job_title = Column(String, nullable=True) # Poste occupé
    department = Column(String, nullable=True)  # Nouveau : Département de l'utilisateur
    skills = Column(String, nullable=True)  # Nouveau : Compétences (séparées par des virgules)
    is_online = Column(Boolean, default=False)
    presence_status = Column(String, default="online") # 'online', 'busy', 'dnd', 'meeting', 'remote', 'vacation'
    fcm_token = Column(String, nullable=True)
    public_key = Column(String, nullable=True) # Clé publique pour l'E2EE (Base64)
    is_active = Column(Boolean, default=True) # Pour bannissement
    is_admin = Column(Boolean, default=False) # Pour accès admin
    token_version = Column(Integer, default=1) # Pour invalider les sessions (logout all devices)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    sent_messages = relationship("Message", back_populates="sender")


class Room(Base):
    __tablename__ = "rooms"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String, nullable=True)
    is_group = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    members = relationship("RoomMember", back_populates="room")
    messages = relationship("Message", back_populates="room")


class RoomMember(Base):
    __tablename__ = "room_members"

    room_id = Column(UUID(as_uuid=True), ForeignKey("rooms.id", ondelete="CASCADE"), primary_key=True)
    profile_id = Column(UUID(as_uuid=True), ForeignKey("profiles.id", ondelete="CASCADE"), primary_key=True)
    is_admin_member = Column(Boolean, default=False)
    joined_at = Column(DateTime(timezone=True), server_default=func.now())

    room = relationship("Room", back_populates="members")
    profile = relationship("Profile")


class Message(Base):
    __tablename__ = "messages"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    room_id = Column(UUID(as_uuid=True), ForeignKey("rooms.id", ondelete="CASCADE"), nullable=False, index=True)
    sender_id = Column(UUID(as_uuid=True), ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False, index=True)
    content = Column(Text, nullable=True)
    message_type = Column(String, default="text")  # 'text','image','file','audio','poll','task'
    reply_to_id = Column(UUID(as_uuid=True), ForeignKey("messages.id", ondelete="SET NULL"), nullable=True)
    is_read = Column(Boolean, default=False) # Accusé de lecture
    read_at = Column(DateTime(timezone=True), nullable=True) # Date de lecture
    # Nouveau : Métadonnées pour sondages et tâches (JSON)
    metadata_ = Column(JSON, nullable=True)
    # Nouveau : Messages programmés
    scheduled_for = Column(DateTime(timezone=True), nullable=True)
    is_sent = Column(Boolean, default=True)  # False = programmé, pas encore envoyé
    created_at = Column(DateTime(timezone=True), server_default=func.now(), index=True)

    room = relationship("Room", back_populates="messages")
    sender = relationship("Profile", back_populates="sent_messages")


class Status(Base):
    __tablename__ = "statuses"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False, index=True)
    media_url = Column(String, nullable=True)
    text = Column(String, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    expires_at = Column(DateTime(timezone=True), nullable=False)

    user = relationship("Profile")


class RefreshToken(Base):
    __tablename__ = "refresh_tokens"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False)
    token = Column(String, unique=True, index=True, nullable=False)
    expires_at = Column(DateTime(timezone=True), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    user = relationship("Profile")

class CallLog(Base):
    __tablename__ = "call_logs"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    caller_id = Column(UUID(as_uuid=True), ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False, index=True)
    receiver_id = Column(UUID(as_uuid=True), ForeignKey("profiles.id", ondelete="CASCADE"), nullable=True, index=True)
    room_id = Column(UUID(as_uuid=True), ForeignKey("rooms.id", ondelete="CASCADE"), nullable=True)
    start_time = Column(DateTime(timezone=True), server_default=func.now())
    end_time = Column(DateTime(timezone=True), nullable=True)
    duration = Column(Integer, default=0)
    status = Column(String, default="completed") # 'completed', 'missed', 'rejected'
    call_type = Column(String, default="audio") # 'audio', 'video'

    caller = relationship("Profile", foreign_keys=[caller_id])
    receiver = relationship("Profile", foreign_keys=[receiver_id])
    room = relationship("Room")
