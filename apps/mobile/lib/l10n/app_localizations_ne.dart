// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Nepali (`ne`).
class AppLocalizationsNe extends AppLocalizations {
  AppLocalizationsNe([String locale = 'ne']) : super(locale);

  @override
  String get navHome => 'गृह';

  @override
  String get navMarketplace => 'बजार';

  @override
  String get navTrips => 'यात्रा';

  @override
  String get navOrders => 'अर्डरहरू';

  @override
  String get navProfile => 'प्रोफाइल';

  @override
  String get navMessages => 'सन्देशहरू';

  @override
  String get authLoginTitle => 'जिरीसेवामा लगइन गर्नुहोस्';

  @override
  String get authLoginSubtitle =>
      'सुरु गर्न आफ्नो फोन नम्बर प्रविष्ट गर्नुहोस्';

  @override
  String get authPhoneLabel => 'फोन नम्बर';

  @override
  String get authPhonePlaceholder => '98XXXXXXXX';

  @override
  String get authPhoneHint =>
      'आफ्नो १० अंकको नेपाल मोबाइल नम्बर प्रविष्ट गर्नुहोस्';

  @override
  String get authSendOtp => 'OTP पठाउनुहोस्';

  @override
  String get authOtpTitle => 'OTP प्रमाणित गर्नुहोस्';

  @override
  String authOtpSubtitle(String phone) {
    return '$phone मा पठाइएको ६ अंकको कोड प्रविष्ट गर्नुहोस्';
  }

  @override
  String get authOtpPlaceholder => '६ अंकको कोड प्रविष्ट गर्नुहोस्';

  @override
  String get authVerifyOtp => 'प्रमाणित गर्नुहोस्';

  @override
  String get authResendOtp => 'OTP पुन: पठाउनुहोस्';

  @override
  String authResendIn(int seconds) {
    return '$seconds सेकेन्डमा पुन: पठाउनुहोस्';
  }

  @override
  String get authChangePhone => 'फोन नम्बर परिवर्तन गर्नुहोस्';

  @override
  String get authInvalidPhone =>
      'मान्य नेपाल मोबाइल नम्बर प्रविष्ट गर्नुहोस् (98XXXXXXXX)';

  @override
  String get authOtpSent => 'तपाईंको फोनमा OTP पठाइयो';

  @override
  String get authOtpError => 'OTP पठाउन असफल। कृपया पुन: प्रयास गर्नुहोस्।';

  @override
  String get authVerifyError => 'अमान्य OTP। कृपया पुन: प्रयास गर्नुहोस्।';

  @override
  String get authSending => 'पठाउँदै...';

  @override
  String get authVerifying => 'प्रमाणित गर्दै...';

  @override
  String get registerTitle => 'आफ्नो प्रोफाइल पूरा गर्नुहोस्';

  @override
  String get registerSubtitle => 'सुरु गर्न आफ्नो बारेमा बताउनुहोस्';

  @override
  String get registerNameLabel => 'पूरा नाम';

  @override
  String get registerNamePlaceholder => 'तपाईंको पूरा नाम';

  @override
  String get registerLanguageLabel => 'रुचाइएको भाषा';

  @override
  String get registerAddressLabel => 'ठेगाना';

  @override
  String get registerAddressPlaceholder => 'तपाईंको ठेगाना वा नगरपालिका';

  @override
  String get registerMunicipalityLabel => 'नगरपालिका';

  @override
  String get registerMunicipalityPlaceholder => 'जस्तै: जिरी, काठमाडौं';

  @override
  String get registerRoleTitle => 'म हुँ...';

  @override
  String get registerRoleSubtitle => 'लागू हुने सबै छान्नुहोस्';

  @override
  String get registerRoleFarmer => 'किसान';

  @override
  String get registerRoleFarmerDesc => 'म उत्पादन उमार्छु र बेच्छु';

  @override
  String get registerRoleConsumer => 'उपभोक्ता';

  @override
  String get registerRoleConsumerDesc => 'म ताजा उत्पादन किन्छु';

  @override
  String get registerRoleRider => 'सवारी चालक';

  @override
  String get registerRoleRiderDesc => 'म यात्रा गर्छु र सामान बोक्न सक्छु';

  @override
  String get registerFarmNameLabel => 'फार्मको नाम';

  @override
  String get registerFarmNamePlaceholder => 'तपाईंको फार्मको नाम';

  @override
  String get registerVehicleTypeLabel => 'सवारी प्रकार';

  @override
  String get registerVehicleCapacityLabel => 'बोक्ने क्षमता (केजी)';

