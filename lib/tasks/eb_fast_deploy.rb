require "eb_fast_deploy/version"
require 'aws-sdk'
require 'dotenv/environment'
require 'fog'

module EbFastDeploy

  OPTIONS = {
    "AvailabilityZones" => {:namespace => "aws:autoscaling:asg", :option_name => "Availability Zones"},
    "Cooldown" => {:namespace => "aws:autoscaling:asg", :option_name => "Cooldown"},
    "CustomAvailabilityZones" => {:namespace => "aws:autoscaling:asg", :option_name => "Custom Availability Zones"},
    "MinSize" => {:namespace => "aws:autoscaling:asg", :option_name => "MinSize"},
    "MaxSize" => {:namespace => "aws:autoscaling:asg", :option_name => "MaxSize"},

    "EC2KeyName" => {:namespace => "aws:autoscaling:launchconfiguration", :option_name => "EC2KeyName"},
    "IamInstanceProfile" => {:namespace => "aws:autoscaling:launchconfiguration", :option_name => "IamInstanceProfile"},
    "ImageId" => {:namespace => "aws:autoscaling:launchconfiguration", :option_name => "ImageId"},
    "InstanceType" => {:namespace => "aws:autoscaling:launchconfiguration", :option_name => "InstanceType"},
    "MonitoringInterval" => {:namespace => "aws:autoscaling:launchconfiguration", :option_name => "MonitoringInterval"},
    "SecurityGroups" => {:namespace => "aws:autoscaling:launchconfiguration", :option_name => "SecurityGroups"},
    "SSHSourceRestriction" => {:namespace => "aws:autoscaling:launchconfiguration", :option_name => "SSHSourceRestriction"},
    "BlockDeviceMappings" => {:namespace => "aws:autoscaling:launchconfiguration", :option_name => "BlockDeviceMappings"},
    "LogPublicationControl" => {:namespace => "aws:elasticbeanstalk:hostmanager", :option_name => "LogPublicationControl"},

    "BreachDuration" => {:namespace => "aws:autoscaling:trigger", :option_name => "BreachDuration"},
    "LowerBreachScaleIncrement" => {:namespace => "aws:autoscaling:trigger", :option_name => "LowerBreachScaleIncrement"},
    "LowerThreshold" => {:namespace => "aws:autoscaling:trigger", :option_name => "LowerThreshold"},
    "MeasureName" => {:namespace => "aws:autoscaling:trigger", :option_name => "MeasureName"},
    "Period" => {:namespace => "aws:autoscaling:trigger", :option_name => "Period"},
    "Statistic" => {:namespace => "aws:autoscaling:trigger", :option_name => "Statistic"},
    "Unit" => {:namespace => "aws:autoscaling:trigger", :option_name => "Unit"},
    "UpperBreachScaleIncrement" => {:namespace => "aws:autoscaling:trigger", :option_name => "UpperBreachScaleIncrement"},
    "UpperThreshold" => {:namespace => "aws:autoscaling:trigger", :option_name => "UpperThreshold"},

    "VPCId" => {:namespace => "aws:ec2:vpc", :option_name => "VPCId"},
    "Subnets" => {:namespace => "aws:ec2:vpc", :option_name => "Subnets"},
    "ELBSubnets" => {:namespace => "aws:ec2:vpc", :option_name => "ELBSubnets"},
    "ELBScheme" => {:namespace => "aws:ec2:vpc", :option_name => "ELBScheme"},
    "DBSubnets" => {:namespace => "aws:ec2:vpc", :option_name => "DBSubnets"},

    "ApplicationHealthcheckURL" => {:namespace => "aws:elasticbeanstalk:application", :option_name => "Application Healthcheck URL"},

    "EnvironmentType" => {:namespace => "aws:elasticbeanstalk:environment", :option_name => "EnvironmentType"},

    "AutomaticallyTerminateUnhealthyInstances" => {:namespace => "aws:elasticbeanstalk:monitoring", :option_name => "Automatically Terminate Unhealthy Instances"},

    "NotificationEndpoint" => {:namespace => "aws:elasticbeanstalk:sns:topics", :option_name => "Notification Endpoint"},
    "NotificationProtocol" => {:namespace => "aws:elasticbeanstalk:sns:topics", :option_name => "Notification Protocol"},
    "NotificationTopicARN" => {:namespace => "aws:elasticbeanstalk:sns:topics", :option_name => "Notification Topic ARN"},
    "NotificationTopicName" => {:namespace => "aws:elasticbeanstalk:sns:topics", :option_name => "Notification Topic Name"},

    "HealthyThreshold" => {:namespace => "aws:elb:healthcheck", :option_name => "HealthyThreshold"},
    "Interval" => {:namespace => "aws:elb:healthcheck", :option_name => "Interval"},
    "Timeout" => {:namespace => "aws:elb:healthcheck", :option_name => "Timeout"},
    "UnhealthyThreshold" => {:namespace => "aws:elb:healthcheck", :option_name => "UnhealthyThreshold"},

    "LoadBalancerHTTPPort" => {:namespace => "aws:elb:loadbalancer", :option_name => "LoadBalancerHTTPPort"},
    "LoadBalancerPortProtocol" => {:namespace => "aws:elb:loadbalancer", :option_name => "LoadBalancerPortProtocol"},
    "LoadBalancerHTTPSPort" => {:namespace => "aws:elb:loadbalancer", :option_name => "LoadBalancerHTTPSPort"},
    "LoadBalancerSSLPortProtocol" => {:namespace => "aws:elb:loadbalancer", :option_name => "LoadBalancerSSLPortProtocol"},
    "SSLCertificateId" => {:namespace => "aws:elb:loadbalancer", :option_name => "SSLCertificateId"},


    "StickinessCookieExpiration" => {:namespace => "aws:elb:policies", :option_name => "Stickiness Cookie Expiration"},
    "StickinessPolicy" => {:namespace => "aws:elb:policies", :option_name => "Stickiness Policy"},

    "DBAllocatedStorage" => {:namespace => "aws:rds:dbinstance", :option_name => "DBAllocatedStorage"},
    "DBDeletionPolicy" => {:namespace => "aws:rds:dbinstance", :option_name => "DBDeletionPolicy"},
    "DBEngine" => {:namespace => "aws:rds:dbinstance", :option_name => "DBEngine"},
    "DBEngineVersion" => {:namespace => "aws:rds:dbinstance", :option_name => "DBEngineVersion"},
    "DBInstanceClass" => {:namespace => "aws:rds:dbinstance", :option_name => "DBInstanceClass"},
    "DBPassword" => {:namespace => "aws:rds:dbinstance", :option_name => "DBPassword"},
    "DBSnapshotIdentifier" => {:namespace => "aws:rds:dbinstance", :option_name => "DBSnapshotIdentifier"},
    "DBUser" => {:namespace => "aws:rds:dbinstance", :option_name => "DBUser"},
    "MultiAZDatabase" => {:namespace => "aws:rds:dbinstance", :option_name => "MultiAZDatabase"},
  }.freeze

