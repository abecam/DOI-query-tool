module DOI
  class Query
    attr_accessor :api_key

    def initialize(a)
      self.api_key = a
    end

    # Takes either a DOI and fetches the associated publication
    def fetch(id, params = {})
      params[:format] = 'unixref'
      params[:id] = "doi:#{id}" unless params[:id]
      params[:pid] = api_key unless params[:pid]
      params[:noredirect] = true
      uri = URI(DOI.fetch_url)
      uri.query = URI.encode_www_form(params.delete_if { |k, _v| k.nil? }.to_a)
      url = uri.to_s

      doc = query(url)

      record = parse_xml(doc)
      record.doi = id
      record
    end

    # Parses the XML returned from the DOI query, and creates an object
    def parse_xml(doc)
      if doc.find_first('//error') || doc.to_s.include?('Malformed DOI')
        process_error(doc)
      else
        process_content(doc)
      end
    end

    private

    def process_error(doc)
      params = {}
      if doc.to_s.include?('Malformed DOI')
        params[:error] = 'Not a valid DOI'
      else
        error = doc.find_first('//error')
        params[:error] = error.content
        params[:error] = 'The DOI could not be resolved' if params[:error].include?('not found in CrossRef')
      end

      DOI::Record.new(params)
    end

    def process_content(doc)
      params = {}

      article = doc.find_first('//journal')
      params[:type] = :journal unless article.nil?
      article ||= doc.find_first('//conference')
      params[:type] ||= :conference unless article.nil?
      article ||= doc.find_first('//book')
      params[:type] ||= :book_chapter unless article.nil?
      if article.nil?
        article ||= doc.find_first('//posted_content')
        params[:type] = if article.attributes['type'] == 'preprint'
                          :pre_print
                        else
                          :other
                        end
        raise DOI::UnrecognizedTypeException if article.nil?
      end

      params[:doc] = article

      title = article.find_first('//journal_article/titles/title')
      title ||= article.find_first('//conference_paper/titles/title')
      title ||= article.find_first('//content_item/titles/title')
      title ||= article.find_first('//titles/title')
      params[:title] = title.nil? ? nil : title.content

      params[:authors] = []
      author_elements = article.find("//content_item/contributors/person_name[@contributor_role='author']")
      author_elements = article.find("//contributors/person_name[@contributor_role='author']") if author_elements.blank?

      author_elements.each do |author|
        author_last_name = author.find_first('.//surname').content
        author_first_name = author.find_first('.//given_name').content
        params[:authors] << DOI::Author.new(author_first_name, author_last_name)
      end

      journal = article.find_first('//journal_metadata/abbrev_title')
      journal ||= article.find_first('//proceedings_metadata/proceedings_title')
      journal ||= article.find_first('//book_series_metadata/titles/title')
      journal ||= article.find_first('//book_metadata/titles/title')

      params[:journal] = journal.nil? ? nil : journal.content

      # add citation
      if article.find_first('//journal_metadata/abbrev_title')
        citation_iso_abbrev = article.find_first('//journal_metadata/abbrev_title').content
      elsif article.find_first('//title')
        citation_iso_abbrev = article.find_first('//title').content
      else
        citation_iso_abbrev = ''
      end
      citation_volume = article.find_first('.//volume') ? article.find_first('.//volume').content : ''
      citation_issue = article.find_first('.//issue') ? '(' + article.find_first('.//issue').content + ')' : ''
      citation_first_page = article.find_first('.//first_page') ? ' : ' + article.find_first('.//first_page').content : ''
      citation = citation_iso_abbrev + ' ' + citation_volume + citation_issue + citation_first_page
      params[:citation] = citation

      date = article.find_first('//publication_date')
      params[:pub_date] = date.nil? ? nil : parse_date(date)

      DOI::Record.new(params)
    end

    def query(url)
      begin
        doc = open(url)
      rescue Exception => e
        raise DOI::FetchException
      end

      begin
        # Manually remove annoying namespaces because libxml can't do it
        string = doc.read.gsub(/xmlns=\"([^\"]*)\"/, '')
        doc = XML::Parser.string(string).parse
        return doc
      rescue Exception => ex
        raise DOI::ParseException # "There was an error fetching the given DOI\n#{ex.message}\n#{ex.backtrace.join("\n")}"
      end
    end

    def parse_date(xml_date)
      if xml_date.nil?
        nil
      else
        day = xml_date.find_first('.//day')
        day = day.nil? ? '01' : day.content
        month = xml_date.find_first('.//month')
        month = month.nil? ? '01' : month.content
        year = xml_date.find_first('.//year')
        year = year.nil? ? '1970' : year.content
        Date.strptime("#{year}-#{month}-#{day}")
      end
    end
  end
end