  @override
  String get registerVehicleCapacityPlaceholder => 'जस्तै: ५०';

  @override
  String get registerBike => 'बाइक';

  @override
  String get registerCar => 'कार';

  @override
  String get registerTruck => 'ट्रक';

  @override
  String get registerBus => 'बस';

  @override
  String get registerOther => 'अन्य';

  @override
  String get registerNext => 'अर्को';

  @override
  String get registerBack => 'पछाडि';

  @override
  String get registerComplete => 'दर्ता पूरा गर्नुहोस्';

  @override
  String get registerCompleting => 'पूरा गर्दै...';

  @override
  String get registerSelectRole => 'कृपया कम्तीमा एउटा भूमिका छान्नुहोस्';

  @override
  String get registerNameRequired => 'नाम आवश्यक छ';

  @override
  String registerStep(int current, int total) {
    return 'चरण $current / $total';
  }

  @override
  String get marketplaceTitle => 'बजार';

  @override
  String get marketplaceSubtitle => 'स्थानीय किसानहरूबाट सिधै ताजा उत्पादन';

  @override
  String get marketplaceSearchPlaceholder => 'उत्पादन खोज्नुहोस्...';

  @override
  String get marketplaceFilters => 'फिल्टरहरू';

  @override
  String get marketplaceClearFilters => 'फिल्टर हटाउनुहोस्';

  @override
  String get marketplaceAllCategories => 'सबै वर्गहरू';

  @override
  String get marketplacePriceRange => 'मूल्य दायरा';

  @override
  String get marketplaceMinPrice => 'न्यूनतम (रु)';

  @override
  String get marketplaceMaxPrice => 'अधिकतम (रु)';

  @override
  String get marketplaceSortBy => 'क्रमबद्ध';

  @override
  String get marketplaceSortPriceAsc => 'मूल्य: कमदेखि बढी';

  @override
  String get marketplaceSortPriceDesc => 'मूल्य: बढीदेखि कम';

  @override
  String get marketplaceSortFreshness => 'ताजापन';

  @override
  String get marketplaceSortRating => 'किसान रेटिङ';

  @override
  String get marketplaceSortDistance => 'दूरी';

  @override
  String get marketplaceNoResults => 'कुनै उत्पादन भेटिएन';

  @override
  String get marketplaceNoResultsHint =>
      'फिल्टर वा खोज शब्दहरू समायोजन गर्ने प्रयास गर्नुहोस्।';

  @override
  String get marketplacePerKg => '/केजी';

  @override
  String get marketplaceLoadMore => 'थप लोड गर्नुहोस्';

  @override
  String marketplaceShowing(int count) {
    return '$count वस्तुहरू देखाउँदै';
  }

  @override
  String get marketplaceSetLocation => 'तपाईंको स्थान सेट गर्नुहोस्';

  @override
  String get marketplaceSetLocationHint =>
      'नजिकैको उत्पादन र दूरी हेर्न स्थान सेट गर्नुहोस्।';

  @override
  String get marketplaceUseMyLocation => 'मेरो स्थान प्रयोग गर्नुहोस्';

  @override
  String get marketplaceLocationSet => 'स्थान सेट भयो';

  @override
  String marketplaceKmAway(String distance) {
    return '$distance किमी टाढा';
  }

  @override
  String marketplaceHarvestedOn(String date) {
    return '$date मा काटेको';
  }

  @override
  String marketplaceAvailable(String qty) {
    return '$qty केजी उपलब्ध';
  }

  @override
  String marketplaceFarmerRating(String rating, int count) {
    return '$rating ($count समीक्षा)';
  }

  @override
  String get marketplaceVerifiedFarmer => 'प्रमाणित';

  @override
  String get produceAddToCart => 'कार्टमा थप्नुहोस्';

  @override
  String get produceAddedToCart => 'थपियो!';

  @override
  String get produceQuantity => 'परिमाण (केजी)';

  @override
  String producePricePerKg(String price) {
    return 'रु $price/केजी';
  }

  @override
  String produceTotalPrice(String total) {
    return 'जम्मा: रु $total';
  }

  @override
  String get produceFarmerInfo => 'किसान जानकारी';

  @override
  String get produceFreshness => 'ताजापन';

  @override
  String get produceDescription => 'विवरण';

  @override
  String get produceCategory => 'वर्ग';

  @override
  String get produceLocation => 'स्थान';

  @override
  String get produceNotFound => 'उत्पादन भेटिएन';

