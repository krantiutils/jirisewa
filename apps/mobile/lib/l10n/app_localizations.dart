import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ne.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ne'),
  ];

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navMarketplace.
  ///
  /// In en, this message translates to:
  /// **'Marketplace'**
  String get navMarketplace;

  /// No description provided for @navTrips.
  ///
  /// In en, this message translates to:
  /// **'Trips'**
  String get navTrips;

  /// No description provided for @navOrders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get navOrders;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @navMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get navMessages;

  /// No description provided for @authLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'Login to JiriSewa'**
  String get authLoginTitle;

  /// No description provided for @authLoginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your phone number to get started'**
  String get authLoginSubtitle;

  /// No description provided for @authPhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get authPhoneLabel;

  /// No description provided for @authPhonePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'98XXXXXXXX'**
  String get authPhonePlaceholder;

  /// No description provided for @authPhoneHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your 10-digit Nepal mobile number'**
  String get authPhoneHint;

  /// No description provided for @authSendOtp.
  ///
  /// In en, this message translates to:
  /// **'Send OTP'**
  String get authSendOtp;

  /// No description provided for @authOtpTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify OTP'**
  String get authOtpTitle;

  /// No description provided for @authOtpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code sent to {phone}'**
  String authOtpSubtitle(String phone);

  /// No description provided for @authOtpPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Enter 6-digit code'**
  String get authOtpPlaceholder;

  /// No description provided for @authVerifyOtp.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get authVerifyOtp;

  /// No description provided for @authResendOtp.
  ///
  /// In en, this message translates to:
  /// **'Resend OTP'**
  String get authResendOtp;

  /// No description provided for @authResendIn.
  ///
  /// In en, this message translates to:
  /// **'Resend in {seconds}s'**
  String authResendIn(int seconds);

  /// No description provided for @authChangePhone.
  ///
  /// In en, this message translates to:
  /// **'Change phone number'**
  String get authChangePhone;

  /// No description provided for @authInvalidPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid Nepal mobile number (98XXXXXXXX)'**
  String get authInvalidPhone;

  /// No description provided for @authOtpSent.
  ///
  /// In en, this message translates to:
  /// **'OTP sent to your phone'**
  String get authOtpSent;

  /// No description provided for @authOtpError.
  ///
  /// In en, this message translates to:
  /// **'Failed to send OTP. Please try again.'**
  String get authOtpError;

  /// No description provided for @authVerifyError.
  ///
  /// In en, this message translates to:
  /// **'Invalid OTP. Please try again.'**
  String get authVerifyError;

  /// No description provided for @authSending.
  ///
  /// In en, this message translates to:
  /// **'Sending...'**
  String get authSending;

  /// No description provided for @authVerifying.
  ///
  /// In en, this message translates to:
  /// **'Verifying...'**
  String get authVerifying;

  /// No description provided for @registerTitle.
  ///
  /// In en, this message translates to:
  /// **'Complete Your Profile'**
  String get registerTitle;

  /// No description provided for @registerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tell us about yourself to get started'**
  String get registerSubtitle;

  /// No description provided for @registerNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get registerNameLabel;

  /// No description provided for @registerNamePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Your full name'**
  String get registerNamePlaceholder;

  /// No description provided for @registerLanguageLabel.
  ///
  /// In en, this message translates to:
  /// **'Preferred Language'**
  String get registerLanguageLabel;

  /// No description provided for @registerAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get registerAddressLabel;

  /// No description provided for @registerAddressPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Your address or municipality'**
  String get registerAddressPlaceholder;

  /// No description provided for @registerMunicipalityLabel.
  ///
  /// In en, this message translates to:
  /// **'Municipality'**
  String get registerMunicipalityLabel;

  /// No description provided for @registerMunicipalityPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'e.g. Kathmandu, Pokhara, Biratnagar'**
  String get registerMunicipalityPlaceholder;

  /// No description provided for @registerRoleTitle.
  ///
  /// In en, this message translates to:
  /// **'I am a...'**
  String get registerRoleTitle;

  /// No description provided for @registerRoleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select all that apply'**
  String get registerRoleSubtitle;

  /// No description provided for @registerRoleFarmer.
  ///
  /// In en, this message translates to:
  /// **'Farmer'**
  String get registerRoleFarmer;

  /// No description provided for @registerRoleFarmerDesc.
  ///
  /// In en, this message translates to:
  /// **'I grow and sell produce'**
  String get registerRoleFarmerDesc;

  /// No description provided for @registerRoleConsumer.
  ///
  /// In en, this message translates to:
  /// **'Consumer'**
  String get registerRoleConsumer;

  /// No description provided for @registerRoleConsumerDesc.
  ///
  /// In en, this message translates to:
  /// **'I buy fresh produce'**
  String get registerRoleConsumerDesc;

  /// No description provided for @registerRoleRider.
  ///
  /// In en, this message translates to:
  /// **'Rider'**
  String get registerRoleRider;

  /// No description provided for @registerRoleRiderDesc.
  ///
  /// In en, this message translates to:
  /// **'I travel and can carry produce'**
  String get registerRoleRiderDesc;

  /// No description provided for @registerFarmNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Farm Name'**
  String get registerFarmNameLabel;

  /// No description provided for @registerFarmNamePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Name of your farm'**
  String get registerFarmNamePlaceholder;

  /// No description provided for @registerVehicleTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Vehicle Type'**
  String get registerVehicleTypeLabel;

  /// No description provided for @registerVehicleCapacityLabel.
  ///
  /// In en, this message translates to:
  /// **'Carrying Capacity (kg)'**
  String get registerVehicleCapacityLabel;

  /// No description provided for @registerVehicleCapacityPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'e.g. 50'**
  String get registerVehicleCapacityPlaceholder;

  /// No description provided for @registerBike.
  ///
  /// In en, this message translates to:
  /// **'Bike'**
  String get registerBike;

  /// No description provided for @registerCar.
  ///
  /// In en, this message translates to:
  /// **'Car'**
  String get registerCar;

  /// No description provided for @registerTruck.
  ///
  /// In en, this message translates to:
  /// **'Truck'**
  String get registerTruck;

  /// No description provided for @registerBus.
  ///
  /// In en, this message translates to:
  /// **'Bus'**
  String get registerBus;

  /// No description provided for @registerOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get registerOther;

  /// No description provided for @registerNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get registerNext;

  /// No description provided for @registerBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get registerBack;

  /// No description provided for @registerComplete.
  ///
  /// In en, this message translates to:
  /// **'Complete Registration'**
  String get registerComplete;

  /// No description provided for @registerCompleting.
  ///
  /// In en, this message translates to:
  /// **'Completing...'**
  String get registerCompleting;

  /// No description provided for @registerSelectRole.
  ///
  /// In en, this message translates to:
  /// **'Please select at least one role'**
  String get registerSelectRole;

  /// No description provided for @registerNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get registerNameRequired;

  /// No description provided for @registerStep.
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total}'**
  String registerStep(int current, int total);

  /// No description provided for @marketplaceTitle.
  ///
  /// In en, this message translates to:
  /// **'Marketplace'**
  String get marketplaceTitle;

  /// No description provided for @marketplaceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Fresh produce directly from local farmers'**
  String get marketplaceSubtitle;

  /// No description provided for @marketplaceSearchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search produce...'**
  String get marketplaceSearchPlaceholder;

  /// No description provided for @marketplaceFilters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get marketplaceFilters;

  /// No description provided for @marketplaceClearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get marketplaceClearFilters;

  /// No description provided for @marketplaceAllCategories.
  ///
  /// In en, this message translates to:
  /// **'All Categories'**
  String get marketplaceAllCategories;

  /// No description provided for @marketplacePriceRange.
  ///
  /// In en, this message translates to:
  /// **'Price Range'**
  String get marketplacePriceRange;

  /// No description provided for @marketplaceMinPrice.
  ///
  /// In en, this message translates to:
  /// **'Min (NPR)'**
  String get marketplaceMinPrice;

  /// No description provided for @marketplaceMaxPrice.
  ///
  /// In en, this message translates to:
  /// **'Max (NPR)'**
  String get marketplaceMaxPrice;

  /// No description provided for @marketplaceSortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get marketplaceSortBy;

  /// No description provided for @marketplaceSortPriceAsc.
  ///
  /// In en, this message translates to:
  /// **'Price: Low to High'**
  String get marketplaceSortPriceAsc;

  /// No description provided for @marketplaceSortPriceDesc.
  ///
  /// In en, this message translates to:
  /// **'Price: High to Low'**
  String get marketplaceSortPriceDesc;

  /// No description provided for @marketplaceSortFreshness.
  ///
  /// In en, this message translates to:
  /// **'Freshness'**
  String get marketplaceSortFreshness;

  /// No description provided for @marketplaceSortRating.
  ///
  /// In en, this message translates to:
  /// **'Farmer Rating'**
  String get marketplaceSortRating;

  /// No description provided for @marketplaceSortDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get marketplaceSortDistance;

  /// No description provided for @marketplaceNoResults.
  ///
  /// In en, this message translates to:
  /// **'No produce found'**
  String get marketplaceNoResults;

  /// No description provided for @marketplaceNoResultsHint.
  ///
  /// In en, this message translates to:
  /// **'Try adjusting your filters or search terms.'**
  String get marketplaceNoResultsHint;

  /// No description provided for @marketplacePerKg.
  ///
  /// In en, this message translates to:
  /// **'/kg'**
  String get marketplacePerKg;

  /// No description provided for @marketplaceLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get marketplaceLoadMore;

  /// No description provided for @marketplaceShowing.
  ///
  /// In en, this message translates to:
  /// **'Showing {count} items'**
  String marketplaceShowing(int count);

  /// No description provided for @marketplaceSetLocation.
  ///
  /// In en, this message translates to:
  /// **'Set your location'**
  String get marketplaceSetLocation;

  /// No description provided for @marketplaceSetLocationHint.
  ///
  /// In en, this message translates to:
  /// **'Set your location to see nearby produce and distances.'**
  String get marketplaceSetLocationHint;

  /// No description provided for @marketplaceUseMyLocation.
  ///
  /// In en, this message translates to:
  /// **'Use my location'**
  String get marketplaceUseMyLocation;

  /// No description provided for @marketplaceLocationSet.
  ///
  /// In en, this message translates to:
  /// **'Location set'**
  String get marketplaceLocationSet;

  /// No description provided for @marketplaceKmAway.
  ///
  /// In en, this message translates to:
  /// **'{distance} km away'**
  String marketplaceKmAway(String distance);

  /// No description provided for @marketplaceHarvestedOn.
  ///
  /// In en, this message translates to:
  /// **'Harvested {date}'**
  String marketplaceHarvestedOn(String date);

  /// No description provided for @marketplaceAvailable.
  ///
  /// In en, this message translates to:
  /// **'{qty} kg available'**
  String marketplaceAvailable(String qty);

  /// No description provided for @marketplaceFarmerRating.
  ///
  /// In en, this message translates to:
  /// **'{rating} ({count} reviews)'**
  String marketplaceFarmerRating(String rating, int count);

  /// No description provided for @marketplaceVerifiedFarmer.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get marketplaceVerifiedFarmer;

  /// No description provided for @produceAddToCart.
  ///
  /// In en, this message translates to:
  /// **'Add to Cart'**
  String get produceAddToCart;

  /// No description provided for @produceAddedToCart.
  ///
  /// In en, this message translates to:
  /// **'Added!'**
  String get produceAddedToCart;

  /// No description provided for @produceQuantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity (kg)'**
  String get produceQuantity;

  /// No description provided for @producePricePerKg.
  ///
  /// In en, this message translates to:
  /// **'NPR {price}/kg'**
  String producePricePerKg(String price);

  /// No description provided for @produceTotalPrice.
  ///
  /// In en, this message translates to:
  /// **'Total: NPR {total}'**
  String produceTotalPrice(String total);

  /// No description provided for @produceFarmerInfo.
  ///
  /// In en, this message translates to:
  /// **'Farmer Information'**
  String get produceFarmerInfo;

  /// No description provided for @produceFreshness.
  ///
  /// In en, this message translates to:
  /// **'Freshness'**
  String get produceFreshness;

  /// No description provided for @produceDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get produceDescription;

  /// No description provided for @produceCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get produceCategory;

  /// No description provided for @produceLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get produceLocation;

  /// No description provided for @produceNotFound.
  ///
  /// In en, this message translates to:
  /// **'Product not found'**
  String get produceNotFound;

  /// No description provided for @produceNotFoundHint.
  ///
  /// In en, this message translates to:
  /// **'This product may have been removed or is no longer available.'**
  String get produceNotFoundHint;

  /// No description provided for @producePhotos.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get producePhotos;

  /// No description provided for @cartTitle.
  ///
  /// In en, this message translates to:
  /// **'Shopping Cart'**
  String get cartTitle;

  /// No description provided for @cartEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your cart is empty'**
  String get cartEmpty;

  /// No description provided for @cartEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Browse the marketplace to find fresh produce.'**
  String get cartEmptyHint;

  /// No description provided for @cartBrowseMarketplace.
  ///
  /// In en, this message translates to:
  /// **'Browse Marketplace'**
  String get cartBrowseMarketplace;

  /// No description provided for @cartClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get cartClearAll;

  /// No description provided for @cartFromFarmer.
  ///
  /// In en, this message translates to:
  /// **'from {farmer}'**
  String cartFromFarmer(String farmer);

  /// No description provided for @cartRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get cartRemove;

  /// No description provided for @cartSubtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get cartSubtotal;

  /// No description provided for @cartProceedToCheckout.
  ///
  /// In en, this message translates to:
  /// **'Proceed to Checkout'**
  String get cartProceedToCheckout;

  /// No description provided for @checkoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Checkout'**
  String get checkoutTitle;

  /// No description provided for @checkoutOrderSummary.
  ///
  /// In en, this message translates to:
  /// **'Order Summary'**
  String get checkoutOrderSummary;

  /// No description provided for @checkoutDeliveryLocation.
  ///
  /// In en, this message translates to:
  /// **'Delivery Location'**
  String get checkoutDeliveryLocation;

  /// No description provided for @checkoutDeliveryLocationHint.
  ///
  /// In en, this message translates to:
  /// **'Tap the map to set your delivery location.'**
  String get checkoutDeliveryLocationHint;

  /// No description provided for @checkoutSelectDeliveryLocation.
  ///
  /// In en, this message translates to:
  /// **'Please select a delivery location on the map.'**
  String get checkoutSelectDeliveryLocation;

  /// No description provided for @checkoutCashOnDelivery.
  ///
  /// In en, this message translates to:
  /// **'Cash on Delivery'**
  String get checkoutCashOnDelivery;

  /// No description provided for @checkoutCashOnDeliveryHint.
  ///
  /// In en, this message translates to:
  /// **'Pay the rider in cash when your order is delivered.'**
  String get checkoutCashOnDeliveryHint;

  /// No description provided for @checkoutEsewaPayment.
  ///
  /// In en, this message translates to:
  /// **'eSewa'**
  String get checkoutEsewaPayment;

  /// No description provided for @checkoutEsewaPaymentHint.
  ///
  /// In en, this message translates to:
  /// **'Pay securely with your eSewa digital wallet. Payment held in escrow until delivery.'**
  String get checkoutEsewaPaymentHint;

  /// No description provided for @checkoutKhaltiPayment.
  ///
  /// In en, this message translates to:
  /// **'Khalti'**
  String get checkoutKhaltiPayment;

  /// No description provided for @checkoutKhaltiPaymentHint.
  ///
  /// In en, this message translates to:
  /// **'Pay securely with your Khalti digital wallet. Payment held in escrow until delivery.'**
  String get checkoutKhaltiPaymentHint;

  /// No description provided for @checkoutConnectipsPayment.
  ///
  /// In en, this message translates to:
  /// **'connectIPS'**
  String get checkoutConnectipsPayment;

  /// No description provided for @checkoutConnectipsPaymentHint.
  ///
  /// In en, this message translates to:
  /// **'Pay directly from your bank account via connectIPS. Payment held in escrow until delivery.'**
  String get checkoutConnectipsPaymentHint;

  /// No description provided for @checkoutSubtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get checkoutSubtotal;

  /// No description provided for @checkoutDeliveryFee.
  ///
  /// In en, this message translates to:
  /// **'Delivery Fee'**
  String get checkoutDeliveryFee;

  /// No description provided for @checkoutCalculatingFee.
  ///
  /// In en, this message translates to:
  /// **'Calculating delivery fee...'**
  String get checkoutCalculatingFee;

  /// No description provided for @checkoutFeeError.
  ///
  /// In en, this message translates to:
  /// **'Could not calculate delivery fee. Please try a different delivery location.'**
  String get checkoutFeeError;

  /// No description provided for @checkoutBaseFee.
  ///
  /// In en, this message translates to:
  /// **'Base Fee'**
  String get checkoutBaseFee;

  /// No description provided for @checkoutDistanceFee.
  ///
  /// In en, this message translates to:
  /// **'Distance ({km} km)'**
  String checkoutDistanceFee(String km);

  /// No description provided for @checkoutWeightFee.
  ///
  /// In en, this message translates to:
  /// **'Weight ({kg} kg)'**
  String checkoutWeightFee(String kg);

  /// No description provided for @checkoutTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get checkoutTotal;

  /// No description provided for @checkoutPlaceOrder.
  ///
  /// In en, this message translates to:
  /// **'Place Order'**
  String get checkoutPlaceOrder;

  /// No description provided for @checkoutPlacing.
  ///
  /// In en, this message translates to:
  /// **'Placing order...'**
  String get checkoutPlacing;

  /// No description provided for @checkoutRedirectingToPayment.
  ///
  /// In en, this message translates to:
  /// **'Redirecting to payment...'**
  String get checkoutRedirectingToPayment;

  /// No description provided for @ordersTitle.
  ///
  /// In en, this message translates to:
  /// **'My Orders'**
  String get ordersTitle;

  /// No description provided for @ordersNoOrders.
  ///
  /// In en, this message translates to:
  /// **'No orders yet'**
  String get ordersNoOrders;

  /// No description provided for @ordersOrderNumber.
  ///
  /// In en, this message translates to:
  /// **'Order #{id}'**
  String ordersOrderNumber(String id);

  /// No description provided for @ordersPlaced.
  ///
  /// In en, this message translates to:
  /// **'Placed {date}'**
  String ordersPlaced(String date);

  /// No description provided for @ordersTabActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get ordersTabActive;

  /// No description provided for @ordersTabCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get ordersTabCompleted;

  /// No description provided for @ordersStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get ordersStatusPending;

  /// No description provided for @ordersStatusMatched.
  ///
  /// In en, this message translates to:
  /// **'Matched'**
  String get ordersStatusMatched;

  /// No description provided for @ordersStatusPickedUp.
  ///
  /// In en, this message translates to:
  /// **'Picked Up'**
  String get ordersStatusPickedUp;

  /// No description provided for @ordersStatusInTransit.
  ///
  /// In en, this message translates to:
  /// **'In Transit'**
  String get ordersStatusInTransit;

  /// No description provided for @ordersStatusDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get ordersStatusDelivered;

  /// No description provided for @ordersStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get ordersStatusCancelled;

  /// No description provided for @ordersStatusDisputed.
  ///
  /// In en, this message translates to:
  /// **'Disputed'**
  String get ordersStatusDisputed;

  /// No description provided for @ordersOrderDetail.
  ///
  /// In en, this message translates to:
  /// **'Order Details'**
  String get ordersOrderDetail;

  /// No description provided for @ordersItems.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get ordersItems;

  /// No description provided for @ordersFromFarmer.
  ///
  /// In en, this message translates to:
  /// **'from {farmer}'**
  String ordersFromFarmer(String farmer);

  /// No description provided for @ordersDeliveryAddress.
  ///
  /// In en, this message translates to:
  /// **'Delivery Address'**
  String get ordersDeliveryAddress;

  /// No description provided for @ordersRiderInfo.
  ///
  /// In en, this message translates to:
  /// **'Rider Information'**
  String get ordersRiderInfo;

  /// No description provided for @ordersSubtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get ordersSubtotal;

  /// No description provided for @ordersDeliveryFee.
  ///
  /// In en, this message translates to:
  /// **'Delivery Fee'**
  String get ordersDeliveryFee;

  /// No description provided for @ordersTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get ordersTotal;

  /// No description provided for @ordersPaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment Method'**
  String get ordersPaymentMethod;

  /// No description provided for @ordersPaymentStatus.
  ///
  /// In en, this message translates to:
  /// **'Payment Status'**
  String get ordersPaymentStatus;

  /// No description provided for @ordersPaymentStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get ordersPaymentStatusPending;

  /// No description provided for @ordersPaymentStatusEscrowed.
  ///
  /// In en, this message translates to:
  /// **'Held in Escrow'**
  String get ordersPaymentStatusEscrowed;

  /// No description provided for @ordersPaymentStatusCollected.
  ///
  /// In en, this message translates to:
  /// **'Collected'**
  String get ordersPaymentStatusCollected;

  /// No description provided for @ordersPaymentStatusSettled.
  ///
  /// In en, this message translates to:
  /// **'Settled'**
  String get ordersPaymentStatusSettled;

  /// No description provided for @ordersPaymentStatusRefunded.
  ///
  /// In en, this message translates to:
  /// **'Refunded'**
  String get ordersPaymentStatusRefunded;

  /// No description provided for @ordersPaymentSuccess.
  ///
  /// In en, this message translates to:
  /// **'Payment successful! Your funds are held securely in escrow until delivery.'**
  String get ordersPaymentSuccess;

  /// No description provided for @ordersPaymentFailed.
  ///
  /// In en, this message translates to:
  /// **'Payment was not completed. You can retry below.'**
  String get ordersPaymentFailed;

  /// No description provided for @ordersConfirmDelivery.
  ///
  /// In en, this message translates to:
  /// **'Confirm Delivery Received'**
  String get ordersConfirmDelivery;

  /// No description provided for @ordersCancelOrder.
  ///
  /// In en, this message translates to:
  /// **'Cancel Order'**
  String get ordersCancelOrder;

  /// No description provided for @ordersDeliveryConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Delivery confirmed! Thank you.'**
  String get ordersDeliveryConfirmed;

  /// No description provided for @ordersRateOrder.
  ///
  /// In en, this message translates to:
  /// **'Rate this order'**
  String get ordersRateOrder;

  /// No description provided for @ordersRateFarmer.
  ///
  /// In en, this message translates to:
  /// **'Rate Farmer'**
  String get ordersRateFarmer;

  /// No description provided for @ordersRateRider.
  ///
  /// In en, this message translates to:
  /// **'Rate Rider'**
  String get ordersRateRider;

  /// No description provided for @ordersRated.
  ///
  /// In en, this message translates to:
  /// **'Rated'**
  String get ordersRated;

  /// No description provided for @ordersReorder.
  ///
  /// In en, this message translates to:
  /// **'Reorder'**
  String get ordersReorder;

  /// No description provided for @ordersRetryEsewaPayment.
  ///
  /// In en, this message translates to:
  /// **'Pay with eSewa'**
  String get ordersRetryEsewaPayment;

  /// No description provided for @ordersRetryKhaltiPayment.
  ///
  /// In en, this message translates to:
  /// **'Pay with Khalti'**
  String get ordersRetryKhaltiPayment;

  /// No description provided for @ordersRetryConnectIPSPayment.
  ///
  /// In en, this message translates to:
  /// **'Pay with connectIPS'**
  String get ordersRetryConnectIPSPayment;

  /// No description provided for @ordersTotalItems.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String ordersTotalItems(int count);

  /// No description provided for @ordersRider.
  ///
  /// In en, this message translates to:
  /// **'Rider'**
  String get ordersRider;

  /// No description provided for @ordersFarmer.
  ///
  /// In en, this message translates to:
  /// **'Farmer'**
  String get ordersFarmer;

  /// No description provided for @ordersReceipt.
  ///
  /// In en, this message translates to:
  /// **'Receipt'**
  String get ordersReceipt;

  /// No description provided for @ordersBackToOrders.
  ///
  /// In en, this message translates to:
  /// **'Back to orders'**
  String get ordersBackToOrders;

  /// No description provided for @ratingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Ratings & Reviews'**
  String get ratingsTitle;

  /// No description provided for @ratingsSubmitRating.
  ///
  /// In en, this message translates to:
  /// **'Submit Rating'**
  String get ratingsSubmitRating;

  /// No description provided for @ratingsSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Submitting...'**
  String get ratingsSubmitting;

  /// No description provided for @ratingsRateYourExperience.
  ///
  /// In en, this message translates to:
  /// **'Rate your experience'**
  String get ratingsRateYourExperience;

  /// No description provided for @ratingsCommentPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Share your experience (optional)'**
  String get ratingsCommentPlaceholder;

  /// No description provided for @ratingsStar1.
  ///
  /// In en, this message translates to:
  /// **'Poor'**
  String get ratingsStar1;

  /// No description provided for @ratingsStar2.
  ///
  /// In en, this message translates to:
  /// **'Fair'**
  String get ratingsStar2;

  /// No description provided for @ratingsStar3.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get ratingsStar3;

  /// No description provided for @ratingsStar4.
  ///
  /// In en, this message translates to:
  /// **'Very Good'**
  String get ratingsStar4;

  /// No description provided for @ratingsStar5.
  ///
  /// In en, this message translates to:
  /// **'Excellent'**
  String get ratingsStar5;

  /// No description provided for @ratingsThankYou.
  ///
  /// In en, this message translates to:
  /// **'Thank you for your rating!'**
  String get ratingsThankYou;

  /// No description provided for @ratingsAlreadyRated.
  ///
  /// In en, this message translates to:
  /// **'You have already rated this person for this order.'**
  String get ratingsAlreadyRated;

  /// No description provided for @ratingsNoRatings.
  ///
  /// In en, this message translates to:
  /// **'No ratings yet'**
  String get ratingsNoRatings;

  /// No description provided for @ratingsError.
  ///
  /// In en, this message translates to:
  /// **'Failed to submit rating. Please try again.'**
  String get ratingsError;

  /// No description provided for @ratingsClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get ratingsClose;

  /// No description provided for @farmerDashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Farmer Dashboard'**
  String get farmerDashboardTitle;

  /// No description provided for @farmerAddListing.
  ///
  /// In en, this message translates to:
  /// **'Add Listing'**
  String get farmerAddListing;

  /// No description provided for @farmerActiveListings.
  ///
  /// In en, this message translates to:
  /// **'Active Listings'**
  String get farmerActiveListings;

  /// No description provided for @farmerPendingOrders.
  ///
  /// In en, this message translates to:
  /// **'Pending Orders'**
  String get farmerPendingOrders;

  /// No description provided for @farmerEarnings.
  ///
  /// In en, this message translates to:
  /// **'Total Earnings'**
  String get farmerEarnings;

  /// No description provided for @farmerMyListings.
  ///
  /// In en, this message translates to:
  /// **'My Listings'**
  String get farmerMyListings;

  /// No description provided for @farmerNoListings.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t listed any produce yet.'**
  String get farmerNoListings;

  /// No description provided for @farmerAddFirstListing.
  ///
  /// In en, this message translates to:
  /// **'Add Your First Listing'**
  String get farmerAddFirstListing;

  /// No description provided for @farmerNewListingTitle.
  ///
  /// In en, this message translates to:
  /// **'Add New Listing'**
  String get farmerNewListingTitle;

  /// No description provided for @farmerEditListingTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Listing'**
  String get farmerEditListingTitle;

  /// No description provided for @farmerListingActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get farmerListingActive;

  /// No description provided for @farmerListingInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get farmerListingInactive;

  /// No description provided for @farmerFormCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get farmerFormCategory;

  /// No description provided for @farmerFormSelectCategory.
  ///
  /// In en, this message translates to:
  /// **'Select a category'**
  String get farmerFormSelectCategory;

  /// No description provided for @farmerFormNameEn.
  ///
  /// In en, this message translates to:
  /// **'Name (English)'**
  String get farmerFormNameEn;

  /// No description provided for @farmerFormNameNe.
  ///
  /// In en, this message translates to:
  /// **'Name (Nepali)'**
  String get farmerFormNameNe;

  /// No description provided for @farmerFormDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get farmerFormDescription;

  /// No description provided for @farmerFormPricePerKg.
  ///
  /// In en, this message translates to:
  /// **'Price per kg (NPR)'**
  String get farmerFormPricePerKg;

  /// No description provided for @farmerFormAvailableQty.
  ///
  /// In en, this message translates to:
  /// **'Available Quantity (kg)'**
  String get farmerFormAvailableQty;

  /// No description provided for @farmerFormFreshnessDate.
  ///
  /// In en, this message translates to:
  /// **'Freshness Date'**
  String get farmerFormFreshnessDate;

  /// No description provided for @farmerFormPhotos.
  ///
  /// In en, this message translates to:
  /// **'Photos (up to 5)'**
  String get farmerFormPhotos;

  /// No description provided for @farmerFormSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get farmerFormSaving;

  /// No description provided for @farmerFormCreate.
  ///
  /// In en, this message translates to:
  /// **'Create Listing'**
  String get farmerFormCreate;

  /// No description provided for @farmerFormUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update Listing'**
  String get farmerFormUpdate;

  /// No description provided for @farmerFormCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get farmerFormCancel;

  /// No description provided for @farmerFormErrorCategory.
  ///
  /// In en, this message translates to:
  /// **'Please select a category.'**
  String get farmerFormErrorCategory;

  /// No description provided for @farmerFormErrorName.
  ///
  /// In en, this message translates to:
  /// **'Both English and Nepali names are required.'**
  String get farmerFormErrorName;

  /// No description provided for @farmerFormErrorPrice.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid price.'**
  String get farmerFormErrorPrice;

  /// No description provided for @farmerFormErrorQty.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid quantity.'**
  String get farmerFormErrorQty;

  /// No description provided for @farmerVerificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Identity Verification'**
  String get farmerVerificationTitle;

  /// No description provided for @farmerVerificationDescription.
  ///
  /// In en, this message translates to:
  /// **'Submit your documents to get verified. Verified farmers get a badge and appear higher in search results.'**
  String get farmerVerificationDescription;

  /// No description provided for @farmerVerificationStatusUnverified.
  ///
  /// In en, this message translates to:
  /// **'Your account is not yet verified.'**
  String get farmerVerificationStatusUnverified;

  /// No description provided for @farmerVerificationStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Your documents are under review.'**
  String get farmerVerificationStatusPending;

  /// No description provided for @farmerVerificationStatusApproved.
  ///
  /// In en, this message translates to:
  /// **'Your account is verified!'**
  String get farmerVerificationStatusApproved;

  /// No description provided for @farmerVerificationStatusRejected.
  ///
  /// In en, this message translates to:
  /// **'Your verification was not approved.'**
  String get farmerVerificationStatusRejected;

  /// No description provided for @farmerVerificationSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit Documents'**
  String get farmerVerificationSubmit;

  /// No description provided for @farmerVerificationResubmit.
  ///
  /// In en, this message translates to:
  /// **'Resubmit Documents'**
  String get farmerVerificationResubmit;

  /// No description provided for @farmerVerificationCitizenshipPhoto.
  ///
  /// In en, this message translates to:
  /// **'Citizenship / ID Card Photo'**
  String get farmerVerificationCitizenshipPhoto;

  /// No description provided for @farmerVerificationFarmPhoto.
  ///
  /// In en, this message translates to:
  /// **'Farm Photo'**
  String get farmerVerificationFarmPhoto;

  /// No description provided for @farmerVerificationMunicipalityLetter.
  ///
  /// In en, this message translates to:
  /// **'Municipality Letter (Optional)'**
  String get farmerVerificationMunicipalityLetter;

  /// No description provided for @farmerVerificationUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading...'**
  String get farmerVerificationUploading;

  /// No description provided for @farmerVerificationSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Submitting...'**
  String get farmerVerificationSubmitting;

  /// No description provided for @farmerVerificationSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Documents submitted for review!'**
  String get farmerVerificationSubmitted;

  /// No description provided for @farmerVerificationVerifiedBadge.
  ///
  /// In en, this message translates to:
  /// **'Verified Farmer'**
  String get farmerVerificationVerifiedBadge;

  /// No description provided for @farmerAnalyticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get farmerAnalyticsTitle;

  /// No description provided for @farmerAnalyticsTotalRevenue.
  ///
  /// In en, this message translates to:
  /// **'Total Revenue'**
  String get farmerAnalyticsTotalRevenue;

  /// No description provided for @farmerAnalyticsTotalOrders.
  ///
  /// In en, this message translates to:
  /// **'Total Orders'**
  String get farmerAnalyticsTotalOrders;

  /// No description provided for @farmerAnalyticsAvgRating.
  ///
  /// In en, this message translates to:
  /// **'Avg Rating'**
  String get farmerAnalyticsAvgRating;

  /// No description provided for @farmerAnalyticsRevenueTrend.
  ///
  /// In en, this message translates to:
  /// **'Revenue Trend'**
  String get farmerAnalyticsRevenueTrend;

  /// No description provided for @farmerAnalyticsSalesByCategory.
  ///
  /// In en, this message translates to:
  /// **'Sales by Category'**
  String get farmerAnalyticsSalesByCategory;

  /// No description provided for @farmerAnalyticsTopProducts.
  ///
  /// In en, this message translates to:
  /// **'Top Products'**
  String get farmerAnalyticsTopProducts;

  /// No description provided for @farmerAnalyticsPriceBenchmarks.
  ///
  /// In en, this message translates to:
  /// **'Price Comparison'**
  String get farmerAnalyticsPriceBenchmarks;

  /// No description provided for @farmerAnalyticsFulfillmentRate.
  ///
  /// In en, this message translates to:
  /// **'Fulfillment Rate'**
  String get farmerAnalyticsFulfillmentRate;

  /// No description provided for @farmerAnalyticsNoData.
  ///
  /// In en, this message translates to:
  /// **'No data for this period.'**
  String get farmerAnalyticsNoData;

  /// No description provided for @farmerAnalyticsPeriod7days.
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get farmerAnalyticsPeriod7days;

  /// No description provided for @farmerAnalyticsPeriod30days.
  ///
  /// In en, this message translates to:
  /// **'30 days'**
  String get farmerAnalyticsPeriod30days;

  /// No description provided for @farmerAnalyticsPeriod90days.
  ///
  /// In en, this message translates to:
  /// **'90 days'**
  String get farmerAnalyticsPeriod90days;

  /// No description provided for @riderDashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Rider Dashboard'**
  String get riderDashboardTitle;

  /// No description provided for @riderPostTrip.
  ///
  /// In en, this message translates to:
  /// **'Post a Trip'**
  String get riderPostTrip;

  /// No description provided for @riderUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get riderUpcoming;

  /// No description provided for @riderActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get riderActive;

  /// No description provided for @riderCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get riderCompleted;

  /// No description provided for @riderNoTrips.
  ///
  /// In en, this message translates to:
  /// **'No trips yet'**
  String get riderNoTrips;

  /// No description provided for @riderPostFirstTrip.
  ///
  /// In en, this message translates to:
  /// **'Post your first trip'**
  String get riderPostFirstTrip;

  /// No description provided for @riderTripFormTitle.
  ///
  /// In en, this message translates to:
  /// **'Post a Trip'**
  String get riderTripFormTitle;

  /// No description provided for @riderPickOrigin.
  ///
  /// In en, this message translates to:
  /// **'Where are you starting?'**
  String get riderPickOrigin;

  /// No description provided for @riderPickOriginHint.
  ///
  /// In en, this message translates to:
  /// **'Tap the map to select your starting point.'**
  String get riderPickOriginHint;

  /// No description provided for @riderPickDestination.
  ///
  /// In en, this message translates to:
  /// **'Where are you heading?'**
  String get riderPickDestination;

  /// No description provided for @riderPickDestinationHint.
  ///
  /// In en, this message translates to:
  /// **'Tap the map to select your destination.'**
  String get riderPickDestinationHint;

  /// No description provided for @riderTripDetails.
  ///
  /// In en, this message translates to:
  /// **'Trip Details'**
  String get riderTripDetails;

  /// No description provided for @riderDepartureDate.
  ///
  /// In en, this message translates to:
  /// **'Departure Date'**
  String get riderDepartureDate;

  /// No description provided for @riderDepartureTime.
  ///
  /// In en, this message translates to:
  /// **'Departure Time'**
  String get riderDepartureTime;

  /// No description provided for @riderCapacity.
  ///
  /// In en, this message translates to:
  /// **'Available Capacity (kg)'**
  String get riderCapacity;

  /// No description provided for @riderVehicleType.
  ///
  /// In en, this message translates to:
  /// **'Vehicle Type'**
  String get riderVehicleType;

  /// No description provided for @riderDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get riderDistance;

  /// No description provided for @riderDuration.
  ///
  /// In en, this message translates to:
  /// **'Est. Duration'**
  String get riderDuration;

  /// No description provided for @riderFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get riderFrom;

  /// No description provided for @riderTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get riderTo;

  /// No description provided for @riderNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get riderNext;

  /// No description provided for @riderBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get riderBack;

  /// No description provided for @riderReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get riderReview;

  /// No description provided for @riderReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Review Your Trip'**
  String get riderReviewTitle;

  /// No description provided for @riderPostTripBtn.
  ///
  /// In en, this message translates to:
  /// **'Post Trip'**
  String get riderPostTripBtn;

  /// No description provided for @riderPosting.
  ///
  /// In en, this message translates to:
  /// **'Posting...'**
  String get riderPosting;

  /// No description provided for @riderCalculatingRoute.
  ///
  /// In en, this message translates to:
  /// **'Calculating route...'**
  String get riderCalculatingRoute;

  /// No description provided for @riderRouteError.
  ///
  /// In en, this message translates to:
  /// **'Could not calculate route. Please try different locations.'**
  String get riderRouteError;

  /// No description provided for @riderTripDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Trip Detail'**
  String get riderTripDetailTitle;

  /// No description provided for @riderTripInfo.
  ///
  /// In en, this message translates to:
  /// **'Trip Information'**
  String get riderTripInfo;

  /// No description provided for @riderTotalCapacity.
  ///
  /// In en, this message translates to:
  /// **'Total Capacity'**
  String get riderTotalCapacity;

  /// No description provided for @riderRemainingCapacity.
  ///
  /// In en, this message translates to:
  /// **'Remaining Capacity'**
  String get riderRemainingCapacity;

  /// No description provided for @riderMatchedOrders.
  ///
  /// In en, this message translates to:
  /// **'Matched Orders'**
  String get riderMatchedOrders;

  /// No description provided for @riderNoMatchedOrders.
  ///
  /// In en, this message translates to:
  /// **'No orders matched to this trip yet.'**
  String get riderNoMatchedOrders;

  /// No description provided for @riderStartTrip.
  ///
  /// In en, this message translates to:
  /// **'Start Trip'**
  String get riderStartTrip;

  /// No description provided for @riderStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting...'**
  String get riderStarting;

  /// No description provided for @riderCompleteTrip.
  ///
  /// In en, this message translates to:
  /// **'Complete Trip'**
  String get riderCompleteTrip;

  /// No description provided for @riderCompleting.
  ///
  /// In en, this message translates to:
  /// **'Completing...'**
  String get riderCompleting;

  /// No description provided for @riderCancelTrip.
  ///
  /// In en, this message translates to:
  /// **'Cancel Trip'**
  String get riderCancelTrip;

  /// No description provided for @riderConfirmPickup.
  ///
  /// In en, this message translates to:
  /// **'Confirm Pickup'**
  String get riderConfirmPickup;

  /// No description provided for @riderStartDelivery.
  ///
  /// In en, this message translates to:
  /// **'Start Delivery'**
  String get riderStartDelivery;

  /// No description provided for @riderOptimizeRoute.
  ///
  /// In en, this message translates to:
  /// **'Optimize Route'**
  String get riderOptimizeRoute;

  /// No description provided for @riderOptimizing.
  ///
  /// In en, this message translates to:
  /// **'Optimizing...'**
  String get riderOptimizing;

  /// No description provided for @riderTripStatusScheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get riderTripStatusScheduled;

  /// No description provided for @riderTripStatusInTransit.
  ///
  /// In en, this message translates to:
  /// **'In Transit'**
  String get riderTripStatusInTransit;

  /// No description provided for @riderTripStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get riderTripStatusCompleted;

  /// No description provided for @riderTripStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get riderTripStatusCancelled;

  /// No description provided for @riderPingsNewOrders.
  ///
  /// In en, this message translates to:
  /// **'New Order Requests'**
  String get riderPingsNewOrders;

  /// No description provided for @riderPingsPickup.
  ///
  /// In en, this message translates to:
  /// **'Pickup'**
  String get riderPingsPickup;

  /// No description provided for @riderPingsDelivery.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get riderPingsDelivery;

  /// No description provided for @riderPingsWeight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get riderPingsWeight;

  /// No description provided for @riderPingsEarnings.
  ///
  /// In en, this message translates to:
  /// **'Earnings'**
  String get riderPingsEarnings;

  /// No description provided for @riderPingsDetour.
  ///
  /// In en, this message translates to:
  /// **'Detour'**
  String get riderPingsDetour;

  /// No description provided for @riderPingsAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get riderPingsAccept;

  /// No description provided for @riderPingsDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get riderPingsDecline;

  /// No description provided for @riderPingsExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get riderPingsExpired;

  /// No description provided for @riderPingsAccepting.
  ///
  /// In en, this message translates to:
  /// **'Accepting...'**
  String get riderPingsAccepting;

  /// No description provided for @riderPingsDeclining.
  ///
  /// In en, this message translates to:
  /// **'Declining...'**
  String get riderPingsDeclining;

  /// No description provided for @riderPingsAccepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get riderPingsAccepted;

  /// No description provided for @riderPingsExpiresIn.
  ///
  /// In en, this message translates to:
  /// **'Expires in {time}'**
  String riderPingsExpiresIn(String time);

  /// No description provided for @chatTitle.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get chatTitle;

  /// No description provided for @chatNoConversations.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get chatNoConversations;

  /// No description provided for @chatNoConversationsHint.
  ///
  /// In en, this message translates to:
  /// **'Start a conversation from an order page.'**
  String get chatNoConversationsHint;

  /// No description provided for @chatSearchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search conversations...'**
  String get chatSearchPlaceholder;

  /// No description provided for @chatYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get chatYou;

  /// No description provided for @chatImage.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get chatImage;

  /// No description provided for @chatLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get chatLocation;

  /// No description provided for @chatTypeMessage.
  ///
  /// In en, this message translates to:
  /// **'Type a message...'**
  String get chatTypeMessage;

  /// No description provided for @chatSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get chatSend;

  /// No description provided for @chatSendImage.
  ///
  /// In en, this message translates to:
  /// **'Send image'**
  String get chatSendImage;

  /// No description provided for @chatToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get chatToday;

  /// No description provided for @chatYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get chatYesterday;

  /// No description provided for @chatLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load earlier messages'**
  String get chatLoadMore;

  /// No description provided for @notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// No description provided for @notificationsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get notificationsEmpty;

  /// No description provided for @notificationsMarkAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all as read'**
  String get notificationsMarkAllRead;

  /// No description provided for @notificationsPreferencesTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification Preferences'**
  String get notificationsPreferencesTitle;

  /// No description provided for @notificationsConsumerGroup.
  ///
  /// In en, this message translates to:
  /// **'Order Updates'**
  String get notificationsConsumerGroup;

  /// No description provided for @notificationsFarmerGroup.
  ///
  /// In en, this message translates to:
  /// **'Farm Orders'**
  String get notificationsFarmerGroup;

  /// No description provided for @notificationsRiderGroup.
  ///
  /// In en, this message translates to:
  /// **'Trip & Delivery'**
  String get notificationsRiderGroup;

  /// No description provided for @subscriptionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Subscription Boxes'**
  String get subscriptionsTitle;

  /// No description provided for @subscriptionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Fresh produce delivered to your door every week'**
  String get subscriptionsSubtitle;

  /// No description provided for @subscriptionsNoPlans.
  ///
  /// In en, this message translates to:
  /// **'No subscription plans available yet.'**
  String get subscriptionsNoPlans;

  /// No description provided for @subscriptionsNoSubscriptions.
  ///
  /// In en, this message translates to:
  /// **'You have no active subscriptions.'**
  String get subscriptionsNoSubscriptions;

  /// No description provided for @subscriptionsBrowse.
  ///
  /// In en, this message translates to:
  /// **'Browse Plans'**
  String get subscriptionsBrowse;

  /// No description provided for @subscriptionsMy.
  ///
  /// In en, this message translates to:
  /// **'My Subscriptions'**
  String get subscriptionsMy;

  /// No description provided for @subscriptionsFrequencyWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get subscriptionsFrequencyWeekly;

  /// No description provided for @subscriptionsFrequencyBiweekly.
  ///
  /// In en, this message translates to:
  /// **'Biweekly'**
  String get subscriptionsFrequencyBiweekly;

  /// No description provided for @subscriptionsFrequencyMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get subscriptionsFrequencyMonthly;

  /// No description provided for @subscriptionsStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get subscriptionsStatusActive;

  /// No description provided for @subscriptionsStatusPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get subscriptionsStatusPaused;

  /// No description provided for @subscriptionsStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get subscriptionsStatusCancelled;

  /// No description provided for @subscriptionsByFarmer.
  ///
  /// In en, this message translates to:
  /// **'by {name}'**
  String subscriptionsByFarmer(String name);

  /// No description provided for @subscriptionsSubscribe.
  ///
  /// In en, this message translates to:
  /// **'Subscribe'**
  String get subscriptionsSubscribe;

  /// No description provided for @subscriptionsSubscribing.
  ///
  /// In en, this message translates to:
  /// **'Subscribing...'**
  String get subscriptionsSubscribing;

  /// No description provided for @subscriptionsPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get subscriptionsPause;

  /// No description provided for @subscriptionsResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get subscriptionsResume;

  /// No description provided for @subscriptionsCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get subscriptionsCancel;

  /// No description provided for @subscriptionsCreatePlan.
  ///
  /// In en, this message translates to:
  /// **'Create Plan'**
  String get subscriptionsCreatePlan;

  /// No description provided for @businessRegisterTitle.
  ///
  /// In en, this message translates to:
  /// **'Register Your Business'**
  String get businessRegisterTitle;

  /// No description provided for @businessDashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Business Dashboard'**
  String get businessDashboardTitle;

  /// No description provided for @businessCreateOrder.
  ///
  /// In en, this message translates to:
  /// **'New Bulk Order'**
  String get businessCreateOrder;

  /// No description provided for @businessBulkOrdersTitle.
  ///
  /// In en, this message translates to:
  /// **'Bulk Orders'**
  String get businessBulkOrdersTitle;

  /// No description provided for @businessActiveOrders.
  ///
  /// In en, this message translates to:
  /// **'Active Orders'**
  String get businessActiveOrders;

  /// No description provided for @businessCompletedOrders.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get businessCompletedOrders;

  /// No description provided for @businessTotalSpent.
  ///
  /// In en, this message translates to:
  /// **'Total Spent'**
  String get businessTotalSpent;

  /// No description provided for @businessNoOrders.
  ///
  /// In en, this message translates to:
  /// **'No bulk orders yet'**
  String get businessNoOrders;

  /// No description provided for @businessStatusDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get businessStatusDraft;

  /// No description provided for @businessStatusSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get businessStatusSubmitted;

  /// No description provided for @businessStatusQuoted.
  ///
  /// In en, this message translates to:
  /// **'Quoted'**
  String get businessStatusQuoted;

  /// No description provided for @businessStatusAccepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get businessStatusAccepted;

  /// No description provided for @businessStatusInProgress.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get businessStatusInProgress;

  /// No description provided for @businessStatusFulfilled.
  ///
  /// In en, this message translates to:
  /// **'Fulfilled'**
  String get businessStatusFulfilled;

  /// No description provided for @businessStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get businessStatusCancelled;

  /// No description provided for @businessAcceptQuotes.
  ///
  /// In en, this message translates to:
  /// **'Accept All Quotes'**
  String get businessAcceptQuotes;

  /// No description provided for @businessCancelOrder.
  ///
  /// In en, this message translates to:
  /// **'Cancel Order'**
  String get businessCancelOrder;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get commonLoading;

  /// No description provided for @commonError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get commonError;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// No description provided for @commonSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get commonSearch;

  /// No description provided for @commonNoData.
  ///
  /// In en, this message translates to:
  /// **'No data available'**
  String get commonNoData;

  /// No description provided for @commonSuccess.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get commonSuccess;

  /// No description provided for @commonUnknownError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get commonUnknownError;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// No description provided for @commonNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get commonNext;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @commonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @commonYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get commonYes;

  /// No description provided for @commonNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get commonNo;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageNepali.
  ///
  /// In en, this message translates to:
  /// **'Nepali'**
  String get languageNepali;

  /// No description provided for @paymentProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing payment...'**
  String get paymentProcessing;

  /// No description provided for @paymentSuccess.
  ///
  /// In en, this message translates to:
  /// **'Payment successful!'**
  String get paymentSuccess;

  /// No description provided for @paymentFailed.
  ///
  /// In en, this message translates to:
  /// **'Payment failed'**
  String get paymentFailed;

  /// No description provided for @paymentVerifying.
  ///
  /// In en, this message translates to:
  /// **'Verifying payment...'**
  String get paymentVerifying;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ne'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ne':
      return AppLocalizationsNe();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
