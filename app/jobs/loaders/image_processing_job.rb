class Loaders::ImageProcessingJob
  def queue_name
    :loader_image_processing
  end

  def run
    # extract metadata from iptc
    # if theres an exception, log details to file_report
  end
end
