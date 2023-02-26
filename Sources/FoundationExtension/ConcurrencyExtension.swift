
extension AsyncStream {
  public static var never: Self {
    Self { _ in }
  }
}
