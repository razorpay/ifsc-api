API server that serves Razorpay's IFSC API.
Current API Root is <https://ifsc.razorpay.com/>

## Routes:

|Route|Method|Response|
|-----|------|--------|
|/:ifsc|GET|JSON|

A sample response is:

```json
{
  "BANK": "KARNATAKA BANK LIMITED",
  "IFSC": "KARB0000001",
  "BRANCH": "RTGS-HO",
  "CONTACT": 2228222,
  "ADDRESS": "REGD. & HEAD OFFICE, P.B.NO.599, MAHAVEER CIRCLE, KANKANADY, MANGALORE - 575002",
  "CITY": "MANGALORE",
  "DISTRICT": "DAKSHINA KANNADA",
  "STATE": "KARNATAKA",
  "RTGS": true
}
```

URL: <https://ifsc.razorpay.com/KARB0000001>
You can see a permalink version of the request [here](http://hurl.eu/hurls/e1d4d8d04d804d72a7506009d19cab583b6549e6/192c7eda180f9537d47e0abe8f7b7c7fa4b419db)

For an invalid IFSC code a 404 is returned. If the branch has been allocated a new IFSC code (the recent SBI merger for instance), the we return the data for the old branch (if it is still valid), along with a redirect to the new IFSC code. A sample response:

```
Server: ifsc.razorpay.com
Content-Type: application/json
Location: https://ifsc.razorpay.com/SBBJ0010303

{
  "BRANCH": "RTGSHO, FUNDS DEPARTMENT, MUMBAI",
  "ADDRESS": "SBI LHO BLDG, 7TH FLOOR, BKC, MUMBAI 400051",
  "CONTACT": "26445803",
  "CITY": "MUMBAI",
  "DISTRICT": "GREATER BOMBAY",
  "STATE": "MAHARASHTRA",
  "BANK": "State Bank of India",
  "IFSC": "SBIN0031303"
}
```

If your client is following redirects, make sure that you match the IFSC code in the response to validate the IFSC, instead of just relying on a non-404 response.

### Running the Docker Image

You can pull the image from `razorpay/ifsc:latest`

Run it with `docker run -d -p 3000:3000 razorpay:ifsc:latest`

You can now test the API using `http://localhost:3000`