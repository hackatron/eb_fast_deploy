require "eb_fast_deploy/version"

def do_cmd(cmd)
  print "- - - cmd: #{cmd}\n"
  result = `#{cmd}`
  print "#{result}\n"
end

def set_vars
  ENV['EB_TARGET'] = (ENV['EB_TARGET'] || "STAGE").upcase
  @eb_environment = ENV["EB_#{ENV['EB_TARGET']}_ENVIRONMENT"]
  @application_name = ENV["EB_#{ENV['EB_TARGET']}_APPLICATION_NAME"]
  ENV['AWS_ACCESS_KEY_ID']= ENV["EB_#{ENV['EB_TARGET']}_AWS_ACCESS_KEY_ID"]
  ENV['AWS_SECRET_ACCESS_KEY'] = ENV["EB_#{ENV['EB_TARGET']}_AWS_SECRET_ACCESS_KEY"]
  ENV['EB_ELASTICBEANSTALK_URL'] = ENV["EB_#{ENV['EB_TARGET']}_ELASTICBEANSTALK_URL"]
  ENV['FOG_DIRECTORY'] = ENV["EB_#{ENV['EB_TARGET']}_FOG_DIRECTORY"]
  ENV['FOG_DEPLOY_DIRECTORY'] = ENV["EB_#{ENV['EB_TARGET']}_FOG_DEPLOY_DIRECTORY"]
  @deploy_tmp_dir = "/home/vagrant/tmp/holden-fandom_for_deploy"
  @deploy_zip_file_path = "/home/vagrant/tmp/holden-fandom_for_deploy.zip"
  @aws_credential_file = "#{Rails.root}/tmp/aws_credential_file"

  print "--- setting ENV ---\n"
  print "ENV['EB_TARGET']: #{ENV['EB_TARGET']}\n"
  print "ENV['AWS_ACCESS_KEY_ID']=#{ENV['AWS_ACCESS_KEY_ID']}\n"
  print "ENV['AWS_SECRET_ACCESS_KEY']=#{ENV['AWS_SECRET_ACCESS_KEY']}\n"
  print "ENV['FOG_DIRECTORY']=#{ENV['FOG_DIRECTORY']}\n"
  print "ENV['FOG_DEPLOY_DIRECTORY']=#{ENV['FOG_DEPLOY_DIRECTORY']}\n"
  print "@eb_environment: #{@eb_environment}\n"
  print "@aws_credential_file: #{@aws_credential_file}\n"
  print
end

