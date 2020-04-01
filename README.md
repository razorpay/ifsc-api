# ifsc-api ![Docker Image Version (latest semver)](https://img.shields.io/docker/v/razorpay/ifsc) ![Docker Image Size (latest semver)](https://img.shields.io/docker/image-size/razorpay/ifsc?sort=semver) ![Docker Build Status](https://img.shields.io/docker/build/razorpay/ifsc) ![Docker Pulls](https://img.shields.io/docker/pulls/razorpay/ifsc)

API server that serves Razorpay's IFSC API.

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

## License

Code is licensed under the MIT License. See LICENSE file for details. Everything under the `data/` directory is available under the Public Domain.
