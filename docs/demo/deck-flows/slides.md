---
theme: default
title: JiriSewa — सम्पूर्ण प्रवाह / All flows
info: |
  ## JiriSewa flows deck
  Static walkthrough of every user flow. Self-contained, works
  without internet.
class: text-center
highlighter: shiki
drawings:
  persist: false
transition: slide-left
mdc: true
fonts:
  sans: Inter
  serif: Mukta
  local: Inter, Mukta
canvasWidth: 980
aspectRatio: 16/9
---

<style>
@import './style/global.css';

.shot-img {
  border-radius: 8px;
  box-shadow: 0 4px 18px rgba(0,0,0,0.10);
  width: 100%;
  height: auto;
  display: block;
}
.phone-frame {
  max-height: 64vh;
  width: auto;
  border-radius: 22px;
  box-shadow: 0 6px 28px rgba(0,0,0,0.18);
  display: block;
  margin: 0 auto;
}
.flow-step {
  font-family: 'Mukta', sans-serif;
  font-weight: 700;
  font-size: 0.95em;
  color: var(--jirisewa-organic);
  letter-spacing: 0.06em;
  text-transform: uppercase;
  margin-bottom: 0.4em;
}
.flow-bullets {
  font-family: 'Mukta', sans-serif;
  font-size: 1em;
  line-height: 1.6;
}
.flow-bullets .en {
  font-family: 'Inter', sans-serif;
  font-size: 0.85em;
  color: var(--jirisewa-ink-soft);
  display: block;
  margin-top: 0.15em;
}
.section-tag {
  display: inline-block;
  font-family: 'Inter', sans-serif;
  font-size: 0.7em;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  color: var(--jirisewa-ink-soft);
  border: 1px solid var(--jirisewa-divider);
  border-radius: 999px;
  padding: 4px 14px;
  margin-bottom: 1.2em;
}
</style>

<div class="np-display brand-blue">सम्पूर्ण प्रवाह</div>
<div class="np" style="font-size:1.4em; margin-top: 0.3em">हरेक प्रयोगकर्ता, हरेक स्क्रिन</div>
<div class="en-sub" style="font-size:1em">All flows · every user · every screen</div>

<div style="margin-top: 4em; font-size: 0.8em; color: var(--jirisewa-ink-soft)">
<div class="np">इन्टरनेट नभए पनि चल्छ</div>
<div class="en-sub">Works without internet</div>
</div>

