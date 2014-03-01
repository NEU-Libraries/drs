require 'blacklight/catalog'
require 'blacklight_advanced_search'
require 'parslet'
require 'parsing_nesting/tree'

class CommunitiesController < SetsController
  include Drs::ControllerHelpers::EditableObjects

  include Blacklight::Catalog
  include Blacklight::Configurable # comply with BL 3.7
  include ActionView::Helpers::DateHelper
  # This is needed as of BL 3.7
  self.copy_blacklight_config_from(CatalogController)

  include BlacklightAdvancedSearch::ParseBasicQ
  include BlacklightAdvancedSearch::Controller

  before_filter :can_read?, except: [:index]

  rescue_from Exceptions::NoParentFoundError, with: :index_redirect
  rescue_from ActiveFedora::ObjectNotFoundError, with: :index_redirect_with_bad_id

  rescue_from ActiveFedora::ObjectNotFoundError do
    @obj_type = "Community"
    render "error/object_404"
  end

  def index
    redirect_to community_path(id: 'neu:1')
  end

  def show
    @set_id = params[:id]
    self.solr_search_params_logic += [:find_object]
    (@response, @document_list) = get_search_results
    @set = SolrDocument.new(@response.docs.first)
    @page_title = @set.title

    self.solr_search_params_logic.delete(:find_object)
    self.solr_search_params_logic += [:show_children_only]
    (@response, @document_list) = get_search_results

    render :template => 'shared/sets/show'
  end

  def employees
    @dept = Community.find(params[:id])
    @page_title = "#{@dept.title} Staff"
  end

  def research_publications
    @dept = Community.find(params[:id])
    @page_title = "#{@dept.title} Research Papers"
  end

  def other_publications
    @dept = Community.find(params[:id])
    @page_title = "#{@dept.title} Papers"
  end

  def presentations
    @dept = Community.find(params[:id])
    @page_title = "#{@dept.title} Presentations"
  end

  def data_sets
    @dept = Community.find(params[:id])
    @page_title = "#{@dept.title} Data Sets"
  end

  def learning_objects
    @dept = Community.find(params[:id])
    @page_title = "#{@dept.title} Learning Objects"
  end

  protected

    def index_redirect
      flash[:error] = "Communities cannot be created without a parent"
      redirect_to communities_path and return
    end

    def index_redirect_with_bad_id
      flash[:error] = "The id you specified does not seem to exist in Fedora."
      redirect_to communities_path and return
    end

    def show_children_only(solr_parameters, user_parameters)
      solr_parameters[:fq] ||= []
      solr_parameters[:fq] << "#{Solrizer.solr_name("parent_id", :stored_searchable)}:\"#{@set_id}\""
    end

    def find_object(solr_parameters, user_parameters)
      solr_parameters[:fq] ||= []
      solr_parameters[:fq] << "id:\"#{@set_id}\""
    end
end