end

def do_cmd(cmd)
  print "- - - cmd: #{cmd}\n"
  result = `#{cmd}`
  print "#{result}\n"
end

def update_eb_environment(version_label = nil)
  rails_default_options_names = [:AWS_ACCESS_KEY_ID, :AWS_SECRET_KEY, :BUNDLE_WITHOUT, :PARAM1, :PARAM2, :RACK_ENV, :RAILS_SKIP_ASSET_COMPILATION, :RAILS_SKIP_MIGRATIONS]
  envs = AWS.elastic_beanstalk.client.describe_environments(:application_name=>ENV['APP_NAME'], :environment_names => [ENV['ENVIRONMENT']])
  unless envs[:environments].empty?
    rails_options_keys = rails_options.map{|opt| opt[:option_name]}
    env_config = AWS.elastic_beanstalk.client.describe_configuration_settings(:application_name=>ENV['APP_NAME'], :environment_name => ENV['ENVIRONMENT'])
    options_to_remove = env_config[:configuration_settings].first[:option_settings].select do |opt|
      opt[:namespace] == "aws:elasticbeanstalk:application:environment" and !rails_options_keys.include?(opt[:option_name]) and !rails_default_options_names.include?(opt[:option_name].to_sym )
    end

    options_to_remove.each{|opt| puts "(Info) options removed:#{opt[:option_name]}=#{opt[:value]}" }

    options_to_remove.each{|opt| opt.delete(:value) }

    if version_label.nil?
      AWS.elastic_beanstalk.client.update_environment(:environment_name => ENV['ENVIRONMENT'],
                                               :option_settings => all_options,
                                               :options_to_remove => options_to_remove )
    else
      AWS.elastic_beanstalk.client.update_environment(:environment_name => ENV['ENVIRONMENT'],
                                               :version_label => @version_label,
                                               :option_settings => all_options,
                                               :options_to_remove => options_to_remove )
    end
    new_env_config = AWS.elastic_beanstalk.client.describe_configuration_settings(:application_name=>ENV['APP_NAME'], :environment_name => ENV['ENVIRONMENT'])
    puts "New env config"
    new_env_config[:configuration_settings].first[:option_settings].each {|opt| puts "(Info) #{opt[:option_name]}=#{opt[:value]}" if opt[:namespace] == "aws:elasticbeanstalk:application:environment" }
    puts " ----- END ----- "
  else
    puts "(Warning) Environment \"#{ ENV['ENVIRONMENT'] }\" doesn't exist"
  end