<!--
Walk through each flow as a narrated photo-story. Tactile equivalents
(paper lot-code, rider's phone) still pass around the room.
-->

---
layout: center
class: text-center
---

<div class="section-tag">Section 1 of 5</div>
<div class="np-display brand-blue">ग्राहक प्रवाह</div>
<div class="en-sub" style="font-size:1.2em; margin-top: 0.6em">Consumer flow · web</div>

<div class="np" style="margin-top: 2em; font-size: 1.1em; max-width: 30ch; margin-left: auto; margin-right: auto">
काठमाडौँको भान्साबाट जिरीको किवी ६ क्लिकमा
</div>
<div class="en-sub" style="margin-top: 0.5em">From a Kathmandu kitchen to Jiri kiwi in six clicks</div>

---

<div class="np-display">१ · बजार खोज्ने</div>
<div class="en-sub">Step 1 — Browse the marketplace</div>

<div class="grid grid-cols-2 gap-8 mt-4">

<div>
<img src="/shots/consumer/01-marketplace.png" class="shot-img" />
</div>

<div>
<div class="flow-step">URL · /ne/marketplace</div>
<div class="flow-bullets">
- ताजा उत्पादन, श्रेणी अनुसार छानिएको
  <span class="en">Fresh produce, category-filtered</span>
- "जिरी" खोजेर ताजा सूचीहरू मात्रै देखाउँछ
  <span class="en">Search "जिरी" to surface only Jiri listings</span>
- प्रत्येकमा किसानको नाम, वडा, मूल्य प्रति केजी
  <span class="en">Each card: farmer, ward, NPR per kg</span>
</div>
</div>

</div>

---

<div class="np-display">२ · विवरण हेर्ने</div>
<div class="en-sub">Step 2 — Read the listing</div>

<div class="grid grid-cols-2 gap-8 mt-4">

<div>
<img src="/shots/consumer/02-listing.png" class="shot-img" />
</div>

<div>
<div class="flow-step">URL · /ne/produce/[id]</div>
<div class="flow-bullets">
- फोटो, ताजापन मिति, उपलब्ध परिमाण
  <span class="en">Photo, freshness date, quantity in stock</span>
- किसानको नाम — सीधै फार्मसम्म जोडिने
  <span class="en">Farmer name links straight to the farm</span>
- रेटिङ्ग र पुराना अर्डरकर्ताहरूको प्रतिक्रिया
  <span class="en">Ratings and prior-buyer feedback</span>
</div>
</div>

</div>

---

<div class="np-display">३ · कार्टमा थप्ने</div>
<div class="en-sub">Step 3 — Add to cart</div>

<div class="grid grid-cols-2 gap-8 mt-4">

<div style="background: white; border: 1px solid var(--jirisewa-divider); border-radius: 12px; padding: 18px; font-family: 'Mukta', sans-serif">
<div style="font-weight: 700; font-size: 1.05em; margin-bottom: 0.6em">तपाईंको कार्ट <span class="en-sub" style="font-size: 0.7em">Your cart · 3 items</span></div>

<div style="display: flex; align-items: center; gap: 12px; padding: 10px 0; border-top: 1px solid var(--jirisewa-divider)">
<div style="width: 44px; height: 44px; border-radius: 8px; background: linear-gradient(135deg,#bbf7d0,#86efac); flex-shrink: 0"></div>
<div style="flex: 1; font-size: 0.85em">
<div style="font-weight: 600">किवी · <span style="font-weight: 400; color: var(--jirisewa-ink-soft)">Kiwi</span></div>
<div class="en-sub" style="font-size: 0.85em; margin: 0">नमुना जिरेल · वडा ८</div>
</div>
<div style="font-size: 0.85em; text-align: right">
<div>2 kg × ₹240</div>
<div style="font-weight: 700">₹480</div>
</div>
</div>

<div style="display: flex; align-items: center; gap: 12px; padding: 10px 0; border-top: 1px solid var(--jirisewa-divider)">
<div style="width: 44px; height: 44px; border-radius: 8px; background: linear-gradient(135deg,#fecaca,#f87171); flex-shrink: 0"></div>
<div style="flex: 1; font-size: 0.85em">
<div style="font-weight: 600">अकबरे खुर्सानी · <span style="font-weight: 400; color: var(--jirisewa-ink-soft)">Akbare</span></div>
<div class="en-sub" style="font-size: 0.85em; margin: 0">सीता कोइराला · वडा ३</div>
</div>
<div style="font-size: 0.85em; text-align: right">
<div>1 kg × ₹350</div>
<div style="font-weight: 700">₹350</div>
</div>
</div>

<div style="display: flex; align-items: center; gap: 12px; padding: 10px 0; border-top: 1px solid var(--jirisewa-divider)">
<div style="width: 44px; height: 44px; border-radius: 8px; background: linear-gradient(135deg,#fef3c7,#fde68a); flex-shrink: 0"></div>
<div style="flex: 1; font-size: 0.85em">
<div style="font-weight: 600">छुर्पी · <span style="font-weight: 400; color: var(--jirisewa-ink-soft)">Churpi</span></div>
<div class="en-sub" style="font-size: 0.85em; margin: 0">दावा शेर्पा · वडा ५</div>
</div>
<div style="font-size: 0.85em; text-align: right">
<div>0.5 kg × ₹600</div>
<div style="font-weight: 700">₹300</div>
</div>
</div>

<div style="border-top: 2px solid var(--jirisewa-ink); margin-top: 12px; padding-top: 12px; font-size: 0.85em">
<div style="display: flex; justify-content: space-between"><span>उप योग <span class="en-sub" style="font-size: 0.85em">Subtotal</span></span><span>₹1,130</span></div>
<div style="display: flex; justify-content: space-between; color: var(--jirisewa-ink-soft)"><span>डेलिभरी <span class="en-sub" style="font-size: 0.85em">Delivery</span></span><span>₹150</span></div>
<div style="display: flex; justify-content: space-between; font-weight: 700; font-size: 1.1em; margin-top: 6px"><span>कुल</span><span>₹1,280</span></div>
</div>

<div style="background: var(--jirisewa-organic); color: white; text-align: center; padding: 10px; border-radius: 8px; margin-top: 12px; font-weight: 600; font-size: 0.9em">चेकआउट जानुहोस् →</div>
</div>

<div>
<div class="flow-step">URL · /ne/cart</div>
<div class="flow-bullets">
- एउटै कार्टमा धेरै किसानका सामान
  <span class="en">Multi-farmer items in one cart</span>
- मात्रा अद्यावधिक — तत्कालै पुनः गणना
  <span class="en">Live recalculation on quantity change</span>
- डेलिभरी शुल्क छुट्टै देखिन्छ — लुकाउने केहि छैन
  <span class="en">Delivery fee shown separately — nothing hidden</span>
</div>
</div>

</div>

---

<div class="np-display">४ · चेकआउट</div>
<div class="en-sub">Step 4 — Checkout</div>

<div class="grid grid-cols-2 gap-8 mt-4">

<div style="background: white; border: 1px solid var(--jirisewa-divider); border-radius: 12px; padding: 18px; font-family: 'Mukta', sans-serif">

<div style="font-weight: 700; font-size: 0.95em; margin-bottom: 0.5em">डेलिभरी ठेगाना <span class="en-sub" style="font-size: 0.75em">Delivery address</span></div>
<div style="background: linear-gradient(135deg,#f0fdf4,#dbeafe); border-radius: 8px; padding: 10px; font-size: 0.8em; line-height: 1.5">
<div style="font-weight: 600">📍 भक्तपुर · मध्यपुर थिमी · वडा ८</div>
<div class="en-sub" style="font-size: 0.85em">Bhaktapur · Madhyapur Thimi · Ward 8</div>
<div style="color: var(--jirisewa-ink-soft); font-size: 0.85em; margin-top: 4px">सूर्य विनायक मार्ग, थिमी–२</div>
</div>

<div style="font-weight: 700; font-size: 0.95em; margin: 14px 0 6px">भुक्तानी विधि <span class="en-sub" style="font-size: 0.75em">Payment method</span></div>

<div style="display: flex; flex-direction: column; gap: 6px; font-size: 0.82em">
<div style="border: 2px solid var(--jirisewa-green); border-radius: 8px; padding: 8px 12px; display: flex; align-items: center; gap: 10px; background: rgba(22,163,74,0.06)">
<div style="width: 16px; height: 16px; border-radius: 50%; border: 5px solid var(--jirisewa-green)"></div>
<div style="flex: 1; font-weight: 600">eSewa</div>
<div class="en-sub" style="font-size: 0.85em; margin: 0">डिजिटल · escrow</div>
</div>
<div style="border: 1px solid var(--jirisewa-divider); border-radius: 8px; padding: 8px 12px; display: flex; align-items: center; gap: 10px">
<div style="width: 16px; height: 16px; border-radius: 50%; border: 2px solid var(--jirisewa-divider)"></div>
<div style="flex: 1">Khalti</div>
</div>
<div style="border: 1px solid var(--jirisewa-divider); border-radius: 8px; padding: 8px 12px; display: flex; align-items: center; gap: 10px">
<div style="width: 16px; height: 16px; border-radius: 50%; border: 2px solid var(--jirisewa-divider)"></div>
<div style="flex: 1">connectIPS</div>
</div>
<div style="border: 1px solid var(--jirisewa-divider); border-radius: 8px; padding: 8px 12px; display: flex; align-items: center; gap: 10px">
<div style="width: 16px; height: 16px; border-radius: 50%; border: 2px solid var(--jirisewa-divider)"></div>
<div style="flex: 1">नगद · Cash on delivery</div>
</div>
</div>

<div style="border-top: 2px solid var(--jirisewa-ink); margin-top: 14px; padding-top: 10px; font-size: 0.85em; display: flex; justify-content: space-between; font-weight: 700">
<span>कुल भुक्तानी</span><span>₹1,280</span>
</div>

<div style="background: var(--jirisewa-green); color: white; text-align: center; padding: 10px; border-radius: 8px; margin-top: 10px; font-weight: 600; font-size: 0.9em">अर्डर पेस गर्नुहोस् →</div>

</div>

<div>
<div class="flow-step">URL · /ne/checkout</div>
<div class="flow-bullets">
- डेलिभरी ठेगाना — नक्सामा थपकेरै रोज्ने
  <span class="en">Pin the delivery address on the map</span>
- भुक्तानी विकल्प — eSewa, Khalti, connectIPS, नगद
  <span class="en">Payments — eSewa, Khalti, connectIPS, cash</span>
- डिजिटल भुक्तानी एस्क्रोमा बस्छ — डेलिभरीसम्म
  <span class="en">Digital payments held in escrow until delivered</span>
</div>
</div>

</div>

---

<div class="np-display">५ · अर्डर सूची</div>
<div class="en-sub">Step 5 — Orders list</div>

<div class="grid grid-cols-2 gap-8 mt-4">

<div>
<img src="/shots/consumer/05-orders.png" class="shot-img" />
</div>

<div>
<div class="flow-step">URL · /ne/orders</div>
<div class="flow-bullets">
- सक्रिय / सम्पन्न ट्याबमा छुट्याइएको
  <span class="en">Split into active / completed tabs</span>
- प्रत्येक अर्डरको स्थिति — एकै नजरमा
  <span class="en">Status of every order at a glance</span>
- राइडर तय भएपछि चाट खुल्छ
  <span class="en">Chat opens once a rider is matched</span>
</div>
</div>

</div>

---

<div class="np-display">६ · अर्डर विवरण र ट्र्याकिङ्ग</div>
<div class="en-sub">Step 6 — Order detail with live tracking</div>

<div class="grid grid-cols-2 gap-8 mt-4">

<div>
<img src="/shots/consumer/06-order-detail.png" class="shot-img" />
</div>

<div>
<div class="flow-step">URL · /ne/orders/[id]</div>
<div class="flow-bullets">
- स्थिति टाइमलाइन — pending → matched → in transit → delivered
  <span class="en">Status timeline at every step</span>
- राइडरको GPS नक्सामा सीधै
  <span class="en">Rider's GPS pinned on the map</span>
- डेलिभरीपछि "पुष्टि गर्नुहोस्" — तब किसानलाई पैसा जान्छ
  <span class="en">Confirm-on-delivery releases the farmer payout</span>
</div>
</div>

</div>

---
layout: center
class: text-center
---

<div class="section-tag">Section 2 of 5</div>
<div class="np-display brand-green">किसान प्रवाह</div>
<div class="en-sub" style="font-size:1.2em; margin-top: 0.6em">Farmer flow · web</div>

<div class="np" style="margin-top: 2em; font-size: 1.1em; max-width: 30ch; margin-left: auto; margin-right: auto">
सूचीकरणदेखि भुक्तानीसम्म — सबै फोनबाट
</div>
<div class="en-sub" style="margin-top: 0.5em">From listing to payout — everything from a phone</div>

---

<div class="np-display">१ · ड्यासबोर्ड</div>
<div class="en-sub">Step 1 — Farmer dashboard</div>

<div class="grid grid-cols-2 gap-8 mt-4">

<div>
<img src="/shots/farmer/01-dashboard.png" class="shot-img" />
</div>

<div>
<div class="flow-step">URL · /ne/farmer/dashboard</div>
<div class="flow-bullets">
- आजको कमाइ, सक्रिय सूची, पेन्डिङ अर्डर
  <span class="en">Today's earnings, live listings, pending orders</span>
- एक थपक्कीमा नयाँ सूची थप्ने
  <span class="en">One tap to add a new listing</span>
- भेरिफिकेसन स्थिति — "स्वीकृत / प्रक्रियामा"
  <span class="en">Verification status front-and-centre</span>
</div>
</div>

</div>

---

<div class="np-display">२ · सूची थप्ने</div>
<div class="en-sub">Step 2 — Create a listing</div>

<div class="grid grid-cols-2 gap-8 mt-4">

<div>
<img src="/shots/farmer/02-new-listing.png" class="shot-img" />
</div>

<div>
<div class="flow-step">URL · /ne/farmer/listings/new</div>
<div class="flow-bullets">
- श्रेणी, नाम (नेपाली + अंग्रेजी), मूल्य प्रति केजी
  <span class="en">Category, NP/EN name, price per kg</span>
- फोटो — एकाधिक तस्बिर
  <span class="en">Multiple photos</span>
- स्थान — फार्मको GPS coordinate स्वतः
  <span class="en">GPS auto-tagged from farm location</span>
</div>
</div>

</div>

---

<div class="np-display">३ · आउने अर्डर</div>
<div class="en-sub">Step 3 — Incoming orders</div>

<div class="grid grid-cols-2 gap-8 mt-4">

<div>
<img src="/shots/farmer/03-orders.png" class="shot-img" />
</div>

<div>
<div class="flow-step">URL · /ne/farmer/orders</div>
<div class="flow-bullets">
- प्रत्येक अर्डरको स्थिति — pickup, transit, delivered
  <span class="en">Status of each order line item</span>
- राइडर मिल्नेबित्तिकै सूचना
  <span class="en">Notification when a rider is matched</span>
- "उठाउन तयार" मार्क गर्ने सीधै यहाँबाट
  <span class="en">Mark "ready for pickup" inline</span>
</div>
</div>

</div>

---

<div class="np-display">४ · विश्लेषण</div>
<div class="en-sub">Step 4 — Analytics</div>

<div class="grid grid-cols-2 gap-8 mt-4">

<div>
<img src="/shots/farmer/04-analytics.png" class="shot-img" />
</div>

<div>
<div class="flow-step">URL · /ne/farmer/analytics</div>
<div class="flow-bullets">
- दैनिक राजस्व ग्राफ
  <span class="en">Daily revenue trend</span>
- शीर्ष उत्पादन र मूल्य तुलना
  <span class="en">Top products + market price benchmarks</span>
- डेलिभरी सफलता दर र रेटिङ्ग वितरण
  <span class="en">Fulfillment rate and rating distribution</span>
</div>
</div>

</div>

---

<div class="np-display">५ · हब-मा छाड्ने (फारम)</div>
<div class="en-sub">Step 5 — Drop off at the hub (form)</div>

<div class="grid grid-cols-2 gap-8 mt-4">

<div>
<img src="/shots/farmer/05-hub-dropoff-form.png" class="shot-img" />
</div>

<div>
<div class="flow-step">URL · /ne/farmer/hubs</div>
<div class="flow-bullets">
- सक्रिय सूचीबाट छनोट
  <span class="en">Pick from your active listings</span>
- मात्रा (केजीमा) र हब चयन
  <span class="en">Quantity in kg + which hub</span>
- "पेस गर्नुहोस्" — अर्को स्क्रिन तीन सेकेन्डमा
  <span class="en">Submit → next screen in three seconds</span>
</div>
</div>

</div>

---

<div class="np-display">६ · लट कोड</div>
<div class="en-sub">Step 6 — Lot code (paper-printable)</div>

<div class="grid grid-cols-2 gap-8 mt-4">

<div>
<img src="/shots/farmer/06-hub-dropoff-success.png" class="shot-img" />
</div>

<div>
<div class="flow-step">Success card</div>
<div class="flow-bullets">
- ६-अक्षरको कोड (उदा. <strong>NYGJ38</strong>) — अद्वितीय
  <span class="en">Six-char unique code (e.g. NYGJ38)</span>
- कागजमा छाप्न मिल्ने — सबभन्दा कमजोर नेटवर्कमा पनि
  <span class="en">Printable on paper — survives the worst networks</span>
- सञ्चालकले कोडले मिलाएर इन्भेन्टरीमा थप्छन्
  <span class="en">Operator scans/types the code into inventory</span>
</div>
</div>

</div>

---
layout: center
class: text-center
---

<div class="section-tag">Section 3 of 5</div>
<div class="np-display" style="color: var(--jirisewa-organic)">कोशेली घर सञ्चालक</div>
<div class="en-sub" style="font-size:1.2em; margin-top: 0.6em">Hub operator flow · web</div>

<div class="np" style="margin-top: 2em; font-size: 1.1em; max-width: 32ch; margin-left: auto; margin-right: auto">
तीनवटा क्लिकमा — पाएको, स्वीकार गरेको, इन्भेन्टरीमा
</div>
<div class="en-sub" style="margin-top: 0.5em">Three clicks — received, confirmed, in inventory</div>

---

<div class="np-display">१ · इन्भेन्टरी</div>
<div class="en-sub">Step 1 — Inventory home</div>

<div class="grid grid-cols-2 gap-8 mt-4">

<div>
<img src="/shots/operator/01-inventory.png" class="shot-img" />
</div>

<div>
<div class="flow-step">URL · /ne/hub</div>
<div class="flow-bullets">
- सबै लटहरू — एकै तालिकामा
  <span class="en">Every lot in one table</span>
- स्थिति अनुसार फिल्टर: छाडिएको / स्वीकृत / पठाइएको
  <span class="en">Filter: dropped / received / dispatched</span>
- कोडले खोजी
  <span class="en">Search by lot code</span>
</div>
</div>

</div>

---

<div class="np-display">२ · स्वीकृति बाँकी</div>
<div class="en-sub">Step 2 — Awaiting confirmation</div>

<div class="grid grid-cols-2 gap-8 mt-4">

<div>
<img src="/shots/operator/02-dropped-off.png" class="shot-img" />
</div>

<div>
<div class="flow-step">Filter · status=dropped_off</div>
<div class="flow-bullets">
- किसानले छाडेको — तर सञ्चालकले अझै नछोएको
  <span class="en">Farmer dropped, operator hasn't touched yet</span>
- "स्वीकार गर्नुहोस्" बटन — एक थपक्की
  <span class="en">"Confirm receipt" button — single click</span>
- स्वीकारेपछि किसानको फोनमा सूचना तुरुन्त
  <span class="en">Confirms instantly notify the farmer's phone</span>
</div>
</div>

</div>

---

<div class="np-display">३ · इन्भेन्टरीमा</div>
<div class="en-sub">Step 3 — In inventory</div>

<div class="grid grid-cols-2 gap-8 mt-4">

<div>
<img src="/shots/operator/03-in-inventory.png" class="shot-img" />
</div>

<div>
<div class="flow-step">Filter · status=in_inventory</div>
<div class="flow-bullets">
- स्वीकृत लटहरू — राइडरले उठाउन तयार
  <span class="en">Confirmed lots, ready for rider pickup</span>
- तौल, मिति, किसान — रेकर्डमा अमिट
  <span class="en">Weight, date, farmer — permanently logged</span>
- मासिक तौल रिपोर्ट यहीँबाट जन्मन्छ
  <span class="en">The monthly tonnage report is born here</span>
</div>
</div>

</div>

---
layout: center
class: text-center
---

<div class="section-tag">Section 4 of 5</div>
<div class="np-display brand-blue">बस लजिस्टिक्स</div>
<div class="en-sub" style="font-size:1.2em; margin-top: 0.6em">Bus logistics — the network already running</div>

<div class="np" style="margin-top: 2em; font-size: 1.1em; max-width: 34ch; margin-left: auto; margin-right: auto">
हामी ट्रक किन्दैनौँ। जिरी–काठमाडौँ बस हरेक दिन चल्छ — हामी त्यसैमा चढ्छौँ।
</div>
<div class="en-sub" style="margin-top: 0.5em">No new trucks. The Jiri–Kathmandu bus runs daily — we ride it.</div>

<!--
This is the cost-discipline beat. Buses already make this trip. Adding
parcels to the existing baggage compartment costs nothing new. The
municipality cares about feasibility — this slide answers it.
-->

---

<div class="np-display">सम्पूर्ण ढुवानी शृङ्खला</div>
<div class="en-sub">The full pipeline · five hops, one product</div>

<div style="display: flex; align-items: center; justify-content: center; gap: 8px; margin-top: 2em; flex-wrap: nowrap">

<div style="flex: 1; max-width: 150px; background: white; border: 1px solid var(--jirisewa-divider); border-radius: 12px; padding: 14px 8px; text-align: center; font-family: 'Mukta', sans-serif">
<div style="font-size: 2em">🏢</div>
<div style="font-weight: 700; font-size: 0.85em; margin-top: 4px">कोशेली घर हब</div>
<div class="en-sub" style="font-size: 0.7em; margin: 0">Hub · Jiri</div>
</div>

<div style="font-size: 1.4em; color: var(--jirisewa-organic); font-weight: 700">→</div>

<div style="flex: 1; max-width: 150px; background: white; border: 1px solid var(--jirisewa-divider); border-radius: 12px; padding: 14px 8px; text-align: center; font-family: 'Mukta', sans-serif">
<div style="font-size: 2em">🎫</div>
<div style="font-weight: 700; font-size: 0.85em; margin-top: 4px">बस काउन्टर</div>
<div class="en-sub" style="font-size: 0.7em; margin: 0">Bus counter · Jiri</div>
</div>

<div style="font-size: 1.4em; color: var(--jirisewa-organic); font-weight: 700">→</div>

<div style="flex: 1; max-width: 150px; background: white; border: 2px solid var(--jirisewa-organic); border-radius: 12px; padding: 14px 8px; text-align: center; font-family: 'Mukta', sans-serif; box-shadow: 0 4px 14px rgba(37,99,235,0.18)">
<div style="font-size: 2em">🚌</div>
<div style="font-weight: 700; font-size: 0.85em; margin-top: 4px">रातभरि बस</div>
<div class="en-sub" style="font-size: 0.7em; margin: 0">Overnight bus · 188 km</div>
</div>

<div style="font-size: 1.4em; color: var(--jirisewa-organic); font-weight: 700">→</div>

<div style="flex: 1; max-width: 150px; background: white; border: 1px solid var(--jirisewa-divider); border-radius: 12px; padding: 14px 8px; text-align: center; font-family: 'Mukta', sans-serif">
<div style="font-size: 2em">🏬</div>
<div style="font-weight: 700; font-size: 0.85em; margin-top: 4px">नयाँ बसपार्क</div>
<div class="en-sub" style="font-size: 0.7em; margin: 0">Naya Buspark · KTM</div>
</div>

<div style="font-size: 1.4em; color: var(--jirisewa-organic); font-weight: 700">→</div>

<div style="flex: 1; max-width: 150px; background: white; border: 1px solid var(--jirisewa-divider); border-radius: 12px; padding: 14px 8px; text-align: center; font-family: 'Mukta', sans-serif">
<div style="font-size: 2em">🛵</div>
<div style="font-weight: 700; font-size: 0.85em; margin-top: 4px">सिटी राइडर</div>
<div class="en-sub" style="font-size: 0.7em; margin: 0">Last-mile rider</div>
</div>

<div style="font-size: 1.4em; color: var(--jirisewa-organic); font-weight: 700">→</div>

<div style="flex: 1; max-width: 150px; background: white; border: 2px solid var(--jirisewa-green); border-radius: 12px; padding: 14px 8px; text-align: center; font-family: 'Mukta', sans-serif; box-shadow: 0 4px 14px rgba(22,163,74,0.18)">
<div style="font-size: 2em">🏠</div>
<div style="font-weight: 700; font-size: 0.85em; margin-top: 4px">ग्राहकको घर</div>
<div class="en-sub" style="font-size: 0.7em; margin: 0">Customer's home</div>
</div>

</div>

<div class="grid grid-cols-3 gap-6 mt-12" style="font-family: 'Mukta', sans-serif; font-size: 0.85em">

<div style="border-left: 3px solid var(--jirisewa-organic); padding-left: 12px">
<div style="font-weight: 700">२४ घण्टा</div>
<div class="en-sub" style="font-size: 0.85em; margin: 0">Hub-to-home, end-to-end</div>
</div>

<div style="border-left: 3px solid var(--jirisewa-organic); padding-left: 12px">
<div style="font-weight: 700">शून्य नयाँ ट्रक</div>
<div class="en-sub" style="font-size: 0.85em; margin: 0">Zero new vehicles bought</div>
</div>

<div style="border-left: 3px solid var(--jirisewa-organic); padding-left: 12px">
<div style="font-weight: 700">तीन हस्तान्तरण</div>
<div class="en-sub" style="font-size: 0.85em; margin: 0">Three handoffs, all logged by lot code</div>
</div>

</div>

<!--
Drive the point: buses ALREADY run this route every day with empty
luggage capacity. We're not adding cost — we're filling a void that
exists today. The lot code is the thread that ties the three
handoffs together.
-->

---

<div class="np-display">हस्तान्तरण कसरी हुन्छ</div>
<div class="en-sub">How each handoff works · the lot code is the thread</div>

<div class="grid grid-cols-3 gap-6 mt-6" style="font-family: 'Mukta', sans-serif">

<div style="background: white; border: 1px solid var(--jirisewa-divider); border-radius: 12px; padding: 18px">
<div style="display: flex; align-items: center; gap: 10px; margin-bottom: 10px">
<div style="width: 36px; height: 36px; border-radius: 50%; background: var(--jirisewa-green); color: white; display: flex; align-items: center; justify-content: center; font-weight: 700">१</div>
<div style="font-weight: 700; font-size: 0.95em">हब → बस काउन्टर</div>
</div>
<div class="en-sub" style="font-size: 0.8em; margin: 0 0 0.8em">Hub → Bus counter</div>
<div style="font-size: 0.78em; line-height: 1.6">
- सञ्चालकले मेनिफेस्ट छाप्छन् <span class="en-sub" style="font-size: 0.85em">(Operator prints manifest)</span>
- लट कोडसहित डालो — काउन्टरमा जान्छ <span class="en-sub" style="font-size: 0.85em">(Crate with lot codes goes to counter)</span>
- काउन्टरमा एप मा "स्वीकार" थिच्छन् <span class="en-sub" style="font-size: 0.85em">(Counter taps "received" in app)</span>
</div>
</div>

<div style="background: white; border: 2px solid var(--jirisewa-organic); border-radius: 12px; padding: 18px; box-shadow: 0 4px 14px rgba(37,99,235,0.10)">
<div style="display: flex; align-items: center; gap: 10px; margin-bottom: 10px">
<div style="width: 36px; height: 36px; border-radius: 50%; background: var(--jirisewa-organic); color: white; display: flex; align-items: center; justify-content: center; font-weight: 700">२</div>
<div style="font-weight: 700; font-size: 0.95em">बसमा यात्रा</div>
</div>
<div class="en-sub" style="font-size: 0.8em; margin: 0 0 0.8em">On the bus</div>
<div style="font-size: 0.78em; line-height: 1.6">
- नियमित यात्रु बसको ब्यागेज खण्डमा <span class="en-sub" style="font-size: 0.85em">(In the regular passenger bus baggage hold)</span>
- कन्डक्टर लट नम्बर मेनिफेस्टमा सही गर्छन् <span class="en-sub" style="font-size: 0.85em">(Conductor signs the lot manifest)</span>
- ट्र्याकिङ्ग — बसको GPS हेरिन्छ <span class="en-sub" style="font-size: 0.85em">(Tracking via the bus's own GPS)</span>
</div>
</div>

<div style="background: white; border: 1px solid var(--jirisewa-divider); border-radius: 12px; padding: 18px">
<div style="display: flex; align-items: center; gap: 10px; margin-bottom: 10px">
<div style="width: 36px; height: 36px; border-radius: 50%; background: var(--jirisewa-green); color: white; display: flex; align-items: center; justify-content: center; font-weight: 700">३</div>
<div style="font-weight: 700; font-size: 0.95em">बसपार्क → घर</div>
</div>
<div class="en-sub" style="font-size: 0.8em; margin: 0 0 0.8em">Buspark → home</div>
<div style="font-size: 0.78em; line-height: 1.6">
- सिटी राइडरले लट कोड स्क्यान गर्छन् <span class="en-sub" style="font-size: 0.85em">(City rider scans lot code)</span>
- एपमा अर्डर खुल्छ — कुन घरमा जाने <span class="en-sub" style="font-size: 0.85em">(App opens orders — which homes to visit)</span>
- ग्राहकले पुष्टि — किसानलाई पैसा <span class="en-sub" style="font-size: 0.85em">(Customer confirms — farmer paid)</span>
</div>
</div>

</div>

<div style="text-align: center; margin-top: 1.6em; font-size: 0.9em">
<span class="np" style="font-weight: 600">एउटै लट कोडले तीनवटै हस्तान्तरण जोड्छ — कुनै मानिस वा कागज नहराउँदै।</span>
</div>
<div class="en-sub" style="text-align: center; margin-top: 0.3em">One lot code threads all three handoffs — nothing and no one slips through the cracks.</div>

<!--
The lot code is the trick. It's six characters, printable on paper,
shouted over a phone, scanned by an app — survives every failure mode.
The bus people don't need to learn anything new. The conductor is
already used to passenger luggage tags.
-->

---
layout: center
class: text-center
---

<div class="section-tag">Section 5 of 5</div>
<div class="np-display brand-green">सिटी राइडर — अन्तिम मील</div>
<div class="en-sub" style="font-size:1.2em; margin-top: 0.6em">Last-mile rider · Android</div>

<div class="np" style="margin-top: 2em; font-size: 1.1em; max-width: 32ch; margin-left: auto; margin-right: auto">
बसपार्कदेखि ग्राहकको ढोकासम्म पुर्‍याउने
</div>
<div class="en-sub" style="margin-top: 0.5em">Carries from the buspark to the customer's door</div>

---

<div class="np-display">१ · होम स्क्रिन</div>
<div class="en-sub">Step 1 — Rider home</div>

<div class="grid grid-cols-2 gap-8 mt-4">

<div class="flex justify-center">
<img src="/shots/rider/01-home.png" class="phone-frame" />
</div>

<div>
<div class="flow-step">App · खेतवाटा (Khetbata)</div>
<div class="flow-bullets">
- आजका नयाँ मेल खाने अर्डर
  <span class="en">Today's matched orders</span>
- कमाइ — हप्ता र महिनाको योग
  <span class="en">Earnings — week + month totals</span>
- अर्को यात्रा सिर्जना गर्ने बटन
  <span class="en">"New trip" button</span>
</div>
</div>

</div>

---

<div class="np-display">२ · बजार</div>
<div class="en-sub">Step 2 — Marketplace (rider view)</div>

<div class="grid grid-cols-2 gap-8 mt-4">

<div class="flex justify-center">
<img src="/shots/rider/02-marketplace.png" class="phone-frame" />
</div>

<div>
<div class="flow-step">मोबाइलमै पूर्ण कार्यक्षमता</div>
<div class="flow-bullets">
- राइडर पनि ग्राहक — आफैले खरीद गर्न सक्ने
  <span class="en">Rider is also a consumer — can shop too</span>
- एउटै app, सबै रोलहरू
  <span class="en">One app, all roles</span>
- अनलाइन/अफलाइन दुवै अवस्थामा काम गर्छ
  <span class="en">Works online and offline</span>
</div>
</div>

</div>

---

<div class="np-display">३ · यात्राहरू</div>
<div class="en-sub">Step 3 — Trips</div>

<div class="grid grid-cols-2 gap-8 mt-4">

<div class="flex justify-center">
<img src="/shots/rider/03-trips.png" class="phone-frame" />
</div>

<div>
<div class="flow-step">URL · /rider/trips</div>
<div class="flow-bullets">
- आगामी, सक्रिय, सम्पन्न यात्रा — ट्याबमा छुट्टै
  <span class="en">Upcoming / active / completed tabs</span>
- रुटको नक्सा र क्षमता
  <span class="en">Route map + remaining capacity</span>
- अर्डर थप्ने / निकाल्ने एकै तह
  <span class="en">Add/remove orders inline</span>
</div>
</div>

</div>

---

<div class="np-display">४ · अर्डर मेल</div>
<div class="en-sub">Step 4 — Order pings & matches</div>

<div class="grid grid-cols-2 gap-8 mt-4">

<div class="flex justify-center">
<div style="width: 280px; height: 540px; border-radius: 28px; background: #0F172A; padding: 14px; box-shadow: 0 6px 28px rgba(0,0,0,0.18)">
<div style="background: white; border-radius: 18px; height: 100%; padding: 14px; font-family: 'Mukta', sans-serif; display: flex; flex-direction: column">

<div style="display: flex; justify-content: space-between; font-size: 0.65em; color: var(--jirisewa-ink-soft); margin-bottom: 8px">
<span>11:01</span><span>•••</span>
</div>

<div style="font-weight: 700; font-size: 1.1em">अर्डर मेल</div>
<div class="en-sub" style="font-size: 0.7em; margin: 0 0 12px">Order matches</div>

<div style="border: 2px solid var(--jirisewa-green); border-radius: 12px; padding: 12px; background: rgba(22,163,74,0.04)">
<div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px">
<div style="background: var(--jirisewa-green); color: white; font-size: 0.65em; padding: 2px 8px; border-radius: 999px; font-weight: 600; letter-spacing: 0.05em">नयाँ · NEW</div>
<div style="font-size: 0.7em; color: var(--jirisewa-ink-soft)">समय: 4:23</div>
</div>

<div style="font-size: 0.78em; line-height: 1.6">
<div style="display: flex; gap: 8px"><span style="color: var(--jirisewa-green); font-weight: 700">●</span><div><div style="font-weight: 600">जिरी बजार हब</div><div class="en-sub" style="font-size: 0.85em; margin: 0">Pickup · 5 km detour</div></div></div>
<div style="display: flex; gap: 8px; margin-top: 6px"><span style="color: var(--jirisewa-organic); font-weight: 700">●</span><div><div style="font-weight: 600">भक्तपुर · थिमी–२</div><div class="en-sub" style="font-size: 0.85em; margin: 0">Drop · 138 km</div></div></div>
</div>

<div style="display: flex; justify-content: space-between; margin-top: 10px; padding-top: 8px; border-top: 1px solid var(--jirisewa-divider); font-size: 0.75em">
<div><div style="color: var(--jirisewa-ink-soft)">तौल</div><div style="font-weight: 700">3.5 kg</div></div>
<div style="text-align: right"><div style="color: var(--jirisewa-ink-soft)">कमाइ</div><div style="font-weight: 700; color: var(--jirisewa-green)">₹450</div></div>
</div>
</div>

<div style="display: flex; gap: 8px; margin-top: 12px">
<div style="flex: 1; background: white; color: var(--jirisewa-ink-soft); border: 1px solid var(--jirisewa-divider); text-align: center; padding: 10px; border-radius: 10px; font-weight: 600; font-size: 0.78em">अस्वीकार</div>
<div style="flex: 1.3; background: var(--jirisewa-green); color: white; text-align: center; padding: 10px; border-radius: 10px; font-weight: 700; font-size: 0.78em">स्वीकार गर्नुहोस्</div>
</div>

<div style="margin-top: auto; padding-top: 12px; display: flex; justify-content: space-around; font-size: 0.6em; color: var(--jirisewa-ink-soft); border-top: 1px solid var(--jirisewa-divider)">
<div>Home</div><div>Trips</div><div style="color: var(--jirisewa-organic); font-weight: 700">Orders</div><div>Profile</div>
</div>

</div>
</div>
</div>

<div>
<div class="flow-step">App · /orders (ping inbox)</div>
<div class="flow-bullets">
- रुटसँग मिल्ने अर्डरहरूको ping
  <span class="en">Pings for orders that match the route</span>
- प्रत्येक pingमा कमाइ अनुमान + detour दूरी
  <span class="en">Each ping shows estimated earnings + detour</span>
- ५ मिनेटमा स्वीकार वा अस्वीकार
  <span class="en">Accept or decline within 5 minutes</span>
</div>
</div>

</div>

---

<div class="np-display">५ · प्रोफाइल</div>
<div class="en-sub">Step 5 — Rider profile</div>

<div class="grid grid-cols-2 gap-8 mt-4">

<div class="flex justify-center">
<img src="/shots/rider/05-profile.png" class="phone-frame" />
</div>

<div>
<div class="flow-step">Profile · Settings</div>
<div class="flow-bullets">
- गाडी प्रकार, क्षमता, लाइसेन्स
  <span class="en">Vehicle type, capacity, license</span>
- भाषा टगल — नेपाली / अंग्रेजी
  <span class="en">Language toggle — Nepali / English</span>
- भुक्तानी विधि र इतिहास
  <span class="en">Payout method and history</span>
</div>
</div>

</div>

---
layout: center
class: text-center
---

<div class="np-display brand-green">हरेक स्क्रिन — आज, हाम्रो उत्पादनमा</div>
<div class="en-sub" style="font-size:1.1em; margin-top: 0.6em">Every screen you just saw — in our product, today</div>

<div style="margin-top: 3em; padding-top: 2em; border-top: 1px solid var(--jirisewa-divider); max-width: 30em; margin-left: auto; margin-right: auto">
<div class="np" style="font-weight: 600; font-size: 1.05em">ग्राहक · किसान · सञ्चालक · राइडर — चारवटै फोनबाट।</div>
<div class="en-sub" style="margin-top: 0.6em">Consumer · farmer · operator · rider — all four, from a phone.</div>
</div>

<!--
Closing beat: the room has now seen every screen, end-to-end. The
product is real, working, bilingual, and ready for Jiri.
-->
