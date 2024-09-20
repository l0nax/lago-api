# frozen_string_literal: true

module Graphql
  class BaseController < ApplicationController
    before_action :set_context_source

    rescue_from JWT::ExpiredSignature do
      render_graphql_error(code: "expired_jwt_token", status: 401)
    end

    # If accessing from outside this domain, nullify the session
    # This allows for outside API access while preventing CSRF attacks,
    # but you'll have to authenticate your user separately
    # protect_from_forgery with: :null_session

    def execute
      raise NotImplementedError
    end

    private

    # Handle variables in form data, JSON body, or a blank value
    def prepare_variables(variables_param)
      case variables_param
      when String
        if variables_param.present?
          JSON.parse(variables_param) || {}
        else
          {}
        end
      when Hash
        variables_param
      when ActionController::Parameters
        variables_param.to_unsafe_hash # GraphQL-Ruby will validate name and type of incoming variables.
      when nil
        {}
      else
        raise ArgumentError, "Unexpected parameter: #{variables_param}"
      end
    end

    def handle_error_in_development(error)
      logger.error(error.message)
      logger.error(error.backtrace.join("\n"))

      render(json: {errors: [{message: error.message, backtrace: error.backtrace}], data: {}}, status: 500)
    end

    def render_graphql_error(code:, status:, message: nil)
      render(
        json: {
          data: {},
          errors: [
            {
              message: message || code,
              extensions: {status:, code:}
            }
          ]
        }
      )
    end

    def set_context_source
      CurrentContext.source = 'graphql'
    end
  end
end