  @override
  String get produceNotFoundHint =>
      'यो उत्पादन हटाइएको हुन सक्छ वा अब उपलब्ध छैन।';

  @override
  String get producePhotos => 'तस्बिरहरू';

  @override
  String get cartTitle => 'किनमेल कार्ट';

  @override
  String get cartEmpty => 'तपाईंको कार्ट खाली छ';

  @override
  String get cartEmptyHint => 'ताजा उत्पादन फेला पार्न बजार हेर्नुहोस्।';

  @override
  String get cartBrowseMarketplace => 'बजार हेर्नुहोस्';

  @override
  String get cartClearAll => 'सबै हटाउनुहोस्';

  @override
  String cartFromFarmer(String farmer) {
    return '$farmer बाट';
  }

  @override
  String get cartRemove => 'हटाउनुहोस्';

  @override
  String get cartSubtotal => 'उपजम्मा';

  @override
  String get cartProceedToCheckout => 'चेकआउटमा जानुहोस्';

  @override
  String get checkoutTitle => 'चेकआउट';

  @override
  String get checkoutOrderSummary => 'अर्डर सारांश';

  @override
  String get checkoutDeliveryLocation => 'डेलिभरी स्थान';

  @override
  String get checkoutDeliveryLocationHint =>
      'डेलिभरी स्थान सेट गर्न नक्सामा ट्याप गर्नुहोस्।';

  @override
  String get checkoutSelectDeliveryLocation =>
      'कृपया नक्सामा डेलिभरी स्थान चयन गर्नुहोस्।';

  @override
  String get checkoutCashOnDelivery => 'डेलिभरीमा नगद';

  @override
  String get checkoutCashOnDeliveryHint =>
      'अर्डर डेलिभर भएपछि सवारी चालकलाई नगदमा तिर्नुहोस्।';

  @override
  String get checkoutEsewaPayment => 'इसेवा';

  @override
  String get checkoutEsewaPaymentHint =>
      'इसेवा डिजिटल वालेटबाट सुरक्षित भुक्तानी गर्नुहोस्। डेलिभरी नभएसम्म रकम एस्क्रोमा राखिन्छ।';

  @override
  String get checkoutKhaltiPayment => 'खल्ती';

  @override
  String get checkoutKhaltiPaymentHint =>
      'खल्ती डिजिटल वालेटबाट सुरक्षित भुक्तानी गर्नुहोस्। डेलिभरी नभएसम्म रकम एस्क्रोमा राखिन्छ।';

  @override
  String get checkoutConnectipsPayment => 'कनेक्ट आइपीएस';

  @override
  String get checkoutConnectipsPaymentHint =>
      'कनेक्ट आइपीएस मार्फत बैंक खाताबाट सिधै तिर्नुहोस्। डेलिभरी नभएसम्म रकम एस्क्रोमा राखिन्छ।';

  @override
  String get checkoutSubtotal => 'उपजम्मा';

  @override
  String get checkoutDeliveryFee => 'डेलिभरी शुल्क';

  @override
  String get checkoutCalculatingFee => 'डेलिभरी शुल्क गणना गर्दै...';

  @override
  String get checkoutFeeError =>
      'डेलिभरी शुल्क गणना गर्न सकिएन। कृपया फरक डेलिभरी स्थान प्रयास गर्नुहोस्।';

  @override
  String get checkoutBaseFee => 'आधार शुल्क';

  @override
  String checkoutDistanceFee(String km) {
    return 'दूरी ($km किमी)';
  }

  @override
  String checkoutWeightFee(String kg) {
    return 'तौल ($kg केजी)';
  }

  @override
  String get checkoutTotal => 'जम्मा';

  @override
  String get checkoutPlaceOrder => 'अर्डर गर्नुहोस्';

  @override
  String get checkoutPlacing => 'अर्डर गर्दै...';

  @override
  String get checkoutRedirectingToPayment => 'भुक्तानीमा लैजाँदै...';

  @override
  String get ordersTitle => 'मेरा अर्डरहरू';

  @override
  String get ordersNoOrders => 'अहिलेसम्म कुनै अर्डर छैन';

  @override
  String ordersOrderNumber(String id) {
    return 'अर्डर #$id';
  }

  @override
  String ordersPlaced(String date) {
    return '$date मा राखिएको';
  }

  @override
  String get ordersTabActive => 'सक्रिय';

  @override
  String get ordersTabCompleted => 'सम्पन्न';

  @override
  String get ordersStatusPending => 'बाँकी';

  @override
  String get ordersStatusMatched => 'मिलेको';

