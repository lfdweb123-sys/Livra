import '../api/api_client.dart';
import '../../constants/api_constants.dart';

class PaymentService {
  final _api = ApiClient.instance;

  Future<Map<String, dynamic>> payWithFeexPay({
    String? orderId,
    String? rideId,
    required String network,
    required String phoneNumber,
    String? otp,
  }) {
    return _api.post(ApiConstants.feexpayInitiate, data: {
      if (orderId != null) 'orderId': orderId,
      if (rideId != null) 'rideId': rideId,
      'network': network,
      'phoneNumber': phoneNumber,
      if (otp != null) 'otp': otp,
    });
  }

  Future<Map<String, dynamic>> payWithVerzapay({
    String? orderId,
    String? rideId,
    required String phoneNumber,
  }) {
    return _api.post(ApiConstants.verzapayInitiate, data: {
      if (orderId != null) 'orderId': orderId,
      if (rideId != null) 'rideId': rideId,
      'phoneNumber': phoneNumber,
    });
  }
}
