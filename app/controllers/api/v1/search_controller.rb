require 'blacklight/catalog'
require 'blacklight_advanced_search'
require 'parslet'
require 'parsing_nesting/tree'

module Api
  module V1
    class SearchController < ApplicationController

      include Blacklight::Catalog
      include Blacklight::CatalogHelperBehavior
      include Blacklight::Configurable # comply with BL 3.7
      include ActionView::Helpers::DateHelper
      # This is needed as of BL 3.7
      self.copy_blacklight_config_from(CatalogController)
      include BlacklightAdvancedSearch::ParseBasicQ
      include BlacklightAdvancedSearch::Controller

      def search

        begin
          @set = fetch_solr_document
        rescue ActiveFedora::ObjectNotFoundError
          render json: {error: "A valid starting id is required"} and return
        end

        self.solr_search_params_logic += [:limit_to_scope]

        (@response, @document_list) = get_search_results
        @pagination = paginate_params(@response)
        render json: {error: "There were no results matching your query.", pagination: @pagination} and return
        if @pagination.total_count == 0

        end

        if @pagination.current_page > @pagination.num_pages
          render json: {error: "The page you've requested is more than is available.", pagination: @pagination} and return
        end

        render json: {pagination: @pagination, response: @response}
      end

      protected

        def limit_to_scope(solr_parameters, user_parameters)
          descendents = @set.combined_set_descendents

          # Limit query to items that are set descendents
          # or files off set descendents
          query = descendents.map do |set|
            p = set.pid
            set = "id:\"#{p}\" OR is_member_of_ssim:\"info:fedora/#{p}\""
          end

          # Ensure files directly on scoping collection are added in
          # as well
          query << "is_member_of_ssim:\"info:fedora/#{@set.pid}\""

          fq = query.join(" OR ")

          solr_parameters[:fq] ||= []
          solr_parameters[:fq] << fq
        end

    end
  end
end