  @override
  String get ordersStatusPickedUp => 'उठाइएको';

  @override
  String get ordersStatusInTransit => 'बाटोमा';

  @override
  String get ordersStatusDelivered => 'डेलिभर भयो';

  @override
  String get ordersStatusCancelled => 'रद्द';

  @override
  String get ordersStatusDisputed => 'विवाद';

  @override
  String get ordersOrderDetail => 'अर्डर विवरण';

  @override
  String get ordersItems => 'वस्तुहरू';

  @override
  String ordersFromFarmer(String farmer) {
    return '$farmer बाट';
  }

  @override
  String get ordersDeliveryAddress => 'डेलिभरी ठेगाना';

  @override
  String get ordersRiderInfo => 'सवारी चालक जानकारी';

  @override
  String get ordersSubtotal => 'उपजम्मा';

  @override
  String get ordersDeliveryFee => 'डेलिभरी शुल्क';

  @override
  String get ordersTotal => 'जम्मा';

  @override
  String get ordersPaymentMethod => 'भुक्तानी विधि';

  @override
  String get ordersPaymentStatus => 'भुक्तानी स्थिति';

  @override
  String get ordersPaymentStatusPending => 'बाँकी';

  @override
  String get ordersPaymentStatusEscrowed => 'एस्क्रोमा राखिएको';

  @override
  String get ordersPaymentStatusCollected => 'संकलित';

  @override
  String get ordersPaymentStatusSettled => 'भुक्तान भयो';

  @override
  String get ordersPaymentStatusRefunded => 'फिर्ता भयो';

  @override
  String get ordersPaymentSuccess =>
      'भुक्तानी सफल! तपाईंको रकम डेलिभरी नभएसम्म सुरक्षित एस्क्रोमा राखिएको छ।';

  @override
  String get ordersPaymentFailed =>
      'भुक्तानी पूरा भएन। तल पुन: प्रयास गर्न सक्नुहुन्छ।';

  @override
  String get ordersConfirmDelivery => 'डेलिभरी प्राप्त पुष्टि गर्नुहोस्';

  @override
  String get ordersCancelOrder => 'अर्डर रद्द गर्नुहोस्';

  @override
  String get ordersDeliveryConfirmed => 'डेलिभरी पुष्टि भयो! धन्यवाद।';

  @override
  String get ordersRateOrder => 'यो अर्डर मूल्याङ्कन गर्नुहोस्';

  @override
  String get ordersRateFarmer => 'किसानलाई मूल्याङ्कन गर्नुहोस्';

  @override
  String get ordersRateRider => 'चालकलाई मूल्याङ्कन गर्नुहोस्';

  @override
  String get ordersRated => 'मूल्याङ्कन गरिसकेको';

  @override
  String get ordersReorder => 'पुन: अर्डर';

  @override
  String get ordersRetryEsewaPayment => 'इसेवाबाट तिर्नुहोस्';

  @override
  String get ordersRetryKhaltiPayment => 'खल्तीबाट तिर्नुहोस्';

  @override
  String get ordersRetryConnectIPSPayment => 'कनेक्ट आइपीएसबाट तिर्नुहोस्';

  @override
  String ordersTotalItems(int count) {
    return '$count वस्तु';
  }

  @override
  String get ordersRider => 'चालक';

  @override
  String get ordersFarmer => 'किसान';

  @override
  String get ordersReceipt => 'रसिद';

  @override
  String get ordersBackToOrders => 'अर्डरहरूमा फर्कनुहोस्';

  @override
  String get ratingsTitle => 'मूल्याङ्कन र समीक्षाहरू';

  @override
  String get ratingsSubmitRating => 'मूल्याङ्कन पेश गर्नुहोस्';

  @override
  String get ratingsSubmitting => 'पेश गर्दै...';

  @override
  String get ratingsRateYourExperience => 'आफ्नो अनुभव मूल्याङ्कन गर्नुहोस्';

  @override
  String get ratingsCommentPlaceholder => 'आफ्नो अनुभव साझा गर्नुहोस् (ऐच्छिक)';

  @override
  String get ratingsStar1 => 'कमजोर';

  @override
  String get ratingsStar2 => 'ठीकै';

  @override
  String get ratingsStar3 => 'राम्रो';

  @override
  String get ratingsStar4 => 'धेरै राम्रो';

  @override
  String get ratingsStar5 => 'उत्कृष्ट';

  @override
  String get ratingsThankYou => 'तपाईंको मूल्याङ्कनको लागि धन्यवाद!';

