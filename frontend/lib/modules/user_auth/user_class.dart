import '../../common/classes/location_class.dart';
import '../../common/parse_service.dart';

class UserClass {
  ParseService _parseService = ParseService();

  String id = '', email = '', firstName = '', lastName = '', status = '', username = '',
    sessionId = '', roles = '', createdAt = '', phoneNumber = '', phoneNumberVerificationKey = '';
  //List<String> roles;
  int emailVerified = 0, phoneNumberVerified = 0;
  LocationClass location = LocationClass.fromJson({});
  UserClass(this.id, this.email, this.firstName, this.lastName, this.status, this.username, this.sessionId, this.roles,
    this.createdAt, this.phoneNumber, this.phoneNumberVerificationKey, this.emailVerified, this.phoneNumberVerified,
    this.location);
  UserClass.fromJson(Map<String, dynamic> json) {
    this.id = json.containsKey('_id') ? json['_id'] : json.containsKey('id') ? json['id'] : '';
    this.email = json.containsKey('email') ? json['email'] : '';
    this.firstName = json.containsKey('firstName') ? json['firstName'] : '';
    this.lastName = json.containsKey('lastName') ? json['lastName'] : '';
    this.status = json.containsKey('status') ? json['status'] : '';
    this.username = json.containsKey('username') ? json['username'] : '';
    this.sessionId = json.containsKey('sessionId') ? json['sessionId'] : '';
    String roles = '';
    if (json.containsKey('roles')) {
      if (json['roles'] is String) {
        roles = json['roles'];
      } else {
        roles = json['roles'].join(',');
      }
    }
    this.roles = roles;
    this.createdAt = json.containsKey('createdAt') ? json['createdAt'] : '';
    this.location = LocationClass.fromJson(json.containsKey('location') ? json['location']: {});
    this.phoneNumber = json['phoneNumber'] ?? '';
    this.phoneNumberVerificationKey = json['phoneNumberVerificationKey'] ?? '';
    this.phoneNumberVerified = json['phoneNumberVerified'] != null ? _parseService.toIntNoNull(json['phoneNumberVerified']) : 0;
    this.emailVerified = json['emailVerified'] != null ? _parseService.toIntNoNull(json['emailVerified']) : 0;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'firstName': firstName,
    'lastName': lastName,
    'status': status,
    'username': username,
    'sessionId': sessionId,
    'roles': roles,
    'createdAt': createdAt,
    'location': location.toJson(),
    'phoneNumber': phoneNumber,
    'phoneNumberVerificationKey': phoneNumberVerificationKey,
    'phoneNumberVerified': phoneNumberVerified,
    'emailVerified': emailVerified,
  };

  static List<UserClass> parseUsers(List<dynamic> itemsRaw) {
    List<UserClass> items = [];
    if (itemsRaw != null) {
      for (var item in itemsRaw) {
        items.add(UserClass.fromJson(item));
      }
    }
    return items;
  }
}
