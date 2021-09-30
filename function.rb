# frozen_string_literal: true

require 'json'
require 'jwt'
require 'pp'

ENV['JWT_SECRET'] = 'MYSECRET'

def main(event:, context:)
  # You shouldn't need to use context, but its fields are explained here:
  # https://docs.aws.amazon.com/lambda/latest/dg/ruby-context.html
  content_type = 'Content-Type'
  authorization = 'Authorization'
  puts "keys are"
  keys = event['headers'].keys
  puts keys
  for key in keys do
    if key.casecmp(content_type) == 0
      event['headers'][content_type] = event['headers'][key]
    # elsif key.casecmp(authorization)
    #   event['headers'][authorization] = event['headers'][key]
    end
  end

  status = nil
  case event['httpMethod']
  when 'GET'
    if event['path'] == '/'
      token = event['headers'][authorization].split(' ')[1]
      begin
        # puts token
        decoded_token_payload = JWT.decode(token, ENV['JWT_SECRET'])[0]

        if Time.now.to_i < decoded_token_payload['nbf'] || Time.now.to_i >= decoded_token_payload['exp']
          status = 403
          body = nil
        else
          status = 200
          body = decoded_token_payload["data"]
        end
      rescue
        puts "Error detected!"
        decoded_token_payload = nil
        status = 403
      ensure
        return generateGetResponse(payload: body, status: status, headers: event["headers"])
      end
    elsif event['path'] == '/token'
      status = 405
    else
      status = 404
    end

  when 'POST'
    if event['path'] == '/token'
      # puts event['headers']
      # puts content_type.to_sym
      if event['headers']['Content-Type'] != 'application/json'
        status = 415
      else
        status = 200
        begin
          parsed_body = JSON.parse(event['body'])
          payload = {data: JSON.parse(event['body']),
            exp: Time.now.to_i + 5,nbf: Time.now.to_i + 2}
            generated_token = JWT.encode payload, ENV['JWT_SECRET'], 'HS256'
        # generatePostResponse(token: generated_token, status: status)
          return {
            token: generated_token,
            statusCode: 201,
            headers: event['headers']
          }

        rescue
          puts  "parsing failed!"
          status = 422
        end
      end

    elsif event['path'] == '/'
      status = 405
    else
      status = 404
    end

  else
    status = 405
  end

  response(body: nil, status: status, headers: event["headers"])
end

def generatePostResponse(token: nil, status: 200, headers: nil)
  {
    token: token,
    statusCode: status,
    headers: headers
  }
end

def generateGetResponse(payload: nil, status: 200, headers: nil)
  {
    payload: payload,
    statusCode: status,
    headers: headers
  }
end

def response(body: nil, status: 200, headers: nil)
  {
    body: body ? body.to_json + "\n" : '',
    statusCode: status,
    headers: headers
  }
end

if $PROGRAM_NAME == __FILE__
  # If you run this file directly via `ruby function.rb` the following code
  # will execute. You can use the code below to help you test your functions
  # without needing to deploy first.
  # ENV['JWT_SECRET'] = 'NOTASECRET'

  # Call /token
  response = main(context: {}, event: {
               # 'body' => '{"name": "bboe"}',
               'body' => '{}',
               'headers' => { 'COntENt-tyPe' => 'application/json' },
               'httpMethod' => 'POST',
               'path' => '/token'
             })
  PP.pp response
  # Generate a token
  payload = {
    data: { name: 128 },
    exp: Time.now.to_i + 1,
    nbf: Time.now.to_i
  }
  # token = JWT.encode payload, ENV['JWT_SECRET'], 'HS256'
  # Call /
  sleep(3)
  PP.pp main(context: {}, event: {
               'headers' => { 'Authorization' => "Bearer #{response[:token]}",
                              'COntENt-tyPe' => 'application/json' },
               'httpMethod' => 'GET',
               'path' => '/'
             })
end
