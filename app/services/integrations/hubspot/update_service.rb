# frozen_string_literal: true

module Integrations
  module Hubspot
    class UpdateService < BaseService
      def initialize(integration:, params:)
        @integration = integration
        @params = params

        super
      end

      def call
        return result.not_found_failure!(resource: 'integration') unless integration

        unless integration.organization.premium_integrations.include?('hubspot')
          return result.not_allowed_failure!(code: 'premium_integration_missing')
        end

        old_private_app_token = integration.private_app_token

        integration.name = params[:name] if params.key?(:name)
        integration.code = params[:code] if params.key?(:code)
        integration.private_app_token = params[:private_app_token] if params.key?(:private_app_token)
        integration.default_targeted_object = params[:default_targeted_object] if params.key?(:default_targeted_object)
        integration.sync_invoices = params[:sync_invoices] if params.key?(:sync_invoices)
        integration.sync_subscriptions = params[:sync_subscriptions] if params.key?(:sync_subscriptions)

        integration.save!

        if integration.type == 'Integrations::HubspotIntegration' && integration.private_app_token != old_private_app_token
          Integrations::Aggregator::SendPrivateAppTokenJob.perform_later(integration:)
        end

        result.integration = integration
        result
      rescue ActiveRecord::RecordInvalid => e
        result.record_validation_failure!(record: e.record)
      end

      private

      attr_reader :integration, :params
    end
  end
end