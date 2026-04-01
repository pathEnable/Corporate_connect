from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from database import get_db
from models import CallLog, Profile
from schemas import CallLogCreate, CallLogResponse
from routes_auth import get_current_user
from typing import List
from uuid import UUID
import datetime

router = APIRouter(prefix="/calls", tags=["Calls"])

@router.post("/log", response_model=CallLogResponse)
def log_call(call_data: CallLogCreate, current_user: Profile = Depends(get_current_user), db: Session = Depends(get_db)):
    """
    Log a call when it ends or is rejected/missed.
    """
    receiver = None
    if call_data.receiver_id:
        receiver = db.query(Profile).filter(Profile.id == call_data.receiver_id).first()
        if not receiver:
            raise HTTPException(status_code=404, detail="Receiver not found")

    start_dt = datetime.datetime.fromisoformat(call_data.start_time.replace("Z", "+00:00"))
    
    end_dt = None
    if call_data.end_time:
        end_dt = datetime.datetime.fromisoformat(call_data.end_time.replace("Z", "+00:00"))

    new_call = CallLog(
        caller_id=current_user.id,
        receiver_id=call_data.receiver_id,
        room_id=call_data.room_id,
        start_time=start_dt,
        end_time=end_dt,
        duration=call_data.duration,
        status=call_data.status,
        call_type=call_data.call_type
    )
    db.add(new_call)
    db.commit()
    db.refresh(new_call)

    caller_name = current_user.full_name
    receiver_name = receiver.full_name if receiver else None

    return CallLogResponse(
        id=new_call.id,
        caller_id=new_call.caller_id,
        receiver_id=new_call.receiver_id,
        room_id=new_call.room_id,
        start_time=new_call.start_time.isoformat(),
        end_time=new_call.end_time.isoformat() if new_call.end_time else None,
        duration=new_call.duration,
        status=new_call.status,
        call_type=new_call.call_type,
        caller_name=caller_name,
        receiver_name=receiver_name
    )

@router.get("/history", response_model=List[CallLogResponse])
def get_call_history(current_user: Profile = Depends(get_current_user), db: Session = Depends(get_db)):
    """
    Get the call history of the current user (calls made and received).
    """
    try:
        calls = db.query(CallLog).filter(
            (CallLog.caller_id == current_user.id) | (CallLog.receiver_id == current_user.id)
        ).order_by(CallLog.start_time.desc()).all()
    except Exception as e:
        # Tables might not be created yet if migrations haven't run
        return []

    response_calls = []
    
    profile_ids = set([c.caller_id for c in calls if c.caller_id] + [c.receiver_id for c in calls if c.receiver_id])
    if not profile_ids:
        return []
        
    profiles = db.query(Profile).filter(Profile.id.in_(profile_ids)).all()
    profile_map = {p.id: p.full_name for p in profiles}

    for c in calls:
        caller_name = profile_map.get(c.caller_id, "Unknown")
        receiver_name = profile_map.get(c.receiver_id, "Unknown")
        
        response_calls.append(CallLogResponse(
            id=c.id,
            caller_id=c.caller_id,
            receiver_id=c.receiver_id,
            room_id=c.room_id,
            start_time=c.start_time.isoformat() if c.start_time else "",
            end_time=c.end_time.isoformat() if c.end_time else None,
            duration=c.duration,
            status=c.status,
            call_type=c.call_type,
            caller_name=caller_name,  
            receiver_name=receiver_name
        ))

    return response_calls
