class ProcessMultipageZipJob
  include SpreadsheetHelper
  include XmlValidator
  include ApplicationHelper

  attr_accessor :loader_name, :zip_path, :parent, :copyright, :current_user, :permissions, :client

  def queue_name
    :multipage_process_zip
  end

  def initialize(loader_name, zip_path, parent, copyright, current_user, permissions, client=nil)
    self.loader_name = loader_name
    self.zip_path = zip_path
    self.parent = parent
    self.copyright = copyright
    self.current_user = current_user
    self.permissions = permissions
    self.client = client
  end

  def run
    report_id = Loaders::LoadReport.create_from_strings(current_user, 0, loader_name, parent)
    load_report = Loaders::LoadReport.find(report_id)

    # unzip zip file to tmp storage
    dir_path = File.join(File.dirname(zip_path), File.basename(zip_path, ".*"))
    spreadsheet_file_path = unzip(zip_path, dir_path)

    process_spreadsheet(dir_path, spreadsheet_file_path, load_report)
  end

  def process_spreadsheet(dir_path, spreadsheet_file_path, load_report)
    count = 0
    spreadsheet = load_spreadsheet(spreadsheet_file_path)

    header_position = 1
    header_row = spreadsheet.row(header_position)

    core_file = nil
    seq_num = -1

    spreadsheet.each_row_streaming(offset: header_position) do |row|
      if row.present? && header_row.present?
        row_results = process_a_row(header_row, row)

        row_num = row_results["sequence"].to_i

        # if row_results ordinal 0
        if row_num == 0
          count = count + 1
          load_report.save!
          load_report.update_counts
          
          core_file = CoreFile.new(pid: Cerberus::Noid.namespaceize(Cerberus::IdService.mint))
          core_file.depositor = "000000000"
          core_file.parent = Collection.find(parent)
          core_file.properties.parent_id = core_file.parent.pid
          core_file.properties.ordinal_value = "0"
          core_file.tag_as_in_progress
          core_file.title = row_results["title"]
          core_file.properties.original_filename = row_results["file_name"]
          core_file.label = row_results["file_name"]

          permissions['CoreFile'].each do |perm, vals|
            vals.each do |group|
              core_file.rightsMetadata.permissions({group: group}, "#{perm}")
            end
          end

          core_file.save!
          seq_num = row_num

          xml_file_path = dir_path + "/" + row_results["file_name"]
          if !xml_file_path.blank? && File.exists?(xml_file_path) && File.extname(xml_file_path) == ".xml"
            # Load mods xml and cleaning
            raw_xml = xml_decode(File.open(xml_file_path, "rb").read)

            # Validate
            validation_result = xml_valid?(raw_xml)

            if validation_result[:errors].blank?
              core_file.mods.content = raw_xml
              core_file.save!
              core_file.match_dc_to_mods
            else
              # Raise error, invalid mods
              load_report.image_reports.create_failure("Invalid MODS", validation_result[:errors], row_results["file_name"])

              # Delete unfinished core_file
              core_file.destroy
              # Reset count
              core_file = nil
              seq_num = -1
            end
          else
            # Raise error, can't load core file mods metadata
            load_report.image_reports.create_failure("Can't load MODS XML", "", row_results["file_name"])

            # Delete unfinished core_file
            core_file.destroy
            # Reset count
            core_file = nil
            seq_num = -1
          end
        end

        if row_num > 0
          if !(row_num == seq_num + 1)
            if !core_file.blank?
              load_report.image_reports.create_failure("Row is out of order - row num #{row_num} seq_num #{seq_num}", "", row_results["file_name"])
              core_file.destroy
              core_file = nil
            end
          elsif !core_file.blank?
            MultipageProcessingJob.new(dir_path, row_results, core_file, load_report.id).run

            if row_results["last_item"] == "TRUE"
              load_report.image_reports.create_success(core_file, "")
              if !core_file.blank?
                core_file.tag_as_completed
                core_file.save!
              end

              # reset for next paged item
              core_file = nil
              seq_num = -1
            else
              # Keep on goin'
              seq_num = row_num
            end
          end
        end
      end
    end

    load_report.number_of_files = count
    if load_report.success_count + load_report.fail_count + load_report.modified_count == load_report.number_of_files
      LoaderMailer.load_alert(load_report, User.find_by_nuid(load_report.nuid)).deliver!
    end
    load_report.save!

    # Cleanup
    FileUtils.rm_rf dir_path
  end

  def process_a_row(header_row, row_value)
    results = Hash.new
    results["file_name"]         = find_in_row(header_row, row_value, 'Filename')
    results["title"]             = find_in_row(header_row, row_value, 'Title')
    results["parent_filename"]   = find_in_row(header_row, row_value, 'Parent Filename')
    results["sequence"]          = find_in_row(header_row, row_value, 'Sequence')
    results["last_item"]         = find_in_row(header_row, row_value, 'Last Item')
    return results
  end

  def find_in_row(header_row, row_value, column_identifier)
    0.upto header_row.length do |row_pos|
      case header_row[row_pos]
        when column_identifier
          return row_value[row_pos].to_s
      end
    end
    return nil
  end

  def unzip(file, dir_path)
    spreadsheet_file_path = ""

    Zip::File.open(file) do |zipfile|
      FileUtils.mkdir(dir_path) unless File.exists? dir_path
      count = 0

      # Extract all files
      zipfile.each do |f|
        if !f.directory? && File.basename(f.name)[0] != "." # Don't extract directories or mac specific files
          fpath = File.join(dir_path, f.name)
          FileUtils.mkdir_p(File.dirname(fpath))
          zipfile.extract(f, fpath) unless File.exist?(fpath)
        end
      end

      # Find the spreadsheet
      xlsx_array = Dir.glob("#{dir_path}/*.xlsx")

      if xlsx_array.length > 1
        raise Exceptions::MultipleSpreadsheetError
      elsif xlsx_array.length == 0
        raise Exceptions::NoSpreadsheetError
      end

      spreadsheet_file_path = xlsx_array.first
    end

    FileUtils.rm(file)
    return spreadsheet_file_path
  end
end