  @override
  String get ratingsAlreadyRated =>
      'तपाईंले यो अर्डरको लागि यो व्यक्तिलाई पहिल्यै मूल्याङ्कन गर्नुभएको छ।';

  @override
  String get ratingsNoRatings => 'अहिलेसम्म कुनै मूल्याङ्कन छैन';

  @override
  String get ratingsError =>
      'मूल्याङ्कन पेश गर्न असफल। कृपया पुन: प्रयास गर्नुहोस्।';

  @override
  String get ratingsClose => 'बन्द गर्नुहोस्';

  @override
  String get farmerDashboardTitle => 'किसान ड्यासबोर्ड';

  @override
  String get farmerAddListing => 'सूची थप्नुहोस्';

  @override
  String get farmerActiveListings => 'सक्रिय सूचीहरू';

  @override
  String get farmerPendingOrders => 'बाँकी अर्डरहरू';

  @override
  String get farmerEarnings => 'कुल आम्दानी';

  @override
  String get farmerMyListings => 'मेरा सूचीहरू';

  @override
  String get farmerNoListings =>
      'तपाईंले अहिलेसम्म कुनै उत्पादन सूचीबद्ध गर्नुभएको छैन।';

  @override
  String get farmerAddFirstListing => 'पहिलो सूची थप्नुहोस्';

  @override
  String get farmerNewListingTitle => 'नयाँ सूची थप्नुहोस्';

  @override
  String get farmerEditListingTitle => 'सूची सम्पादन गर्नुहोस्';

  @override
  String get farmerListingActive => 'सक्रिय';

  @override
  String get farmerListingInactive => 'निष्क्रिय';

  @override
  String get farmerFormCategory => 'वर्ग';

  @override
  String get farmerFormSelectCategory => 'वर्ग छान्नुहोस्';

  @override
  String get farmerFormNameEn => 'नाम (अंग्रेजी)';

  @override
  String get farmerFormNameNe => 'नाम (नेपाली)';

  @override
  String get farmerFormDescription => 'विवरण';

  @override
  String get farmerFormPricePerKg => 'प्रति केजी मूल्य (रु)';

  @override
  String get farmerFormAvailableQty => 'उपलब्ध मात्रा (केजी)';

  @override
  String get farmerFormFreshnessDate => 'ताजापनको मिति';

  @override
  String get farmerFormPhotos => 'फोटोहरू (५ सम्म)';

  @override
  String get farmerFormSaving => 'सुरक्षित गर्दै...';

  @override
  String get farmerFormCreate => 'सूची बनाउनुहोस्';

  @override
  String get farmerFormUpdate => 'सूची अपडेट गर्नुहोस्';

  @override
  String get farmerFormCancel => 'रद्द गर्नुहोस्';

  @override
  String get farmerFormErrorCategory => 'कृपया वर्ग छान्नुहोस्।';

  @override
  String get farmerFormErrorName => 'अंग्रेजी र नेपाली दुवै नाम आवश्यक छ।';

  @override
  String get farmerFormErrorPrice => 'कृपया मान्य मूल्य प्रविष्ट गर्नुहोस्।';

  @override
  String get farmerFormErrorQty => 'कृपया मान्य मात्रा प्रविष्ट गर्नुहोस्।';

  @override
  String get farmerVerificationTitle => 'पहिचान प्रमाणीकरण';

  @override
  String get farmerVerificationDescription =>
      'प्रमाणित हुन आफ्ना कागजातहरू पेश गर्नुहोस्। प्रमाणित किसानहरूले ब्याज पाउँछन् र खोज परिणाममा माथि देखिन्छन्।';

  @override
  String get farmerVerificationStatusUnverified =>
      'तपाईंको खाता अझै प्रमाणित भएको छैन।';

  @override
  String get farmerVerificationStatusPending =>
      'तपाईंका कागजातहरू समीक्षामा छन्।';

  @override
  String get farmerVerificationStatusApproved => 'तपाईंको खाता प्रमाणित छ!';

  @override
  String get farmerVerificationStatusRejected =>
      'तपाईंको प्रमाणीकरण स्वीकृत भएन।';

  @override
  String get farmerVerificationSubmit => 'कागजातहरू पेश गर्नुहोस्';

  @override
  String get farmerVerificationResubmit => 'कागजातहरू पुन: पेश गर्नुहोस्';

  @override
  String get farmerVerificationCitizenshipPhoto => 'नागरिकता / परिचयपत्र फोटो';

