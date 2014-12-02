class ApplicationController < ActionController::Base
  # Adds a few additional behaviors into the application controller
  include Blacklight::Controller
  # Adds Drs behaviors into the application controller
  include Cerberus::Controller
  # Solr Escape group values
  include Cerberus::ControllerHelpers::SolrEscapeGroups

  # Please be sure to impelement current_user and user_session. Blacklight depends on
  # these methods in order to perform user specific actions.

  layout "homepage"

  protect_from_forgery
  before_filter :store_location

  # around_filter :profile

  def profile
    if params[:profile] && result = RubyProf.profile { yield }

      out = StringIO.new
      RubyProf::GraphHtmlPrinter.new(result).print out, :min_percent => 0
      self.response_body = out.string

    else
      yield
    end
  end

  def email_handled_exception(exception)
    if !current_user.nil?
      name = current_user.name
    else
      name = "Not Logged In"
    end

    ExceptionNotifier.notify_exception(exception, :env => request.env, :data => {:user => "#{name}"})
  end

  def mint_unique_pid
    Cerberus::Noid.namespaceize(Cerberus::IdService.mint)
  end

  def reset_page_parameter
    # This a kludge to avoid monkey patching for https://github.com/NEU-Libraries/cerberus/issues/611
    # REMOVE THIS when updating Blacklight
    # relevant pull/issue - https://github.com/projectblacklight/blacklight/pull/528
    # relevant patch - https://github.com/projectblacklight/blacklight/commit/aa5a40d170c6568da42881ea9279c8abbfbbb031#diff-1948ff0d97b888dc61ae381aec62dfa5
    if params[:per_page]
      params[:page] = "1"
    end
  end

  def fetch_solr_document(options = {})
    options = options.with_indifferent_access

    fetch = Proc.new do |x|
      q = ActiveFedora::SolrService.query("id:\"#{x}\"").first
      raise ActiveFedora::ObjectNotFoundError if q.nil?

      return SolrDocument.new(q)
    end

    if options[:id]
      fetch.call(options[:id])
    else
      fetch.call(params[:id])
    end
  end

  def store_location
    # store last url - this is needed for post-login redirect to whatever the user last visited.
    return unless request.get?
    if (request.path != "/users/sign_in" &&
        request.path != "/users/sign_up" &&
        request.path != "/users/password/new" &&
        request.path != "/users/sign_out" &&
        request.path != "/users/auth/shibboleth" &&
        request.path != "/users/auth/shibboleth/callback" &&
        !(request.path.include? "/downloads/") &&
        !request.xhr?) # don't store ajax calls
      session[:previous_url] = request.fullpath
    end
  end

  helper_method :current_user_can?

  def current_user_can?(perm_level, record)
    if current_user
      current_user.can? perm_level, record
    elsif perm_level != :read
      false
    else
      record.read_groups.include? 'public'
    end
  end

  def after_sign_in_path_for(resource)
    session[:previous_url] || root_path
  end

  # Some useful helpers for seeing the filters defined on given controllers
  # Taken from: http://scottwb.com/blog/2012/02/16/enumerate-rails-3-controller-filters/
  def self.filters(kind = nil)
    all_filters = _process_action_callbacks
    all_filters = all_filters.select{|f| f.kind == kind} if kind
    all_filters.map(&:filter)
  end

  def self.before_filters
    filters(:before)
  end

  def self.after_filters
    filters(:after)
  end

  def self.around_filters
    filters(:around)
  end
end
