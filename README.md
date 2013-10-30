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
Variabili di inizializzazione del RAKE TASK.
<RAILS_ROOT>/config/eb_environments/<ENVIRONMENT>/ruby_container_options
Variabili di ambiente utilizzate nell'applicazione, verranno memorizzate in elasticbeanstalk > configuration.
<RAILS_ROOT>/config/eb_environments/<ENVIRONMENT>/rds_network_options
Configurazioni di sistema su rds e network, come autoscaling e chiavi.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

