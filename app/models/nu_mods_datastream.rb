class NuModsDatastream < ActiveFedora::OmDatastream 
  include OM::XML::Document 

  set_terminology do |t|
    t.root(path: 'mods', 'xmlns:mods' => 'http://www.loc.gov/mods/v3', 'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance', 'xsi:schemaLocation' => 'http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-4.xsd')
    t.mods_title_info(path: 'titleInfo', namespace_prefix: 'mods'){
      t.mods_title(path: 'title', namespace_prefix: 'mods') 
    }
    t.mods_abstract(path: 'abstract', namespace_prefix: 'mods')
    t.mods_personal_name(path: 'name', namespace_prefix: 'mods', attributes: { type: 'personal' }){
      t.mods_first_name(path: 'namePart', namespace_prefix: 'mods', attributes: { type: 'given' }) 
      t.mods_last_name(path: 'namePart', namespace_prefix: 'mods', attributes: { type: 'family' }) 
    }
    t.mods_corporate_name(path: 'name', namespace_prefix: 'mods', attributes: { type: 'corporate' }){
      t.mods_full_corporate_name(path: 'namePart') 
    } 
    t.mods_origin_info(path: 'originInfo', namespace_prefix: 'mods'){
      t.mods_date_issued(path: 'dateIssued', namespace_prefix: 'mods', attributes: { encoding: 'w3cdtf', keyDate: 'yes' })
    }
    t.mods_citation(path: 'note', namespace_prefix: 'mods', attributes: { type: 'citation' }) 
    t.mods_subject(path: 'subject', namespace_prefix: 'mods'){
      t.mods_keyword(path: 'topic', namespace_prefix: 'mods') 
    }
    t.mods_identifier(path: 'identifier', namespace_prefix: 'mods')
    t.mods_type_of_resource(path: 'typeOfResource', namespace_prefix: 'mods'){
      t.mods_is_collection(path: { attribute: 'collection' })
    }

    t.mods_title(proxy: [:mods_title_info, :mods_title])
    t.mods_full_corporate_name(proxy: [:mods_corporate_name, :mods_full_corporate_name]) 
  end

  def self.xml_template 
    builder = Nokogiri::XML::Builder.new do |xml|
      xml.mods('xmlns:mods' => 'http://www.loc.gov/mods/v3', 'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
                'xsi:schemaLocation' => 'http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-4.xsd'){ 
        xml.parent.namespace = xml.parent.namespace_definitions.find { |ns| ns.prefix=="mods" } 
        xml['mods'].titleInfo
        xml['mods'].abstract
        xml['mods'].name('type' => 'personal')
        xml['mods'].name('type' => 'corporate') 
        xml['mods'].originInfo
        xml['mods'].note('type' => 'citation') 
        xml['mods'].subject
        xml['mods'].identifier
        xml['mods'].typeOfResource 
      }
    end
    builder.doc 
  end

  def assign_creator_personal_name(first_name, last_name)
    if first_name.blank? && last_name.blank?
      return true 
    elsif first_name.blank? || last_name.blank? 
      raise "Must pass both a first and a last name for a personal creator to be complete." 
    else 
      self.mods_personal_name.mods_first_name = first_name 
      self.mods_personal_name.mods_last_name = last_name 
    end
  end

  def mass_mods_keywords(array)
    self.mods_subject.mods_keyword = array
  end
end