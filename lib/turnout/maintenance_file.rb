require 'yaml'
require 'fileutils'

module Turnout
  class MaintenanceFile
    attr_reader :path

    SETTINGS = [:reason, :allowed_paths, :allowed_ips, :response_code, :retry_after]
    attr_reader *SETTINGS

    def initialize(path)
      @path = path
      @reason = Turnout.config.default_reason
      @allowed_paths = Turnout.config.default_allowed_paths
      @allowed_ips = []
      @response_code = Turnout.config.default_response_code
      @retry_after = Turnout.config.default_retry_after

      import_yaml if exists?
    end

    def exists?
      maint_file.exists?
    end

    def to_h
      SETTINGS.each_with_object({}) do |att, hash|
        hash[att] = send(att)
      end
    end

    def to_yaml(key_mapper = :to_s)
      to_h.each_with_object({}) { |(key, val), hash|
        hash[key.send(key_mapper)] = val
      }.to_yaml
    end

    def write
      maint_file.write to_yaml
    end

    def delete
      maint_file.delete
    end

    def import(hash)
      SETTINGS.map(&:to_s).each do |att|
        self.send(:"#{att}=", hash[att]) unless hash[att].nil?
      end

      true
    end
    alias :import_env_vars :import

    # Find the first MaintenanceFile that exists
    def self.find
      path = named_paths.values.find { |path| maint_file(path).exists? }
      self.new(path) if path
    end

    def self.named(name)
      path = named_paths[name.to_sym]
      self.new(path) unless path.nil?
    end

    def self.default
      self.new(named_paths.values.first)
    end

    private

    def retry_after=(value)
      @retry_after = value
    end

    def reason=(reason)
      @reason = reason.to_s
    end

    # Splits strings on commas for easier importing of environment variables
    def allowed_paths=(paths)
      if paths.is_a? String
        # Grab everything between commas that aren't escaped with a backslash
        paths = paths.to_s.split(/(?<!\\),\ ?/).map do |path|
          path.strip.gsub('\,', ',') # remove the escape characters
        end
      end

      @allowed_paths = paths
    end

    # Splits strings on commas for easier importing of environment variables
    def allowed_ips=(ips)
      ips = ips.to_s.split(',') if ips.is_a? String

      @allowed_ips = ips
    end

    def response_code=(code)
      @response_code = code.to_i
    end

    def dir_path
      File.dirname(path)
    end

    def import_yaml
      import YAML::load(maint_file.read) || {}
    end

    def maint_file
      AWS::S3.new.buckets[Turnout.config.bucket].objects[path]
    end

    def self.named_paths
      Turnout.config.named_maintenance_file_paths
    end

    def self.maint_file(path)
      AWS::S3.new.buckets[Turnout.config.bucket].objects[path]
    end
  end
end
