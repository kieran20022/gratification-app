enum ReminderAnimation { bounce, pulse, shake, fade, none }
enum ReminderPosition  { top, center, bottom }

class ReminderSettings {
  static const defaultMessage = "You've been in {app} for {time}";

  final String            message;
  final ReminderAnimation animation;
  final ReminderPosition  position;

  const ReminderSettings({
    this.message   = defaultMessage,
    this.animation = ReminderAnimation.bounce,
    this.position  = ReminderPosition.center,
  });

  ReminderSettings copyWith({
    String?            message,
    ReminderAnimation? animation,
    ReminderPosition?  position,
  }) => ReminderSettings(
    message:   message   ?? this.message,
    animation: animation ?? this.animation,
    position:  position  ?? this.position,
  );
}
