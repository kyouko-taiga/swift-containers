/// A POD type that does not require any special handling on copying or destruction.
///
/// This protocol can be used as a generic constraint for so-called "trivial" types, i.e., types
/// that do not require explicit initialization. It is likely to become obsolete when Swift will
/// provide a built-in mechanism to identify PODs.
public protocol _AnyTrivial {
}

extension Bool    : _AnyTrivial {}

extension Float32 : _AnyTrivial {}
extension Float64 : _AnyTrivial {}

extension Int8    : _AnyTrivial {}
extension Int16   : _AnyTrivial {}
extension Int32   : _AnyTrivial {}
extension Int64   : _AnyTrivial {}

extension UInt    : _AnyTrivial {}
extension UInt8   : _AnyTrivial {}
extension UInt16  : _AnyTrivial {}
extension UInt32  : _AnyTrivial {}
extension UInt64  : _AnyTrivial {}