end

def check_required_variables!(variables_array)
  variables_array.each do |opt|
    raise "(Error) #{opt} not defined" if ENV[opt].nil?
  end
end

def set_vars
  return if @is_config_loaded
  puts "-------------------------------------------------------------"

  @is_config_loaded = true

  sha1 = `git log | head -1|cut -d \" \" -f2`
  sha1 = sha1.gsub("\n","")
  @version_label = "#{Time.now.to_i}-git-#{sha1}"
  @dirname = "#{ENV['APP_NAME'].gsub(' ', '')}_#{ENV['ENVIRONMENT'].gsub(' ', '')}"

  @deploy_tmp_dir = ENV['COPY_CACHE'] || "/tmp/#{@dirname}_eb_deploy"
  @deploy_zip_filename = "#{@dirname}_#{@version_label}.zip"
  @deploy_zip_file_path = File.join(@deploy_tmp_dir, @deploy_zip_filename)

  @env_file_path = Rails.root.to_s+"/config/eb_environments/#{ENV['ENVIRONMENT']}/ruby_container_options"
  if File.exists?(@env_file_path)
    @eb_ruby_container_options = Dotenv::Environment.new(@env_file_path)
  else
    puts "(Warning) ruby_container_options doesn't exists"
  end

  @rds_network_options_path = Rails.root.to_s+"/config/eb_environments/#{ENV['ENVIRONMENT']}/rds_network_options"
  if File.exists?(@env_file_path)
    @rds_network_options = Dotenv::Environment.new(@rds_network_options_path);
  else
    puts "(Warning) rds_network_options doesn't exists"
  end

  AWS.config(
    access_key_id: ENV['AWS_ACCESS_KEY_ID'],
    secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'],
    region: ENV['AWS_REGION']
  )

  print_env
end

def rails_options
  opts = []
  @eb_ruby_container_options.each do |k,v|
    opts << {:namespace => "aws:elasticbeanstalk:application:environment", :option_name =>k, :value=>v}
  end
  opts
end

def rds_network_options
  opts = []
  @rds_network_options.each do |k,v|
    raise "(Error) Unknown option \"#{k}\"=#{v} in #{@rds_network_options_path}, please check Elastic Beanstalk documentation and EbFastDeploy::OPTIONS" unless EbFastDeploy::OPTIONS.include?(k)
    opts << {:namespace => EbFastDeploy::OPTIONS[k][:namespace], :option_name =>EbFastDeploy::OPTIONS[k][:option_name], :value=>v}
  end
  opts
end

def all_options
  rds_network_options + rails_options
end

def print_env
  puts "@dirname: #{@dirname}"
  puts "version_label: #{@version_label}"
  puts "@deploy_tmp_dir: #{@deploy_tmp_dir}"
  puts "@deploy_zip_filename: #{@deploy_zip_filename}"
  puts "@deploy_zip_file_path: #{@deploy_zip_file_path}"

  puts "---------------  RDS AND NETWORK --------------\n"
  rds_network_options
  rds_network_options.each do |opt|
    puts "#{opt[:namespace]} #{opt[:option_name]}=#{opt[:value]}"
  end

  puts "---------------  RUBY CONTAINER  --------------\n"
  rails_options.each do |opt|
    puts "#{opt[:namespace]} #{opt[:option_name]}=#{opt[:value]}"
  end
end

namespace :eb do
  desc "setvars"
  task :setvars do
    set_vars
  end

  desc "setvars"
  task :print_env do
    set_vars
  end

  desc "assets compile and upload to S3"
  task :assets do
    set_vars

    do_cmd "rake assets:precompile"
  end

  desc "bundle pack"
  task :bundle_pack do
    set_vars

    do_cmd "env RUBYOPT= bundle package --all"
