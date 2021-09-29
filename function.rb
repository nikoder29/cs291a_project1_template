# frozen_string_literal: true

require 'json'
require 'jwt'
require 'pp'

ENV['JWT_SECRET'] = 'MYSECRET'

def main(event:, context:)
  # You shouldn't need to use context, but its fields are explained here:
  # https://docs.aws.amazon.com/lambda/latest/dg/ruby-context.html
  content_type = 'content-type'
  authorization = 'Authorization'

  keys = event['headers'].keys

  keys.each do |key|

    if key.casecmp(content_type)
      event['headers'][content_type] = event['headers'][key]
    elsif key.casecmp(authorization)
      event['headers'][authorization] = event['headers'][key]
    end
  end

  status = nil
  case event['httpMethod']
  when 'GET'
    if event['path'] == '/'
      token = event['headers'][authorization].split(' ')[1]
      begin
        # puts token
        decoded_token_payload = JWT.decode(token, ENV['JWT_SECRET'])
        # puts decoded_token_payload
        if Time.now.to_i >= decoded_token_payload['nbf'] && Time.now.to_i < decoded_token_payload['exp']
          status = 403
          decoded_token_payload = nil
        end
      rescue
        decoded_token_payload = nil
        status = 403
      ensure
        return generateGetResponse(payload: decoded_token_payload, status: status)
      end
    elsif event['path'] == '/token'
      status = 405
    else
      status = 404
    end

  when 'POST'
    if event['path'] == '/token'
      if event['headers'][content_type] != 'application/json'
        status = 415
      else
        status = 200
        begin
          payload = {data: JSON.parse(event['body']),
            exp: Time.now.to_i + 5,nbf: Time.now.to_i + 2}
            generated_token = JWT.encode payload, ENV['JWT_SECRET'], 'HS256'
        # generatePostResponse(token: generated_token, status: status)
          {
            token: generated_token,
            statusCode: 201,
            headers: event['headers']
          }

        rescue
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

  response(body: nil, status: status)
end

def generatePostResponse(token: nil, status: 200)
  {
    token: token,
    statusCode: status
  }
end

def generateGetResponse(payload: nil, status: 200)
  {
    payload: payload,
    statusCode: status
  }
end

def response(body: nil, status: 200)
  {
    body: body ? body.to_json + "\n" : '',
    statusCode: status
  }
end

if $PROGRAM_NAME == __FILE__
  # If you run this file directly via `ruby function.rb` the following code
  # will execute. You can use the code below to help you test your functions
  # without needing to deploy first.
  ENV['JWT_SECRET'] = 'NOTASECRET'

  # Call /token
  PP.pp main(context: {}, event: {
               # 'body' => '{"name": "bboe"}',
               'body' => '',
               'headers' => { 'Content-Type' => 'application/json' },
               'httpMethod' => 'POST',
               'path' => '/token'
             })

  # Generate a token
  payload = {
    data: { user_id: 128 },
    exp: Time.now.to_i + 1,
    nbf: Time.now.to_i
  }
  token = JWT.encode payload, ENV['JWT_SECRET'], 'HS256'
  # Call /
  PP.pp main(context: {}, event: {
               'headers' => { 'Authorization' => "Bearer #{token}",
                              'Content-Type' => 'application/json' },
               'httpMethod' => 'GET',
               'path' => '/'
             })
end
