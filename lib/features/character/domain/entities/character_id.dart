/// Identifies a Forge character. Only [watcher] is fully presented in this
/// phase — the rest exist so [CharacterProfile] and script data don't need
/// to be reshaped when later characters are added.
enum CharacterId {
  watcher,
  warrior,
  scholar,
  monk,
  shadow,
  architect,
  futureSelf,
}
