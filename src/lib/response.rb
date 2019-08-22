# frozen_string_literal: true

module Response
  def self.get(status_code, body, extra = {})
    {
      statusCode: status_code,
      body: body,
      extra: extra,
    }
  end
end