#    do_cmd "bundle install"

  end

  desc "upload project to s3"
  task :upload do
    print "=== upload project to s3 ===\n"
    print "\n"

    set_vars
    check_required_variables! ['AWS_DEPLOY_BUCKET', 'AWS_REGION', 'AWS_ACCESS_KEY_ID', 'AWS_SECRET_ACCESS_KEY']

    do_cmd "mkdir #{@deploy_tmp_dir}"
    do_cmd "rm #{@deploy_zip_file_path}"
    do_cmd "rsync --exclude='.git' --exclude='.bundle' --exclude='tmp/*' --exclude='log/*' . #{@deploy_tmp_dir} -r --delete-excluded --delete"

    current_dir = `pwd`
    do_cmd "cd #{@deploy_tmp_dir} && zip -r #{@deploy_zip_file_path} . && cd #{pwd}"

    print "storage = Fog::Storage.new provider: AWS, aws_access_key_id: #{ENV['AWS_ACCESS_KEY_ID']}, aws_secret_access_key: #{ENV['AWS_SECRET_ACCESS_KEY']}\n"
    storage = Fog::Storage.new({
    provider: 'AWS',
    region: ENV['AWS_REGION'],
    aws_access_key_id: ENV['AWS_ACCESS_KEY_ID'],
    aws_secret_access_key: ENV['AWS_SECRET_ACCESS_KEY']
    })
    print "bucket = storage.directories.get(#{ENV['AWS_DEPLOY_BUCKET']})\n"
    bucket = storage.directories.get(ENV['AWS_DEPLOY_BUCKET'])

    if File.exist? @deploy_zip_file_path
      print "creating new remote file..."
      deploy_zip_file = File.open @deploy_zip_file_path, "r"
      remote_file = bucket.files.new key: @deploy_zip_filename, body: deploy_zip_file
      result = remote_file.save
      print "remote_file.save: #{result}\n"
    else
      print "file #{@deploy_zip_file_path} not found"
    end

  end

  desc "publish to elastic beanstalk"
  task :create_and_deploy_version do
    set_vars

    aws_app_opt = {
      application_name: ENV['APP_NAME'],
      source_bundle: {
        s3_bucket: ENV['AWS_DEPLOY_BUCKET'],
        s3_key: @deploy_zip_filename
      },
      version_label: @version_label
    }

    eb = AWS.elastic_beanstalk
    eb.client.create_application_version aws_app_opt
    update_eb_environment( @version_label )
  end

  desc "deploy to elastic beanstalk"
  task :deploy => [
    :assets,
    :bundle_pack,
    :upload,
    :create_and_deploy_version
  ] do
    set_vars
=begin
    print "=== deploy to elastic beanstalk ===\n\n"

    Rake::Task['eb:assets'].invoke
    Rake::Task['eb:bundle_pack'].invoke
    Rake::Task['eb:upload'].invoke
    Rake::Task['eb:publish'].invoke
    Rake::Task['eb:cleanup'].invoke
=end
  end

  desc "create application on Elastic Beanstalk"
  task :create_eb_application do
    set_vars
    check_required_variables! ['AWS_ACCESS_KEY_ID', 'AWS_SECRET_ACCESS_KEY', 'AWS_REGION', 'APP_NAME']

    unless app_exists?
      opts = {}
      opts[:application_name] = ENV['APP_NAME']
      opts[:description] = ENV['APP_DESC'] unless ENV['APP_DESC'].nil?
      AWS.elastic_beanstalk.client.create_application( opts )
    else
      print "(Warning) Application \"#{ ENV['APP_NAME'] }\" already exists"
    end
  end

  def app_exists?
    apps = AWS.elastic_beanstalk.client.describe_applications(:application_names=>[ENV['APP_NAME']])
    !apps[:applications].empty?
  end

  desc "create environment on Elastic Beanstalk"
  task :create_eb_environment => :create_eb_application do
    set_vars
    envs = AWS.elastic_beanstalk.client.describe_environments(:application_name=>ENV['APP_NAME'], :environment_names => [ENV['ENVIRONMENT']])

    if envs[:environments].empty?
      #TODO: aggiungere i parametri per RDS, ELB, etc
      AWS.elastic_beanstalk.client.create_environment(:application_name => ENV['APP_NAME'],
                                                  :environment_name => ENV['ENVIRONMENT'],
                                                  :solution_stack_name => ENV['STACK'],
                                                  :option_settings => all_options)
      puts "(Info) Environment \"#{ ENV['ENVIRONMENT'] }\" created"
    else
      puts "(Warning) Environment \"#{ ENV['ENVIRONMENT'] }\" already exists"
    end
  end

  desc "update environment on Elastic Beanstalk"
  task :update_eb_environment => :create_eb_environment do
    set_vars
    update_eb_environment
  end
end