  @override
  String get farmerVerificationFarmPhoto => 'फार्मको फोटो';

  @override
  String get farmerVerificationMunicipalityLetter => 'नगरपालिका पत्र (ऐच्छिक)';

  @override
  String get farmerVerificationUploading => 'अपलोड गर्दै...';

  @override
  String get farmerVerificationSubmitting => 'पेश गर्दै...';

  @override
  String get farmerVerificationSubmitted =>
      'कागजातहरू समीक्षाको लागि पेश गरियो!';

  @override
  String get farmerVerificationVerifiedBadge => 'प्रमाणित किसान';

  @override
  String get farmerAnalyticsTitle => 'विश्लेषण';

  @override
  String get farmerAnalyticsTotalRevenue => 'कुल आम्दानी';

  @override
  String get farmerAnalyticsTotalOrders => 'कुल अर्डर';

  @override
  String get farmerAnalyticsAvgRating => 'औसत रेटिङ';

  @override
  String get farmerAnalyticsRevenueTrend => 'आम्दानी प्रवृत्ति';

  @override
  String get farmerAnalyticsSalesByCategory => 'वर्ग अनुसार बिक्री';

  @override
  String get farmerAnalyticsTopProducts => 'शीर्ष उत्पादनहरू';

  @override
  String get farmerAnalyticsPriceBenchmarks => 'मूल्य तुलना';

  @override
  String get farmerAnalyticsFulfillmentRate => 'पूर्ति दर';

  @override
  String get farmerAnalyticsNoData => 'यो अवधिको लागि डाटा छैन।';

  @override
  String get farmerAnalyticsPeriod7days => '७ दिन';

  @override
  String get farmerAnalyticsPeriod30days => '३० दिन';

  @override
  String get farmerAnalyticsPeriod90days => '९० दिन';

  @override
  String get riderDashboardTitle => 'चालक ड्यासबोर्ड';

  @override
  String get riderPostTrip => 'यात्रा पोस्ट गर्नुहोस्';

  @override
  String get riderUpcoming => 'आगामी';

  @override
  String get riderActive => 'सक्रिय';

  @override
  String get riderCompleted => 'सम्पन्न';

  @override
  String get riderNoTrips => 'अहिलेसम्म कुनै यात्रा छैन';

  @override
  String get riderPostFirstTrip => 'पहिलो यात्रा पोस्ट गर्नुहोस्';

  @override
  String get riderTripFormTitle => 'यात्रा पोस्ट गर्नुहोस्';

  @override
  String get riderPickOrigin => 'तपाईं कहाँबाट सुरु गर्दै हुनुहुन्छ?';

  @override
  String get riderPickOriginHint =>
      'आफ्नो सुरुवात बिन्दु चयन गर्न नक्सामा ट्याप गर्नुहोस्।';

  @override
  String get riderPickDestination => 'तपाईं कहाँ जाँदै हुनुहुन्छ?';

  @override
  String get riderPickDestinationHint =>
      'आफ्नो गन्तव्य चयन गर्न नक्सामा ट्याप गर्नुहोस्।';

  @override
  String get riderTripDetails => 'यात्रा विवरण';

  @override
  String get riderDepartureDate => 'प्रस्थान मिति';

  @override
  String get riderDepartureTime => 'प्रस्थान समय';

  @override
  String get riderCapacity => 'उपलब्ध क्षमता (केजी)';

  @override
  String get riderVehicleType => 'सवारी प्रकार';

  @override
  String get riderDistance => 'दूरी';

  @override
  String get riderDuration => 'अनुमानित समय';

  @override
  String get riderFrom => 'बाट';

  @override
  String get riderTo => 'सम्म';

  @override
  String get riderNext => 'अर्को';

  @override
  String get riderBack => 'पछाडि';

  @override
  String get riderReview => 'समीक्षा';

  @override
  String get riderReviewTitle => 'तपाईंको यात्रा समीक्षा गर्नुहोस्';

  @override
  String get riderPostTripBtn => 'यात्रा पोस्ट गर्नुहोस्';

  @override
  String get riderPosting => 'पोस्ट गर्दै...';

  @override
  String get riderCalculatingRoute => 'मार्ग गणना गर्दै...';

  @override
  String get riderRouteError =>
      'मार्ग गणना गर्न सकिएन। कृपया फरक स्थान प्रयास गर्नुहोस्।';

  @override
  String get riderTripDetailTitle => 'यात्रा विवरण';

  @override
  String get riderTripInfo => 'यात्रा जानकारी';

  @override
  String get riderTotalCapacity => 'कुल क्षमता';

