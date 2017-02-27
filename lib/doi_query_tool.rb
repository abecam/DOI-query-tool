module DOI
  require 'rubygems'
  require 'xml'
  require 'open-uri'
  require 'active_support/all'

  require 'doi/author'
  require 'doi/query'
  require 'doi/record'
  require 'doi/exceptions'

  FETCH_URL = 'https://www.crossref.org/openurl/'

  LOOKUP_URL = 'http://dx.doi.org/'

  def self.lookup_url
    class_variable_defined?('@@lookup_url') ? @@lookup_url : LOOKUP_URL
  end

  def self.lookup_url= url
    @@lookup_url = url
  end

  def self.fetch_url
    class_variable_defined?('@@fetch_url') ? @@lookup_url : FETCH_URL
  end

  def self.fetch_url= url
    @@fetch_url = url
  end
end
