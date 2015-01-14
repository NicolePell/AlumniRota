require 'sinatra'
require 'sinatra/partial'
require 'httparty'
require 'google/api_client'
require 'google/api_client/client_secrets'
require 'google/api_client/auth/file_storage'
require 'logger'

set :partial_template_engine, :erb
set :public_folder, Proc.new { File.join(root, '..', 'public') }

enable :sessions

CREDENTIAL_STORE_FILE = "#{$0}-oauth2.json"

def logger; settings.logger end

def api_client; settings.api_client end

def calendar_api; settings.calendar end

def user_credentials
  @authorization ||= (
    auth = api_client.authorization.dup
    auth.redirect_uri = to('/oauth2callback')
    auth.update_token!(session)
    auth
  )
end

configure do
  log_file = File.open('calendar.log', 'a+')
  log_file.sync = true
  logger = Logger.new(log_file)
  logger.level = Logger::DEBUG

  client = Google::APIClient.new(
  application_name: 'Alumni Rota',
  application_version: '1.0.0'
  )

  file_storage = Google::APIClient::FileStorage.new(CREDENTIAL_STORE_FILE)
  if file_storage.authorization.nil?
    client_secrets = Google::APIClient::ClientSecrets.load
    client.authorization = client_secrets.to_authorization
    client.authorization.scope = 'https://www.googleapis.com/auth/calendar'
  else
    client.authorization = file_storage.authorization
  end

  calendar = client.discovered_api('calendar', 'v3')

  set :logger, logger
  set :api_client, client
  set :calendar, calendar

end

  before do
    unless user_credentials.access_token || request.path_info =~ /\A\/oauth2/
      redirect to('/oauth2authorize')
    end
  end

  after do
    session[:access_token] = user_credentials.access_token
    session[:refresh_token] = user_credentials.refresh_token
    session[:expires_in] = user_credentials.expires_in
    session[:issued_at] = user_credentials.issued_at

    file_storage = Google::APIClient::FileStorage.new(CREDENTIAL_STORE_FILE)
    file_storage.write_credentials(user_credentials)
  end

get '/oauth2authorize' do
  redirect user_credentials.authorization_uri.to_s, 303
end

get '/oauth2callback' do
  user_credentials.code = params[:code]
  if params[:code]
    user_credentials.fetch_access_token!
    redirect to('/')
  end
end

get '/' do
  result = api_client.execute(:api_method => calendar_api.events.list,
                              :parameters => {'calendarId' => "r9pjj9vja5eka03ip7r7m72ims@group.calendar.google.com"},
                              :authorization => user_credentials)
  [result.status, { 'Content-Type' => 'application/json'}, result.data.to_json]
end
