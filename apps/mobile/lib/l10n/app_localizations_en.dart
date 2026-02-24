// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get navHome => 'Home';

  @override
  String get navMarketplace => 'Marketplace';

  @override
  String get navTrips => 'Trips';

  @override
  String get navOrders => 'Orders';

  @override
  String get navProfile => 'Profile';

  @override
  String get navMessages => 'Messages';

  @override
  String get authLoginTitle => 'Login to JiriSewa';

  @override
  String get authLoginSubtitle => 'Enter your phone number to get started';

  @override
  String get authPhoneLabel => 'Phone Number';

  @override
  String get authPhonePlaceholder => '98XXXXXXXX';

  @override
  String get authPhoneHint => 'Enter your 10-digit Nepal mobile number';

  @override
  String get authSendOtp => 'Send OTP';

  @override
  String get authOtpTitle => 'Verify OTP';

  @override
  String authOtpSubtitle(String phone) {
    return 'Enter the 6-digit code sent to $phone';
  }

  @override
  String get authOtpPlaceholder => 'Enter 6-digit code';

  @override
  String get authVerifyOtp => 'Verify';

  @override
  String get authResendOtp => 'Resend OTP';

  @override
  String authResendIn(int seconds) {
    return 'Resend in ${seconds}s';
  }

  @override
  String get authChangePhone => 'Change phone number';

  @override
  String get authInvalidPhone =>
      'Enter a valid Nepal mobile number (98XXXXXXXX)';

  @override
  String get authOtpSent => 'OTP sent to your phone';

  @override
  String get authOtpError => 'Failed to send OTP. Please try again.';

  @override
  String get authVerifyError => 'Invalid OTP. Please try again.';

  @override
  String get authSending => 'Sending...';

  @override
  String get authVerifying => 'Verifying...';

  @override
  String get registerTitle => 'Complete Your Profile';

  @override
  String get registerSubtitle => 'Tell us about yourself to get started';

  @override
  String get registerNameLabel => 'Full Name';

  @override
  String get registerNamePlaceholder => 'Your full name';

  @override
  String get registerLanguageLabel => 'Preferred Language';

  @override
  String get registerAddressLabel => 'Address';

  @override
  String get registerAddressPlaceholder => 'Your address or municipality';

  @override
  String get registerMunicipalityLabel => 'Municipality';

  @override
  String get registerMunicipalityPlaceholder =>
      'e.g. Kathmandu, Pokhara, Biratnagar';

  @override
  String get registerRoleTitle => 'I am a...';

  @override
  String get registerRoleSubtitle => 'Select all that apply';

  @override
  String get registerRoleFarmer => 'Farmer';

  @override
  String get registerRoleFarmerDesc => 'I grow and sell produce';

  @override
  String get registerRoleConsumer => 'Consumer';

  @override
  String get registerRoleConsumerDesc => 'I buy fresh produce';

  @override
  String get registerRoleRider => 'Rider';

  @override
  String get registerRoleRiderDesc => 'I travel and can carry produce';

  @override
  String get registerFarmNameLabel => 'Farm Name';

  @override
  String get registerFarmNamePlaceholder => 'Name of your farm';

  @override
  String get registerVehicleTypeLabel => 'Vehicle Type';

  @override
  String get registerVehicleCapacityLabel => 'Carrying Capacity (kg)';

  @override
  String get registerVehicleCapacityPlaceholder => 'e.g. 50';

  @override
  String get registerBike => 'Bike';

  @override
  String get registerCar => 'Car';

  @override
  String get registerTruck => 'Truck';

  @override
  String get registerBus => 'Bus';

  @override
  String get registerOther => 'Other';

  @override
  String get registerNext => 'Next';

  @override
  String get registerBack => 'Back';

  @override
  String get registerComplete => 'Complete Registration';

  @override
  String get registerCompleting => 'Completing...';

  @override
  String get registerSelectRole => 'Please select at least one role';

  @override
  String get registerNameRequired => 'Name is required';

  @override
  String registerStep(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String get marketplaceTitle => 'Marketplace';

  @override
  String get marketplaceSubtitle => 'Fresh produce directly from local farmers';

  @override
  String get marketplaceSearchPlaceholder => 'Search produce...';

  @override
  String get marketplaceFilters => 'Filters';

  @override
  String get marketplaceClearFilters => 'Clear filters';

  @override
  String get marketplaceAllCategories => 'All Categories';

  @override
  String get marketplacePriceRange => 'Price Range';

  @override
  String get marketplaceMinPrice => 'Min (NPR)';

  @override
  String get marketplaceMaxPrice => 'Max (NPR)';

  @override
  String get marketplaceSortBy => 'Sort by';

  @override
  String get marketplaceSortPriceAsc => 'Price: Low to High';

  @override
  String get marketplaceSortPriceDesc => 'Price: High to Low';

  @override
  String get marketplaceSortFreshness => 'Freshness';

  @override
  String get marketplaceSortRating => 'Farmer Rating';

  @override
  String get marketplaceSortDistance => 'Distance';

  @override
  String get marketplaceNoResults => 'No produce found';

  @override
  String get marketplaceNoResultsHint =>
      'Try adjusting your filters or search terms.';

  @override
  String get marketplacePerKg => '/kg';

  @override
  String get marketplaceLoadMore => 'Load more';

  @override
  String marketplaceShowing(int count) {
    return 'Showing $count items';
  }

  @override
  String get marketplaceSetLocation => 'Set your location';

  @override
  String get marketplaceSetLocationHint =>
      'Set your location to see nearby produce and distances.';

  @override
  String get marketplaceUseMyLocation => 'Use my location';

  @override
  String get marketplaceLocationSet => 'Location set';

  @override
  String marketplaceKmAway(String distance) {
    return '$distance km away';
  }

  @override
  String marketplaceHarvestedOn(String date) {
    return 'Harvested $date';
  }

  @override
  String marketplaceAvailable(String qty) {
    return '$qty kg available';
  }

  @override
  String marketplaceFarmerRating(String rating, int count) {
    return '$rating ($count reviews)';
  }

  @override
  String get marketplaceVerifiedFarmer => 'Verified';

  @override
  String get produceAddToCart => 'Add to Cart';

  @override
  String get produceAddedToCart => 'Added!';

  @override
  String get produceQuantity => 'Quantity (kg)';

  @override
  String producePricePerKg(String price) {
    return 'NPR $price/kg';
  }

  @override
  String produceTotalPrice(String total) {
    return 'Total: NPR $total';
  }

  @override
  String get produceFarmerInfo => 'Farmer Information';

  @override
  String get produceFreshness => 'Freshness';

  @override
  String get produceDescription => 'Description';

  @override
  String get produceCategory => 'Category';

  @override
  String get produceLocation => 'Location';

  @override
  String get produceNotFound => 'Product not found';

  @override
  String get produceNotFoundHint =>
      'This product may have been removed or is no longer available.';

  @override
  String get producePhotos => 'Photos';

  @override
  String get cartTitle => 'Shopping Cart';

  @override
  String get cartEmpty => 'Your cart is empty';

  @override
  String get cartEmptyHint => 'Browse the marketplace to find fresh produce.';

  @override
  String get cartBrowseMarketplace => 'Browse Marketplace';

  @override
  String get cartClearAll => 'Clear all';

  @override
  String cartFromFarmer(String farmer) {
    return 'from $farmer';
  }

  @override
  String get cartRemove => 'Remove';

  @override
  String get cartSubtotal => 'Subtotal';

  @override
  String get cartProceedToCheckout => 'Proceed to Checkout';

  @override
  String get checkoutTitle => 'Checkout';

  @override
  String get checkoutOrderSummary => 'Order Summary';

  @override
  String get checkoutDeliveryLocation => 'Delivery Location';

  @override
  String get checkoutDeliveryLocationHint =>
      'Tap the map to set your delivery location.';

  @override
  String get checkoutSelectDeliveryLocation =>
      'Please select a delivery location on the map.';

  @override
  String get checkoutCashOnDelivery => 'Cash on Delivery';

  @override
  String get checkoutCashOnDeliveryHint =>
      'Pay the rider in cash when your order is delivered.';

  @override
  String get checkoutEsewaPayment => 'eSewa';

  @override
  String get checkoutEsewaPaymentHint =>
      'Pay securely with your eSewa digital wallet. Payment held in escrow until delivery.';

  @override
  String get checkoutKhaltiPayment => 'Khalti';

  @override
  String get checkoutKhaltiPaymentHint =>
      'Pay securely with your Khalti digital wallet. Payment held in escrow until delivery.';

  @override
  String get checkoutConnectipsPayment => 'connectIPS';

  @override
  String get checkoutConnectipsPaymentHint =>
      'Pay directly from your bank account via connectIPS. Payment held in escrow until delivery.';

  @override
  String get checkoutSubtotal => 'Subtotal';

  @override
  String get checkoutDeliveryFee => 'Delivery Fee';

  @override
  String get checkoutCalculatingFee => 'Calculating delivery fee...';

  @override
  String get checkoutFeeError =>
      'Could not calculate delivery fee. Please try a different delivery location.';

  @override
  String get checkoutBaseFee => 'Base Fee';

  @override
  String checkoutDistanceFee(String km) {
    return 'Distance ($km km)';
  }

  @override
  String checkoutWeightFee(String kg) {
    return 'Weight ($kg kg)';
  }

  @override
  String get checkoutTotal => 'Total';

  @override
  String get checkoutPlaceOrder => 'Place Order';

  @override
  String get checkoutPlacing => 'Placing order...';

  @override
  String get checkoutRedirectingToPayment => 'Redirecting to payment...';

  @override
  String get ordersTitle => 'My Orders';

  @override
  String get ordersNoOrders => 'No orders yet';

  @override
  String ordersOrderNumber(String id) {
    return 'Order #$id';
  }

  @override
  String ordersPlaced(String date) {
    return 'Placed $date';
  }

  @override
  String get ordersTabActive => 'Active';

  @override
  String get ordersTabCompleted => 'Completed';

  @override
  String get ordersStatusPending => 'Pending';

  @override
  String get ordersStatusMatched => 'Matched';

  @override
  String get ordersStatusPickedUp => 'Picked Up';

  @override
  String get ordersStatusInTransit => 'In Transit';

  @override
  String get ordersStatusDelivered => 'Delivered';

  @override
  String get ordersStatusCancelled => 'Cancelled';

  @override
  String get ordersStatusDisputed => 'Disputed';

  @override
  String get ordersOrderDetail => 'Order Details';

  @override
  String get ordersItems => 'Items';

  @override
  String ordersFromFarmer(String farmer) {
    return 'from $farmer';
  }

  @override
  String get ordersDeliveryAddress => 'Delivery Address';

  @override
  String get ordersRiderInfo => 'Rider Information';

  @override
  String get ordersSubtotal => 'Subtotal';

  @override
  String get ordersDeliveryFee => 'Delivery Fee';

  @override
  String get ordersTotal => 'Total';

  @override
  String get ordersPaymentMethod => 'Payment Method';

  @override
  String get ordersPaymentStatus => 'Payment Status';

  @override
  String get ordersPaymentStatusPending => 'Pending';

  @override
  String get ordersPaymentStatusEscrowed => 'Held in Escrow';

  @override
  String get ordersPaymentStatusCollected => 'Collected';

  @override
  String get ordersPaymentStatusSettled => 'Settled';

  @override
  String get ordersPaymentStatusRefunded => 'Refunded';

  @override
  String get ordersPaymentSuccess =>
      'Payment successful! Your funds are held securely in escrow until delivery.';

  @override
  String get ordersPaymentFailed =>
      'Payment was not completed. You can retry below.';

  @override
  String get ordersConfirmDelivery => 'Confirm Delivery Received';

  @override
  String get ordersCancelOrder => 'Cancel Order';

  @override
  String get ordersDeliveryConfirmed => 'Delivery confirmed! Thank you.';

  @override
  String get ordersRateOrder => 'Rate this order';

  @override
  String get ordersRateFarmer => 'Rate Farmer';

  @override
  String get ordersRateRider => 'Rate Rider';

  @override
  String get ordersRated => 'Rated';

  @override
  String get ordersReorder => 'Reorder';

  @override
  String get ordersRetryEsewaPayment => 'Pay with eSewa';

  @override
  String get ordersRetryKhaltiPayment => 'Pay with Khalti';

  @override
  String get ordersRetryConnectIPSPayment => 'Pay with connectIPS';

  @override
  String ordersTotalItems(int count) {
    return '$count items';
  }

  @override
  String get ordersRider => 'Rider';

  @override
  String get ordersFarmer => 'Farmer';

  @override
  String get ordersReceipt => 'Receipt';

  @override
  String get ordersBackToOrders => 'Back to orders';

  @override
  String get ratingsTitle => 'Ratings & Reviews';

  @override
  String get ratingsSubmitRating => 'Submit Rating';

  @override
  String get ratingsSubmitting => 'Submitting...';

  @override
  String get ratingsRateYourExperience => 'Rate your experience';

  @override
  String get ratingsCommentPlaceholder => 'Share your experience (optional)';

  @override
  String get ratingsStar1 => 'Poor';

  @override
  String get ratingsStar2 => 'Fair';

  @override
  String get ratingsStar3 => 'Good';

  @override
  String get ratingsStar4 => 'Very Good';

  @override
  String get ratingsStar5 => 'Excellent';

  @override
  String get ratingsThankYou => 'Thank you for your rating!';

  @override
  String get ratingsAlreadyRated =>
      'You have already rated this person for this order.';

  @override
  String get ratingsNoRatings => 'No ratings yet';

  @override
  String get ratingsError => 'Failed to submit rating. Please try again.';

  @override
  String get ratingsClose => 'Close';

  @override
  String get farmerDashboardTitle => 'Farmer Dashboard';

  @override
  String get farmerAddListing => 'Add Listing';

  @override
  String get farmerActiveListings => 'Active Listings';

  @override
  String get farmerPendingOrders => 'Pending Orders';

  @override
  String get farmerEarnings => 'Total Earnings';

  @override
  String get farmerMyListings => 'My Listings';

  @override
  String get farmerNoListings => 'You haven\'t listed any produce yet.';

  @override
  String get farmerAddFirstListing => 'Add Your First Listing';

  @override
  String get farmerNewListingTitle => 'Add New Listing';

  @override
  String get farmerEditListingTitle => 'Edit Listing';

  @override
  String get farmerListingActive => 'Active';

  @override
  String get farmerListingInactive => 'Inactive';

  @override
  String get farmerFormCategory => 'Category';

  @override
  String get farmerFormSelectCategory => 'Select a category';

  @override
  String get farmerFormNameEn => 'Name (English)';

  @override
  String get farmerFormNameNe => 'Name (Nepali)';

  @override
  String get farmerFormDescription => 'Description';

  @override
  String get farmerFormPricePerKg => 'Price per kg (NPR)';

  @override
  String get farmerFormAvailableQty => 'Available Quantity (kg)';

  @override
  String get farmerFormFreshnessDate => 'Freshness Date';

  @override
  String get farmerFormPhotos => 'Photos (up to 5)';

  @override
  String get farmerFormSaving => 'Saving...';

  @override
  String get farmerFormCreate => 'Create Listing';

  @override
  String get farmerFormUpdate => 'Update Listing';

  @override
  String get farmerFormCancel => 'Cancel';

  @override
  String get farmerFormErrorCategory => 'Please select a category.';

  @override
  String get farmerFormErrorName =>
      'Both English and Nepali names are required.';

  @override
  String get farmerFormErrorPrice => 'Please enter a valid price.';

  @override
  String get farmerFormErrorQty => 'Please enter a valid quantity.';

  @override
  String get farmerVerificationTitle => 'Identity Verification';

  @override
  String get farmerVerificationDescription =>
      'Submit your documents to get verified. Verified farmers get a badge and appear higher in search results.';

  @override
  String get farmerVerificationStatusUnverified =>
      'Your account is not yet verified.';

  @override
  String get farmerVerificationStatusPending =>
      'Your documents are under review.';

  @override
  String get farmerVerificationStatusApproved => 'Your account is verified!';

  @override
  String get farmerVerificationStatusRejected =>
      'Your verification was not approved.';

  @override
  String get farmerVerificationSubmit => 'Submit Documents';

  @override
  String get farmerVerificationResubmit => 'Resubmit Documents';

  @override
  String get farmerVerificationCitizenshipPhoto =>
      'Citizenship / ID Card Photo';

  @override
  String get farmerVerificationFarmPhoto => 'Farm Photo';

  @override
  String get farmerVerificationMunicipalityLetter =>
      'Municipality Letter (Optional)';

  @override
  String get farmerVerificationUploading => 'Uploading...';

  @override
  String get farmerVerificationSubmitting => 'Submitting...';

  @override
  String get farmerVerificationSubmitted => 'Documents submitted for review!';

  @override
  String get farmerVerificationVerifiedBadge => 'Verified Farmer';

  @override
  String get farmerAnalyticsTitle => 'Analytics';

  @override
  String get farmerAnalyticsTotalRevenue => 'Total Revenue';

  @override
  String get farmerAnalyticsTotalOrders => 'Total Orders';

  @override
  String get farmerAnalyticsAvgRating => 'Avg Rating';

  @override
  String get farmerAnalyticsRevenueTrend => 'Revenue Trend';

  @override
  String get farmerAnalyticsSalesByCategory => 'Sales by Category';

  @override
  String get farmerAnalyticsTopProducts => 'Top Products';

  @override
  String get farmerAnalyticsPriceBenchmarks => 'Price Comparison';

  @override
  String get farmerAnalyticsFulfillmentRate => 'Fulfillment Rate';

  @override
  String get farmerAnalyticsNoData => 'No data for this period.';

  @override
  String get farmerAnalyticsPeriod7days => '7 days';

  @override
  String get farmerAnalyticsPeriod30days => '30 days';

  @override
  String get farmerAnalyticsPeriod90days => '90 days';

  @override
  String get riderDashboardTitle => 'Rider Dashboard';

  @override
  String get riderPostTrip => 'Post a Trip';

  @override
  String get riderUpcoming => 'Upcoming';

  @override
  String get riderActive => 'Active';

  @override
  String get riderCompleted => 'Completed';

  @override
  String get riderNoTrips => 'No trips yet';

  @override
  String get riderPostFirstTrip => 'Post your first trip';

  @override
  String get riderTripFormTitle => 'Post a Trip';

  @override
  String get riderPickOrigin => 'Where are you starting?';

  @override
  String get riderPickOriginHint =>
      'Tap the map to select your starting point.';

  @override
  String get riderPickDestination => 'Where are you heading?';

  @override
  String get riderPickDestinationHint =>
      'Tap the map to select your destination.';

  @override
  String get riderTripDetails => 'Trip Details';

  @override
  String get riderDepartureDate => 'Departure Date';

  @override
  String get riderDepartureTime => 'Departure Time';

  @override
  String get riderCapacity => 'Available Capacity (kg)';

  @override
  String get riderVehicleType => 'Vehicle Type';

  @override
  String get riderDistance => 'Distance';

  @override
  String get riderDuration => 'Est. Duration';

  @override
  String get riderFrom => 'From';

  @override
  String get riderTo => 'To';

  @override
  String get riderNext => 'Next';

  @override
  String get riderBack => 'Back';

  @override
  String get riderReview => 'Review';

  @override
  String get riderReviewTitle => 'Review Your Trip';

  @override
  String get riderPostTripBtn => 'Post Trip';

  @override
  String get riderPosting => 'Posting...';

  @override
  String get riderCalculatingRoute => 'Calculating route...';

  @override
  String get riderRouteError =>
      'Could not calculate route. Please try different locations.';

  @override
  String get riderTripDetailTitle => 'Trip Detail';

  @override
  String get riderTripInfo => 'Trip Information';

  @override
  String get riderTotalCapacity => 'Total Capacity';

  @override
  String get riderRemainingCapacity => 'Remaining Capacity';

  @override
  String get riderMatchedOrders => 'Matched Orders';

  @override
  String get riderNoMatchedOrders => 'No orders matched to this trip yet.';

  @override
  String get riderStartTrip => 'Start Trip';

  @override
  String get riderStarting => 'Starting...';

  @override
  String get riderCompleteTrip => 'Complete Trip';

  @override
  String get riderCompleting => 'Completing...';

  @override
  String get riderCancelTrip => 'Cancel Trip';

  @override
  String get riderConfirmPickup => 'Confirm Pickup';

  @override
  String get riderStartDelivery => 'Start Delivery';

  @override
  String get riderOptimizeRoute => 'Optimize Route';

  @override
  String get riderOptimizing => 'Optimizing...';

  @override
  String get riderTripStatusScheduled => 'Scheduled';

  @override
  String get riderTripStatusInTransit => 'In Transit';

  @override
  String get riderTripStatusCompleted => 'Completed';

  @override
  String get riderTripStatusCancelled => 'Cancelled';

  @override
  String get riderPingsNewOrders => 'New Order Requests';

  @override
  String get riderPingsPickup => 'Pickup';

  @override
  String get riderPingsDelivery => 'Delivery';

  @override
  String get riderPingsWeight => 'Weight';

  @override
  String get riderPingsEarnings => 'Earnings';

  @override
  String get riderPingsDetour => 'Detour';

  @override
  String get riderPingsAccept => 'Accept';

  @override
  String get riderPingsDecline => 'Decline';

  @override
  String get riderPingsExpired => 'Expired';

  @override
  String get riderPingsAccepting => 'Accepting...';

  @override
  String get riderPingsDeclining => 'Declining...';

  @override
  String get riderPingsAccepted => 'Accepted';

  @override
  String riderPingsExpiresIn(String time) {
    return 'Expires in $time';
  }

  @override
  String get chatTitle => 'Messages';

  @override
  String get chatNoConversations => 'No messages yet';

  @override
  String get chatNoConversationsHint =>
      'Start a conversation from an order page.';

  @override
  String get chatSearchPlaceholder => 'Search conversations...';

  @override
  String get chatYou => 'You';

  @override
  String get chatImage => 'Photo';

  @override
  String get chatLocation => 'Location';

  @override
  String get chatTypeMessage => 'Type a message...';

  @override
  String get chatSend => 'Send';

  @override
  String get chatSendImage => 'Send image';

  @override
  String get chatToday => 'Today';

  @override
  String get chatYesterday => 'Yesterday';

  @override
  String get chatLoadMore => 'Load earlier messages';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsEmpty => 'No notifications yet';

  @override
  String get notificationsMarkAllRead => 'Mark all as read';

  @override
  String get notificationsPreferencesTitle => 'Notification Preferences';

  @override
  String get notificationsConsumerGroup => 'Order Updates';

  @override
  String get notificationsFarmerGroup => 'Farm Orders';

  @override
  String get notificationsRiderGroup => 'Trip & Delivery';

  @override
  String get subscriptionsTitle => 'Subscription Boxes';

  @override
  String get subscriptionsSubtitle =>
      'Fresh produce delivered to your door every week';

  @override
  String get subscriptionsNoPlans => 'No subscription plans available yet.';

  @override
  String get subscriptionsNoSubscriptions =>
      'You have no active subscriptions.';

  @override
  String get subscriptionsBrowse => 'Browse Plans';

  @override
  String get subscriptionsMy => 'My Subscriptions';

  @override
  String get subscriptionsFrequencyWeekly => 'Weekly';

  @override
  String get subscriptionsFrequencyBiweekly => 'Biweekly';

  @override
  String get subscriptionsFrequencyMonthly => 'Monthly';

  @override
  String get subscriptionsStatusActive => 'Active';

  @override
  String get subscriptionsStatusPaused => 'Paused';

  @override
  String get subscriptionsStatusCancelled => 'Cancelled';

  @override
  String subscriptionsByFarmer(String name) {
    return 'by $name';
  }

  @override
  String get subscriptionsSubscribe => 'Subscribe';

  @override
  String get subscriptionsSubscribing => 'Subscribing...';

  @override
  String get subscriptionsPause => 'Pause';

  @override
  String get subscriptionsResume => 'Resume';

  @override
  String get subscriptionsCancel => 'Cancel';

  @override
  String get subscriptionsCreatePlan => 'Create Plan';

  @override
  String get businessRegisterTitle => 'Register Your Business';

  @override
  String get businessDashboardTitle => 'Business Dashboard';

  @override
  String get businessCreateOrder => 'New Bulk Order';

  @override
  String get businessBulkOrdersTitle => 'Bulk Orders';

  @override
  String get businessActiveOrders => 'Active Orders';

  @override
  String get businessCompletedOrders => 'Completed';

  @override
  String get businessTotalSpent => 'Total Spent';

  @override
  String get businessNoOrders => 'No bulk orders yet';

  @override
  String get businessStatusDraft => 'Draft';

  @override
  String get businessStatusSubmitted => 'Submitted';

  @override
  String get businessStatusQuoted => 'Quoted';

  @override
  String get businessStatusAccepted => 'Accepted';

  @override
  String get businessStatusInProgress => 'In Progress';

  @override
  String get businessStatusFulfilled => 'Fulfilled';

  @override
  String get businessStatusCancelled => 'Cancelled';

  @override
  String get businessAcceptQuotes => 'Accept All Quotes';

  @override
  String get businessCancelOrder => 'Cancel Order';

  @override
  String get commonLoading => 'Loading...';

  @override
  String get commonError => 'Error';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonSearch => 'Search';

  @override
  String get commonNoData => 'No data available';

  @override
  String get commonSuccess => 'Success';

  @override
  String get commonUnknownError => 'Something went wrong. Please try again.';

  @override
  String get commonClose => 'Close';

  @override
  String get commonBack => 'Back';

  @override
  String get commonNext => 'Next';

  @override
  String get commonDone => 'Done';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonOk => 'OK';

  @override
  String get commonYes => 'Yes';

  @override
  String get commonNo => 'No';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageNepali => 'Nepali';

  @override
  String get paymentProcessing => 'Processing payment...';

  @override
  String get paymentSuccess => 'Payment successful!';

  @override
  String get paymentFailed => 'Payment failed';

  @override
  String get paymentVerifying => 'Verifying payment...';
}