namespace :eb do
  desc "assets compile and upload to S3"
  task :assets do
    set_vars unless @eb_environment

    do_cmd "rake assets:precompile FOG_DIRECTORY=#{ENV['FOG_DIRECTORY']} AWS_ACCESS_KEY_ID=#{ENV['AWS_ACCESS_KEY_ID']} AWS_SECRET_ACCESS_KEY=#{ENV['AWS_SECRET_ACCESS_KEY']}"
    do_cmd "mv public/assets/manifest.yml tmp/"
    do_cmd "rm public/assets/* -Rf"
    do_cmd "mv tmp/manifest.yml public/assets/"
  end

  desc "bundle pack"
  task :bundle_pack do
    set_vars unless @eb_environment

    do_cmd "rm vendor/cache -Rf"
    do_cmd "bundle install"

    #gems
    #call "bundle pack --all" from shell before this rake
    #because it doesn't pach git gems
    do_cmd "bundle pack --all"

  end

  desc "upload project to s3"
  task :upload do
    print "=== upload project to s3 ===\n"
    print "\n"

    set_vars unless @eb_environment

    do_cmd "mkdir #{@deploy_tmp_dir}"
    do_cmd "rm #{@deploy_zip_file_path}"
    do_cmd "rsync --exclude='.git' --exclude='.bundle' --exclude='tmp/*' --exclude='log/*' . #{@deploy_tmp_dir} -r --delete-excluded --delete"

    current_dir = `pwd`
    do_cmd "cd #{@deploy_tmp_dir} && zip -r #{@deploy_zip_file_path} . && cd #{pwd}"

    print "storage = Fog::Storage.new provider: #{ENV['FOG_PROVIDER']}, aws_access_key_id: #{ENV['AWS_ACCESS_KEY_ID']}, aws_secret_access_key: #{ENV['AWS_SECRET_ACCESS_KEY']}\n"
    storage = Fog::Storage.new({
    provider: ENV['FOG_PROVIDER'],
    region: ENV['FOG_REGION'],
    aws_access_key_id: ENV['AWS_ACCESS_KEY_ID'],
    aws_secret_access_key: ENV['AWS_SECRET_ACCESS_KEY']
    })
    print "bucket = storage.directories.get(#{ENV['FOG_DEPLOY_DIRECTORY']})\n"
    bucket = storage.directories.get(ENV['FOG_DEPLOY_DIRECTORY'])

    if File.exist? @deploy_zip_file_path
      print "creating new remote file..."
      deploy_zip_file = File.open @deploy_zip_file_path, "r"
      remote_file = bucket.files.new key: "prj.zip", body: deploy_zip_file
      result = remote_file.save
      print "remote_file.save: #{result}\n"
    else
      print "file #{@deploy_zip_file_path} not found"
    end

  end

  desc "disable memcache"
  task :disable_memcache do
    #assets precompile run in production env and search for memcache server
    do_cmd "sed -i 's/^  elasticache/#  elasticache/' #{Rails.root}/config/environments/production.rb"
    do_cmd "sed -i 's/^  config.cache_store/#  config.cache_store/' #{Rails.root}/config/environments/production.rb"
  end

  desc "elastic beanstalk config"
  task :cfg do
    set_vars unless @eb_environment

    #create temporary aws_credentials file
    f = File.new(@aws_credential_file, "w+")

    content = ""
    content << "AWSAccessKeyId=#{ENV['AWS_ACCESS_KEY_ID']}\n"
    content << "AWSSecretKey=#{ENV['AWS_SECRET_ACCESS_KEY']}\n"
    f.write content
    f.close

    #eb cfg
    eb_cfg_path = "#{Rails.root}/.elasticbeanstalk/config"
    f = File.new(eb_cfg_path, "a+")

    f.write "ApplicationName=#{@application_name}\n"
    f.close
  end

  desc "publish to elastic beanstalk"
  task :publish do
    AWS.config(
      access_key_id: ENV['AWS_ACCESS_KEY_ID'],
      secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'],
      region: ENV['FOG_REGION']
    )
    version_label = "#{Time.now}"
    aws_app_opt = {
      application_name: @application_name,
      description: "deploy",
      source_bundle: {
        s3_bucket: ENV['FOG_DEPLOY_DIRECTORY'],
        s3_key: "prj.zip"
      },
      version_label: version_label
    }

    aws_env_opt = {
      environment_name: @eb_environment,
      version_label: version_label
    }

    eb = AWS.elastic_beanstalk
    eb.client.create_application_version aws_app_opt
    eb.client.update_environment aws_env_opt
  end

  desc "clean modified files"
  task :cleanup do
    File.delete(@aws_credential_file) if File.exist?(@aws_credential_file)
    do_cmd "git checkout .elasticbeanstalk/config"
    do_cmd "git checkout config/environments/production.rb"
#    do_cmd "rm vendor/cache -Rf"
  end

  desc "deploy to elastic beanstalk"
  task :deploy do
    set_vars

    print "=== deploy to elastic beanstalk ===\n\n"

#    Rake::Task['eb:cfg'].invoke
    Rake::Task['eb:assets'].invoke
    Rake::Task['eb:bundle_pack'].invoke
    Rake::Task['eb:upload'].invoke
    Rake::Task['eb:publish'].invoke
    Rake::Task['eb:cleanup'].invoke

  end
end

