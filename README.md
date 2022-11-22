# ifsc-api ![Docker Image Version (latest semver)](https://img.shields.io/docker/v/razorpay/ifsc) ![Docker Image Size (latest semver)](https://img.shields.io/docker/image-size/razorpay/ifsc?sort=semver) ![Docker Build Status](https://img.shields.io/docker/build/razorpay/ifsc) ![Docker Pulls](https://img.shields.io/docker/pulls/razorpay/ifsc)

API server that serves Razorpay's IFSC API.

Current API Root is <https://ifsc.razorpay.com/>

## Documentation

The API documentation is maintained at https://github.com/razorpay/ifsc/wiki/API.

### Search API
|Route|Method|Response|
|-----|------|--------|
|/search|GET|JSON|
#### Query parameters
1. **state**: Filter used for querying by state. Uses the ISO3166 code
2. **city**: Filter used for querying by city
3. **bankcode**: Filter used for querying by bank code
3. **limit**: The number of items to return
4. **offset**: The offset from which to return data for pagination

A sample response for `/search?limit=1&offset=0&bankcode=DENS`:

```json
{
	"BRANCH": "Delhi Nagrik Sehkari Bank IMPS",
	"CENTRE": "DELHI",
	"DISTRICT": "DELHI",
	"STATE": "MAHARASHTRA",
	"ADDRESS": "720, NEAR GHANTAGHAR, SUBZI MANDI, DELHI - 110007",
	"CONTACT": "+919560344685",
	"IMPS": true,
	"CITY": "MUMBAI",
	"UPI": true,
	"MICR": "110196002",
	"RTGS": true,
	"NEFT": true,
	"SWIFT": "",
	"ISO3166": "IN-MH",
	"BANK": "Delhi Nagrik Sehkari Bank",
	"BANKCODE": "DENS",
	"IFSC": "YESB0DNB002"
}
``` 

|Route|Method|Response|
|-----|------|--------|
|/city|GET|JSON|
#### Query parameters
1. **state**: Filter used for querying by state. Uses the ISO3166 code
2. **bankcode**: Filter used for querying by bank code  
  
Returns the cities result set given state and bankcode
### Running the Docker Image

You can pull the image from `razorpay/ifsc:latest`

Run it with `docker run --detach --publish 3000:3000 razorpay/ifsc:latest`

This repo has the same tags as the parent IFSC repo.

## Development

```
bundle install
# Make sure redis is running and available at localhost:6379
# This initializes the redis server
bundle exec ruby init.rb
bundle exec rackup
```

Your server should now be accessible at `http://localhost:9292`

## License

Code is licensed under the MIT License. See LICENSE file for details. Everything under the `data/` directory is available under the Public Domain.
