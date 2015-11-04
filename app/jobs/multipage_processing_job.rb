include Cerberus::ThumbnailCreation

class MultipageProcessingJob
  attr_accessor :dir_path, :file_values, :core_file, :report_id

  def queue_name
    :loader_multipage_processing
  end

  def initialize(dir_path, file_values, core_file, report_id)
    self.dir_path = dir_path
    self.file_values = file_values
    self.core_file = core_file
    self.report_id = report_id
  end

  def run
    load_report = Loaders::LoadReport.find(report_id)
    file_path = self.dir_path + "/" + self.file_values["file_name"]

    # test file_path
    if File.exists?(file_path)

      # Create thumbnail obj
      thumb = PageFile.new(pid: Cerberus::Noid.namespaceize(Cerberus::IdService.mint))

      thumb.title                  = self.file_values["title"]
      thumb.identifier             = thumb.pid
      thumb.keywords               = self.core_file.keywords.flatten unless self.core_file.keywords.nil?
      thumb.depositor              = self.core_file.depositor
      thumb.proxy_uploader         = self.core_file.proxy_uploader
      thumb.core_record            = self.core_file
      thumb.rightsMetadata.content = self.core_file.rightsMetadata.content
      thumb.ordinal_value          = self.file_values["sequence"]
      thumb.ordinal_last           = self.file_values["last_item"] unless self.file_values["last_item"].nil?
      thumb.save!

      create_all_thumbnail_sizes(file_path, thumb.pid)
    else
      load_report.image_reports.create_failure("File not found in zip file", "", self.file_values["file_name"])
      self.core_file.destroy
      return
    end

    if self.file_values["sequence"] == "1"
      # Make thumbnails for core_file
      thumbnail_list = []
      for i in 1..5 do
        thumbnail_list << "/downloads/#{thumb.pid}?datastream_id=thumbnail_#{i}"
      end

      self.core_file.thumbnail_list = thumbnail_list
      self.core_file.save!
    end
  end

end
