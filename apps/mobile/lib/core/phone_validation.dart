// Nepal phone number validation and formatting.
//
// Valid Nepal mobile numbers:
// - 10 digits starting with 97, 98, or 96
// - Operators: NTC (984, 985, 986), Ncell (980, 981, 982), Smart (961, 962, 988)

final _nepalPhoneRegex = RegExp(r'^(97|98|96)\d{8}$');

/// Strips spaces, dashes, and leading +977 country code.
String normalizePhone(String raw) {
  var phone = raw.replaceAll(RegExp(r'[\s\-()]'), '');
  if (phone.startsWith('+977')) {
    phone = phone.substring(4);
  } else if (phone.startsWith('977')) {
    phone = phone.substring(3);
  }
  if (phone.startsWith('0')) {
    phone = phone.substring(1);
  }
  return phone;
}

/// Returns true if the normalized phone is a valid 10-digit Nepal mobile number.
bool isValidNepalPhone(String raw) {
  final phone = normalizePhone(raw);
  return _nepalPhoneRegex.hasMatch(phone);
}

/// Returns the E.164 formatted phone for Supabase Auth (+977XXXXXXXXXX).
String toE164(String raw) {
  return '+977${normalizePhone(raw)}';
}
