require "eb_fast_deploy/version"
require 'aws-sdk'
require 'dotenv/environment'
require 'fog'

def do_cmd(cmd)
  print "- - - cmd: #{cmd}\n"
  result = `#{cmd}`
  print "#{result}\n"
end

def set_vars
  return if @is_config_loaded
  puts "-------------------------------------------------------------"

  @is_config_loaded = true

  sha1 = `git log | head -1|cut -d \" \" -f2`
  sha1 = sha1.gsub("\n","")
  @version_label = "#{Time.now.to_i}-git-#{sha1}"
  dirname = "#{ENV['APP_NAME'].gsub(' ', '')}_#{ENV['ENVIRONMENT'].gsub(' ', '')}"

  @deploy_tmp_dir = ENV['COPY_CACHE'] || "/tmp/#{dirname}_eb_deploy"
  @deploy_zip_filename = "#{dirname}_#{@version_label}.zip"
  @deploy_zip_file_path = "#{@deploy_tmp_dir}/#{@deploy_zip_filename}"

  puts "dirname: #{dirname}"
  puts "version_label: #{@version_label}"
  puts "@deploy_tmp_dir: #{@deploy_tmp_dir}"
  puts "@deploy_zip_filename: #{@deploy_zip_filename}"
  puts "@deploy_zip_file_path: #{@deploy_zip_file_path}"

  @env_file_path = Rails.root.to_s+"/config/eb_environments/#{ENV['ENVIRONMENT']}/ruby_container_options"
  if File.exists?(@env_file_path)
    @eb_ruby_container_options = Dotenv::Environment.new(@env_file_path)
  end

  AWS.config(
    access_key_id: ENV['AWS_ACCESS_KEY_ID'],
    secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'],
    region: ENV['AWS_REGION']
  )
end

def rails_options
  opts = []
  @eb_ruby_container_options.each do |k,v|
    opts << {:namespace => "aws:elasticbeanstalk:application:environment", :option_name =>k, :value=>v}
  end
  opts
end

namespace :eb do
  desc "setvars"
  task :setvars do
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
#      description: "deploy",
      source_bundle: {
        s3_bucket: ENV['AWS_DEPLOY_BUCKET'],
        s3_key: @deploy_zip_filename
      },
      version_label: @version_label
    }

    aws_env_opt = {
      environment_name: ENV['ENVIRONMENT'],
      version_label: @version_label
    }

    eb = AWS.elastic_beanstalk
    eb.client.create_application_version aws_app_opt
    eb.client.update_environment aws_env_opt
  end

  desc "deploy to elastic beanstalk"
  task :deploy => [
    :assets,
    :bundle_pack,
    :upload,
    :update_eb_environment,
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

    ['AWS_ACCESS_KEY_ID', 'AWS_SECRET_ACCESS_KEY', 'AWS_REGION', 'APP_NAME'].each do |opt|
      if ENV[opt].nil?
        puts "(Error) #{opt} not defined"
        exit
      end
    end

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
                                                  :option_settings => rails_options)
      puts "(Info) Environment \"#{ ENV['ENVIRONMENT'] }\" created"
    else
      puts "(Warning) Environment \"#{ ENV['ENVIRONMENT'] }\" already exists"
    end
  end

  desc "update environment on Elastic Beanstalk"
  task :update_eb_environment => :create_eb_environment do
    set_vars
    RAILS_DEFAULT_OPTIONS_KEYS = [:AWS_ACCESS_KEY_ID, :AWS_SECRET_KEY, :BUNDLE_WITHOUT, :PARAM1, :PARAM2, :RACK_ENV, :RAILS_SKIP_ASSET_COMPILATION, :RAILS_SKIP_MIGRATIONS]
    envs = AWS.elastic_beanstalk.client.describe_environments(:application_name=>ENV['APP_NAME'], :environment_names => [ENV['ENVIRONMENT']])
    unless envs[:environments].empty?
      rails_options_keys = rails_options.map{|opt| opt[:option_name]}
      env_config = AWS.elastic_beanstalk.client.describe_configuration_settings(:application_name=>ENV['APP_NAME'], :environment_name => ENV['ENVIRONMENT'])
      options_to_remove = env_config[:configuration_settings].first[:option_settings].select do |opt|
        opt[:namespace] == "aws:elasticbeanstalk:application:environment" and !rails_options_keys.include?(opt[:option_name]) and !RAILS_DEFAULT_OPTIONS_KEYS.include?(opt[:option_name].to_sym )
      end

      options_to_remove.each{|opt| puts "(Info) options removed:#{opt[:option_name]}=#{opt[:value]}" }

      options_to_remove.each{|opt| opt.delete(:value) }

      AWS.elastic_beanstalk.client.update_environment(:environment_name => ENV['ENVIRONMENT'],
                                                 :option_settings => rails_options,
                                                 :options_to_remove => options_to_remove )

      new_env_config = AWS.elastic_beanstalk.client.describe_configuration_settings(:application_name=>ENV['APP_NAME'], :environment_name => ENV['ENVIRONMENT'])
      puts "New env config"
      new_env_config[:configuration_settings].first[:option_settings].each {|opt| puts "(Info) #{opt[:option_name]}=#{opt[:value]}" if opt[:namespace] == "aws:elasticbeanstalk:application:environment" }
      puts " ----- END ----- "
    else
      puts "(Warning) Environment \"#{ ENV['ENVIRONMENT'] }\" doesn't exist"
    end
  end
end

