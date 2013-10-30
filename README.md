# EbFastDeploy

  easy AWS elastic beanstalk deploy

```
  foreman run -e config/eb_environments/<ENVIRONMENT>/env rake eb:deploy
```

## Installation

Add this line to your application's Gemfile:

    gem 'eb_fast_deploy'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install eb_fast_deploy

## Usage


Convention:

<RAILS_ROOT>/config/eb_environments/<ENVIRONMENT>/env 

Stack and eb configuration variables.

<RAILS_ROOT>/config/eb_environments/<ENVIRONMENT>/ruby_container_options

Environments variables used in application.

<RAILS_ROOT>/config/eb_environments/<ENVIRONMENT>/rds_network_options

Rds and network configurations.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

