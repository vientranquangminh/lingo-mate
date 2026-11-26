import 'package:equatable/equatable.dart';

import '../../../../core/learning/learning_models.dart';

/// A roleplay: the messages so far and whether the partner or the mic is busy (F-22).
class RoleplayState extends Equatable {
  const RoleplayState({
    this.messages = const [],
    this.waiting = false,
    this.listening = false,
    this.failed = false,
    this.heard,
  });

  final List<RoleplayMessage> messages;
  final bool waiting;
  final bool listening;
  final bool failed;
  final String? heard;

  /// Returns a copy with the given fields replaced.
  RoleplayState copyWith({
    List<RoleplayMessage>? messages,
    bool? waiting,
    bool? listening,
    bool? failed,
    String? Function()? heard,
  }) => RoleplayState(
    messages: messages ?? this.messages,
    waiting: waiting ?? this.waiting,
    listening: listening ?? this.listening,
    failed: failed ?? this.failed,
    heard: heard != null ? heard() : this.heard,
  );

  @override
  List<Object?> get props => [messages, waiting, listening, failed, heard];
}