  @override
  String get riderRemainingCapacity => 'बाँकी क्षमता';

  @override
  String get riderMatchedOrders => 'मिलेका अर्डरहरू';

  @override
  String get riderNoMatchedOrders =>
      'यो यात्रामा अहिलेसम्म कुनै अर्डर मिलेको छैन।';

  @override
  String get riderStartTrip => 'यात्रा सुरु गर्नुहोस्';

  @override
  String get riderStarting => 'सुरु गर्दै...';

  @override
  String get riderCompleteTrip => 'यात्रा पूरा गर्नुहोस्';

  @override
  String get riderCompleting => 'पूरा गर्दै...';

  @override
  String get riderCancelTrip => 'यात्रा रद्द गर्नुहोस्';

  @override
  String get riderConfirmPickup => 'पिकअप पुष्टि गर्नुहोस्';

  @override
  String get riderStartDelivery => 'डेलिभरी सुरु गर्नुहोस्';

  @override
  String get riderOptimizeRoute => 'मार्ग अप्टिमाइज गर्नुहोस्';

  @override
  String get riderOptimizing => 'अप्टिमाइज गर्दै...';

  @override
  String get riderTripStatusScheduled => 'तालिकाबद्ध';

  @override
  String get riderTripStatusInTransit => 'बाटोमा';

  @override
  String get riderTripStatusCompleted => 'सम्पन्न';

  @override
  String get riderTripStatusCancelled => 'रद्द';

  @override
  String get riderPingsNewOrders => 'नयाँ अर्डर अनुरोधहरू';

  @override
  String get riderPingsPickup => 'पिकअप';

  @override
  String get riderPingsDelivery => 'डेलिभरी';

  @override
  String get riderPingsWeight => 'तौल';

  @override
  String get riderPingsEarnings => 'आम्दानी';

  @override
  String get riderPingsDetour => 'बाटो परिवर्तन';

  @override
  String get riderPingsAccept => 'स्वीकार गर्नुहोस्';

  @override
  String get riderPingsDecline => 'अस्वीकार गर्नुहोस्';

  @override
  String get riderPingsExpired => 'म्याद सकिएको';

  @override
  String get riderPingsAccepting => 'स्वीकार गर्दै...';

  @override
  String get riderPingsDeclining => 'अस्वीकार गर्दै...';

  @override
  String get riderPingsAccepted => 'स्वीकार भयो';

  @override
  String riderPingsExpiresIn(String time) {
    return '$time मा म्याद सकिन्छ';
  }

  @override
  String get chatTitle => 'सन्देशहरू';

  @override
  String get chatNoConversations => 'अहिलेसम्म कुनै सन्देश छैन';

  @override
  String get chatNoConversationsHint =>
      'अर्डर पृष्ठबाट कुराकानी सुरु गर्नुहोस्।';

  @override
  String get chatSearchPlaceholder => 'कुराकानी खोज्नुहोस्...';

  @override
  String get chatYou => 'तपाईं';

  @override
  String get chatImage => 'तस्बिर';

  @override
  String get chatLocation => 'स्थान';

  @override
  String get chatTypeMessage => 'सन्देश लेख्नुहोस्...';

  @override
  String get chatSend => 'पठाउनुहोस्';

  @override
  String get chatSendImage => 'तस्बिर पठाउनुहोस्';

  @override
  String get chatToday => 'आज';

  @override
  String get chatYesterday => 'हिजो';

  @override
  String get chatLoadMore => 'पुराना सन्देशहरू लोड गर्नुहोस्';

  @override
  String get notificationsTitle => 'सूचनाहरू';

  @override
  String get notificationsEmpty => 'अहिलेसम्म कुनै सूचना छैन';

  @override
  String get notificationsMarkAllRead => 'सबै पढेको चिन्ह लगाउनुहोस्';

  @override
  String get notificationsPreferencesTitle => 'सूचना प्राथमिकताहरू';

  @override
  String get notificationsConsumerGroup => 'अर्डर अपडेटहरू';

  @override
  String get notificationsFarmerGroup => 'खेत अर्डरहरू';

  @override
  String get notificationsRiderGroup => 'यात्रा र डेलिभरी';

  @override
  String get subscriptionsTitle => 'सदस्यता बाकसहरू';

  @override
  String get subscriptionsSubtitle => 'हरेक हप्ता ताजा उत्पादन तपाईंको ढोकामा';

  @override
  String get subscriptionsNoPlans => 'अहिलेसम्म कुनै सदस्यता योजना उपलब्ध छैन।';

