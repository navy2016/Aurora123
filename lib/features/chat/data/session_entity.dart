import 'package:isar/isar.dart';
part 'session_entity.g.dart';

@collection
class SessionEntity {
  Id id = Isar.autoIncrement;
  @Index(unique: true, replace: true)
  late String sessionId;
  late String title;
  late DateTime lastMessageTime;
  String? snippet;
  
  // Link to a generic TopicEntity
  // We store the ID directly. Isar Links<T> are also an option, 
  // but a simple ID is often easier for lightweight relations.
  int? topicId; 
}
