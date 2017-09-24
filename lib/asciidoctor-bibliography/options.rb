require "asciidoctor"
require_relative "errors"
require "csl/styles"

module AsciidoctorBibliography
  class Options < Hash
    PREFIX = "bibliography-".freeze

    DEFAULTS = {
      "bibliography-database" => nil,
      "bibliography-locale" => 'en-US',
      "bibliography-style" => "apa",
      "bibliography-hyperlinks" => "true",
      "bibliography-order" => "alphabetical", # TODO: deprecate
      "bibliography-tex-style" => "authoryear",
      "bibliography-sort" => nil,
    }.freeze

    def initialize
      merge DEFAULTS
    end

    def style
      # Error throwing delegated to CSL library. Seems to have nice messages.
      self["bibliography-style"] || DEFAULTS["bibliography-style"]
    end

    def locale
      value = self["bibliography-locale"] || DEFAULTS["bibliography-locale"]
      unless CSL::Locale.list.include? value
        message = "Option :bibliography-locale: has an invalid value (#{value}). Allowed values are #{CSL::Locale.list.inspect}."
        raise Errors::Options::Invalid, message
      end

      value
    end

    def hyperlinks?
      value = self["bibliography-hyperlinks"] || DEFAULTS["bibliography-hyperlinks"]
      unless %w[true false].include? value
        message = "Option :bibliography-hyperlinks: has an invalid value (#{value}). Allowed values are 'true' and 'false'."
        raise Errors::Options::Invalid, message
      end

      value == "true"
    end

    def database
      value = self["bibliography-database"] || DEFAULTS["bibliography-database"]
      if value.nil?
        message = "Option :bibliography-database: is mandatory. A bibliographic database is required."
        raise Errors::Options::Missing, message
      end

      value
    end

    def sort
      begin
        value = YAML.safe_load self["bibliography-sort"].to_s
      rescue Psych::SyntaxError => psych_error
        message = "Option :bibliography-sort: is not a valid YAML string: \"#{psych_error}\"."
        raise Errors::Options::Invalid, message
      end

      value = self.class.validate_parsed_sort_type! value
      value = self.class.validate_parsed_sort_contents! value unless value.nil?
      value
    end

    def tex_style
      self["bibliography-tex-style"] || DEFAULTS["bibliography-tex-style"]
    end

    def self.validate_parsed_sort_type!(value)
      return value if value.nil?
      return value if value.is_a?(Array) && value.all? { |v| v.is_a? Hash }
      return [value] if value.is_a? Hash
      message = "Option :bibliography-sort: has an invalid value (#{value}). Please refer to manual for more info."
      raise Errors::Options::Invalid, message
    end

    def self.validate_parsed_sort_contents!(array)
      # TODO: should we restrict these? Double check the CSL spec.
      allowed_keys = %w[variable macro sort names-min names-use-first names-use-last]
      return array unless array.any? { |hash| (hash.keys - allowed_keys).any? }
      message = "Option :bibliography-sort: has a value containing invalid keys (#{array}). Allowed keys are #{allowed_keys.inspect}. Please refer to manual for more info."
      raise Errors::Options::Invalid, message
    end

    def self.new_from_reader(reader)
      header_attributes = get_header_attributes_hash reader
      header_attributes.select! { |key, _| DEFAULTS.keys.include? key }
      new.merge header_attributes
    end

    def self.get_header_attributes_hash(reader)
      # We peek at the document attributes we need, without perturbing the parsing flow.
      # NOTE: we'll use this in a preprocessor and they haven't been parsed yet, there.
      tmp_document = ::Asciidoctor::Document.new
      tmp_reader = ::Asciidoctor::PreprocessorReader.new(tmp_document, reader.source_lines)

      ::Asciidoctor::Parser.
        parse(tmp_reader, tmp_document, header_only: true).
        attributes
    end
  end
end