  @override
  String get subscriptionsNoSubscriptions => 'तपाईंको कुनै सक्रिय सदस्यता छैन।';

  @override
  String get subscriptionsBrowse => 'योजनाहरू हेर्नुहोस्';

  @override
  String get subscriptionsMy => 'मेरा सदस्यताहरू';

  @override
  String get subscriptionsFrequencyWeekly => 'हप्ताको';

  @override
  String get subscriptionsFrequencyBiweekly => 'दुई हप्ताको';

  @override
  String get subscriptionsFrequencyMonthly => 'महिनाको';

  @override
  String get subscriptionsStatusActive => 'सक्रिय';

  @override
  String get subscriptionsStatusPaused => 'रोकिएको';

  @override
  String get subscriptionsStatusCancelled => 'रद्द गरिएको';

  @override
  String subscriptionsByFarmer(String name) {
    return '$name बाट';
  }

  @override
  String get subscriptionsSubscribe => 'सदस्यता लिनुहोस्';

  @override
  String get subscriptionsSubscribing => 'सदस्यता लिँदै...';

  @override
  String get subscriptionsPause => 'रोक्नुहोस्';

  @override
  String get subscriptionsResume => 'पुनः सुरु';

  @override
  String get subscriptionsCancel => 'रद्द गर्नुहोस्';

  @override
  String get subscriptionsCreatePlan => 'योजना बनाउनुहोस्';

  @override
  String get businessRegisterTitle => 'आफ्नो व्यापार दर्ता गर्नुहोस्';

  @override
  String get businessDashboardTitle => 'व्यापार ड्यासबोर्ड';

  @override
  String get businessCreateOrder => 'नयाँ थोक अर्डर';

  @override
  String get businessBulkOrdersTitle => 'थोक अर्डरहरू';

  @override
  String get businessActiveOrders => 'सक्रिय अर्डरहरू';

  @override
  String get businessCompletedOrders => 'पूरा भएका';

  @override
  String get businessTotalSpent => 'कुल खर्च';

  @override
  String get businessNoOrders => 'अहिलेसम्म कुनै थोक अर्डर छैन';

  @override
  String get businessStatusDraft => 'ड्राफ्ट';

  @override
  String get businessStatusSubmitted => 'पेश गरिएको';

  @override
  String get businessStatusQuoted => 'उद्धरण दिइएको';

  @override
  String get businessStatusAccepted => 'स्वीकृत';

  @override
  String get businessStatusInProgress => 'प्रगतिमा';

  @override
  String get businessStatusFulfilled => 'पूरा भयो';

  @override
  String get businessStatusCancelled => 'रद्द गरिएको';

  @override
  String get businessAcceptQuotes => 'सबै उद्धरणहरू स्वीकार गर्नुहोस्';

  @override
  String get businessCancelOrder => 'अर्डर रद्द गर्नुहोस्';

  @override
  String get commonLoading => 'लोड हुँदैछ...';

  @override
  String get commonError => 'त्रुटि';

  @override
  String get commonRetry => 'पुन: प्रयास';

  @override
  String get commonCancel => 'रद्द';

  @override
  String get commonSave => 'सुरक्षित गर्नुहोस्';

  @override
  String get commonDelete => 'मेट्नुहोस्';

  @override
  String get commonConfirm => 'पुष्टि गर्नुहोस्';

  @override
  String get commonSearch => 'खोज्नुहोस्';

  @override
  String get commonNoData => 'कुनै डाटा उपलब्ध छैन';

  @override
  String get commonSuccess => 'सफल';

  @override
  String get commonUnknownError => 'केही गलत भयो। कृपया पुन: प्रयास गर्नुहोस्।';

  @override
  String get commonClose => 'बन्द गर्नुहोस्';

  @override
  String get commonBack => 'पछाडि';

  @override
  String get commonNext => 'अर्को';

  @override
  String get commonDone => 'सम्पन्न';

  @override
  String get commonEdit => 'सम्पादन';

  @override
  String get commonOk => 'ठीक छ';

  @override
  String get commonYes => 'हो';

  @override
  String get commonNo => 'होइन';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageNepali => 'नेपाली';

  @override
  String get paymentProcessing => 'भुक्तानी प्रशोधन गर्दै...';

  @override
  String get paymentSuccess => 'भुक्तानी सफल!';

  @override
  String get paymentFailed => 'भुक्तानी असफल';

  @override
  String get paymentVerifying => 'भुक्तानी प्रमाणित गर्दै...';
}
