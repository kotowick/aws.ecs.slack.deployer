# frozen_string_literal: true

require 'pp'

module Shared
  def self.symbolize_keys(hash)
    hash.each_with_object({}) do |(key, value), result|
      new_key = case key
      when String then key.to_sym
      else key
      end

      new_value = case value
      when Hash then symbolize_keys(value)
      else value
      end
      result[new_key] = new_value
    end
  end
end
