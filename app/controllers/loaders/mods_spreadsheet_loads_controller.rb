class Loaders::ModsSpreadsheetLoadsController < Loaders::LoadsController
  before_filter :verify_group
  require 'stanford-mods'
  include ModsDisplay::ControllerExtension

  def new
    query_result = ActiveFedora::SolrService.query("active_fedora_model_ssi:\"Collection\"", :fl => "id, title_tesim", :rows => 999999999, :sort => "id asc")
    @collections_options = Array.new()
    query_result.each do |c|
      if current_user.can?(:edit, c['id'])
        @collections_options << {'label' => "#{c['id']} - #{c['title_tesim'][0]}", 'value' => c['id']}
      end
    end
    @loader_name = t('drs.loaders.'+t('drs.loaders.mods_spreadsheet.short_name')+'.long_name')
    @loader_short_name = t('drs.loaders.mods_spreadsheet.short_name')
    @page_title = @loader_name + " Loader"
    render 'loaders/new', locals: { collections_options: @collections_options}
  end

  def create
    permissions = {"CoreFile" => {"read"  => ["public"], "edit" => ["northeastern:drs:repository:staff"]}}
    process_create(permissions, t('drs.loaders.mods_spreadsheet.short_name'), "ModsSpreadsheetLoadsController")
  end

  def preview
    @core_file = CoreFile.first #TODO: hook this in the with the job, just hardcoded for now
    @mods_html = render_mods_display(CoreFile.find(@core_file.pid)).to_html.html_safe
    @report = Loaders::LoadReport.find(params[:id])
    @user = User.find_by_nuid(@report.nuid)
    @collection_title = ActiveFedora::SolrService.query("id:\"#{@report.collection}\"", :fl=>"title_tesim")
    @collection_title = @collection_title[0]['title_tesim'][0]
    if @collection_title.blank?
      @collection_title = "N/A"
    end
    render 'loaders/preview'
  end

  def preview_compare
    @core_file = CoreFile.first #TODO: hook this in the with the job, just hardcoded for now
    old_core = CoreFile.all[2] #TODO: hook this is in with the job
    @diff = mods_diff(@core_file, old_core)
    @diff_css = Diffy::CSS
    @mods_html = render_mods_display(CoreFile.find(@core_file.pid)).to_html.html_safe
    @report = Loaders::LoadReport.find(params[:id])
    @user = User.find_by_nuid(@report.nuid)
    @collection_title = ActiveFedora::SolrService.query("id:\"#{@report.collection}\"", :fl=>"title_tesim")
    @collection_title = @collection_title[0]['title_tesim'][0]
    if @collection_title.blank?
      @collection_title = "N/A"
    end
    render 'loaders/preview'
  end

  private

    def verify_group
      redirect_to new_user_session_path if current_user.nil?
      redirect_to root_path unless current_user.mods_spreadsheet_loader?
    end

    def mods_diff(core_file_a, core_file_b)
      mods_a = Nokogiri::XML(core_file_a.mods.content).to_s
      mods_b = Nokogiri::XML(core_file_b.mods.content).to_s
      return Diffy::Diff.new(mods_a, mods_b, :include_plus_and_minus_in_html => true, :context => 1).to_s(:html).html_safe
    end

    def unzip(file, dir_path)
      spreadsheet_file_path = ""
      FileUtils.mkdir(dir_path) unless File.exists? dir_path

      # Extract load zip
      file_list = safe_unzip(file, dir_path)

      # Find the spreadsheet
      xlsx_array = Dir.glob("#{dir_path}/*.xlsx")

      if xlsx_array.length > 1
        raise Exceptions::MultipleSpreadsheetError
      elsif xlsx_array.length == 0
        raise Exceptions::NoSpreadsheetError
      end

      spreadsheet_file_path = xlsx_array.first

      FileUtils.rm(file)
      return spreadsheet_file_path
    end
end
