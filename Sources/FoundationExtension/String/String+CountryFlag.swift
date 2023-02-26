
extension String {
    public var countryFlag: String {
        var tempScalarView = String.UnicodeScalarView()
        for i in self.uppercased().utf16 {
            if let scalar = UnicodeScalar(127397 + Int(i)) {
                tempScalarView.append(scalar)
            }
        }
        return String(tempScalarView)
    }
}
