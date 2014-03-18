# Copyright © 2012 The Pennsylvania State University
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# -*- encoding : utf-8 -*-
module Drs
  module SolrDocumentBehavior
    def title_or_label
      title || label
    end

    def pid
      Array(self[:id]).first
    end

    def date_of_issue
      #TODO - this is broken in metadata assignment
      Array(self[Solrizer.solr_name("desc_metadata__date_created")]).first
    end

    def create_date
      Array(self[Solrizer.solr_name("desc_metadata__date_created")]).first
    end

    def creators
      Array(self[Solrizer.solr_name("desc_metadata__creator")])
    end

    def type_label
      if self.klass == "NuCoreFile" && !self.canonical_object.nil?
        return I18n.t("drs.display_labels.#{self.canonical_object.klass}.name")
      end
      I18n.t("drs.display_labels.#{self.klass}.name")
    end

    def thumbnail_list
      Array(self[Solrizer.solr_name("thumbnail_list", :stored_searchable)])
    end

    def klass
      Array(self[Solrizer.solr_name("active_fedora_model", :stored_sortable)]).first
    end

    def parent
      Array(self[Solrizer.solr_name("parent_id", :stored_searchable)]).first
    end

    def content_objects(canonical = false)
      all_possible_models = [ "ImageSmallFile", "ImageMediumFile", "ImageLargeFile",
                              "ImageMasterFile", "ImageThumbnailFile", "MsexcelFile",
                              "MspowerpointFile", "MswordFile", "PdfFile", "TextFile",
                              "ZipFile", "AudioFile", "VideoFile" ]
      models_stringified = all_possible_models.inject { |base, str| base + " or #{str}" }
      models_query = ActiveFedora::SolrService.escape_uri_for_query models_stringified
      full_self_id = ActiveFedora::SolrService.escape_uri_for_query "info:fedora/#{self.pid}"

      if canonical
        query_result = ActiveFedora::SolrService.query("canonical_tesim:yes AND is_part_of_ssim:#{full_self_id}", rows: 999)
      else
        query_result = ActiveFedora::SolrService.query("active_fedora_model_ssi:(#{models_stringified}) AND is_part_of_ssim:#{full_self_id}", rows: 999)
      end

      docs = query_result.map { |x| SolrDocument.new(x) }
    end

    def canonical_object
      self.content_objects(true).first
    end

    ##
    # Give our SolrDocument an ActiveModel::Naming appropriate route_key
    def route_key
      get(Solrizer.solr_name('has_model', :symbol)).split(':').last.downcase
    end

    ##
    # Offer the source (ActiveFedora-based) model to Rails for some of the
    # Rails methods (e.g. link_to).
    # @example
    #   link_to '...', SolrDocument(:id => 'bXXXXXX5').new => <a href="/dams_object/bXXXXXX5">...</a>
    def to_model
      m = ActiveFedora::Base.load_instance_from_solr(id, self)
      return self if m.class == ActiveFedora::Base
      m
    end

    def noid
      self[Solrizer.solr_name('noid', Sufia::GenericFile.noid_indexer)]
    end

    def date_uploaded
      field = self[Solrizer.solr_name("desc_metadata__date_uploaded", :stored_sortable, type: :date)]
      return unless field.present?
      begin
        Date.parse(field).to_formatted_s(:standard)
      rescue
        logger.info "Unable to parse date: #{field.first.inspect} for #{self['id']}"
      end
    end

    def depositor(default = '')
      val = Array(self[Solrizer.solr_name("depositor")]).first
      val.present? ? val : default
    end

    def title
      #Array(self[Solrizer.solr_name('desc_metadata__title')]).first
      Array(self[Solrizer.solr_name("title", :stored_sortable)]).first
    end

    def description
      #Array(self[Solrizer.solr_name('desc_metadata__description')]).first
      Array(self[Solrizer.solr_name("abstract", :stored_searchable)]).first
    end

    def label
      Array(self[Solrizer.solr_name('label')]).first
    end

    def file_format
       Array(self[Solrizer.solr_name('file_format')]).first
    end

    def creator
      Array(self[Solrizer.solr_name("desc_metadata__creator")]).first
    end

    def tags
      Array(self[Solrizer.solr_name("desc_metadata__tag")])
    end

    def mime_type
      Array(self[Solrizer.solr_name("mime_type")]).first
    end

    def read_groups
      Array(self[Ability.read_group_field])
    end

    def edit_groups
      Array(self[Ability.edit_group_field])
    end

    def edit_people
      Array(self[Ability.edit_person_field])
    end

    def public?
      read_groups.include?('public')
    end

    def registered?
      read_groups.include?('registered')
    end


    def pdf?
      ['application/pdf'].include? self.mime_type
    end

    def image?
      ['image/png','image/jpeg', 'image/jpg', 'image/jp2', 'image/bmp', 'image/gif'].include? self.mime_type
    end

    def video?
      ['video/mpeg', 'video/mp4', 'video/webm', 'video/x-msvideo', 'video/avi', 'video/quicktime', 'application/mxf'].include? self.mime_type
    end

    def audio?
      # audio/x-wave is the mime type that fits 0.6.0 returns for a wav file.
      # audio/mpeg is the mime type that fits 0.6.0 returns for an mp3 file.
      ['audio/mp3', 'audio/mpeg', 'audio/x-wave', 'audio/x-wav', 'audio/ogg'].include? self.mime_type
    end
  end
end
