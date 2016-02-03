# ifsc-api

API server that serves Razorpay's IFSC API.

Routes:

|Route|Method|Response|
|-----|------|--------|
|/:ifsc|GET|JSON|

A sample response is:

```json
{
BANK: "KARNATAKA BANK LIMITED",
IFSC: "KARB0000001",
MICR: "NA",
BRANCH: "RTGS-HO",
ADDRESS: 2228222,
CONTACT: "REGD. & HEAD OFFICE, P.B.NO.599, MAHAVEER CIRCLE, KANKANADY, MANGALORE - 575002",
CITY: "MANGALORE",
DISTRICT: "DAKSHINA KANNADA",
STATE: "KARNATAKA"
}
```

For an invalid IFSC code a 404 is returned.