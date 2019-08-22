# frozen_string_literal: true

require 'pp'
require './src/lib/shared'

module Store
  @store = {}

  def self.update(data)
    data = Shared.symbolize_keys(data)
    data.each do |k, v|
      @store[k] = v
    end
  end

  def self.get
    @store
  end
end
