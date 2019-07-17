# ifsc-api

API server that serves Razorpay's IFSC API.

[![](https://images.microbadger.com/badges/image/razorpay/ifsc:1.4.5.svg)](https://microbadger.com/images/razorpay/ifsc:1.4.5) [![](https://images.microbadger.com/badges/version/razorpay/ifsc:1.4.5.svg)](https://microbadger.com/images/razorpay/ifsc:1.4.5)

Current API Root is <https://ifsc.razorpay.com/>

## Documentation

The API documentation is maintained at https://github.com/razorpay/ifsc/wiki/API.

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
