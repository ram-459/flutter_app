import 'package:abc_app/models/address_model.dart';
import 'package:abc_app/models/cart_item_model.dart';
import 'package:abc_app/models/order_model.dart';
import 'package:abc_app/models/payment_model.dart';
import 'package:abc_app/services/firestore_service.dart';
import 'package:abc_app/services/razorpay_service.dart';
import 'package:abc_app/screens/patient/order_confirmation_page.dart';
import 'package:abc_app/screens/patient/saved_addresses_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class CheckoutPage extends StatefulWidget {
  final List<CartItemModel> cartItems;
  final double subtotal;
  final double shipping;
  final double total;

  const CheckoutPage({
    super.key,
    required this.cartItems,
    required this.subtotal,
    required this.shipping,
    required this.total,
  });

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final FirestoreService _firestoreService = FirestoreService();
  final RazorpayService _razorpayService = RazorpayService();

  String? _selectedAddressId;
  List<AddressModel> _availableAddresses = [];
  String _selectedPaymentMethod = 'Razorpay';
  bool _isLoading = false;
  String? _razorpayOrderId;

  @override
  void initState() {
    super.initState();
    _razorpayService.initialize();
    _setupRazorpayCallbacks();
  }

  void _setupRazorpayCallbacks() {
    _razorpayService.onSuccess = _handlePaymentSuccess;
    _razorpayService.onFailure = _handlePaymentFailure;
    _razorpayService.onExternalWallet = _handleExternalWallet;
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    try {
      print('Payment Success Response: ${response.paymentId}');

      // Get the current user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showErrorDialog('User not logged in. Please login again.');
        setState(() => _isLoading = false);
        return;
      }

      // === FIX 1 ===
      // Validate address selection
      if (_selectedAddressId?.isEmpty ?? true) {
        _showErrorDialog('Please select a shipping address.');
        setState(() => _isLoading = false);
        return;
      }

      // Find the selected address with proper fallback
      final selectedAddress = _availableAddresses.firstWhere(
            (a) => a.id == _selectedAddressId,
        orElse: () => AddressModel(
          id: '',
          title: 'Default Address',
          addressLine1: 'No address selected',
          addressLine2: '',
          city: 'Unknown City',
          stateRegion: 'Unknown State',
          postalCode: '000000',
          country: 'Unknown Country',
          isDefault: false,
          userId: '',
        ),
      );

      // === FIX 2 ===
      // Check if address is valid
      if (selectedAddress.id?.isEmpty ?? true) {
        _showErrorDialog('Invalid shipping address selected.');
        setState(() => _isLoading = false);
        return;
      }

      // Validate cart items
      if (widget.cartItems.isEmpty) {
        _showErrorDialog('Cart is empty. Cannot place order.');
        setState(() => _isLoading = false);
        return;
      }

      // Create payment record first
      final payment = PaymentModel(
        orderId: _razorpayOrderId ?? response.orderId ?? '',
        userId: user.uid,
        paymentMethod: 'Razorpay',
        status: 'Success',
        amount: widget.total,
        razorpayPaymentId: response.paymentId,
        razorpayOrderId: response.orderId,
        razorpaySignature: response.signature,
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      );

      await _firestoreService.createPayment(payment);
      print('Payment record created successfully');

      // Place the order after successful payment
      await _placeOrderAfterPayment(selectedAddress, user.uid);

    } catch (e) {
      print('Error in payment success handler: $e');
      setState(() => _isLoading = false);
      _showErrorDialog('Payment verification failed. Please contact support with payment ID: ${response.paymentId}');
    }
  }

  void _handlePaymentFailure(PaymentFailureResponse response) {
    print('Payment Failed: ${response.code} - ${response.message}');
    setState(() => _isLoading = false);

    String errorMessage = 'Payment failed. Please try again.';

    if (response.message != null) {
      errorMessage = 'Payment failed: ${response.message}';
    }

    _showErrorDialog(errorMessage);

    // Optional: Log the failure to Firestore for analytics
    _logPaymentFailure(response);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    print('External Wallet: ${response.walletName}');
    setState(() => _isLoading = false);

    // You can handle external wallet payments here
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Redirecting to ${response.walletName}')),
    );
  }

  Future<void> _logPaymentFailure(PaymentFailureResponse response) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('payment_failures').add({
          'userId': user.uid,
          'errorCode': response.code,
          'errorMessage': response.message,
          'timestamp': Timestamp.now(),
          'amount': widget.total,
          'orderId': _razorpayOrderId,
        });
      }
    } catch (e) {
      print('Error logging payment failure: $e');
    }
  }

  void _showErrorDialog(String message) {
    // Check if context is still valid
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payment Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _processPayment() async {
    // === FIX 3 (THIS IS THE CASH ON DELIVERY BUG) ===
    // Validate address selection first
    // This safely checks if _selectedAddressId is null OR empty
    if (_selectedAddressId?.isEmpty ?? true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a shipping address.')),
      );
      return;
    }

    // Find the selected address with proper fallback
    final selectedAddress = _availableAddresses.firstWhere(
          (a) => a.id == _selectedAddressId,
      orElse: () => AddressModel(
        id: '',
        title: 'Default Address',
        addressLine1: 'No address selected',
        addressLine2: '',
        city: 'Unknown City',
        stateRegion: 'Unknown State',
        postalCode: '000000',
        country: 'Unknown Country',
        isDefault: false,
        userId: '',
      ),
    );

    // === FIX 4 (THIS IS THE CASH ON DELIVERY BUG) ===
    // Check if address is valid
    // This safely checks if the found address's id is null OR empty
    if (selectedAddress.id?.isEmpty ?? true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a valid shipping address.')),
      );
      return;
    }

    if (widget.cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your cart is empty.')),
      );
      return;
    }

    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null || currentUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: User not logged in. Please restart the app.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_selectedPaymentMethod == 'Cash on Delivery') {
        await _placeOrderAfterPayment(selectedAddress, currentUserId);
      } else if (_selectedPaymentMethod == 'Razorpay') {
        await _initiateRazorpayPayment(currentUserId);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment failed: $e')),
        );
      }
    }
  }

  Future<void> _placeOrderAfterPayment(AddressModel selectedAddress, String currentUserId) async {
    try {
      print('Starting _placeOrderAfterPayment...');

      final String pharmacyId = widget.cartItems.first.pharmacyId;
      final String pharmacyName = widget.cartItems.first.pharmacyName;

      final order = OrderModel(
        userId: currentUserId,
        pharmacyId: pharmacyId,
        pharmacyName: pharmacyName,
        items: widget.cartItems,
        shippingAddress: selectedAddress,
        subtotal: widget.subtotal,
        shipping: widget.shipping,
        total: widget.total,
        paymentMethod: _selectedPaymentMethod,
        status: _selectedPaymentMethod == 'Cash on Delivery' ? 'Pending' : 'Confirmed',
        createdAt: Timestamp.now(),
      );

      print('Placing order in Firestore...');
      await _firestoreService.placeOrder(order);
      print('Order placed successfully in Firestore!');

      // Check if mounted before navigating
      if (!mounted) {
        print('Widget not mounted, cannot navigate');
        return;
      }

      setState(() => _isLoading = false);

      print('Navigating to OrderConfirmationPage...');

      // Use pushReplacement instead of pushAndRemoveUntil to avoid issues
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => OrderConfirmationPage(order: order),
        ),
      );

      print('Navigation completed!');

    } catch (e) {
      print('Error in _placeOrderAfterPayment: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to place order: $e')),
        );
      }
    }
  }
  // === FIX 5 (RAZORPAY PATH) ===
  Future<void> _initiateRazorpayPayment(String userId) async {
    try {
      print('Initiating Razorpay payment for amount: ${widget.total}');

      // Create Razorpay order
      final orderResponse = await _razorpayService.createRazorpayOrder(widget.total);

      // Safely get the ID
      final dynamic razorpayId = orderResponse?['id'];

      // Validate that it's a non-empty String
      if (razorpayId is String && razorpayId.isNotEmpty) {
        _razorpayOrderId = razorpayId; // Assign to state variable
        print('Razorpay order created: $razorpayId');

        // Get user details for prefill
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        final userData = userDoc.data() as Map<String, dynamic>?;

        // Open checkout with the validated, local 'razorpayId'
        _razorpayService.openCheckout(
          amount: widget.total,
          orderId: razorpayId, // Pass the validated ID
          name: userData?['name'] ?? 'Customer',
          email: userData?['email'] ?? '',
          contact: userData?['phoneNumber'] ?? '9999999999',
        );

        print('Razorpay checkout opened successfully');

      } else {
        // Throw a specific error if the ID was missing, null, or not a String
        print('Failed to create payment order. Response: $orderResponse');
        throw Exception('Failed to get a valid Payment Order ID from the server.');
      }

    } catch (e) {
      print('Error initiating Razorpay payment: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
      _showErrorDialog('Failed to initialize payment: ${e.toString()}');
    }
  }

  @override
  void dispose() {
    _razorpayService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Checkout'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Shipping Address Section ---
                  const Text(
                    'Shipping Address',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildAddressSelector(),
                  const SizedBox(height: 32),

                  // --- Payment Method Section ---
                  const Text(
                    'Payment Method',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildPaymentMethodOption('Razorpay'),
                  _buildPaymentMethodOption('Cash on Delivery'),
                  const SizedBox(height: 32),

                  // --- Order Summary Section ---
                  const Text(
                    'Order Summary',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildSummaryRow('Subtotal (${widget.cartItems.length} items)', widget.subtotal),
                  _buildSummaryRow('Shipping', widget.shipping),
                  const Divider(height: 24),
                  _buildSummaryRow('Total', widget.total, isTotal: true),

                  // --- Additional Info for Razorpay ---
                  if (_selectedPaymentMethod == 'Razorpay') ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[100] ?? Colors.blue), // Safe fallback
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info, color: Colors.blue[600], size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'You will be redirected to Razorpay for secure payment processing.',
                              style: TextStyle(
                                color: Colors.blue[800],
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // --- Bottom Button ---
          _buildContinueButton(),
        ],
      ),
    );
  }

  Widget _buildAddressSelector() {
    return StreamBuilder<List<AddressModel>>(
      stream: _firestoreService.getAddresses(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error loading addresses: ${snapshot.error}'));
        }

        _availableAddresses = snapshot.data ?? [];

        if (_availableAddresses.isEmpty) {
          return Center(
            child: Column(
              children: [
                Text('No addresses found.', style: TextStyle(color: Colors.grey[600])),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    // Check for mounted context before navigation
                    if (!mounted) return;
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const SavedAddressesPage()));
                  },
                  child: const Text('Add Address'),
                ),
              ],
            ),
          );
        }

        // Set default address if none selected
        if ((_selectedAddressId?.isEmpty ?? true) || !_availableAddresses.any((a) => a.id == _selectedAddressId)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) { // Check if the widget is still in the tree
              setState(() {
                // Find the first valid address
                final defaultAddress = _availableAddresses.firstWhere(
                        (a) => a.isDefault, orElse: () => _availableAddresses.first);
                _selectedAddressId = defaultAddress.id;
              });
            }
          });
        }

        return DropdownButtonFormField<String>(
          value: _selectedAddressId,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Select Address',
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          items: _availableAddresses.map((address) {
            return DropdownMenuItem<String>(
              value: address.id,
              child: Text(
                '${address.title} - ${address.addressLine1}',
                style: const TextStyle(fontSize: 14),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            );
          }).toList(),
          onChanged: (String? newValue) {
            setState(() {
              _selectedAddressId = newValue;
            });
          },
          validator: (value) {
            if (value?.isEmpty ?? true) {
              return 'Please select an address';
            }
            return null;
          },
        );
      },
    );
  }

  Widget _buildPaymentMethodOption(String title) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: RadioListTile<String>(
        title: Text(title),
        value: title,
        groupValue: _selectedPaymentMethod,
        onChanged: (String? value) {
          if (value != null) {
            setState(() {
              _selectedPaymentMethod = value;
            });
          }
        },
        activeColor: Colors.blue[800],
      ),
    );
  }

  Widget _buildSummaryRow(String title, double amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: isTotal ? 18 : 16,
              color: Colors.grey[700],
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '₹${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isTotal ? 18 : 16,
              color: Colors.black,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueButton() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[800],
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: _isLoading ? null : _processPayment,
          child: _isLoading
              ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
              : Text(
            _selectedPaymentMethod == 'Cash on Delivery'
                ? 'Place Order (Cash on Delivery)'
                : 'Continue to Payment',
            style: const TextStyle(fontSize: 16, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
