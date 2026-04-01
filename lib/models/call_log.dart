class CallLogModel {
  final String id;
  final String callerId;
  final String receiverId;
  final String? roomId;
  final String startTime;
  final String? endTime;
  final int duration;
  final String status;
  final String callType;
  final String? callerName;
  final String? receiverName;

  CallLogModel({
    required this.id,
    required this.callerId,
    required this.receiverId,
    this.roomId,
    required this.startTime,
    this.endTime,
    required this.duration,
    required this.status,
    required this.callType,
    this.callerName,
    this.receiverName,
  });

  factory CallLogModel.fromJson(Map<String, dynamic> json) {
    return CallLogModel(
      id: json['id'] as String,
      callerId: json['caller_id'] as String,
      receiverId: json['receiver_id'] as String,
      roomId: json['room_id'] as String?,
      startTime: json['start_time'] as String,
      endTime: json['end_time'] as String?,
      duration: json['duration'] as int? ?? 0,
      status: json['status'] as String? ?? 'completed',
      callType: json['call_type'] as String? ?? 'audio',
      callerName: json['caller_name'] as String?,
      receiverName: json['receiver_name'] as String?,
    );
  }
}
