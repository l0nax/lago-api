# frozen_string_literal: true

require 'lago_http_client'

module Webhooks
  # NOTE: Abstract Service, should not be used directly
  class BaseService
    def initialize(object:, options: {}, webhook_id: nil)
      @object = object
      @options = options&.with_indifferent_access
      @webhook_id = webhook_id
    end

    def call
      return unless current_organization&.webhook_url?

      payload = {
        webhook_type:,
        object_type:,
        object_type => object_serializer.serialize,
      }

      preprocess_webhook(current_webhoook, payload)

      http_client = LagoHttpClient::Client.new(current_organization.webhook_url)
      headers = generate_headers(payload)
      response = http_client.post(payload, headers)

      succeed_webhook(current_webhook, response)
    rescue LagoHttpClient::HttpError => e
      fail_webhook(current_webhook, e)

      # NOTE: By default, Lago is retrying 3 times a webhook
      return if current_webhook.attempts == 3

      SendWebhookJob.set(wait: wait_value)
        .perform_later(webhook_type, object, options, current_webhook.id)
    end

    private

    attr_reader :object, :options, :webhook_id

    def object_serializer
      # Empty
    end

    def current_organization
      # Empty
    end

    def webhook_type
      # Empty
    end

    def object_type
      # Empty
    end

    def generate_headers(payload)
      [
        'X-Lago-Signature' => generate_signature(payload),
      ]
    end

    def generate_signature(payload)
      JWT.encode(
        {
          data: payload.to_json,
          iss: issuer,
        },
        RsaPrivateKey,
        'RS256',
      )
    end

    def issuer
      ENV['LAGO_API_URL']
    end

    def current_webhook
      @current_webhook ||= current_organization.webhooks.find_or_initialize_by(
        id: webhook_id,
        webhook_type:,
        object_id: object&.id,
        object_type: object&.class,
        endpoint: current_organization.webhook_url,
      )
    end

    def preprocess_webhook(webhook)
      webhook.payload = payload.to_json
      webhook.attempts += 1
      webhook.retried_at = DateTime.zone.now unless webhook.attempts == 1
    end

    def succeed_webhook(webhook, response)
      webhook.http_status = response.status.to_i
      webhook.response = response.to_json
      webhook.succeeded!
    end

    def fail_webhook(webhook, error)
      webhook.http_status = error.error_code
      webhook.response = error.json_message
      webhook.failed!
    end

    def wait_value
      # NOTE: This is based on the Rails Active Job wait algorithm
      executions = current_webhook.attempts
      ((executions**4) + (Kernel.rand * (executions**4) * jitter)) + 2
    end
  end
end
