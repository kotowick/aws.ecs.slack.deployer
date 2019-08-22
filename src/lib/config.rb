# frozen_string_literal: true

require 'yaml'
require './src/lib/shared'

module Config
  @config = {}

  def self.load(file = "./config/#{ENV['CONFIG_FILE']}")
    data = YAML.load_file(file)
    symbolize_data = Shared.symbolize_keys(data)

    symbolize_data.each do |k, v|
      @config[k] = v
    end
  end

  def self.get
    @config
  end
end
