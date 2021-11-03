require 'net/https'
require 'uri'
require 'json'

# https://www.rxspark.com/api-reference/v2
module RxSpark
  # Service to call RxSpark's enrollment service
  # and persist response to the given user record
  # Usage: RxSpark::MembershipEnrollmentService.new(123).delay.call
  class MembershipEnrollmentService
    class RxSparkError < StandardError; end

    def initialize(user_id:)
      @user_id = user_id
    end

    def call
      return unless ENV['RX_SPARK_ENABLED']

      enroll_member!(user_id: @user_id)
      OpenStruct.new(
        { success?: true, payload: { rxspark_user_id: data['user_id'] } }
      )
    rescue RxSparkError => e
      OpenStruct.new({ success?: false, error: e.message })
    end

    private

    def enroll_member!(user_id:)
      user = find_member(user_id: user_id)
      api_response = post_to_api(user: user)

      user.rxspark_user_id = api_response['user_id']
      user.rxspark_card_download_url = api_response['card_download_url']

      raise RxSparkError, user.errors.full_messages.to_sentence \
          unless user.save

      user.rxspark_user_id
    end

    def find_member(user_id:)
      user = User.find_by(id: user_id)
      raise RxSparkError, 'User not found' unless user

      user
    end

    def post_to_api(user:)
      uri = URI.parse("#{RX_SPARK_URL}/users")
      header = { 'Api-Key': RX_SPARK_API_KEY }

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE

      request = Net::HTTP::Post.new(uri.request_uri, header)
      request.set_form_data(
        user_payload(user: user)
      )
      response = http.request(request)

      raise RxSparkError, JSON.parse(response.body)['message'] \
        if response.code.to_i != 200

      JSON.parse(response.body)['user'] || {}
    end

    def user_payload(user:)
      {
        first_name: user.first_name,
        last_name: user.last_name,
        email: user.email,
        gender: user.gender,
        address_1: user.address1,
        address_2: '',
        city: user.city,
        zip: user.zipcode,
        phone: user.phone,
        sid: user.id
      }
    end
  end
end
